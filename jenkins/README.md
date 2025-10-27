## Jenkins Job DSL and seeding instructions

This folder contains a Job DSL script to create a Jenkins pipeline job for the E-Learning site.

Files:
- `job-dsl/create-e-learning-pipeline.groovy` — Job DSL script that creates a pipeline job named `elearning-pipeline` which reads the `Jenkinsfile` in the repository (branch `main`).

Prerequisites on your Jenkins server:
- Jenkins with the following plugins installed:
  - Job DSL Plugin
  - Pipeline (workflow) Plugin
  - Credentials Plugin
- A credentials entry with id `dockerhub-credentials` that the existing `Jenkinsfile` expects (username/password for DockerHub).
- kubectl configured on Jenkins agents or a kubeconfig available to the agent running the pipeline.

How to seed (create) the job using a 'seed' pipeline job
1. In Jenkins create a new Pipeline job (call it `seed-job`).
2. In the Pipeline definition, use 'Pipeline script' or 'Pipeline script from SCM'. Below is a minimal pipeline script that will checkout this repository and run the Job DSL script included here.

Example Pipeline script for the seed job (paste into the Pipeline script box):

```groovy
pipeline {
  agent any
  stages {
    stage('Checkout') {
      steps {
        // Checkout the same repository where the DSL script lives
        checkout([$class: 'GitSCM', branches: [[name: '*/main']], userRemoteConfigs: [[url: 'https://github.com/rujaiananth/E-Learning']]])
      }
    }

    stage('Run Job DSL') {
      steps {
        // Run the Job DSL script that creates the pipeline job
        jobDsl targets: 'jenkins/job-dsl/create-e-learning-pipeline.groovy',
               removedJobAction: 'IGNORE',
               removedViewAction: 'IGNORE'
      }
    }
  }
}
```

3. Save and run the `seed-job`. After it completes successfully the job `elearning-pipeline` will be created.

Alternative: create job manually through Jenkins UI
- Create a new Pipeline job named `elearning-pipeline` and set 'Pipeline script from SCM' with:
  - SCM: Git
  - Repository URL: `https://github.com/rujaiananth/E-Learning`
  - Branches to build: `*/main`
  - Script Path: `Jenkinsfile`

Verify
- Open `elearning-pipeline` in Jenkins and run it. Monitor the logs to ensure Docker build, push and kubectl deploy steps execute.

Notes
- The repository already contains a `Jenkinsfile`. The job DSL simply wires a Jenkins job to that Jenkinsfile. Adjust the DSL or Jenkinsfile if you need different credential IDs, image tags, or namespaces.

CLI / REST (create job programmatically)
--------------------------------------
If you prefer to create the job programmatically (Option C), the repo includes a job XML and a helper script.

Files added:
- `jenkins/job-configs/elearning-pipeline-config.xml` — Jenkins job XML for a Pipeline job that points to `Jenkinsfile` on branch `main`.
- `jenkins/cli/create-job.sh` — Bash script that posts the XML to the Jenkins REST API (handles CSRF crumb if enabled) and falls back to updating an existing job if create fails.

Usage (REST POST with script):

```bash
# make script executable
chmod +x jenkins/cli/create-job.sh

# create the job (replace values)
./jenkins/cli/create-job.sh http://your-jenkins-host:8080 elearning-pipeline jenkins/job-configs/elearning-pipeline-config.xml jenkins-user YOUR_API_TOKEN
```

Notes:
- The script requires a Jenkins user API token (or password). Use an account with permission to create/update jobs.
- The script first attempts POST /createItem?name=..., and if that returns a non-success HTTP code it will try POST /job/<name>/config.xml to update an existing job.
- If your Jenkins uses HTTPS, set `JENKINS_URL` to the full https URL. If Jenkins is behind authentication (LDAP, SSO), ensure the user you use has job-create privileges and an API token.

Alternative using `jenkins-cli.jar`:

1. Download `jenkins-cli.jar` from your Jenkins instance: `http://your-jenkins-host:8080/jnlpJars/jenkins-cli.jar`.
2. Create the job with:

```bash
# create job from XML
java -jar jenkins-cli.jar -s http://your-jenkins-host:8080 create-job elearning-pipeline < jenkins/job-configs/elearning-pipeline-config.xml --username jenkins-user --password YOUR_API_TOKEN
```

If you want, I can also add a small wrapper script to download the CLI jar and run the create-job command; tell me and I'll add it.
