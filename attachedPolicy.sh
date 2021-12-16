#!/bin/bash

# FOR MORE INFORMATION: https://www.terraform.io/docs/cloud/api/policy-sets.html#attach-a-policy-set-to-workspaces

##### Variables to export
# export POLICY_NAME="sentinel-policy-fail-poc"
# export TFE_ORG="CNE-Solutions-Azure-Example"
# export TFE_HOST="app.terraform.io"
# export TFE_TOKEN="****"
# export TFE_WORKSPACE="monse-workspace"


function validate_args(){
    echo "##[debug]Verifying the provided arguments..."
    if [ -n "$TFE_TOKEN" ] && [ -n "$TFE_HOST" ] && [ -n "$TFE_ORG" ] && [ -n "$TFE_WORKSPACE" ]; then
        echo "##[debug]Verification sucessful!"
    else
        echo "##vso[task.logissue type=error]Missing or invalid arguments. Verify your inputs and restart the script."
        exit 1
    fi
}

function assignedPolicy(){
    echo "##[debug]Retrieving Policy ID"
    POLICY_ID=$(curl \
            --silent \
            --header "Authorization: Bearer $TFE_TOKEN" \
            https://$TFE_HOST/api/v2/organizations/$TFE_ORG/policy-sets?search%5Bname%5D=$POLICY_NAME | jq -r ".data[].id" )
    echo "##[debug]Policy ID is $POLICY_ID"

    echo "##[debug]Retrieving workspace ID"
    WORKSPACE_ID=$(curl \
        --silent \
        --header "Authorization: Bearer $TFE_TOKEN" \
        --header "Content-Type: application/vnd.api+json" \
        --request GET \
        https://$TFE_HOST/api/v2/organizations/$TFE_ORG/workspaces/$TFE_WORKSPACE | jq -r ".data.id")
    echo "##[debug]Workspace ID is $WORKSPACE_ID"

    PAYLOAD=$(cat <<EOF
{
    "data": [
        { "id": "$WORKSPACE_ID", "type": "workspaces" }
    ]
}
EOF
)

    status=$(curl \
        --silent \
        --output /dev/null \
        --write-out '%{http_code}' \
        --header "Authorization: Bearer $TFE_TOKEN" \
        --header "Content-Type: application/vnd.api+json" \
        --request POST \
        --data "$PAYLOAD" https://$TFE_HOST/api/v2/policy-sets/$POLICY_ID/relationships/workspaces)

    if [ "$status" -eq 204 ]; then
        echo "##[debug]Policy Set $POLICY_NAME has been attached successfully within workspace $TFE_WORKSPACE"
        exit 0
    elif [ "$status" -eq 404 ]; then
        echo "##[error]Policy set not found or user unauthorized to perform action"
        exit 1
    else
        echo "##[error]An error has occured while attached the workspace. Response code $status"
        exit 1
    fi
}

validate_args

assignedPolicy