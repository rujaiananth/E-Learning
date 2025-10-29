#!/usr/bin/env bash
set -euo pipefail

JENKINS_URL="http://127.0.0.1:8080"
JOB="elearning-pipeline"
CONFIG="jenkins/job-configs/elearning-pipeline-config.xml"
CREATE_SCRIPT="jenkins/cli/create-job.sh"

if [ ! -f "$CONFIG" ]; then
  echo "ERROR: Config file not found at $CONFIG. Make sure you're running this from the repo root."
  exit 2
fi
if [ ! -f "$CREATE_SCRIPT" ]; then
  echo "ERROR: create-job helper missing at $CREATE_SCRIPT"
  exit 2
fi

read -p "Jenkins user: " USER
read -s -p "API token: " TOKEN
echo

# 1) Check job presence
echo "Checking if job '${JOB}' exists..."
HTTP=$(curl -s -o /dev/null -w "%{http_code}" -u "${USER}:${TOKEN}" "${JENKINS_URL}/job/${JOB}/api/json" || true)
if [ "$HTTP" = "200" ]; then
  echo "Job ${JOB} exists."
else
  echo "Job ${JOB} not found (HTTP ${HTTP}). Attempting to create it..."
  chmod +x "${CREATE_SCRIPT}"
  "./${CREATE_SCRIPT}" "${JENKINS_URL}" "${JOB}" "${CONFIG}" "${USER}" "${TOKEN}"
fi

# 2) Optional: check Job DSL plugin presence (informative)
echo "Checking Job DSL plugin presence (informational)..."
curl -sS -u "${USER}:${TOKEN}" "${JENKINS_URL}/pluginManager/api/json?depth=1" | jq -r '.plugins[] | select(.shortName=="job-dsl") | "\(.shortName) \(.version)"' || echo "Job DSL plugin not found via plugin API (may still exist, or API blocked)."

# 3) Check credential presence via Script Console (we'll POST a groovy check)
echo "Checking for credential id 'dockerhub-credentials' via Script Console..."
GROOVY=$(cat <<'EOF'
import jenkins.model.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.*
def found = false
def store = Jenkins.instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()
def creds = com.cloudbees.plugins.credentials.CredentialsProvider.lookupCredentials(com.cloudbees.plugins.credentials.common.StandardUsernamePasswordCredentials.class, Jenkins.instance, null, null)
for (c in creds) {
  if (c.id == 'dockerhub-credentials') { found = true; break }
}
println(found ? 'CREDENTIAL_FOUND' : 'CREDENTIAL_MISSING')
EOF
)
# Post script (Script Console)
CRUMB=$(curl -sS -u "${USER}:${TOKEN}" "${JENKINS_URL}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)" || true)
if [ -n "$CRUMB" ]; then
  CRUMB_HEADER=(-H "$CRUMB")
else
  CRUMB_HEADER=()
fi
GROOVY_OUT=$(curl -sS -u "${USER}:${TOKEN}" "${CRUMB_HEADER[@]}" -X POST "${JENKINS_URL}/scriptText" --data-urlencode "script=${GROOVY}")
echo "$GROOVY_OUT" | sed -n '1,200p'
if echo "$GROOVY_OUT" | grep -q "CREDENTIAL_FOUND"; then
  echo "Credential 'dockerhub-credentials' exists."
else
  echo "Credential 'dockerhub-credentials' NOT found. You must create it (Manage Jenkins → Credentials) before docker push will work."
fi

# 4) Trigger a build
echo "Triggering build for ${JOB}..."
CRUMB=$(curl -sS -u "${USER}:${TOKEN}" "${JENKINS_URL}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)")
curl -sS -u "${USER}:${TOKEN}" -H "$CRUMB" -X POST "${JENKINS_URL}/job/${JOB}/build" || true

echo "Build triggered. Now tailing console (press Ctrl+C to stop)..."
sleep 2

# tail console continuously
while true; do
  clear
  echo "---- CONSOLE OUTPUT for ${JOB}/lastBuild ----"
  curl -sS -u "${USER}:${TOKEN}" "${JENKINS_URL}/job/${JOB}/lastBuild/consoleText" || true
  # If build finished, exit loop
  STATUS=$(curl -sS -u "${USER}:${TOKEN}" "${JENKINS_URL}/job/${JOB}/lastBuild/api/json" | jq -r '.building // empty')
  if [ "$STATUS" = "false" ] || [ -z "$STATUS" ]; then
    echo
    echo "Build finished."
    curl -sS -u "${USER}:${TOKEN}" "${JENKINS_URL}/job/${JOB}/lastBuild/consoleText" | tail -n 50
    break
  fi
  sleep 4
done

# 5) Advice based on last lines of console
LAST_LINES=$(curl -sS -u "${USER}:${TOKEN}" "${JENKINS_URL}/job/${JOB}/lastBuild/consoleText" | tail -n 200)
echo
echo "---- Last 200 lines of console ----"
echo "$LAST_LINES"

if echo "$LAST_LINES" | grep -qi "docker login"; then
  echo "If docker login failed, ensure the credential 'dockerhub-credentials' exists and is valid."
fi
if echo "$LAST_LINES" | grep -qi "kubectl"; then
  echo "If kubectl failed, ensure kubeconfig is available on the agent and has proper permissions."
fi

echo "Script finished. Inspect the console output above for specific failures and paste any error snippets if you want me to analyze them."