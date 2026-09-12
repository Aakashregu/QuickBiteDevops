pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
        timeout(time: 20, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        // Edit these TWO non-secret values before your first build.
        DOCKERHUB_NAMESPACE = 'stakeplayer999'
        APP_HOST = '10.20.1.229'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git log -1 --oneline'
            }
        }

        stage('Build') {
            steps {
                sh '''
                    set -eu
                    docker build --pull -t "quickbite-local:${BUILD_NUMBER}" .
                '''
            }
        }

        stage('Tag') {
            steps {
                sh '''
                    set -eu
                    docker tag "quickbite-local:${BUILD_NUMBER}" \
                      "${DOCKERHUB_NAMESPACE}/quickbite-frontend:${BUILD_NUMBER}"
                '''
            }
        }

        stage('Push') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKERHUB_USER',
                    passwordVariable: 'DOCKERHUB_TOKEN'
                )]) {
                    sh '''
                        set +x
                        set -eu
                        export DOCKER_CONFIG="$(mktemp -d)"
                        trap 'docker logout >/dev/null 2>&1 || true; rm -rf "$DOCKER_CONFIG"' EXIT
                        printf '%s' "$DOCKERHUB_TOKEN" | docker login \
                          --username "$DOCKERHUB_USER" --password-stdin
                        docker push "${DOCKERHUB_NAMESPACE}/quickbite-frontend:${BUILD_NUMBER}"
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                sshagent(credentials: ['app-server-ssh']) {
                    sh '''
                        set -eu
                        bash scripts/deploy.sh "$APP_HOST" \
                          "${DOCKERHUB_NAMESPACE}/quickbite-frontend:${BUILD_NUMBER}"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "QuickBite deployment succeeded. Image tag: ${env.BUILD_NUMBER}"
        }
        failure {
            echo 'Check the first failed stage and its Console Output. Do not expose credentials.'
        }
    }
}
