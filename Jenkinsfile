pipeline {
    
    agent any

    environment {
        // Docker Hub credentials configured in Jenkins (replace with your IDs)
        DOCKER_REGISTRY = "docker.io"
        DOCKER_CREDENTIALS_ID = "docker-registry-credentials"
        IMAGE_NAME = "sweetyraj22/e-learning-site"
        
        // Kubernetes namespace
        K8S_NAMESPACE = "default"
        K8S_DEPLOYMENT_NAME = "e-learning-site"
    }

    options {
        // Prevent multiple concurrent builds
        disableConcurrentBuilds()
        // Keep logs for 10 builds
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
                git branch: 'main', url: 'https://github.com/Sweety083/E-Learning-Website-HTML-CSS.git', credentialsId: 'github-credentials'
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
                    // Fetch current deployment version
                    def currentColor = sh(script: "kubectl get deployment ${K8S_DEPLOYMENT_NAME}-blue -n ${K8S_NAMESPACE} --ignore-not-found -o jsonpath='{.metadata.name}' || echo ''", returnStdout: true).trim()
                    
                    def newColor = currentColor ? "green" : "blue"
                    
                    echo "Deploying new version to ${newColor} environment"
                    
                    // Update Kubernetes deployment manifest dynamically
                    sh """
                        sed 's#IMAGE_PLACEHOLDER#${IMAGE_NAME}:${IMAGE_TAG}#' k8s/service.yaml | kubectl apply -n ${K8S_NAMESPACE} -f -
                    """
                    
                    // Switch service to new deployment (Blue-Green)
                    sh """
                        kubectl patch service e-learning-service -n ${K8S_NAMESPACE} -p '{"spec":{"selector":{"app":"${K8S_DEPLOYMENT_NAME}-${newColor}"}}}'
                    """
                }
            }
        }
    }

    post {
        success {
            echo 'Deployment successful! 🚀'
        }
        failure {
            echo 'Deployment failed. Please check the logs.'
        }
    }
}



