// Mirrors the pipeline style already used by the sibling monorepo (e:\blue) —
// same Jenkins server, same conventions (pollSCM instead of a webhook since
// Jenkins isn't publicly reachable, Docker-per-stage agents, build discard).
//
// NOTE: this Jenkinsfile alone doesn't make Jenkins build this repo — a
// Pipeline job pointed at this repo's URL (using "Pipeline script from SCM")
// still needs to be created on the Jenkins server itself, which needs admin
// access this session doesn't have. See the README's CI/CD note.
pipeline {
    agent none

    options {
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '15'))
    }

    triggers {
        pollSCM('H/5 * * * *')
    }

    stages {
        stage('Analyze & Test') {
            agent {
                // Cirrus Labs' image — actively maintained, includes the
                // Flutter SDK + Android toolchain, widely used for Flutter CI.
                docker {
                    image 'ghcr.io/cirruslabs/flutter:stable'
                }
            }
            steps {
                sh '''
                    flutter --version
                    flutter pub get
                    flutter analyze
                    flutter test
                '''
            }
        }

        stage('Build (debug smoke test)') {
            agent {
                docker {
                    image 'ghcr.io/cirruslabs/flutter:stable'
                }
            }
            steps {
                // Compile-smoke-test only — confirms the Android toolchain
                // still builds (the kind of thing a package-id rename could
                // silently break). Not a release build: that needs the
                // signing keystore, which isn't wired into this pipeline yet
                // (see android/app/build.gradle.kts's signingConfigs and the
                // ANDROID_KEYSTORE_* credentials this job would need once
                // that lands).
                sh 'flutter build apk --debug'
            }
        }

        // No Deploy stage. Unlike e:\blue's web/API services (which deploy by
        // recreating docker-compose containers), a Flutter app's "deploy" is
        // publishing a signed artifact to the Play Store / App Store / an
        // internal distribution channel (Firebase App Distribution, etc) —
        // a fundamentally different, manual, business-decision-gated process
        // that doesn't belong in an automatic on-every-push pipeline stage.
        // Add it deliberately later, not by copying this pattern.
    }

    post {
        failure {
            echo 'Build gagal — cek log stage di atas.'
        }
        success {
            echo 'Build sukses.'
        }
    }
}
