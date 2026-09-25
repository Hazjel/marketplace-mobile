// Mengikuti gaya pipeline monorepo web (repo marketplace) di Jenkins yang sama:
// pollSCM karena Jenkins tidak publicly reachable, dan build discard.
//
// CATATAN: Jenkinsfile ini sendiri tidak membuat Jenkins membangun repo ini.
// Job Pipeline "Pipeline script from SCM" yang menunjuk repo ini harus dibuat
// di server Jenkins, dan itu butuh akses admin. Config siap pakai ada di
// ci/jenkins-job.xml, langkahnya di README bagian CI/CD.

// Pengganti agent { docker }: docker-workflow menjalankan docker stop di thread CPS yang dipotong
// setelah 5 menit, dan di host Jenkins ini docker stop bisa lebih lama karena disk lambat.
def runInContainer(Map opts) {
    String name = "blukios-mobile-ci-${env.BUILD_NUMBER}-${opts.name}"
    String scriptDir = "${env.WORKSPACE}@tmp/ci"
    dir(scriptDir) {
        writeFile file: "${opts.name}.sh", text: opts.script
    }
    try {
        sh """
            docker run --rm --name '${name}' \\
                --volumes-from "\$(cat /etc/hostname)" \\
                -u "\$(id -u):\$(id -g)" \\
                -w "\$(pwd)" \\
                --entrypoint sh \\
                ${opts.args ?: ''} \\
                '${opts.image}' -xe '${scriptDir}/${opts.name}.sh'
        """
    } finally {
        // Build yang di-abort membunuh docker CLI, bukan container-nya; --rm tidak sempat jalan.
        sh "docker rm -f '${name}' >/dev/null 2>&1 || true"
    }
}

// Image Cirrus Labs: Flutter SDK + toolchain Android, dipakai luas untuk CI Flutter.
FLUTTER_IMAGE = 'ghcr.io/cirruslabs/flutter:stable'
// Cache pub dan Gradle di volume bernama: tanpa ini setiap build mengunduh ulang
// seluruh dependency, dan di disk host ini itu bagian termahal dari build.
CACHE_ARGS = '-v blukios-mobile-pub-cache:/root/.pub-cache -v blukios-mobile-gradle:/root/.gradle'

pipeline {
    agent none

    options {
        // Longgar karena disk host lambat (fsync bisa lebih dari satu detik).
        // Batas ini hanya melindungi kerja di dalam step `sh`, bukan thread CPS.
        timeout(time: 360, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '15'))
    }

    triggers {
        pollSCM('H/5 * * * *')
    }

    stages {
        stage('Analyze & Test') {
            agent any
            steps {
                runInContainer(
                    name: 'analyze-test',
                    image: FLUTTER_IMAGE,
                    args: CACHE_ARGS,
                    script: '''
                        flutter --version
                        flutter pub get
                        flutter analyze
                        flutter test
                    '''
                )
            }
        }

        stage('Build (debug smoke test)') {
            agent any
            steps {
                // Compile-smoke-test saja: memastikan toolchain Android masih
                // bisa membangun (hal seperti rename package id bisa merusaknya
                // tanpa suara). Bukan release build: itu butuh keystore signing
                // yang belum di-wire ke pipeline ini (lihat signingConfigs di
                // android/app/build.gradle.kts dan kredensial ANDROID_KEYSTORE_*
                // yang job ini perlukan setelah itu ada).
                runInContainer(
                    name: 'build-apk',
                    image: FLUTTER_IMAGE,
                    args: CACHE_ARGS,
                    script: 'flutter build apk --debug'
                )
            }
        }

        // Tidak ada stage Deploy. Berbeda dari service web/API di repo marketplace
        // (yang deploy dengan me-recreate container docker-compose), "deploy" aplikasi
        // Flutter berarti menerbitkan artefak yang sudah di-sign ke Play Store, App Store,
        // atau kanal distribusi internal. Itu proses manual yang digerakkan keputusan
        // bisnis, jadi tidak pantas jadi stage otomatis di setiap push. Tambahkan
        // dengan sengaja nanti, bukan dengan menyalin pola ini.
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
