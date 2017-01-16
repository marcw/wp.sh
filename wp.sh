#!/bin/bash

host=""
project_path=""
user=""
remote_hostname=""
local_hostname=""
remote_wpcli=""
db_filename="wp-db.sql"
dry_run="--dry-run"


function say_red {
    echo -e "\033[31m>>> $@\033[0m"
}

function say_green {
    echo -e "\033[32m>>> $@\033[0m"
}

function say_yellow {
    echo -e "\033[33m>>> $@\033[0m"
}

function protect {
    if [ -z "$dry_run" ]
    then
        $@
    else
        say_red "[dry run] $@"
    fi
}

function run_local {
    say_yellow "[local] $@"
    $@
}

function run {
    say_yellow "[remote] $@"
    ssh ${user}@${host} "cd ${project_path} && $@"
}

function usage {
    echo "Usage: ${0} cmd [--force]"
    echo -e "\t cmd can be:"
    echo -e "\t\t deploy"
    echo -e "\t\t deploy_db"
    echo -e "\t\t fetch"
    echo -e "\t\t fetch_db"
    exit 1
}

# parsing first argument (command)
if [ -z "$1" ]
then
    usage
fi


CMD=$1
if [ "deploy" != "$CMD" ] && [ "fetch" != "$CMD" ] && [ "deploy_db" != "$CMD" ] && [ "fetch_db" != "$CMD" ]
then
    say_red "Unrecognized command."
    usage
fi

if [ "$2" == "--force" ]
then
    dry_run=""
fi

source "`pwd`/wp.sh.config"

function deploy_files {
    say_yellow "Rsyncing to remote"
    exclude="--exclude=.git --exclude=wp-config.php"
    options="--no-owner -vv --no-group --progress -crDpLt --force"
    rsync ${dry_run} ${exclude} ${options} ./ ${user}@${host}:${project_path}
}

function deploy_db {
    say_yellow "Deploying database to remote server"
    run_local wp search-replace ${local_hostname} ${remote_hostname}
    run_local wp search-replace `pwd` ${project_path}
    run_local wp db export ${db_filename}


    run_local wp db export ${db_filename}
    sed -i '' 's/utf8mb4_unicode_520_ci/utf8mb4_unicode_ci/g' ${db_filename}
    scp ${db_filename} ${user}@${host}:${project_path}/${db_filename}

    run php ${remote_wpcli} db import ${db_filename}

    run_local wp search-replace ${remote_hostname} ${local_hostname}
    run_local wp search-replace ${project_path} `pwd`

    rm ${db_filename}
    run rm ${db_filename}
}

function fetch_files {
    say_yellow "Rsyncing from remote"
    exclude="--exclude-from=rsync-exclude.txt"
    options="--no-owner --no-group --progress -crDpLt --force"
    rsync ${dry_run} ${exclude} ${options} ${user}@${host}:${project_path}/ ./
}

function fetch_db {
    say_yellow "Fetching database..."
    run php ${remote_wpcli} db export ${db_filename}
    scp ${user}@${host}:$project_path/${db_filename} ${db_filename}
    run_local wp db import ${db_filename}

    run_local wp search-replace ${remote_hostname} ${local_hostname}
    run_local wp search-replace ${project_path} `pwd`

    rm ${db_filename}
    run rm ${db_filename}
}

if [ "deploy" == "$CMD" ]
then
    deploy_files
    exit $?
fi

if [ "deploy_db" == "$CMD" ]
then
    deploy_db
    exit $?
fi


if [ "fetch" == "$CMD" ]
then
    fetch_files
    exit $?
fi

if [ "fetch_db" == "$CMD" ]
then
    fetch_db
    exit $?
fi
