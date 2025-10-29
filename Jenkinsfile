pipeline {
    agent any

    // Optional parameter: set TARGET_VERSION to 'blue' or 'green' to force a switch.
    parameters {
        string(name: 'TARGET_VERSION', defaultValue: '', description: "Optional: 'blue' or 'green'. If empty the pipeline will toggle the current live version.")
    }

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
                    // Apply configmaps first so deployments mount the correct content
                    sh '/usr/local/bin/kubectl apply -f k8s/configmap-blue.yaml || true'
                    sh '/usr/local/bin/kubectl apply -f k8s/configmap-green.yaml || true'
                    sh '/usr/local/bin/kubectl apply -f k8s/blue-deployment.yaml'
                    sh '/usr/local/bin/kubectl apply -f k8s/green-deployment.yaml'
                    sh '/usr/local/bin/kubectl apply -f k8s/k8s-service.yaml'
                }
            }
        }

        stage('Switch Blue/Green') {
            steps {
                script {
                    // Optional explicit override: use TARGET_VERSION parameter if provided (must be 'blue' or 'green')
                    def forced = ''
                    try {
                        forced = params.TARGET_VERSION?.trim()
                    } catch (ignored) {
                        // params may be unavailable in some contexts; ignore
                        forced = ''
                    }

                    // Read current selector version (may be 'blue' or 'green')
                    def current = sh(script: "/usr/local/bin/kubectl get svc elearning-service -o=jsonpath='{.spec.selector.version}' || true", returnStdout: true).trim()
                    echo "Current live version: ${current}"

                    // If the service does not have a selector or the value is empty, assume 'blue' as default
                    if (!current) {
                        echo "No current version detected; defaulting to 'blue'"
                        current = 'blue'
                    }

                    def target = ''
                    if (forced && (forced == 'blue' || forced == 'green')) {
                        echo "TARGET_VERSION parameter provided: ${forced} -> using as target"
                        target = forced
                    } else {
                        // Flip the version
                        target = current == 'green' ? 'blue' : 'green'
                        echo "No valid TARGET_VERSION provided; toggling to: ${target}"
                    }

                    // Patch the Service selector to point to the target deployment
                    sh "/usr/local/bin/kubectl patch service elearning-service -p '{\"spec\":{\"selector\":{\"app\":\"elearning\",\"version\":\"${target}\"}}}'"

                    // Verify
                    sh "/usr/local/bin/kubectl get svc elearning-service -o=jsonpath='{.spec.selector.version}'"

                    // Print the kube context and full service YAML so we can see where Jenkins applied the change
                    sh "/usr/local/bin/kubectl config current-context || true"
                    sh "/usr/local/bin/kubectl get svc elearning-service -o yaml || true"
                }
            }
        }
    }
}
