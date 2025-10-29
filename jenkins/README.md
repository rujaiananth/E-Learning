## Jenkins Job DSL and seeding instructions

This folder contains a Job DSL script to create a Jenkins pipeline job for the E-Learning site.

Files:
- `job-dsl/create_elearning_pipeline.groovy` — Job DSL script that creates a pipeline job named `elearning-pipeline` which reads the `Jenkinsfile` in the repository (branch `main`).

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
  jobDsl targets: 'jenkins/job-dsl/create_elearning_pipeline.groovy',
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

Blue-Green toggle behavior
--------------------------

- The repository `Jenkinsfile` now includes a stage named `Switch Blue/Green` that will automatically detect the current Service selector (the `version` label) and flip it to the other version. If the selector is missing or empty, the pipeline assumes `blue` and switches to `green`.
- This stage runs the following high-level steps:
  1. Read the current selector: `kubectl get svc elearning-service -o=jsonpath='{.spec.selector.version}'`
  2. Compute target = (current == 'green' ? 'blue' : 'green')
  3. Patch the Service: `kubectl patch service elearning-service -p '{"spec":{"selector":{"app":"elearning","version":"<target>"}}}'`
  4. Verify the new selector value

Demo / GitHub trigger
---------------------

1. Create the pipeline job in Jenkins (see seeding instructions above) so that it uses the repository `Jenkinsfile`.
2. Configure a GitHub webhook on the repository to POST to your Jenkins job's Git endpoint or use the GitHub plugin (recommended). A push to `main` will trigger the pipeline.
3. Run the pipeline manually from Jenkins or push a commit to `main` on GitHub. The pipeline will:
  - Build the images (if configured)
  - Apply both blue and green deployments (if not present)
  - Apply the Service (initially pointing to `blue`)
  - Toggle the service selector to the other color (blue↔green)
4. Verify by visiting the NodePort (or Ingress) and by running locally:
  - `kubectl get svc elearning-service -o=jsonpath='{.spec.selector.version}'` — should show the new live color

GitHub webhook (recommended)
----------------------------

To make GitHub pushes immediately trigger the pipeline instead of polling:

1. Ensure Jenkins has the GitHub plugin (GitHub Integration / GitHub plugin) installed.
2. In the Job DSL (`jenkins/job-dsl/create_elearning_pipeline.groovy`) the job is configured to use `githubPush()` so the created job will react to GitHub webhooks.
3. Add a webhook in your GitHub repository settings:
  - Payload URL: `http://<JENKINS_HOST>:<PORT>/github-webhook/` (e.g. `http://127.0.0.1:8080/github-webhook/` for local Jenkins)
  - Content type: `application/json`
  - Secret: (optional) — you can leave empty for local demos
  - Which events: choose `Push events` (or `Let me select individual events` → `Push`)
4. Save the webhook and push a commit to `main`. Jenkins should receive the webhook and start `elearning-pipeline` immediately.

Notes:
- If Jenkins is not reachable from GitHub (e.g., running on localhost), either use an SSH tunnel / ngrok to expose Jenkins to GitHub, or leave SCM polling enabled as a fallback.
- If you seed the job via the Job DSL, the `githubPush()` trigger will be created on the job automatically (provided the GitHub plugin is installed).

Security & Permissions
----------------------
- The Jenkins agent that runs this pipeline must have `kubectl` installed and be able to access the target Kubernetes cluster (kubeconfig or in-cluster config). Ensure credentials and RBAC allow reading and patching the Service and applying deployments.
- If Jenkins runs inside the cluster, make sure the service account used by the agent has a Role/ClusterRole with permissions on services and deployments.

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

Triggering a build from the command line
---------------------------------------

I added a small helper script: `jenkins/cli/build-job.sh`. It triggers a Jenkins job via the REST API and handles CSRF crumbs. It supports parameterized jobs.

Example usage (replace values):

```bash
chmod +x jenkins/cli/build-job.sh
./jenkins/cli/build-job.sh \
  --url https://jenkins.example.com \
  --job elearning-pipeline \
  --user jenkins-user \
  --token YOUR_API_TOKEN
```

If the job accepts parameters:

```bash
./jenkins/cli/build-job.sh --url https://jenkins.example.com --job elearning-pipeline --user jenkins-user --token YOUR_API_TOKEN --param TARGET=green
```

Notes:
- The script uses HTTP Basic auth with the username and API token. Use a dedicated service account with minimal permissions.
- If your Jenkins is using a self-signed certificate, add `-k` to the underlying curl call in the script or configure your machine to trust the certificate.
- For secure automation, prefer storing the API token as a Jenkins or system credential rather than passing it directly in CI logs.
