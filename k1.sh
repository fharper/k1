#!/bin/zsh

##################################################################
#
# Small ZSH script to clean my kubefirst tests or help me debug
#
# Please use at your own risk
#
##################################################################

#######################
# USER CONFIGURATIONS #
#######################

# Please update the following
local username="fharper"
local org="kubefirst-fharper"


##################
# CONFIGURATIONS #
##################

local github_api="https://api.github.com"
local gitlab_api="https://gitlab.com/api/v4"


########
# TOOL #
########
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


############
# ENV VARS #
############
if [ -z "${GITHUB_TOKEN}" ]; then
  echo "Please set the GITHUB_TOKEN environment variable"
fi

if [ -z "${GITLAB_TOKEN}" ]; then
  echo "Please set the GITLAB_TOKEN environment variable"
fi

########
# menu #
########

gum format -- "Which Git Provider??"
local git_provider=$(gum choose \
    "1- GitHub" \
    "2- GitLab" \
)

gum format -- "What do you to do?"
local action=$(gum choose \
    "1- destroy k3d" \
    "2- make repos public" \
    "3- get token scopes" \
    "4- add a repo with Terraform" \
)

########################
# destroy k3d + GitHub #
########################
if [[ "$git_provider" == 1-* && "$action" == 1-* ]] ; then

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
elif [[ "$git_provider" == 2-* && "$action" == 1-* ]] ; then

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

#######################
# GitHub repos public #
#######################
elif [[ "$git_provider" == 1-* && "$action" == 2-* ]] ; then

    # gitops
    curl -sS -L -X PATCH -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$username/gitops  -d '{"private":false}'
    curl -sS -L -X PATCH -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$org/gitops  -d '{"private":false}'

    # metaphor
    curl -sS -L -X PATCH -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$username/metaphor  -d '{"private":false}'
    curl -sS -L -X PATCH -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$org/metaphor  -d '{"private":false}'


#######################
# GitLab repos public #
#######################
elif [[ "$git_provider" == 2-* && "$action" == 2-* ]] ; then

    # gitops
    local project_id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$org/projects/ | jq '.[] | select(.name=="gitops") | .id')
    if [[ -z $project_id ]]; then
        curl -sS -X PUT -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id -d '{"visibility":"public"}'
    fi

    # metaphor
    local project_id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$org/projects/ | jq '.[] | select(.name=="metaphor") | .id')
    if [[ -z $project_id ]]; then
        curl -sS -X PUT -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id -d '{"visibility":"public"}'
    fi


#######################
# GitLab token scopes #
#######################
elif [[ "$git_provider" == 1-* && "$action" == 3-* ]] ; then

    curl -sS -f -I -H "Authorization: Bearer $GITHUB_TOKEN" $github_api | grep -i x-oauth-scopes | grep -v access-control-expose-headers

#######################
# GitLab token scopes #
#######################
elif [[ "$git_provider" == 2-* && "$action" == 3-* ]] ; then

    curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/personal_access_tokens/self | jq '.scopes'


####################################
# GitHub add a repo with Terraform #
####################################
elif [[ "$git_provider" == 1-* && "$action" == 4-* ]] ; then
    local file="terraform/github/repos.tf"
    local branch="testing-atlantis"

    git clone git@github.com:$org/gitops.git
    cd gitops

    echo '' >> $file
    echo 'module "newtestrepo" {' >> $file
    echo '  source = "./modules/repository"' >> $file
    echo '  repo_name          = "newtestrepo"' >> $file
    echo '  archive_on_destroy = false' >> $file
    echo '  auto_init          = false' >> $file
    echo '}' >> $file

    git checkout -b $branch
    git add $file
    git commit -m "adding a new repository for testing Atlantis"
    git push -u origin

    git remote -v | head -n 1 | awk -F "@" '{print $2}' | awk -F " " '{print $1}' | sed 's/:/\//g' | sed 's/\.git/\/pull\/new\/'$branch'/g' | awk '{print "http://"$1}' | xargs open

    cd ..
    rm -rf gitops

fi
