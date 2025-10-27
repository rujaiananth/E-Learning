#!/usr/bin/env bash
set -euo pipefail

# create-job.sh
# Create or update a Jenkins job using the REST API. Supports crumb retrieval.
# Usage: ./create-job.sh <JENKINS_URL> <JOB_NAME> <CONFIG_XML_PATH> <USER> <API_TOKEN>

if [ "$#" -ne 5 ]; then
  echo "Usage: $0 JENKINS_URL JOB_NAME CONFIG_XML_PATH USER API_TOKEN"
  echo "Example: $0 http://localhost:8080 elearning-pipeline jenkins/job-configs/elearning-pipeline-config.xml admin mytoken"
  exit 2
fi

JENKINS_URL="$1"
JOB_NAME="$2"
CONFIG_PATH="$3"
USER="$4"
API_TOKEN="$5"

if [ ! -f "$CONFIG_PATH" ]; then
  echo "Config file not found: $CONFIG_PATH"
  exit 3
fi

echo "Getting crumb from ${JENKINS_URL}..."
CRUMB_HEADER=$(curl -sS -u "${USER}:${API_TOKEN}" "${JENKINS_URL}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)") || true

if [ -z "$CRUMB_HEADER" ]; then
  echo "No crumb returned (Jenkins might not have CSRF enabled). Proceeding without crumb header."
  CRUMB_OPT=()
else
  CRUMB_OPT=( -H "$CRUMB_HEADER" )
fi

echo "Creating or updating job '${JOB_NAME}'..."
HTTP_CODE=$(curl -sS -o /dev/null -w "%{http_code}" -u "${USER}:${API_TOKEN}" -X POST "${JENKINS_URL}/createItem?name=${JOB_NAME}" -H "Content-Type: application/xml" "${CRUMB_OPT[@]}" --data-binary @"${CONFIG_PATH}" ) || true

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "302" ]; then
  echo "Job '${JOB_NAME}' created/updated successfully (HTTP ${HTTP_CODE})."
  exit 0
fi

if [ "$HTTP_CODE" = "400" ]; then
  echo "Bad request (400). Check the XML."
  exit 4
fi

echo "Failed to create job, HTTP status: ${HTTP_CODE}. Trying to update existing job via POST to /job/<name>/config.xml"
HTTP_CODE2=$(curl -sS -o /dev/null -w "%{http_code}" -u "${USER}:${API_TOKEN}" -X POST "${JENKINS_URL}/job/${JOB_NAME}/config.xml" -H "Content-Type: application/xml" "${CRUMB_OPT[@]}" --data-binary @"${CONFIG_PATH}" ) || true

if [ "$HTTP_CODE2" = "200" ]; then
  echo "Job '${JOB_NAME}' updated successfully (HTTP ${HTTP_CODE2})."
  exit 0
fi

echo "Both create and update attempts failed (create HTTP ${HTTP_CODE}, update HTTP ${HTTP_CODE2})."
exit 5
