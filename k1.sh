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

# Please update the following for default values
local cluster_name="kubefirst-fred"
local google_cloud_region="us-east1"
local github_organization="kubefirst-fharper"
local github_username="fharper"
local gitlab_organization="kubefirst-fharper"
local mongodb_hostname="localhost"
local mongodb_password="pass"
local mongodb_port=27017
local mongodb_username="user"


##################
# CONFIGURATIONS #
##################

local github_api="https://api.github.com"
local gitlab_api="https://gitlab.com/api/v4"
local civo_api="https://api.civo.com/v2"

# Used for input using the getUserInput function
# You can't output text to display in the Terminal while a subshell (with '$()') is waiting for the command output.
# It will display only in the end, which isn't useful in the while condition I'm using.
# See https://stackoverflow.com/a/64810239/895232
local user_input=""


########
# TOOL #
########

# Check if gum is installed
if ! which gum >/dev/null; then
  echo "Please install gum - https://github.com/charmbracelet/gum/"
  exit
fi


#############
# FUNCTIONS #
#############

#
# Print something with style
#
# @param the message to display
#
function say {
    gum style --foreground 93 "$1"
}

#
# Display an error message with red formatting
#
# @param the error message
#
function error {
    gum style --foreground 9 "$1"
}

#
# Clear last terminal line
#
function clearLastLine {
    tput cuu 1 >&2
    tput el >&2
}

#
# Get the cluster name to destroy
#
# Use $cluster_name as default if nothing is entered
#
function getClusterName {
    say "What is the cluster name?"
    local cluster=$(gum input --placeholder="$cluster_name")

    # If nothing is entered, it will use the default cluster name
    if [[ -n "$cluster" ]] ; then
        cluster_name="$cluster"
    fi
    clearLastLine
}

#
# Ask the user for a specific input, which cannot be empty
#
# @param input name
# @param the label asking the user's input
# @param a placeholder (not require)
#
# return the user input
#
function getUserInput {
    # Be sure it's empty from previous call
    user_input=""

    # Cannot be empty
    while [[ "$user_input" = "" ]] ; do
        say "$2"
        user_input=$(gum input --placeholder="$3")

        if [[ -z "$user_input" ]] ; then
            clearLastLine
            error "$1 cannot be empty"
            echo
        fi
    done
}

#
# Let the user select a region from the list, or enter one manually if no list is provided
# It will set the correct variable depending on the cloud.
#
# @param the cloud targeted
#
#
function getClusterRegion {

    # Google Cloud
    if [[ "$1" == "Google Cloud" ]] ; then

        say "Fetching Google Cloud regions"
        local regions=$(gcloud compute regions list  --format='json' | jq -r '.[].name')
        clearLastLine

        gum format -- "Which region?"
        google_cloud_region=$(echo "$regions" | gum choose --selected "$google_cloud_region")
        clearLastLine
    else
        error "cloud not supported yet for region listing"
    fi
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
    "5- Google Cloud" \
    "6- k3d" \
    "7- kubefirst" \
    "8- MongoDB" \
    "9- EXIT" \
)
clearLastLine

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

# MongoDB submenu
if [[ "$platform" == *"MongoDB" ]] ; then
    gum format -- "What do you to do?"
    action=$(gum choose \
        "1- drop gitops-catalog" \
        "2- remove an installed app state" \
    )
fi

clearLastLine

