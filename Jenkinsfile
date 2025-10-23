pipeline {
    agent any

    environment {
        IMAGE_NAME = "elearning-website"
        DOCKERHUB_USER = "rujairj"
        IMAGE_TAG = "${BUILD_NUMBER}"
        KUBE_NAMESPACE = 'default'
    }

    stages {
        stage('Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/rujaiananth/E-Learning'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh "docker build -t ${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG} ."
                }
            }
        }

        stage('Push to DockerHub') {
            steps {
                script {
                    // Use Jenkins usernamePassword credential (id: dockerhub-credentials)
                    withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
                        sh "docker push ${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"
                    }
                }
            }
        }

        stage('Deploy / Update Green') {
            steps {
                script {
                    // Ensure green deployment exists (first time apply will create)
                    sh 'kubectl apply -f k8s/green-deployment.yaml'

                    // Update image of elearning container in elearning-green deployment
                    sh "kubectl set image deployment/elearning-green elearning=${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG} -n ${KUBE_NAMESPACE}"

                    // Wait for rollout to complete
                    sh "kubectl rollout status deployment/elearning-green -n ${KUBE_NAMESPACE} --timeout=120s"
                }
            }
        }

        stage('Switch Service to Green') {
            steps {
                script {
                    // Patch service to point to green pods
                    sh "kubectl patch service elearning-service -n ${KUBE_NAMESPACE} -p '{\"spec\":{\"selector\":{\"app\":\"elearning\",\"version\":\"green\"}}}'"
                }
            }
        }

        stage('Optional: Cleanup Blue') {
            steps {
                script {
                    // Optionally remove the blue deployment after successful switch.
                    // Keep this step safe by ignoring errors.
                    sh "kubectl delete deployment elearning-blue -n ${KUBE_NAMESPACE} || true"
                }
            }
        }
    }

    post {
        always {
            echo "Pipeline finished. IMAGE=${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"
        }
    }
}
pipeline {
    agent any

    environment {
        IMAGE_NAME = "elearning-website"
        DOCKERHUB_USER = "rujairj"
        IMAGE_TAG = "${BUILD_NUMBER}"
        KUBE_NAMESPACE = 'default'
    }

    stages {
        stage('Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/Sweety083/E-Learning-Website-HTML-CSS'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh "docker build -t ${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG} ."
                }
            }
        }

        stage('Push to DockerHub') {
            steps {
                script {
                    // Use Jenkins usernamePassword credential (id: dockerhub-credentials)
                    withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
                        sh "docker push ${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"
                    }
                }
            }
        }

        stage('Deploy / Update Green') {
            steps {
                script {
                    // Ensure green deployment exists (first time apply will create)
                    sh 'kubectl apply -f k8s/green-deployment.yaml'

                    // Update image of elearning container in elearning-green deployment
                    sh "kubectl set image deployment/elearning-green elearning=${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG} -n ${KUBE_NAMESPACE}"

                    // Wait for rollout to complete
                    sh "kubectl rollout status deployment/elearning-green -n ${KUBE_NAMESPACE} --timeout=120s"
                }
            }
        }

        stage('Switch Service to Green') {
            steps {
                script {
                    // Patch service to point to green pods
                    sh "kubectl patch service elearning-service -n ${KUBE_NAMESPACE} -p '{\"spec\":{\"selector\":{\"app\":\"elearning\",\"version\":\"green\"}}}'"
                }
            }
        }

        stage('Optional: Cleanup Blue') {
            steps {
                script {
                    // Optionally remove the blue deployment after successful switch.
                    // Keep this step safe by ignoring errors.
                    sh "kubectl delete deployment elearning-blue -n ${KUBE_NAMESPACE} || true"
                }
            }
        }
    }

    post {
        always {
            echo "Pipeline finished. IMAGE=${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"
        }
    }
}
