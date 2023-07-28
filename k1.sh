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
  exit
fi

if ! which jq >/dev/null; then
  echo "Please install jq - https://github.com/stedolan/jq"
  exit
fi

if ! which gum >/dev/null; then
  echo "Please install gum - https://github.com/charmbracelet/gum/"
  exit
fi

if ! which doctl >/dev/null; then
  echo "Please install doctl - https://github.com/digitalocean/doctl"
  exit
fi


############
# ENV VARS #
############
if [ -z "${GITHUB_TOKEN}" ]; then
  echo "Please set the GITHUB_TOKEN environment variable"
  exit
fi

if [ -z "${GITLAB_TOKEN}" ]; then
  echo "Please set the GITLAB_TOKEN environment variable"
  exit
fi

if [ -z "${CIVO_TOKEN}" ]; then
  echo "Please set the CIVO_TOKEN environment variable"
  exit
fi

if [ -z "${DO_TOKEN}" ]; then
  echo "Please set the DO_TOKEN environment variable"
  exit
fi

if [ -z "${DO_SPACES_KEY}" ]; then
  echo "Please set the DO_SPACES_KEY environment variable"
  exit
fi

if [ -z "${DO_SPACES_SECRET}" ]; then
  echo "Please set the DO_SPACES_SECRET environment variable"
  exit
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

# Welcome message
gum style \
	--foreground 212 --border-foreground 212 --border double \
	--align center --width 100 --margin "1 2" --padding "2 4" \
	'k1-utils' 'With great power comes great responsibility, use carefully!'

# Platform menu
gum format -- "Which platform?"
local platform=$(gum choose \
    "1- Civo" \
    "2- DigitalOcean" \
    "3- GitHub" \
    "4- GitLab" \
    "5- k3d" \
    "6- kubefirst" \
    "7- EXIT" \
)

