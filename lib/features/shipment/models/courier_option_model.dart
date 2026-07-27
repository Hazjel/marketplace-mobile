class CourierOptionModel {
  final String shippingName;
  final String serviceName;
  final double shippingCostNet;
  final String code;

  CourierOptionModel({
    required this.shippingName,
    required this.serviceName,
    required this.shippingCostNet,
    required this.code,
  });

  factory CourierOptionModel.fromJson(Map<String, dynamic> json) {
    return CourierOptionModel(
      shippingName: json['shipping_name'] ?? '',
      serviceName: json['service_name'] ?? '',
      shippingCostNet: (json['shipping_cost_net'] ?? 0).toDouble(),
      code: (json['code'] ?? '').toString(),
    );
  }
}
