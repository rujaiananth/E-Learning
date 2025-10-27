pipeline {
    agent any

    environment {
        // Ensure common binary locations are available to the Jenkins process
        PATH = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    }

    stages {
        stage('Diagnostic') {
            steps {
                // Quick environment check to help debug missing binaries or PATH problems
                sh 'echo "Jenkins user: $(whoami)"'
                sh 'echo "PATH=$PATH"'
                sh 'which docker || echo docker:not-found'
                sh 'which minikube || echo minikube:not-found'
                sh 'which kubectl || echo kubectl:not-found'
            }
        }
        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/rujaiananth/E-Learning'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    // Use absolute paths to avoid issues when Jenkins is started by launchd
                    sh 'eval $(/opt/homebrew/bin/minikube docker-env)'
                    sh '/usr/local/bin/docker build -t elearning-website:v1 .'
                }
            }
        }

        stage('Deploy Blue-Green') {
            steps {
                script {
                    sh '/usr/local/bin/kubectl apply -f k8s/blue-deployment.yaml'
                    sh '/usr/local/bin/kubectl apply -f k8s/green-deployment.yaml'
                    sh '/usr/local/bin/kubectl apply -f k8s/k8s-service.yaml'
                }
            }
        }

        stage('Switch to Green') {
            steps {
                script {
                    sh "/usr/local/bin/kubectl patch service elearning-service -p '{\"spec\":{\"selector\":{\"app\":\"elearning\",\"version\":\"green\"}}}'"
                }
            }
        }
    }
}
