#!/bin/bash

# INFO: terraform.io/cloud-docs/api-docs/modules#publish-a-private-module-from-a-vcs

##### Variables to export
# export REPO_NAME="terraform-aws-vpc-ssm"
# export TFE_ORG="CNE-Solutions-Azure-Example"
# export TFE_HOST="app.terraform.io"
# export OAUTH_TOKEN_ID="ot-****"
# export TFE_TOKEN="***"
# export GIT_ORG="MonseGuzman"

echo "##[debug]Removing prefix..."
prefix="terraform-aws-"            
moduleName=${REPO_NAME#"$prefix"}
echo "##[debug]Module name: $moduleName"

code=$(curl \
  --silent \
  --request GET \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  https://$TFE_HOST/api/v2/organizations/$TFE_ORG/registry-modules/private/$TFE_ORG/$moduleName/aws | jq -r ".data.attributes.name" )

echo "##[debug]The module name: $code"

if [ "$moduleName" == "$code" ]; then
  echo "##[debug]The $REPO_NAME is already uploaded into $TFE_ORG"
else
  echo "##[debug]Creating PAYLOAD"
  PAYLOAD=$(cat <<EOF
  {
    "data": {
      "attributes": {
        "vcs-repo": {
            "identifier":"$GIT_ORG/$REPO_NAME",
            "oauth-token-id":"$OAUTH_TOKEN_ID",
            "display_identifier":"$GIT_ORG/$REPO_NAME"
          }
      },
      "type":"registry-modules"
    }
  }
EOF
)

  echo "##[debug]PAYLOAD"
  echo $PAYLOAD
  echo "##[debug]Publishing the '$REPO_NAME' SSM on $TFE_ORG"

  status=$(curl \
    --silent \
    --output /dev/null \
    --write-out '%{http_code}' \
    --header "Authorization: Bearer $TOKEN" \
    --header "Content-Type: application/vnd.api+json" \
    --request POST \
    --data "$PAYLOAD" \
    https://$TFE_HOST/api/v2/organizations/$TFE_ORG/registry-modules/vcs)
  
  if [ "$status" -eq 201 ]; then
    echo "##[debug]Successfully published module version"
    exit 0
  elif [ "$status" -eq 404 ]; then
    echo "##[error]User not authorized"
    exit 1
  else
    echo "##[error]An error has occured while publishing the SSM. Response code $status"
    exit 1
  fi
fi
