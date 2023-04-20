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
local cluster_name="kubefirst-fred"


##################
# CONFIGURATIONS #
##################

local github_api="https://api.github.com"
local gitlab_api="https://gitlab.com/api/v4"
local civo_api="https://api.civo.com/v2"


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

if [ -z "${CIVO_TOKEN}" ]; then
  echo "Please set the CIVO_TOKEN environment variable"
fi

#############
# FUNCTIONS #
#############
function say {
    gum style --foreground 93 "$1"
}

########
# menu #
########

gum style \
	--foreground 212 --border-foreground 212 --border double \
	--align center --width 100 --margin "1 2" --padding "2 4" \
	'k1-utils' 'With great power comes great responsibility, use carefully!'

gum format -- "Which platform?"
local platform=$(gum choose \
    "1- GitHub" \
    "2- GitLab" \
    "3- k3d" \
    "4- Civo" \
    "5- Misc" \
    "6- EXIT" \
)

local action=""
local platform_name=${platform//[0-9]- /}
if [[ "$platform" == 1* || "$platform" == 2* ]] ; then
    gum format -- "What do you to do with $platform_name?"
    local action=$(gum choose \
        "1- destroy" \
        "2- make repos public" \
        "3- get token scopes" \
        "4- add a repo with Terraform" \
    )
fi

if [[ "$platform" == 3* || "$platform" == 4* ]] ; then
    gum format -- "What do you to do $platform_name?"
    local action=$(gum choose \
        "1- destroy" \
    )
fi

if [[ "$platform" == 5* ]] ; then
    gum format -- "What do you to do?"
    local action=$(gum choose \
        "1- clean logs" \
    )
fi

##################
# destroy GitHub #
##################
if [[ "$platform" == 1* && "$action" == 1* ]] ; then

    local confirmation=$(gum confirm && echo "true" || echo "false")

    if [[ $confirmation == "true" ]] ; then
        say "Destroying everything GitHub"

        # Groups
        say "Destroying GitHub Groups"
        say "Destroying GitHub Group Developer"
        curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/orgs/$org/teams/developers
        say "Destroying GitHub Group Admins"
        curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/orgs/$org/teams/admins

        # Repos
        say "Destroying GitHub repositories"
        say "Destroying GitHub repository $username/gitops"
        curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$username/gitops
        say "Destroying GitHub repository $username/metaphor"
        curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$username/metaphor
        say "Destroying GitHub repository $org/gitops"
        curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$org/gitops
        say "Destroying GitHub repository $org/metaphor"
        curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$org/metaphor
    fi


##################
# destroy GitLab #
##################
elif [[ "$platform" == 2* && "$action" == 1* ]] ; then

    local confirmation=$(gum confirm && echo "true" || echo "false")

    if [[ $confirmation == "true" ]] ; then
        echo "Destroying everything GitLab"

        # Groups
        say "Destroying GitLab Groups (if any)"

        ## Developers
        local id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/ | jq '.[] | select(.full_path=="'$org'/developers") | .id')
        if [[ ! -z $id ]]; then
            say "Destroying GitLab Group Developers"
            curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$id
        fi

        ## admins
        local id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/ | jq '.[] | select(.full_path=="'$org'/admins") | .id')
        if [[ ! -z $id ]]; then
            say "Destroying GitLab Group Admins"
            curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$id
        fi

        # Repos
        say "Destroying GitLab Repositories & Registry (if any)"

        ## gitops
        local project_id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$org/projects/ | jq '.[] | select(.name=="gitops") | .id')
        if [[ ! -z $project_id ]]; then
            say "Destroying GitLab Repository gitops"
            curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id
        fi

        ## metaphor
        local project_id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$org/projects/ | jq '.[] | select(.name=="metaphor") | .id')

        if [[ ! -z $project_id ]]; then
            local registry_id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id/registry/repositories | jq '.[].id')

            if [[ ! -z $registry_id ]]; then
                ### Container Registry Tags
                say "Destroying GitLab Container Registry Tags for metaphor"
                curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id/registry/repositories/$registry_id/tags/ --data "name_regex=.*"

                ### Container Registry
                say "Destroying GitLab Container Registry for metaphor"
                curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id/registry/repositories/$registry_id
            fi

            ### Repository
            say "Destroying GitLab Repository metaphor"
            curl -sS -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id
        fi

        # SSH Key
        local id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/user/keys/ | jq '.[] | select(.title=="kubefirst-k3d-ssh-key") | .id')
        if [[ ! -z $id ]]; then
            say "Destroying GitLab SSH Key"
            curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/user/keys/$id
        fi
    fi


#######################
# GitHub repos public #
#######################
elif [[ "$platform" == 1* && "$action" == 2* ]] ; then

    local confirmation=$(gum confirm && echo "true" || echo "false")

    if [[ $confirmation == "true" ]] ; then
        say "Changing GitHub Private Repositories to Public ones"

        # gitops
        say "Changing GitHub Private Repositories gitops to Public ones"
        curl -sS -L -X PATCH -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$username/gitops  -d '{"private":false}'
        curl -sS -L -X PATCH -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$org/gitops  -d '{"private":false}'

        # metaphor
        say "Changing GitHub Private Repositories metaphor to Public ones"
        curl -sS -L -X PATCH -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$username/metaphor  -d '{"private":false}'
        curl -sS -L -X PATCH -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$org/metaphor  -d '{"private":false}'
    fi


