// Job DSL script to create a pipeline job that uses the repository Jenkinsfile
pipelineJob('elearning-pipeline') {
    description('Builds Docker image, pushes to DockerHub and deploys to Kubernetes using the repository Jenkinsfile')

    // Pull the Jenkinsfile from this repo (branch: main)
    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url('https://github.com/rujaiananth/E-Learning')
                    }
                    branches('*/main')
                }
            }
            scriptPath('Jenkinsfile')
        }
    }

    // Optional: poll SCM for changes (adjust or remove as needed)
    // Prefer GitHub push webhook (requires GitHub plugin). If your Jenkins isn't reachable
    // from GitHub, fallback to SCM polling by uncommenting the scm() line below.
    triggers {
        githubPush()
        // scm('H/5 * * * *')
    }

    disabled(false)
}
