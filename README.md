# terraform-scripts

## Summary
I had created this repository with my scripts to execute distinct functions with the Terraform API.

## Scripts
| Name                    | Description |
|-------------------------|----------|
| attachedPolicy.sh | Search specific sentinel policy and workspace to attach in the workspace  |
| create-tfe-worksapce.sh | Create a Workspace with the specific version on Terraform Cloud |
| delete-tfe-workspace.sh | Delete a Workspace on Terraform Cloud |
| team-access.sh | Give a team access to a specific workspace |
| tfe-private-module-github.sh | Publish a specific module (on Github/Bitbucket/GitLab) in the private Terraform Registry |

## How to use
The majority of the scripts required to export these variables

````
    export TFE_ORG="CNE-Solutions-Azure-Example"
    export TFE_HOST="app.terraform.io"
    export TFE_TOKEN="***"
    export TFE_WORKSPACE="monse-workspace"
    
    ## To publish:
    export OAUTH_TOKEN_ID="ot-****"
    export REPO_NAME="terraform-aws-vpc-ssm"
    export GIT_ORG="MonseGuzman"
````