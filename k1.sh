#!/bin/zsh

local username="fharper"
local org="kubefirst-fharper"

local github_api="https://api.github.com"
local gitlab_api="https://gitlab.com/api/v4"

###############
# Check tools #
###############
if ! which k3d >/dev/null; then
  echo "Please install k3d"
  return
fi

if ! which jq >/dev/null; then
  echo "Please install jq"
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


#######
# k3d #
#######
k3d cluster delete kubefirst
kubefirst clean


##########
# GitHub #
##########

## Groups
curl -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/orgs/$org/teams/developers
curl -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/orgs/$org/teams/admins

## Repos
curl -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$username/gitops
curl -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$username/metaphor
curl -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$org/gitops
curl -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$org/metaphor


##########
# GitLab #
##########

## Groups

### Developers
local id=$(curl -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/ | jq '.[] | select(.full_path=="$org/developers") | .id')
if $id; then
  curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$id
fi

### admins
local id=$(curl -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/ | jq '.[] | select(.full_path=="$org/admins") | .id')
if $id; then
  curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$id
fi

## Repos

### gitops
local project_id=$(curl -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$org/projects/ | jq '.[] | select(.name=="gitops") | .id')
if [[ -z $project_id ]]; then
  curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id
fi

### metaphor
local project_id=$(curl -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$org/projects/ | jq '.[] | select(.name=="metaphor") | .id')

if [[ -z $project_id ]]; then
    curl -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id/registry/repositories

    local $registry_id=curl -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id/registry/repositories | jq '.[].id'

    #### Container Registry Tags
    curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id/registry/repositories/$registry_id/tags/ --data "name_regex=.*"

    #### Container Registry
    curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id/registry/repositories/$registry_id

    #### Repository
    curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id
fi

## SSH Key
local id=$(curl -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/user/keys/ | jq '.[] | select(.title=="kubefirst-k3d-ssh-key") | .id')
if [[ -z $id ]]; then
  curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/user/keys/$id
fi
