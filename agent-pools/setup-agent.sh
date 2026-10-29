#!/bin/bash
set -e

if [ -z "$AZP_URL" ]; then
  echo 1>&2 "Error: AZP_URL is not set"
  exit 1
fi

if [ -z "$AZP_TOKEN" ]; then
  echo 1>&2 "Error: AZP_TOKEN is not set"
  exit 1
fi

AZP_AGENT_NAME=${AZP_AGENT_NAME:-$(hostname)}
AZP_POOL=${AZP_POOL:-Default}
AZP_WORK=${AZP_WORK:-_work}

echo "Determining matching Azure Pipelines agent package..."
AZP_AGENT_PACKAGE_URL=$(curl -LsS \
  -u user:$AZP_TOKEN \
  -H 'Accept:application/json' \
  "$AZP_URL/_apis/distributedtask/packages/agent?platform=linux-x64&top=1" | \
  jq -r '.value[0].downloadUrl')

if [ -z "$AZP_AGENT_PACKAGE_URL" -o "$AZP_AGENT_PACKAGE_URL" == "null" ]; then
  echo 1>&2 "Error: could not determine a matching Azure Pipelines agent package"
  exit 1
fi

echo "Downloading and extracting Azure Pipelines agent..."
curl -LsS $AZP_AGENT_PACKAGE_URL | tar -xz

echo "Configuring Azure Pipelines agent..."
./config.sh --unattended \
  --agent "${AZP_AGENT_NAME}" \
  --url "${AZP_URL}" \
  --auth PAT \
  --token "${AZP_TOKEN}" \
  --pool "${AZP_POOL}" \
  --work "${AZP_WORK}" \
  --replace \
  --acceptTeeEula

cleanup() {
  echo "Removing Azure Pipelines agent registration..."
  ./config.sh remove --unattended \
    --auth PAT \
    --token "${AZP_TOKEN}"
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

echo "Starting Azure Pipelines agent runner..."
./run.sh & wait $!
