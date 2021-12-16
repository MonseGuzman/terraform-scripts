#!/bin/bash

# INFO: https://www.terraform.io/cloud-docs/api-docs/workspaces#delete-a-workspace

##### Variables to export
# export TFE_ORG="CNE-Solutions-Azure-Example"
# export TFE_HOST="app.terraform.io"
# export TFE_TOKEN="****"
# export TFE_WORKSPACE="monse-workspace"

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

function check_tfe_ws_state() {
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

check_tfe_ws_state "$WORKSPACE_ID"
TF_STATE_STATUS=$?

# if [ $TF_STATE_STATUS -eq 1 ]; then
#     run_tfe_ws_destroy "$WORKSPACE_ID"
# fi

delete_tfe_ws