# Git Providers Submenu
local action=""
local platform_name=${platform//[0-9]- /}
if [[ "$platform" == *"GitHub" || "$platform" == *"GitLab" ]] ; then
    gum format -- "What do you to do with $platform_name?"
    local action=$(gum choose \
        "1- destroy" \
        "2- make repos public" \
        "3- get token scopes" \
        "4- add a repo with Terraform" \
    )
fi

# Cloud Providers Submenu
if [[ "$platform" == *"k3d" || "$platform" == *"Civo" || "$platform" == *"Google Cloud" || "$platform" == *"DigitalOcean" ]] ; then
    gum format -- "What do you to do $platform_name?"
    action=$(gum choose \
        "1- destroy" \
    )
fi

# kubefirst submenu
if [[ "$platform" == *"kubefirst" ]] ; then
    gum format -- "What do you to do?"
    action=$(gum choose \
        "1- destroy" \
        "2- clean logs" \
        "3- backup configs" \
    )
fi

#
# GitHub
#
if [[ "$platform" == *"GitHub" ]] ; then

    ##################
    # destroy GitHub #
    ##################
    if [[ "$action" == *"destroy" ]] ; then

        local confirmation=$(gum confirm && echo "true" || echo "false")

        if [[ $confirmation == "true" ]] ; then
            say "Destroying everything GitHub"

            # Groups
            say "Destroying GitHub Groups (if any)"

            if [[ ! $(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/orgs/$org/teams/developers 2> /dev/null | grep "Not Found") ]]; then
                say "Destroying GitHub Group Developer"
                curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/orgs/$org/teams/developers
            fi

            if [[ ! $(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/orgs/$org/teams/admins 2> /dev/null | grep "Not Found") ]]; then
                say "Destroying GitHub Group Admins"
                curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/orgs/$org/teams/admins
            fi

            # Repos
            say "Destroying GitHub repositories (if any)"

            if [[ ! $(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$username/gitops 2> /dev/null | grep "Not Found") ]]; then
                say "Destroying GitHub repository $username/gitops"
                curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$username/gitops
            fi

            if [[ ! $(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$username/metaphor 2> /dev/null | grep "Not Found") ]]; then
                say "Destroying GitHub repository $username/metaphor"
                curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$username/metaphor
            fi

            if [[ ! $(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$org/gitops 2> /dev/null | grep "Not Found") ]]; then
                say "Destroying GitHub repository $org/gitops"
                curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$org/gitops
            fi

            if [[ ! $(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$org/metaphor 2> /dev/null | grep "Not Found") ]]; then
                say "Destroying GitHub repository $org/metaphor"
                curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$org/metaphor
            fi
        fi

    #######################
    # GitHub repos public #
    #######################
    elif [[ "$action" == *"make repos public" ]] ; then

        local confirmation=$(gum confirm && echo "true" || echo "false")

        if [[ $confirmation == "true" ]] ; then
            say "Changing GitHub Private Repositories to Public ones (if any)"

            # gitops
            if [[ ! $(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$username/gitops 2> /dev/null | grep "Not Found") ]]; then
                say "Changing GitHub Private Repositories gitops to Public"
                curl -sS -L -X PATCH -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$username/gitops  -d '{"private":false}'
            fi

            if [[ ! $(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/orgs/$org/gitops 2> /dev/null | grep "Not Found") ]]; then
                say "Changing GitHub Private Repositories gitops to Public"
                curl -sS -L -X PATCH -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$org/gitops  -d '{"private":false}'
            fi

            # metaphor
            if [[ ! $(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$username/metaphor 2> /dev/null | grep "Not Found") ]]; then
                say "Changing GitHub Private Repositories metaphor to Public"
                curl -sS -L -X PATCH -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$username/metaphor  -d '{"private":false}'
            fi

            if [[ ! $(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/orgs/$org/metaphor 2> /dev/null | grep "Not Found") ]]; then
                say "Changing GitHub Private Repositories metaphor to Public"
                curl -sS -L -X PATCH -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$org/metaphor  -d '{"private":false}'
            fi
        fi

    #######################
    # GitHub token scopes #
    #######################
    elif [[ "$action" == *"get token scopes" ]] ; then

        say "Getting the scopes of the GitLab token"
        curl -sS -f -I -H "Authorization: Bearer $GITHUB_TOKEN" $github_api | grep -i x-oauth-scopes | grep -v access-control-expose-headers

    ####################################
    # GitHub add a repo with Terraform #
    ####################################
    elif [[ "$action" == *"add a repo with Terraform" ]] ; then
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
    fi

#
# GitLab
#

elif [[ "$platform" == *"GitLab" ]] ; then

    ##################
    # destroy GitLab #
    ##################
    if [["$action" == *"destroy" ]] ; then

        local confirmation=$(gum confirm && echo "true" || echo "false")

        if [[ $confirmation == "true" ]] ; then
            echo "Destroying everything GitLab"

            # Groups
            say "Destroying GitLab Groups (if any)"

            ## Developers
            local id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/ | jq '.[] | select(.full_path=="'$org'/developers") | .id')
            if [[ -n $id ]]; then
                say "Destroying GitLab Group Developers"
                curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$id
                echo ""
            fi

            ## admins
            local id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/ | jq '.[] | select(.full_path=="'$org'/admins") | .id')
            if [[ -n $id ]]; then
                say "Destroying GitLab Group Admins"
                curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$id
                echo ""
            fi

            # Repos
            say "Destroying GitLab Repositories & Registry (if any)"

            ## gitops
            local project_id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$org/projects/ | jq '.[] | select(.name=="gitops") | .id')
            if [[ -n $project_id ]]; then
                say "Destroying GitLab Repository gitops"
                curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id
                echo ""
            fi

            ## metaphor
            local project_id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$org/projects/ | jq '.[] | select(.name=="metaphor") | .id')

            if [[ -n $project_id ]]; then
                local registry_id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id/registry/repositories | jq '.[].id')

                if [[ -n $registry_id ]]; then
                    ### Container Registry Tags
                    say "Destroying GitLab Container Registry Tags for metaphor"
                    curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id/registry/repositories/$registry_id/tags/ --data "name_regex=.*"
                    echo ""

                    ### Container Registry
                    say "Destroying GitLab Container Registry for metaphor"
                    curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id/registry/repositories/$registry_id
                    echo ""
                fi

                ### Repository
                say "Destroying GitLab Repository metaphor"
                curl -sS -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id
                echo ""
            fi

            # SSH Key
            say "Destroying GitLab SSH Key (if any)"

            local id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/user/keys/ | jq '.[] | select(.title=="kubefirst-k3d-ssh-key") | .id')
            if [[ -n $id ]]; then
                say "Destroying GitLab kubefirst-k3d-ssh-key SSH Key "
                curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/user/keys/$id
                echo ""
            fi

            local id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/user/keys/ | jq '.[] | select(.title=="kbot-ssh-key") | .id')
            if [[ -n $id ]]; then
                say "Destroying GitLab kbot-ssh-key SSH Key "
                curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/user/keys/$id
                echo ""
            fi
        fi

    #######################
    # GitLab repos public #
    #######################
    elif [[ "$action" == *"make repos public" ]] ; then

        local confirmation=$(gum confirm && echo "true" || echo "false")

        if [[ $confirmation == "true" ]] ; then
            say "Changing GitLab Private Repositories to Public ones (if any)"

            # gitops
            local project_id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$org/projects/ | jq '.[] | select(.name=="gitops") | .id')
            if [[ -n $project_id ]]; then
                say "Changing GitHub Private Repository gitops to a Public one"
                curl -sS -X PUT -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id -d '{"visibility":"public"}'
            fi

            # metaphor
            local project_id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$org/projects/ | jq '.[] | select(.name=="metaphor") | .id')
            if [[ -n $project_id ]]; then
                say "Changing GitHub Private Repository metaphor to a Public one"
                curl -sS -X PUT -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id -d '{"visibility":"public"}'
            fi
        fi

    #######################
    # GitLab token scopes #
    #######################
    elif [[ "$action" == *"get token scopes" ]] ; then

        say "Getting the scopes of the GitHub token"
        curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/personal_access_tokens/self | jq '.scopes'

    ####################################
    # GitLab add a repo with Terraform #
    ####################################
    elif [[ "$action" == *"add a repo with Terraform" ]] ; then
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

    fi