#
# GitHub
#
if [[ "$platform" == *"GitHub" ]] ; then

    # Check if GitHub token environment variable is set
    if [[ -z "${GITHUB_TOKEN}" ]] ; then
        echo "Please set the GITHUB_TOKEN environment variable"
        exit

    ##################
    # destroy GitHub #
    ##################
    elif [[ "$action" == *"destroy" ]] ; then

        local confirmation=$(gum confirm && echo "true" || echo "false")

        if [[ $confirmation == "true" ]] ; then
            say "Destroying everything GitHub"

            # Groups
            say "Destroying GitHub Groups (if any)"

            if [[ ! $(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/orgs/$github_organization/teams/developers 2> /dev/null | grep "Not Found") ]]; then
                say "Destroying GitHub Group Developer"
                curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/orgs/$github_organization/teams/developers
            fi

            if [[ ! $(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/orgs/$github_organization/teams/admins 2> /dev/null | grep "Not Found") ]]; then
                say "Destroying GitHub Group Admins"
                curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/orgs/$github_organization/teams/admins
            fi

            # Repos
            say "Destroying GitHub repositories (if any)"

            if [[ ! $(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$github_username/gitops 2> /dev/null | grep "Not Found") ]]; then
                say "Destroying GitHub repository $github_username/gitops"
                curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$github_username/gitops
            fi

            if [[ ! $(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$github_username/metaphor 2> /dev/null | grep "Not Found") ]]; then
                say "Destroying GitHub repository $github_username/metaphor"
                curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$github_username/metaphor
            fi

            if [[ ! $(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$github_organization/gitops 2> /dev/null | grep "Not Found") ]]; then
                say "Destroying GitHub repository $github_organization/gitops"
                curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$github_organization/gitops
            fi

            if [[ ! $(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$github_organization/metaphor 2> /dev/null | grep "Not Found") ]]; then
                say "Destroying GitHub repository $github_organization/metaphor"
                curl -sS -X DELETE -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$github_organization/metaphor
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
            if [[ ! $(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$github_username/gitops 2> /dev/null | grep "Not Found") ]]; then
                say "Changing GitHub Private Repositories gitops to Public"
                curl -sS -L -X PATCH -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$github_username/gitops  -d '{"private":false}'
            fi

            if [[ ! $(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/orgs/$github_organization/gitops 2> /dev/null | grep "Not Found") ]]; then
                say "Changing GitHub Private Repositories gitops to Public"
                curl -sS -L -X PATCH -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$github_organization/gitops  -d '{"private":false}'
            fi

            # metaphor
            if [[ ! $(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$github_username/metaphor 2> /dev/null | grep "Not Found") ]]; then
                say "Changing GitHub Private Repositories metaphor to Public"
                curl -sS -L -X PATCH -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$github_username/metaphor  -d '{"private":false}'
            fi

            if [[ ! $(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/orgs/$github_organization/metaphor 2> /dev/null | grep "Not Found") ]]; then
                say "Changing GitHub Private Repositories metaphor to Public"
                curl -sS -L -X PATCH -H "Authorization: Bearer $GITHUB_TOKEN" $github_api/repos/$github_organization/metaphor  -d '{"private":false}'
            fi
        fi

    #######################
    # GitHub token scopes #
    #######################
    elif [[ "$action" == *"get token scopes" ]] ; then
        say "Getting the scopes of the GitHub token"
        echo
        curl -sS -f -I -H "Authorization: token ${GITHUB_TOKEN}" https://api.github.com | grep ^x-oauth-scopes: | cut -d' ' -f2- | tr -d "[:space:]" | tr ',' '\n'
        echo "\n"

    ####################################
    # GitHub add a repo with Terraform #
    ####################################
    elif [[ "$action" == *"add a repo with Terraform" ]] ; then
        say "Creating a PR to add a repository named 'newtestrepo' with Terraform on GitHub"

        local file="terraform/github/repos.tf"
        local branch="testing-atlantis"

        git clone git@github.com:$github_organization/gitops.git
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
    # We need to do API calls as the glab CLI is extremely limited

    # Check if jq is installed
    if ! which jq >/dev/null; then
        echo "Please install jq - https://github.com/stedolan/jq"
        exit

    # Check if the GitLab token environment variable is set
    elif [[ -z "${GITLAB_TOKEN}" ]] ; then
        echo "Please set the GITLAB_TOKEN environment variable"
        exit

    ##################
    # destroy GitLab #
    ##################
    elif [[ "$action" == *"destroy" ]] ; then

        local confirmation=$(gum confirm && echo "true" || echo "false")

        if [[ $confirmation == "true" ]] ; then
            echo "Destroying everything GitLab"

            # Groups
            say "Destroying GitLab Groups (if any)"

            ## Developers
            local id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/ | jq '.[] | select(.full_path=="'$gitlab_organization'/developers") | .id')
            if [[ -n $id ]]; then
                say "Destroying GitLab Group Developers"
                curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$id
                echo ""
            fi

            ## admins
            local id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/ | jq '.[] | select(.full_path=="'$gitlab_organization'/admins") | .id')
            if [[ -n $id ]]; then
                say "Destroying GitLab Group Admins"
                curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$id
                echo ""
            fi

            # Repos
            say "Destroying GitLab Repositories & Registry (if any)"

            ## gitops
            local project_id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$gitlab_organization/projects/ | jq '.[] | select(.name=="gitops") | .id')
            if [[ -n $project_id ]]; then
                say "Destroying GitLab Repository gitops"
                curl -X DELETE -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id
                echo ""
            fi

            ## metaphor
            local project_id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$gitlab_organization/projects/ | jq '.[] | select(.name=="metaphor") | .id')

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
            local project_id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$gitlab_organization/projects/ | jq '.[] | select(.name=="gitops") | .id')
            if [[ -n $project_id ]]; then
                say "Changing GitHub Private Repository gitops to a Public one"
                curl -sS -X PUT -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id -d "visibility=public"
            fi

            # metaphor
            local project_id=$(curl -sS -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/groups/$gitlab_organization/projects/ | jq '.[] | select(.name=="metaphor") | .id')
            if [[ -n $project_id ]]; then
                say "Changing GitHub Private Repository metaphor to a Public one"
                curl -sS -X PUT -H "Authorization: Bearer $GITLAB_TOKEN" $gitlab_api/projects/$project_id -d "visibility=public"
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

        git clone git@gitlab.com:$gitlab_organization/gitops.git
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


