#!/bin/bash

# INFO:
# https://www.terraform.io/cloud-docs/api-docs/workspaces#delete-a-workspace
# https://www.terraform.io/cloud-docs/api-docs/run#runs-api
# https://www.terraform.io/cloud-docs/api-docs/run#runs-api

##### Variables to export
# export TFE_ORG="CNE-Solutions-Azure-Example"
# export TFE_HOST="app.terraform.io"
# export TFE_TOKEN="****"
# export TFE_WORKSPACE="monse-workspace"
# export TFE_WORKSPACE_DESTROY_TIMEOUT="15"

function validate_args(){
    echo "##[debug]Verifying the provided arguments..."
    if [ -n "$TFE_TOKEN" ] && [ -n "$TFE_HOST" ] && [ -n "$TFE_ORG" ] && [ -n "$TFE_WORKSPACE" ]; then
        echo "##[debug]Verification sucessful!"
    else
        echo "##[error]Missing or invalid arguments. Verify your inputs and restart the script."
        exit 1
    fi
}

function verify_tfe_ws() {
    echo "##[debug]Verifying if workspace $TFE_WORKSPACE exists on TFE Org $TFE_ORG"
        
    if ! check_org=$(curl \
            --silent \
            --header "Authorization: Bearer $TFE_TOKEN" \
            --header "Content-Type: application/vnd.api+json" \
            --request GET \
            https://$TFE_HOST/api/v2/organizations/$TFE_ORG/workspaces | jq -r ".data[].attributes.name" | grep -w "$TFE_WORKSPACE"); then
        echo "##[error]Workspace $TFE_WORKSPACE not found on TFE Org $TFE_ORG. No action taken."
        exit 1
    else
        echo "##[debug]Workspace $TFE_WORKSPACE found in TFE Org $TFE_ORG and validated!"
    fi
}

function get_ws_state() {
  echo "##[debug]Verifying if workspace $TFE_WORKSPACE has any state to destroy"
  check_ws_state=$(curl \
      --silent \
      --output /dev/null \
      --write-out '%{http_code}' \
      --header "Authorization: Bearer $TFE_TOKEN" \
      --header "Content-Type: application/vnd.api+json" \
      --request GET \
      https://$TFE_HOST/api/v2/workspaces/$WORKSPACE_ID/current-state-version)

  if [ "$check_ws_state" -eq 200 ]; then
    echo "##[debug]Workspace $TFE_WORKSPACE has state to destroy."
    return 1
  elif [ "$check_ws_state" -eq 404 ]; then
    echo "##[debug]Workspace $TFE_WORKSPACE has no state to destroy."
    return 0
  else
    echo "##[error]An error has occured while checking for state in the workspace. Response code $check_ws_state"
    exit 1
  fi
}

function check_tfe_resources(){
  echo "##[debug]Verifying if workspace $TFE_WORKSPACE has resources to destroy"
  resources=$(curl \
          --silent \
          --request GET \
          --header "Authorization: Bearer $TFE_TOKEN" \
          --header "Content-Type: application/vnd.api+json" \
          https://$TFE_HOST/api/v2/workspaces/$WORKSPACE_ID/resources | jq -r ".data")
  
  echo $resources

  if [ "$resources" == "[]" ]; then
    echo "##[debug]Workspace $TFE_WORKSPACE has no resources to destroy."
    return 0
  else
    echo "##[debug]Workspace $TFE_WORKSPACE has resources to destroy."
    return 1
  fi
}

function run_tfe_ws_destroy(){
  echo "##[group]Running a final destroy before deleting WS ($TFE_WORKSPACE) on Org ($TFE_ORG)..."
  PAYLOAD=$(cat <<EOF
  {
    "data": {
      "attributes": {
        "is-destroy":true,
        "auto-apply":true
      },
      "type":"runs",
      "relationships": {
        "workspace": {
          "data": {
            "type": "workspaces",
            "id": "$WORKSPACE_ID"
          }
        }
      }
    }
  }
EOF
)      
  RUN_ID=$(curl \
      --silent \
      --header "Authorization: Bearer $TFE_TOKEN" \
      --header "Content-Type: application/vnd.api+json" \
      --request POST \
      --data "$PAYLOAD" https://$TFE_HOST/api/v2/runs | jq -r ".data.id")

  echo "##[debug]Run ID: $RUN_ID"

  # Timeout for loop
  SLEEP_DURATION=15
  MAX_RUN_TIME="$sTFE_WORKSPACE_DESTROY_TIMEOUT minutes" # linux
  END_TIME=$(date -ud "$MAX_RUN_TIME" +%s)

  # MAX_RUN_TIME="${TFE_WORKSPACE_DESTROY_TIMEOUT}M" # mac os
  # END_TIME=$(date -v +$MAX_RUN_TIME +%s) 

  # Check run result in loop
  CONTINUE=1
  while [ $CONTINUE -ne 0 ]; do
    # Sleep
    sleep $SLEEP_DURATION
    echo "##[debug]Checking run status"

    # Check the status of run
    RUN_STATUS=$(curl \
      --silent \
      --header "Authorization: Bearer $TFE_TOKEN" \
      --header "Content-Type: application/vnd.api+json" \
      https://$TFE_HOST/api/v2/runs/$RUN_ID | jq -r ".data.attributes.status")

    echo "##[debug]Run Status: $RUN_STATUS"

    RUN_ERROR=0
    if [[ "$RUN_STATUS" == "applied" ]]; then
      CONTINUE=0
    elif [[ "$RUN_STATUS" == "planned_and_finished" ]]; then
      CONTINUE=0
    elif [[ "$RUN_STATUS" == "errored" ]]; then
      echo "##[debug]Plan errored! Check logs!"
      RUN_ERROR=1
      CONTINUE=0
    fi

    # Check for timeoutvalue and stop loop if found
    if [[ $(date -u +%s) -ge $END_TIME ]]; then
      echo "##[debug]Timeout reached!!"
      CONTINUE=0
    fi
  done

  # Handling exit codes
  if [[ "$RUN_ERROR" == "1" ]]; then
    echo "##[debug]Failed to fully destroy resources!"
    exit 1
  else
    echo "##[debug]Destroy completed succesfully!"
  fi

  echo "##[endgroup]"
}

function delete_tfe_ws(){
    echo "##[debug]Deleting the following WS ($TFE_WORKSPACE) on Org ($TFE_ORG)..."
    curl \
        --silent \
        --header "Authorization: Bearer $TFE_TOKEN" \
        --header "Content-Type: application/vnd.api+json" \
        --request DELETE \
        https://$TFE_HOST/api/v2/organizations/$TFE_ORG/workspaces/$TFE_WORKSPACE >/dev/null 2>&1
    echo "##[debug]WS ($TFE_WORKSPACE) on Org ($TFE_ORG)...has been deleted."
}

validate_args
verify_tfe_ws

echo "##[debug]Retrieving workspace ID"
WORKSPACE_ID=$(curl \
    --silent \
    --header "Authorization: Bearer $TFE_TOKEN" \
    --header "Content-Type: application/vnd.api+json" \
    --request GET \
    https://$TFE_HOST/api/v2/organizations/$TFE_ORG/workspaces/$TFE_WORKSPACE | jq -r ".data.id")
echo "##[debug]Workspace ID is $WORKSPACE_ID"

get_ws_state "$WORKSPACE_ID"
TF_STATE_STATUS=$?

if [ $TF_STATE_STATUS -eq 1 ]; then
  check_tfe_resources  "$WORKSPACE_ID"
  TF_RESOURCES=$?

  if [ $TF_RESOURCES -eq 1 ]; then
      run_tfe_ws_destroy "$WORKSPACE_ID"
      check_tfe_resources  "$WORKSPACE_ID"
  fi
fi

delete_tfe_ws