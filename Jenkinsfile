pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "elearning-site"
    }

    stages {
        stage('Clone Repository') {
            steps {
                 git url: 'https://github.com/Sweety083/E-Learning-Website-HTML-CSS.git', branch: 'main', credentialsId: 'github-creds'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh 'docker build -t elearning-site .'
                }
            }
        }

        stage('Run Container') {
            steps {
                script {
                    // Stop existing container if running
                    sh 'docker rm -f elearning-container || true'
                    // Run new container
                    sh 'docker run -d -p 8080:80 --name elearning-container elearning-site'
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