#
# k3d
#
elif [[ "$platform" == *"k3d" ]] ; then

    # Check if they have k3d installed first
    if ! which k3d >/dev/null; then
        echo "Please install k3d - https://github.com/k3d-io/k3d"
        exit

    ###############
    # Destroy k3d #
    ###############
    elif [[ "$action" == *"destroy" ]] ; then
        local confirmation=$(gum confirm && echo "true" || echo "false")

        if [[ $confirmation == "true" ]] ; then
            say "Destroying k3d clusters (if any)"

            # clusters
            local cluster=$(k3d cluster list --output json | jq -r '.[].name' | grep kubefirst)
            if [[ -n $cluster ]]; then
            # kubefirst settings
            say "Destroying all kubefirst files & folders (if any)"

            if [ -d ~/.k1 ]; then
                say "Destroying kubefirst folder"
                rm -rf ~/.k1
            fi

            if [ -f ~/.kubefirst ]; then
                say "Destroying kubefirst configuration file"
                rm ~/.kubefirst
                say "Destroying k3d $cluster cluster"
                k3d cluster delete $cluster
            fi
        fi
    fi


#
# Civo
#
elif [[ "$platform" == *"Civo" ]] ; then

    # Check if civo is installed
    if ! which civo >/dev/null; then
        echo "Please install civo - https://github.com/civo/cli"
        exit

    ################
    # Destroy Civo #
    ################
    elif [[ "$action" == *"destroy" ]] ; then
        getClusterName

        local confirmation=$(gum confirm && echo "true" || echo "false")

        if [[ $confirmation == "true" ]] ; then
            say "Destroying everything Civo"

            # Need to be deleted before the cluster
            local volumes=$(civo volume ls --output json | jq -r '.[] | select(.network_id=="'$cluster_name'") | .id')
            if [[ -n "$volumes" ]]; then
                say "Destroying the Civo Volumes"

                # Destroy each volumes
                for volume (${(f)volumes})
                do
                    civo volumes remove "$volume" --yes
                done
            fi

            local cluster=$(civo kubernetes ls --output json | jq -r '.[] | select(.name=="'$cluster_name'") | .id')
            if [[ -n $cluster ]]; then
                say "Destroying the Civo cluster"

                civo kubernetes remove --yes "$cluster_name"
            fi

            # Need to be deleted after the cluster
            local network=$(civo network ls --output json | jq -r '.[] | select(.label=="'$cluster_name'") | .id')
            if [[ -n $network ]]; then
                say "Destroying the Civo network"

                civo network remove --yes "$cluster_name"
            fi
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

            if [[ -d ~/.k1 ]] ; then
                say "Destroying kubefirst folder"
                rm -rf ~/.k1
            fi

            if [[ -f ~/.kubefirst ]] ; then
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

        if [[ -d ~/.k1 && -f ~/.kubefirst ]] ; then
            say "Backuping everything"
            zip k1-configs.zip ~/.k1 ~/.kubefirst
        elif [[ -d ~/.k1 ]] ; then
            say "Backuping only the ~/.k1 folder"
            zip k1-configs.zip ~/.k1
        elif [[ -f ~/.kubefirst ]] ; then
            say "Backuping only the ~/.kubefirst file"
            zip k1-configs.zip ~/.kubefirst
        fi

    fi


