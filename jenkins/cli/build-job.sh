#!/usr/bin/env bash
# Trigger a Jenkins job build using the REST API (handles CSRF crumb)
# Usage:
#   ./build-job.sh \
#     --url https://jenkins.example.com \
#     --job elearning-pipeline \
#     --user jenkins-user \
#     --token <API_TOKEN> \
#     [--param KEY=VALUE ...]

set -euo pipefail

print_usage() {
  cat <<EOF
Usage: $0 --url JENKINS_URL --job JOB_NAME --user USER --token API_TOKEN [--param KEY=VALUE ...]

Options:
  --url    Jenkins base URL (e.g. https://jenkins.example.com)
  --job    Job name (e.g. elearning-pipeline)
  --user   Jenkins username (or service account)
  --token  Jenkins API token or password
  --param  Optional job parameter in KEY=VALUE form; repeat for multiple params
  -h, --help  Show this help

Examples:
  ./build-job.sh --url https://jenkins.local:8080 --job elearning-pipeline --user admin --token abc123
  ./build-job.sh --url https://jenkins.local:8080 --job elearning-pipeline --user admin --token abc123 --param TARGET=green
EOF
}

if [ "$#" -eq 0 ]; then
  print_usage
  exit 1
fi

JENKINS_URL=""
JOB_NAME=""
USER=""
TOKEN=""
PARAMS=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --url) JENKINS_URL="$2"; shift 2;;
    --job) JOB_NAME="$2"; shift 2;;
    --user) USER="$2"; shift 2;;
    --token) TOKEN="$2"; shift 2;;
    --param) PARAMS+=("$2"); shift 2;;
    -h|--help) print_usage; exit 0;;
    *) echo "Unknown arg: $1"; print_usage; exit 2;;
  esac
done

# Allow credentials to be supplied via environment variables for better security
USER=${USER:-${JENKINS_USER:-}}
TOKEN=${TOKEN:-${JENKINS_TOKEN:-}}

if [ -z "$JENKINS_URL" ] || [ -z "$JOB_NAME" ] || [ -z "$USER" ] || [ -z "$TOKEN" ]; then
  echo "Missing required arguments or environment variables"
  echo "You can pass --user and --token, or set JENKINS_USER and JENKINS_TOKEN environment variables."
  print_usage
  exit 2
fi

# Normalize URL (no trailing slash)
JENKINS_URL="${JENKINS_URL%/}"

# Get crumb (do not echo token)
CRUMB_JSON=$(curl -sS --user "$USER:$TOKEN" "$JENKINS_URL/crumbIssuer/api/json" 2>/dev/null || true)
CRUMB=""
CRUMB_FIELD=""
if [ -n "$CRUMB_JSON" ]; then
  # Try to parse crumb and field
  CRUMB=$(echo "$CRUMB_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('crumb',''))" 2>/dev/null || true)
  CRUMB_FIELD=$(echo "$CRUMB_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('crumbRequestField',''))" 2>/dev/null || true)
fi

# Build the URL. Use buildWithParameters if there are params
# Use a safe expansion in case PARAMS is empty/unset under 'set -u'
if [ "${#PARAMS[@]:-0}" -gt 0 ]; then
  BUILD_ENDPOINT="$JENKINS_URL/job/$JOB_NAME/buildWithParameters"
else
  BUILD_ENDPOINT="$JENKINS_URL/job/$JOB_NAME/build"
fi

# Construct curl command
CURL_OPTS=(--user "$USER:$TOKEN" -X POST -sS)
if [ -n "$CRUMB" ] && [ -n "$CRUMB_FIELD" ]; then
  CURL_OPTS+=( -H "$CRUMB_FIELD: $CRUMB" )
fi

# Add params (only iterate when there are any)
if [ "${#PARAMS[@]:-0}" -gt 0 ]; then
  for p in "${PARAMS[@]}"; do
    CURL_OPTS+=( --data-urlencode "$p" )
  done
fi

# Execute
echo "Triggering job $JOB_NAME on $JENKINS_URL (user: $USER)"
# shellcheck disable=SC2086
RESPONSE=$(curl ${CURL_OPTS[@]} "$BUILD_ENDPOINT" -D - 2>&1) || true
echo "$RESPONSE"

STATUS=$?
if [ $STATUS -ne 0 ]; then
  echo "Failed to trigger job (curl exit $STATUS)"
  exit $STATUS
fi

echo "Triggered. Check Jenkins UI or job/build queue for status."
exit 0
