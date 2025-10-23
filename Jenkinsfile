pipeline {
    agent any

    environment {
        DOCKER_REGISTRY = "docker.io"
        DOCKER_CREDENTIALS_ID = "dockerhub"
        IMAGE_NAME = "sweetyraj22/e-learning-site"
        K8S_NAMESPACE = "default"
    }

    options {
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {

        stage('Clean Workspace') {
            steps {
                deleteDir()
            }
        }

        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/Sweety083/E-Learning-Website-HTML-CSS.git', credentialsId: '1adc61e3-4dbc-48f9-bc77-8646123f5f2c'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    def commitHash = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.IMAGE_TAG = "${commitHash}"
                    sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(credentialsId: "${DOCKER_CREDENTIALS_ID}", usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh """
                        echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin ${DOCKER_REGISTRY}
                        docker push ${IMAGE_NAME}:${IMAGE_TAG}
                    """
                }
            }
        }

        stage('Deploy to Kubernetes (Blue-Green)') {
            steps {
                script {
                    def activeColor = sh(script: "kubectl get svc e-learning-service -o=jsonpath='{.spec.selector.version}' || echo blue", returnStdout: true).trim()
                    def newColor = activeColor == "blue" ? "green" : "blue"
                    echo "Switching traffic from ${activeColor} to ${newColor}"

                    sh """
                        sed 's#IMAGE_PLACEHOLDER#${IMAGE_NAME}:${IMAGE_TAG}#' k8s/deployment-${newColor}.yaml | kubectl apply -f -
                        kubectl patch svc e-learning-service -p '{"spec":{"selector":{"app":"e-learning-site","version":"${newColor}"}}}'
                        kubectl rollout status deployment/e-learning-site-${newColor}
                    """
                }
            }
        }
    }

    post {
        success {
            echo '✅ Blue-Green Deployment completed successfully!'
        }
        failure {
            echo '❌ Deployment failed. Please check the Jenkins logs.'
        }
    }
}
