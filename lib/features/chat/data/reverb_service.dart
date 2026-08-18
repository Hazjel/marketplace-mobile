import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/core/network/api_client.dart';
import 'package:blukios_marketplace/features/chat/models/chat_models.dart';

/// Reverb (Pusher-protocol) websocket client for chat.
///
/// Written directly against [WebSocketChannel] rather than using
/// `pusher_channels_flutter`: that package pins to Pusher's hosted
/// cluster model and exposes no way to point at a self-hosted Reverb
/// host, and its newer versions conflict with flutter_secure_storage.
/// The protocol itself is only a handful of JSON frames.
///
/// Laravel broadcasts `MessageSent` on `private-chat.{receiverId}`, and
/// channel authorization only allows subscribing to your own id — so a
/// user has exactly one channel carrying everything addressed to them.
class ReverbService {
  final ApiClient _apiClient;

  ReverbService(this._apiClient);

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String? _socketId;
  String? _userId;
  void Function(MessageModel)? _onMessage;

  /// Additional private channels subscribed on this same socket — e.g.
  /// `transaction.{id}` for live status updates. Pusher protocol allows
  /// multiple `pusher:subscribe` frames per connection, so this rides the
  /// one socket already open for chat rather than opening a second one.
  /// Keyed by channel name; re-subscribed automatically on (re)connect.
  final Map<String, void Function(Map<String, dynamic>)> _extraChannels = {};

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _disposed = false;

  /// Socket id of the live connection, sent as `X-Socket-ID` when posting
  /// a message so the server's `->toOthers()` skips our own echo.
  String? get socketId => _socketId;

  bool get isConnected => _channel != null;

  Uri get _wsUri {
    final scheme = ApiConfig.reverbUseTLS ? 'wss' : 'ws';
    // nginx proxies /app to the reverb container, so this rides the
    // normal web port rather than hitting 8080 directly.
    return Uri.parse(
      '$scheme://${ApiConfig.reverbHost}/app/${ApiConfig.reverbAppKey}'
      '?protocol=7&client=dart&version=1.0',
    );
  }

  Future<void> connect({
    required String userId,
    required void Function(MessageModel) onMessage,
  }) async {
    if (_channel != null) return;

    _disposed = false;
    _userId = userId;
    _onMessage = onMessage;

    try {
      final channel = WebSocketChannel.connect(_wsUri);
      _channel = channel;

      _subscription = channel.stream.listen(
        _handleFrame,
        onError: (error) {
          debugPrint('Reverb socket error: $error');
          _scheduleReconnect();
        },
        onDone: _scheduleReconnect,
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Reverb connect failed: $e');
      _scheduleReconnect();
    }
  }

  Future<void> _handleFrame(dynamic raw) async {
    try {
      final frame = jsonDecode(raw as String);
      if (frame is! Map) return;

      final event = frame['event'] as String? ?? '';
      final data = frame['data'];

      switch (event) {
        case 'pusher:connection_established':
          // data is itself a JSON *string* here, not an object.
          final payload = data is String ? jsonDecode(data) : data;
          _socketId = payload is Map ? payload['socket_id']?.toString() : null;
          _reconnectAttempts = 0;
          await _subscribeToOwnChannel();
          for (final channelName in _extraChannels.keys) {
            await _authAndSubscribe(channelName);
          }
          break;

        case 'pusher:ping':
          _send({'event': 'pusher:pong', 'data': {}});
          break;

        case 'pusher:error':
          debugPrint('Reverb protocol error: $data');
          break;

        default:
          // No broadcastAs() on the PHP events, so the wire name is the
          // fully-qualified class name.
          if (event.contains('MessageSent')) {
            _handleMessageEvent(data);
            break;
          }

          final channelName = frame['channel'] as String?;
          final handler =
              channelName != null ? _extraChannels[channelName] : null;
          if (handler != null) {
            final payload = data is String ? jsonDecode(data) : data;
            if (payload is Map) {
              handler(Map<String, dynamic>.from(payload));
            }
          }
      }
    } catch (e) {
      debugPrint('Failed to handle Reverb frame: $e');
    }
  }

  void _handleMessageEvent(dynamic data) {
    final payload = data is String ? jsonDecode(data) : data;
    if (payload is! Map) return;

    // Payload shape: { "message": { ...message with sender... } }
    final message = payload['message'];
    if (message is! Map) return;

    _onMessage?.call(
      MessageModel.fromJson(Map<String, dynamic>.from(message)),
    );
  }

  Future<void> _subscribeToOwnChannel() async {
    final userId = _userId;
    if (userId == null) return;
    await _authAndSubscribe('private-chat.$userId');
  }

  /// Subscribes to an arbitrary additional private channel on this same
  /// socket (e.g. `transaction.{id}`), independent of the chat channel.
  /// [onEvent] receives the decoded payload of whatever event the channel
  /// broadcasts — callers key their own routing off its shape since a
  /// feature channel here only ever carries one event type.
  ///
  /// Safe to call before the socket has connected: the subscription is
  /// deferred and sent once `pusher:connection_established` arrives (and
  /// re-sent automatically on reconnect).
  Future<void> subscribeToChannel(
    String channelName, {
    required void Function(Map<String, dynamic> data) onEvent,
  }) async {
    _extraChannels[channelName] = onEvent;
    if (_socketId != null) {
      await _authAndSubscribe(channelName);
    }
  }

  void unsubscribeFromChannel(String channelName) {
    if (_extraChannels.remove(channelName) == null) return;
    _send({
      'event': 'pusher:unsubscribe',
      'data': {'channel': channelName},
    });
  }

  /// Shared by the chat channel and any [subscribeToChannel] caller: private
  /// channels require a server-signed auth token bound to this socket id.
  Future<void> _authAndSubscribe(String channelName) async {
    final socketId = _socketId;
    if (socketId == null) return;

    try {
      final response = await _apiClient.post(
        ApiConfig.broadcastAuth,
        data: {'socket_id': socketId, 'channel_name': channelName},
      );

      final auth = response.data['auth'];
      if (auth == null) {
        debugPrint('Reverb auth returned no token for $channelName');
        return;
      }

      _send({
        'event': 'pusher:subscribe',
        'data': {'channel': channelName, 'auth': auth},
      });
    } catch (e) {
      debugPrint('Reverb channel auth failed for $channelName: $e');
    }
  }

  void _send(Map<String, dynamic> frame) {
    _channel?.sink.add(jsonEncode(frame));
  }

  /// Backs off exponentially, capped at 30s, so a server restart doesn't
  /// turn into a reconnect storm.
  void _scheduleReconnect() {
    if (_disposed || _reconnectTimer != null) return;

    _channel = null;
    _socketId = null;

    final delaySeconds = (1 << _reconnectAttempts).clamp(1, 30);
    _reconnectAttempts = (_reconnectAttempts + 1).clamp(0, 5);

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _reconnectTimer = null;
      final userId = _userId;
      final onMessage = _onMessage;
      if (_disposed || userId == null || onMessage == null) return;
      connect(userId: userId, onMessage: onMessage);
    });
  }

  Future<void> disconnect() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _subscription?.cancel();
    await _channel?.sink.close();

    _subscription = null;
    _channel = null;
    _socketId = null;
    _userId = null;
    _onMessage = null;
    _extraChannels.clear();
    _reconnectAttempts = 0;
  }
}
