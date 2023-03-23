#!/bin/zsh

##################################################################
#
# Small ZSH script to clean my kubefirst tests or help me debug
#
# Please use at your own risk
#
##################################################################

#################
# CONFIGURATION #
#################
local username="fharper"
local org="kubefirst-fharper"

local github_api="https://api.github.com"
local gitlab_api="https://gitlab.com/api/v4"

###############
# Check tools #
###############
if ! which k3d >/dev/null; then
  echo "Please install k3d - https://github.com/k3d-io/k3d"
  return
fi

if ! which jq >/dev/null; then
  echo "Please install jq - https://github.com/stedolan/jq"
  return
fi

if ! which gum >/dev/null; then
  echo "Please install gum - https://github.com/charmbracelet/gum/"
  return
fi


##################
# Check env vars #
##################
if [ -z "${GITHUB_TOKEN}" ]; then
  echo "Please set the GITHUB_TOKEN environment variable"
fi

if [ -z "${GITLAB_TOKEN}" ]; then
  echo "Please set the GITLAB_TOKEN environment variable"
fi


gum format -- "What do you to do?"
local action=$(gum choose \
    "1- destroy k3d + GitHub" \
    "2- destroy k3d + GitLab" \
)

########################
# destroy k3d + GitHub #
########################
if [[ "$action" == 1-* ]] ; then

    # k3d
    k3d cluster delete kubefirst
    kubefirst clean

    # Groups
    curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/orgs/$org/teams/developers
    curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/orgs/$org/teams/admins

    # Repos
    curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$username/gitops
    curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$username/metaphor
    curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$org/gitops
    curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$org/metaphor


########################
# destroy k3d + GitLab #
########################
elif [[ "$action" == 2-* ]] ; then

    # k3d
    k3d cluster delete kubefirst
    kubefirst clean

    # Groups

    ## Developers
    local id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/ | jq '.[] | select(.full_path=="$org/developers") | .id')
    if $id; then
    curl -sS -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$id
    fi

    ## admins
    local id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/ | jq '.[] | select(.full_path=="$org/admins") | .id')
    if $id; then
    curl -sS -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$id
    fi

    # Repos

    ## gitops
    local project_id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$org/projects/ | jq '.[] | select(.name=="gitops") | .id')
    if [[ -z $project_id ]]; then
    curl -sS -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id
    fi

    ## metaphor
    local project_id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$org/projects/ | jq '.[] | select(.name=="metaphor") | .id')

    if [[ -z $project_id ]]; then
        local registry_id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id/registry/repositories | jq '.[].id')

        if [[ -z $registry_id ]]; then
            ### Container Registry Tags
            curl -sS -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id/registry/repositories/$registry_id/tags/ --data "name_regex=.*"

            ### Container Registry
            curl -sS -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id/registry/repositories/$registry_id
        fi

        ### Repository
        curl -sS -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id
    fi

    # SSH Key
    local id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/user/keys/ | jq '.[] | select(.title=="kubefirst-k3d-ssh-key") | .id')
    if [[ -z $id ]]; then
    curl -sS -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/user/keys/$id
    fi

fi