#
# DigitalOcean
#
# CLI docs: https://docs.digitalocean.com/reference/doctl/reference/
#
elif [[ "$platform" == *"DigitalOcean" ]] ; then

    # Check if DigitalOcean CLI is installed
    if ! which doctl >/dev/null; then
        echo "Please install doctl - https://github.com/digitalocean/doctl"
        exit

        ########################
        # Destroy DigitalOcean #
        ########################
    elif [[ "$action" == *"destroy" ]] ; then
        getClusterName

        local confirmation=$(gum confirm && echo "true" || echo "false")

        if [[ $confirmation == "true" ]] ; then
            say "Destroying everything DigitalOcean"

            local cluster=$(doctl kubernetes cluster list | grep "$cluster_name")
            if [[ -n $cluster ]]; then
                say "Destroying DigitalOcean cluster with associated resources"
                doctl kubernetes cluster delete "$cluster_name" --dangerous --force
            fi
        fi
    fi


#
# Google Cloud
#
# CLI docs: https://cloud.google.com/sdk/gcloud/reference
#
elif [[ "$platform" == *"Google Cloud" ]] ; then

    # Check if Google Cloud CLI is installed
    if ! which gcloud >/dev/null; then
        echo "Please install gcloud - https://cloud.google.com/sdk"
        exit

    elif ! which jq >/dev/null; then
        echo "Please install jq - https://github.com/stedolan/jq"
        exit

    ########################
    # Destroy Google Cloud #
    ########################
    elif [[ "$action" == *"destroy" ]] ; then
        getClusterName
        getClusterRegion "Google Cloud"

        local confirmation=$(gum confirm && echo "true" || echo "false")

        if [[ $confirmation == "true" ]] ; then
            say "Destroying everything Google Cloud"

            # Buckets
            local buckets=$(gcloud storage buckets list --filter "$cluster_name" --format='json' | jq -r '.[].storage_url')
            if [[ -n "$buckets" ]]; then
                say "Destroying the Google Cloud bucket(s)"

                for bucket (${(f)buckets})
                do
                    # Using "storage rm -r" instead of "storage buckets delete" will also make deletion of non-empty buckets possible
                    gcloud storage rm -r "$bucket" --quiet
                done
            fi

            # Keyrings (we create them in global)
            say "Destroying the Google Cloud Keyring (if any)"

            local keyrings_groups=$(gcloud kms keyrings list --location global --filter "$cluster_name" --format="json" | jq -r '.[].name')
            if [[ -n "$keyrings_groups" ]]; then

                # Process all the keyrings groups
                for keyrings_group (${(f)keyrings_groups})
                do
                    # Get the keys
                    local keyrings=$(gcloud kms keys list --location global --keyring "$keyrings_group" --format="json" | jq -r '.[].name')
                    if [[ -n "$keyrings" ]]; then

                        for key (${(f)keyrings})
                        do
                            # Get the versions
                            local versions=$(gcloud kms keys versions list --location global --keyring "$keyrings_group" --key "$key" --format="json" | jq -r '.[] | select(.state=="ENABLED") | .name')

                            if [[ -n "$versions" ]]; then

                                #Destroy each versions
                                for version (${(f)versions})
                                do
                                    gcloud kms keys versions destroy "$version"
                                done
                            fi
                        done
                    fi
                done
            fi

            # Services Accounts
            local service_accounts=$(gcloud iam service-accounts list --filter "$cluster_name" --format="json" | jq -r '.[].name' | sed 's/projects\/.*\/serviceAccounts\/\(.*\)/\1/')
            if [[ -n "$service_accounts" ]]; then
                say "Destroying the Google Cloud Services Accounts"

                # Destroy each services accounts
                for service (${(f)service_accounts})
                do
                    gcloud iam service-accounts delete "$service" --quiet
                done
            fi

            # Cluster
            local cluster=$(gcloud container clusters list --filter "$cluster_name")
            if [[ -n "$cluster" ]]; then
                say "Destroying the Google Cloud cluster"
                gcloud container clusters delete "$cluster_name" --region "$google_cloud_region" --quiet
            fi

            # Firewall Rules
            local firewall_rules=$(gcloud compute firewall-rules list --filter "$cluster_name" --format="json" | jq -r '.[].name')
            if [[ -n "$firewall_rules" ]]; then
                say "Destroying the Google Cloud Network Firewall Rules"

                # Destroy each firewall rule
                for rule (${(f)firewall_rules})
                do
                    gcloud compute firewall-rules delete "$rule" --quiet
                done
            fi

            # VPC Routes
            local vpc_routes=$(gcloud compute routes list --filter "$cluster_name" --format="json" | jq -r '.[].name')
            if [[ -n "$vpc_routes" ]]; then
                say "Destroying the Google Cloud VPC Routes"

                # Destroy each route
                for route (${(f)vpc_routes})
                do
                    gcloud compute routes delete "$route" --quiet
                done
            fi

            # VPC Subnet
            local subnet=$(gcloud compute networks subnets list --filter "$cluster_name" --format="json" | jq -r '.[].name')
            if [[ -n "$subnet" ]]; then
                say "Destroying the Google Cloud VPC Subnet"
                gcloud compute networks subnets delete "$subnet" --region "$google_cloud_region" --quiet
            fi

            # VPC
            local vpc=$(gcloud compute networks list --filter "$cluster_name" --format="json" | jq -r '.[].name')
            if [[ -n "$vpc" ]]; then
                say "Destroying the Google Cloud VPC"
                gcloud compute networks delete "$vpc" --quiet
            fi
        fi
    fi

