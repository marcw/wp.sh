#!/bin/bash

host=""
project_path=""
user=""
remote_hostname=""
local_hostname=""
remote_wpcli=""
db_filename="wp-db.sql"
dry_run="--dry-run"

set -e

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
    echo -e "\t\t export_db"
    echo -e "\t\t export_db_for_prod"
    echo -e "\t\t import_db_from_prod dump.sql"
    echo -e "\t\t sync_from_local"
    exit 1
}

# parsing first argument (command)
if [ -z "$1" ]
then
    usage
fi


CMD=$1

if [ "$2" == "--force" ]
then
    dry_run=""
fi

source "`pwd`/wp.sh.config"

function deploy_files {
    say_yellow "Rsyncing to remote"
    exclude="--exclude=.git --exclude=wp-config.php --exclude=wp.sh.config --exclude=node_modules --exclude=.idea"
    options="--no-owner --no-group --progress -crDpLt --force"
    rsync ${dry_run} ${exclude} ${options} ./ ${user}@${host}:${project_path}
}

function sync_from_local {
    say_yellow "Rsyncing to remote"
    exclude="--exclude=.git --exclude=wp-config.php"
    options="--no-owner --delete --no-group --progress -crDpLt --force"
    rsync ${dry_run} ${exclude} ${options} ./ ${user}@${host}:${project_path}
}

function import_db_from_prod() {
    say_yellow "Exporting database for production use"
    echo $!
    run_local wp db import $1
    run_local wp search-replace ${remote_hostname} ${local_hostname}
    run_local wp search-replace ${project_path} `pwd` 

    say_green "Database has been imported"
}

function export_db_for_prod {
    say_yellow "Exporting database for production use"
    run_local wp search-replace ${local_hostname} ${remote_hostname}
    run_local wp search-replace `pwd` ${project_path}
    run_local wp db export ${db_filename}

    run_local wp db export ${db_filename}
    sed -i '' 's/utf8mb4_unicode_520_ci/utf8mb4_unicode_ci/g' ${db_filename}

    run_local wp search-replace ${remote_hostname} ${local_hostname}
    run_local wp search-replace ${project_path} `pwd`

    say_green "Database has been exported to ${db_filename}"
}

function deploy_db {
    export_db_for_prod
    say_yellow "Deploying database to remote server"
    run_local scp ${db_filename} ${user}@${host}:${project_path}/${db_filename}

    run php ${remote_wpcli} db import ${db_filename}

    run_local wp search-replace ${remote_hostname} ${local_hostname}
    run_local wp search-replace ${project_path} `pwd`

    rm ${db_filename}
    run rm ${db_filename}
}

function fetch_files {
    say_yellow "Rsyncing from remote"
    exclude="--exclude=.git --exclude=wp-config.php --exclude=wp.sh.config"
    options="--no-owner --no-group --progress -crDpLt --force"
    rsync ${dry_run} ${exclude} ${options} ${user}@${host}:${project_path}/ ./
}

function fetch_db {
    say_yellow "Fetching database..."
    run php ${remote_wpcli} db export ${db_filename}

    run_local scp ${user}@${host}:$project_path/${db_filename} ${db_filename}
    import_db_from_prod ${db_filename}
    run rm ${db_filename}
}

function export_db {
    say_yellow "Exporting database to ${db_filename}"
    run_local wp search-replace ${local_hostname} ${remote_hostname}
    run_local wp search-replace `pwd` ${project_path}
    run_local wp db export ${db_filename}
    sed -i '' 's/utf8mb4_unicode_520_ci/utf8mb4_unicode_ci/g' ${db_filename}
    run_local wp search-replace ${remote_hostname} ${local_hostname}
    run_local wp search-replace ${project_path} `pwd`
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

if [ "export_db" == "$CMD" ]
then
    export_db
    exit $?
fi

if [ "export_db_for_prod" == "$CMD" ]
then
    export_db_for_prod
    exit $?
fi

if [ "import_db_from_prod" == "$CMD" ]
then
    import_db_from_prod "$2"
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

if [ "sync_from_local" == "$CMD" ]
then
    sync_from_local
    exit $?
fi

say_red "Unknown command"
exit 1
