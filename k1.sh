#!/bin/zsh

local username="fharper"
local org="kubefirst-fharper"

local github_api="https://api.github.com"
local gitlab_api="https://gitlab.com/api/v4"

# Check if tools installed
if ! which k3d >/dev/null; then
  echo "Please install k3d"
  return
fi

if ! which gh >/dev/null; then
  echo "Please install GitHub CLI"
  return
fi

if ! which glab >/dev/null; then
  echo "Please install GitHub CLI"
  return
fi

if ! which jq >/dev/null; then
  echo "Please install jq"
  return
fi

# Check if environment variables are set
if [ -z "${GITHUB_TOKEN}" ]; then
  echo "Please set the GITHUB_TOKEN environment variable"
fi

if [ -z "${GITLAB_TOKEN}" ]; then
  echo "Please set the GITLAB_TOKEN environment variable"
fi

# k3d
k3d cluster delete kubefirst
kubefirst clean

# GitHub

## Groups
curl -X DELETE -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/orgs/$org/teams/developers
curl -X DELETE -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/orgs/$org/teams/admins

## Repos
gh repo delete $username/metaphor --yes
gh repo delete $username/gitops --yes
gh repo delete $org/metaphor --yes
gh repo delete $org/gitops --yes

# GitLab

## Groups

### Developers
local id=$(curl -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/ | jq '.[] | select(.full_path=="$org/developers") | .id')
if $id; then
  curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$id
fi

local id=$(curl -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/ | jq '.[] | select(.full_path=="$org/admins") | .id')
if $id; then
  curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$id
fi

## Repos
glab repo delete $org/metaphor-go --yes
glab repo delete $org/gitops --yes
glab repo delete $org/metaphor-frontend --yes
glab repo delete $org/metaphor --yes

## SSH Key
local id=$(curl -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/user/keys/ | jq '.[] | select(.title=="kubefirst-k3d-ssh-key") | .id')
if [[ -z $id ]]; then
  curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/user/keys/$id
fi