#
# MongoDB
#
# CLI docs: https://www.mongodb.com/docs/mongodb-shell/
#
elif [[ "$platform" == *"MongoDB" ]] ; then

    # Check if MongoDB Shell is installed
    if ! which mongosh >/dev/null; then
        echo "Please install mongosh - https://github.com/mongodb-js/mongosh"
        exit

    ######################################
    # drop the gitops-catalog collection #
    ######################################
    elif [[ "$action" == *"drop gitops-catalog" ]] ; then
        local confirmation=$(gum confirm && echo "true" || echo "false")

        if [[ $confirmation == "true" ]] ; then
            say "Dropping the gitops-catalog document from MongoDB"
            echo 'use api;\ndb.getCollection("gitops-catalog").drop();' | mongosh "mongodb://$mongodb_username:$mongodb_password@$mongodb_hostname:$mongodb_port"
        fi

    #################################
    # remove an installed app state #
    #################################
    elif [[ "$action" == *"remove an installed app state" ]] ; then
        getUserInput "application's name" "Which application do you want to remove?" "kubernetes-dashboard"
        app_name=$user_input

        getClusterName

        local confirmation=$(gum confirm && echo "true" || echo "false")

        if [[ $confirmation == "true" ]] ; then
            say "Removing $app_name from the list of installed application from MongoDB"
            echo 'use api;\ndb.services.updateOne({'cluster_name': "'$cluster_name'" }, { $pull: { services: { name: "'$app_name'" } } } );' | mongosh "mongodb://$mongodb_username:$mongodb_password@$mongodb_hostname:$mongodb_port"
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
