// Mengikuti gaya pipeline monorepo web (repo marketplace) di Jenkins yang sama:
// pollSCM karena Jenkins tidak publicly reachable, dan build discard.
//
// CATATAN: Jenkinsfile ini sendiri tidak membuat Jenkins membangun repo ini.
// Job Pipeline "Pipeline script from SCM" yang menunjuk repo ini harus dibuat
// sekali di server Jenkins. Jenkins itu memakai "Full Control Once Logged In",
// jadi akun Jenkins mana pun bisa membuatnya; langkahnya di README bagian CI/CD.

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

// Image Cirrus Labs: Flutter SDK + toolchain Android. Di-pin, bukan :stable --
// rilis baru bisa membawa lint baru yang memerahkan build tanpa perubahan kode.
// Cirrus tertinggal dari rilis Flutter (laptop rilis memakai 3.47.4, tag Cirrus
// terbaru 3.44.0); pubspec.lock hanya butuh Flutter >= 3.38.4. Naikkan dengan
// sengaja begitu tag yang lebih baru terbit.
FLUTTER_IMAGE = 'ghcr.io/cirruslabs/flutter:3.44.0'

// SDK di image dimiliki root (Dockerfile Cirrus: chown -R root:root /sdks/flutter).
// Sebagai uid Jenkins, git menolak repo SDK ("dubious ownership") dan flutter tidak
// bisa menulis lockfile cache-nya, jadi container jalan sebagai root (argumen -u
// terakhir menang atas -u bawaan runInContainer). Akibatnya file yang dibuat di
// workspace (.dart_tool, build/) milik root: setiap skrip mengembalikannya ke uid
// Jenkins saat keluar, kalau tidak checkout berikutnya gagal menghapusnya.
//
// Cache pub dan Gradle di satu volume bernama: tanpa itu setiap build mengunduh
// ulang semua dependency, dan di disk host ini itu bagian termahal dari build.
CONTAINER_ARGS = '-u 0:0 -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" ' +
    '-e PUB_CACHE=/cache/pub -e GRADLE_USER_HOME=/cache/gradle -v blukios-mobile-ci-cache:/cache'
RESTORE_OWNER = 'trap \'chown -R "$HOST_UID:$HOST_GID" .\' EXIT\n'

pipeline {
    agent none

    parameters {
        // Default mati: build Gradle berat di disk host yang dipakai bersama pipeline
        // tim lain. Centang saat "Build with Parameters" kalau perlu memastikan
        // toolchain Android masih bisa membangun (mis. setelah upgrade Gradle/AGP).
        booleanParam(name: 'BUILD_DEBUG_APK', defaultValue: false,
            description: 'Juga build APK debug (berat, beberapa menit di disk host ini)')
    }

    options {
        // Longgar karena disk host lambat (fsync bisa lebih dari satu detik).
        // Batas ini hanya melindungi kerja di dalam step `sh`, bukan thread CPS.
        timeout(time: 360, unit: 'MINUTES')
        // Satu checkout per build: checkout otomatis per stage bisa mengambil
        // ujung main yang lebih baru dari yang dites stage sebelumnya.
        skipDefaultCheckout()
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
                checkout scm
                runInContainer(
                    name: 'analyze-test',
                    image: FLUTTER_IMAGE,
                    args: CONTAINER_ARGS,
                    script: RESTORE_OWNER + '''
                        flutter --version
                        flutter pub get --enforce-lockfile
                        flutter analyze
                        flutter test
                    '''
                )
            }
        }

        stage('Build debug APK') {
            agent any
            when {
                beforeAgent true
                expression { params.BUILD_DEBUG_APK }
            }
            steps {
                // Compile-smoke-test saja, bukan release: APK rilis di-sign dan
                // diterbitkan dari laptop ke GitHub Releases (README bagian Release).
                // NDK tidak ada di image dan diunduh Gradle saat pertama dibutuhkan;
                // volume sendiri supaya unduhan itu tidak terulang tiap build.
                runInContainer(
                    name: 'build-apk',
                    image: FLUTTER_IMAGE,
                    args: CONTAINER_ARGS + ' -v blukios-mobile-ci-ndk:/opt/android-sdk-linux/ndk',
                    script: RESTORE_OWNER + 'flutter build apk --debug\n'
                )
            }
        }

        // Tidak ada stage Deploy. "Deploy" aplikasi Flutter berarti menerbitkan
        // artefak yang sudah di-sign; itu keputusan rilis manual, bukan efek setiap push.
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
