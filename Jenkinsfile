pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "elearning-site"
        CONTAINER_NAME = "elearning-container"
    }

    stages {
        stage('Build Docker Image') {
            steps {
                script {
                    echo "🔨 Building Docker image: ${DOCKER_IMAGE}"
                    sh "docker build -t ${DOCKER_IMAGE} ."
                }
            }
        }

        stage('Run Container') {
            steps {
                script {
                    echo "🛑 Stopping existing container if any..."
                    sh "docker rm -f ${CONTAINER_NAME} || true"

                    echo "🏃 Running new container..."
                    sh "docker run -d -p 8080:80 --name ${CONTAINER_NAME} ${DOCKER_IMAGE}"

                    echo "📦 Container running:"
                    sh "docker ps | grep ${CONTAINER_NAME} || true"
                }
            }
        }
    }

    post {
        success {
            echo '🎉 E-Learning website deployed successfully!'
        }
        failure {
            echo '❌ Build failed, check logs!'
        }
    }
}