#######################
# GitLab repos public #
#######################
elif [[ "$platform" == 2* && "$action" == 2* ]] ; then

    local confirmation=$(gum confirm && echo "true" || echo "false")

    if [[ $confirmation == "true" ]] ; then
        say "Changing GitLab Private Repositories to Public ones (if any)"

        # gitops
        local project_id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$org/projects/ | jq '.[] | select(.name=="gitops") | .id')
        if [[ ! -z $project_id ]]; then
            say "Changing GitHub Private Repository gitops to a Public one"
            curl -sS -X PUT -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id -d '{"visibility":"public"}'
        fi

        # metaphor
        local project_id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$org/projects/ | jq '.[] | select(.name=="metaphor") | .id')
        if [[ ! -z $project_id ]]; then
            say "Changing GitHub Private Repository metaphor to a Public one"
            curl -sS -X PUT -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id -d '{"visibility":"public"}'
        fi
    fi


#######################
# GitLab token scopes #
#######################
elif [[ "$platform" == 1* && "$action" == 3* ]] ; then

    say "Getting the scopes of the GitLab token"
    curl -sS -f -I -H "Authorization: Bearer $GITHUB_TOKEN" $github_api | grep -i x-oauth-scopes | grep -v access-control-expose-headers


#######################
# GitLab token scopes #
#######################
elif [[ "$platform" == 2* && "$action" == 3* ]] ; then

    say "Getting the scopes of the GitHub token"
    curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/personal_access_tokens/self | jq '.scopes'


####################################
# GitHub add a repo with Terraform #
####################################
elif [[ "$platform" == 1* && "$action" == 4* ]] ; then
    say "Creating a PR to add a repository named 'newtestrepo' with Terraform on GitHub"

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


####################################
# GitLab add a repo with Terraform #
####################################
elif [[ "$platform" == 2* && "$action" == 4* ]] ; then
    say "Creating a PR to add a repository named 'newtestrepo' with Terraform on GitLab"

    local file="terraform/gitlab/projects.tf"
    local branch="testing-atlantis"

    git clone git@gitlab.com:$org/gitops.git
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


    git remote -v | head -n 1 | awk -F "@" '{print $2}' | awk -F " " '{print $1}' | sed 's/:/\//g' | sed 's/\.git/\/-\/merge_requests\/new\?merge_request%5Bsource_branch%5D='$branch'/g' | awk '{print "http://"$1}' | xargs open

    cd ..
    rm -rf gitops


###############
# Destroy k3d #
###############
elif [[ "$platform" == 3* && "$action" == 1* ]] ; then

    local confirmation=$(gum confirm && echo "true" || echo "false")

    if [[ $confirmation == "true" ]] ; then
        say "Destroying everything k3d"

        # cluster
        say "Destroying k3d kubefirst cluster"
        k3d cluster delete kubefirst

        # kubefirst settings
        say "Destroying all kubefirst files & folders"
        rm -rf ~/.k1
        rm ~/.kubefirst
    fi


################
# Destroy Civo #
################
elif [[ "$platform" == 4* && "$action" == 1* ]] ; then

    local confirmation=$(gum confirm && echo "true" || echo "false")

    if [[ $confirmation == "true" ]] ; then
        say "Destroying everything Civo"

        local cluster_id=$(curl -sS -H "Authorization: Bearer $CIVO_TOKEN" $civo_api/kubernetes/clusters | jq -r '.items[] | select(.name=="'$cluster_name'")  | .id')

        # volumes
        local volumes_ids=($(curl -sS -H "Authorization: Bearer $CIVO_TOKEN" $civo_api/volumes | jq -r '.[] | select(.cluster_id=="'$cluster_id'") | .id'))
        say "Destroying all Civo volumes (if any)"
        for volume_id in $volumes_ids; do
            curl -X DELETE -H "Authorization: Bearer $CIVO_TOKEN" $civo_api/volumes/$volume_id
        done

        # cluster
        if [[ ! -z $cluster_id ]]; then
            say "Destroying the Civo cluster"
            curl -X DELETE -H "Authorization: Bearer $CIVO_TOKEN" $civo_api/kubernetes/clusters/$cluster_id
        fi

        # network
        local network_id=$(curl -sS -H "Authorization: Bearer $CIVO_TOKEN" $civo_api/networks | jq -r '.[] | select(.label=="'$cluster_name'") | .id')
        if [[ ! -z $network_id ]]; then
            say "Destroying the Civo network"
            curl -X DELETE -H "Authorization: Bearer $CIVO_TOKEN" $civo_api/networks/$network_id
        fi
    fi

elif [[ "$platform" == 5* ]] ; then
    local confirmation=$(gum confirm && echo "true" || echo "false")

    if [[ $confirmation == "true" ]] ; then
        say "Destroying the kubefirst logs"
        rm ~/.k1/logs/*
    fi

elif [[ "$platform" == 6* ]] ; then
    echo "\n"
    say "Goodbye my lover"
    say "Goodbye my friend"
    say "You have been the one"
    say "You have been the one for me"
    echo "\n"
    exit

fi
