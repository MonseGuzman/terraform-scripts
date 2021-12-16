#!/bin/bash

# INFO: https://www.terraform.io/cloud-docs/api-docs/workspaces#create-a-workspace

##### Variables to export
# export TFE_ORG="CNE-Solutions-Azure-Example"
# export TFE_HOST="app.terraform.io"
# export TFE_TOKEN="****"
# export TFE_WORKSPACE="monse-workspace"
# export TF_VERSION="1.0.0"

set -e

function validate_args(){
    echo "##[debug]Verifying the provided arguments..."
    if [ -n "$TFE_TOKEN" ] && [ -n "$TFE_HOST" ] && [ -n "$TFE_ORG" ]; then
        echo "##[debug]Verification sucessful!"
    else
        echo "##[error]Missing or invalid arguments. Verify your inputs and restart the script."
        exit 1
    fi
}

function verify_tfe_org() {
    echo "##[debug]Verifying if organization exists on Terraform Enterprise"
    
    if ! check_org=$(curl \
                    --silent \
                    --header "Authorization: Bearer $TFE_TOKEN" \
                    --header "Content-Type: application/vnd.api+json" \
                    --request GET \
                    https://$TFE_HOST/api/v2/organizations | jq -r ".data[].attributes.name" | grep -w "$TFE_ORG"); then
        echo "##[error] Organization doesn't exist on Terraform enterprise"
        exit 1
    else
        echo "##[debug] The $TFE_ORG organization provided has been validated"
    fi
}

function create_tfe_workspace() {
    echo "##[debug]Verifying if workspace $TFE_WORKSPACE doesn't exist already in organization $TFE_ORG"
    check_ws_response=$(curl \
        --silent \
        --output /dev/null \
        --write-out '%{http_code}' \
        --header "Authorization: Bearer $TFE_TOKEN" \
        --header "Content-Type: application/vnd.api+json" \
        --request GET https://$TFE_HOST/api/v2/organizations/$TFE_ORG/workspaces/$TFE_WORKSPACE)

    if [ "$check_ws_response" -eq 404 ]; then
        echo "##[debug]Creating workspace $TFE_WORKSPACE..."
        echo "##[debug]Creating payload configuration"
        PAYLOAD=$(cat <<EOF
{
"data": {
    "attributes": {
        "name": "$TFE_WORKSPACE",
        "allow-destroy-plan": true,
        "auto-apply": true,
        "terraform_version": "$TF_VERSION",
        "execution-mode": "remote",
        "working-directory": ""
    },
    "type": "workspaces"
    }
}
EOF
)
        create_ws_response=$(curl \
            --silent \
            --output /dev/null \
            --write-out '%{http_code}' \
            --header "Authorization: Bearer $TFE_TOKEN" \
            --header "Content-Type: application/vnd.api+json" \
            --request POST \
            --data "$PAYLOAD" https://$TFE_HOST/api/v2/organizations/$TFE_ORG/workspaces/)

        if [ "$create_ws_response" -eq 201 ]; then
            echo "##[debug]Workspace $TFE_WORKSPACE has been created successfully within organization $TFE_ORG"
        else
            echo "##[error]An error has occured while creating the workspace. Response code $create_ws_response"
            exit 1
        fi
    else
        echo "##[error]Workspace $TFE_WORKSPACE already exists within organization $TFE_ORG"
        exit 1
    fi
}
  

validate_args
verify_tfe_org

create_tfe_workspace

echo "##[debug]Retrieving workspace ID"
WORKSPACE_ID=$(curl \
            --silent \
            --header "Authorization: Bearer $TFE_TOKEN" \
            --header "Content-Type: application/vnd.api+json" \
            --request GET \
            https://$TFE_HOST/api/v2/organizations/$TFE_ORG/workspaces/$TFE_WORKSPACE | jq -r ".data.id")
echo "##[debug]Workspace ID is $WORKSPACE_ID"