pipeline {
    agent any

    environment {
        PATH = "/usr/local/bin:$PATH"   // Ensure Jenkins can find Docker
        DOCKER_IMAGE = "elearning-site"
        CONTAINER_NAME = "elearning-container"
    }

    stages {
        stage('Clone Repository') {
            steps {
                echo "📥 Cloning repository..."
                git url: 'https://github.com/Sweety083/E-Learning-Website-HTML-CSS.git', branch: 'main', credentialsId: 'github-creds'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo "🔨 Building Docker image: ${DOCKER_IMAGE}"
                    sh 'docker --version'
                    sh "docker build -t ${DOCKER_IMAGE} ."
                }
            }
        }

        stage('Run Container') {
            steps {
                script {
                    echo "🚀 Running Docker container: ${CONTAINER_NAME}"
                    // Stop and remove any existing container with the same name
                    sh "docker rm -f ${CONTAINER_NAME} || true"
                    // Run the new container
                    sh "docker run -d -p 8080:80 --name ${CONTAINER_NAME} ${DOCKER_IMAGE}"
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

