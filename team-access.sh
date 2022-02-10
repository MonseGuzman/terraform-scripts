#!/bin/bash

# export TFE_ORG="CNE-Solutions-Azure-Example"
# export TFE_HOST="app.terraform.io"
# export TFE_TOKEN="****"
# export TFE_WORKSPACE="monse-workspace"
# export TEAM_NAME="admin_access"

set -e

echo "##[debug]Retrieving workspace ID"
WORKSPACE_ID=$(curl \
    --silent \
    --header "Authorization: Bearer $TFE_TOKEN" \
    --header "Content-Type: application/vnd.api+json" \
    --request GET \
    https://$TFE_HOST/api/v2/organizations/$TFE_ORG/workspaces/$TFE_WORKSPACE | jq -r ".data.id")
echo "##[debug]Workspace ID is $WORKSPACE_ID"

TEAM_ID=($(curl \
    --silent \
    --header "Authorization: Bearer $TFE_TOKEN" \
    --header "Content-Type: application/vnd.api+json" \
    --request GET \
    https://$TFE_HOST/api/v2/organizations/$TFE_ORG/teams | jq -r ".data[].id" ))

for i in "${TEAM_ID[@]}"
do
  if ! searching=$(curl \
    --silent \
    --header "Authorization: Bearer $TFE_TOKEN" \
    --header "Content-Type: application/vnd.api+json" \
    --request GET \
    https://$TFE_HOST/api/v2/teams/$i | jq -r ".data.attributes.name" | grep -w "$TEAM_NAME" ); then

    echo ""
  else
    echo "The team $i was found!"
    TEAM_ID=$i
  fi
done


PAYLOAD=$(cat <<EOF
{
  "data": {
    "attributes": {
      "access": "custom",
      "runs": "apply",
      "variables": "none",
      "state-versions": "read-outputs",
      "plan-outputs": "none",
      "sentinel-mocks": "read",
      "workspace-locking": false
    },
    "relationships": {
      "workspace": {
        "data": {
          "type": "workspaces",
          "id": "$WORKSPACE_ID"
        }
      },
      "team": {
        "data": {
          "type": "teams",
          "id": "$i"
        }
      }
    },
    "type": "team-workspaces"
  }
}
EOF
)

check_access=$(curl \
    --silent \
    --output /dev/null \
    --write-out '%{http_code}' \
    --header "Authorization: Bearer $TFE_TOKEN" \
    --header "Content-Type: application/vnd.api+json" \
    --request POST \
    --data "$PAYLOAD" \
    https://app.terraform.io/api/v2/team-workspaces)

if [ "$check_access" -eq 201 ]; then
  echo "##[debug]The team was added succesfully!"
else
  echo "##[error]An error has occured while adding the access. Response code $check_access"
fi