###############
# Destroy k3d #
###############
elif [[ "$platform" == *"k3d" && "$action" == *"destroy" ]] ; then

    local confirmation=$(gum confirm && echo "true" || echo "false")

    if [[ $confirmation == "true" ]] ; then
        say "Destroying k3d clusters (if any)"

        # cluster
        local cluster=$(k3d cluster list | grep kubefirst-console)
        if [[ -n $cluster ]]; then
            say "Destroying k3d kubefirst-console cluster"
            k3d cluster delete kubefirst-console
        fi

        local cluster=$(k3d cluster list | grep kubefirst)
        if [[ -n $cluster ]]; then
            say "Destroying k3d kubefirst cluster"
            k3d cluster delete kubefirst
        fi

        # kubefirst settings
        say "Destroying all kubefirst files & folders (if any)"

        if [ -d ~/.k1 ]; then
            say "Destroying kubefirst folder"
            rm -rf ~/.k1
        fi

        if [ -f ~/.kubefirst ]; then
            say "Destroying kubefirst configuration file"
            rm ~/.kubefirst
        fi
    fi


################
# Destroy Civo #
################
elif [[ "$platform" == *"Civo" && "$action" == *"destroy" ]] ; then

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
        if [[ -n $cluster_id ]]; then
            say "Destroying the Civo cluster"
            curl -X DELETE -H "Authorization: Bearer $CIVO_TOKEN" $civo_api/kubernetes/clusters/$cluster_id
        fi

        # network
        local network_id=$(curl -sS -H "Authorization: Bearer $CIVO_TOKEN" $civo_api/networks | jq -r '.[] | select(.label=="'$cluster_name'") | .id')
        if [[ -n $network_id ]]; then
            say "Destroying the Civo network"
            curl -X DELETE -H "Authorization: Bearer $CIVO_TOKEN" $civo_api/networks/$network_id
        fi
    fi

#
# kubefirst
#
elif [[ "$platform" == *"kubefirst" ]] ; then
    #####################
    # Destroy kubefirst #
    #####################
    if [[ "$action" == *"destroy" ]] ; then
        local confirmation=$(gum confirm && echo "true" || echo "false")

        if [[ $confirmation == "true" ]] ; then
            say "Destroying all kubefirst files & folders (if any)"

            if [ -d ~/.k1 ]; then
                say "Destroying kubefirst folder"
                rm -rf ~/.k1
            fi

            if [ -f ~/.kubefirst ]; then
                say "Destroying kubefirst configuration file"
                rm ~/.kubefirst
            fi
        fi

    ##########################
    # Destroy Kubefirst Logs #
    ##########################
    elif [[ "$action" == *"clean logs" ]] ; then
        local confirmation=$(gum confirm && echo "true" || echo "false")

        if [[ $confirmation == "true" ]] ; then
            say "Destroying the kubefirst logs"

            if [ -d ~/.k1/logs ]; then
                rm ~/.k1/logs/*
            fi
        fi

    ###################################################
    # Backup Kubefirst Configurations files + folders #
    ###################################################
    elif [[ "$action" == *"backup configs" ]] ; then
        say "Backuping kubefirst .kubefirst file & .k1 folder from your home directory (if they exist)"

        if [ -d ~/.k1 && -f ~/.kubefirst ]; then
            say "Backuping everything"
            zip k1-configs.zip ~/.k1 ~/.kubefirst
        elif [ -d ~/.k1 ]; then
            say "Backuping only the ~/.k1 folder"
            zip k1-configs.zip ~/.k1
        elif [ -f ~/.kubefirst ]; then
            say "Backuping only the ~/.kubefirst file"
            zip k1-configs.zip ~/.kubefirst
        fi

    fi

########################
# Destroy DigitalOcean #
########################
elif [[ "$platform" == *"DigitalOcean" && "$action" == *"destroy" ]] ; then
    local confirmation=$(gum confirm && echo "true" || echo "false")

    if [[ $confirmation == "true" ]] ; then
        say "Destroying everything DigitalOcean"

        local cluster=$(doctl kubernetes cluster list | grep "$cluster_name")
        if [[ -n $cluster ]]; then
            say "Destroying DigitalOcean cluster with associated resources"
            doctl kubernetes cluster delete "$cluster_name" --dangerous --force
        fi
    fi

############
# Quitting #
############
elif [[ "$platform" == *"EXIT" ]] ; then
    echo "\n"
    say "Goodbye my lover"
    say "Goodbye my friend"
    say "You have been the one"
    say "You have been the one for me"
    echo "\n"
    exit

fi
