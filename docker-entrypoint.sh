#!/bin/bash

set -eo pipefail

set +e

# Script trace mode
if [ "${DEBUG_MODE}" == "true" ]; then
    set -o xtrace
fi

update_config_var() {
    local config_path=$1
    local var_name=$2
    local var_value=$3
    local is_multiple=$4

    if [ ! -f "$config_path" ]; then
        echo "**** Configuration file '$config_path' does not exist"
        return
    fi

    echo -n "** Updating '$config_path' parameter \"$var_name\": '$var_value'... "

    # Remove configuration parameter definition in case of unset parameter value
    if [ -z "$var_value" ]; then
        sed -i -e "/^$var_name:/d" "$config_path"
        echo "removed"
        return
    fi

    # Remove value from configuration parameter in case of double quoted parameter value
    if [ "$var_value" == '""' ]; then
        sed -i -e "/^$var_name:/s/=.*/=/" "$config_path"
        echo "undefined"
        return
    fi

    if [ "$(grep -E "^\s*$var_name:" $config_path)" ] && [ "$is_multiple" != "true" ]; then
        sed -i -e "/^\s*$var_name:/s/:.*/: $var_value/" "$config_path"
        echo "updated"
    elif [ "$(grep -Ec "^#\s*$var_name:" $config_path)" -gt 1 ]; then
        sed -i -e  "/^[#;]\s*$var_name:$/i\\$var_name: $var_value" "$config_path"
        echo "added first occurrence"
    else
        sed -i -e "/^[#;]\s*$var_name:/s/.*/&\n$var_name: $var_value/" "$config_path"
        echo "added"
    fi

}

# Check prerequisites for PostgreSQL database
check_variables() {
    DB_SERVER_HOST=${DB_SERVER_HOST:-"postgres-server"}
    DB_SERVER_PORT=${DB_SERVER_PORT:-"5432"}
    CREATE_DB_USER=${CREATE_DB_USER:-"false"}

    DB_SERVER_ROOT_USER=${POSTGRES_USER:-"postgres"}
    DB_SERVER_ROOT_PASS=${POSTGRES_PASSWORD:-""}

    DB_SERVER_USER=${POSTGRES_USER:-"dancer_user"}
    DB_SERVER_PASS=${POSTGRES_PASSWORD:-"d4nc3r_us3r"}
    DB_SERVER_DBNAME=${DB_SERVER_DBNAME:-"db"}
}

check_db_connect() {
    echo "********************"
    echo "* DB_SERVER_HOST: ${DB_SERVER_HOST}"
    echo "* DB_SERVER_PORT: ${DB_SERVER_PORT}"
    echo "* DB_SERVER_DBNAME: ${DB_SERVER_DBNAME}"
    if [ "${USE_DB_ROOT_USER}" == "true" ]; then
        echo "* DB_SERVER_ROOT_USER: ${DB_SERVER_ROOT_USER}"
        echo "* DB_SERVER_ROOT_PASS: ${DB_SERVER_ROOT_PASS}"
    else
        DB_SERVER_ROOT_USER=${DB_SERVER_USER}
        DB_SERVER_ROOT_PASS=${DB_SERVER_PASS}
    fi
    echo "* DB_SERVER_USER: ${DB_SERVER_USER}"
    echo "* DB_SERVER_PASS: ${DB_SERVER_PASS}"
    echo "********************"

    if [ -n "${DB_SERVER_PASS}" ]; then
        export PGPASSWORD="${DB_SERVER_PASS}"
    fi

    WAIT_TIMEOUT=5

    while [ ! "$(psql -h ${DB_SERVER_HOST} -p ${DB_SERVER_PORT} -U ${DB_SERVER_ROOT_USER} -d ${DB_SERVER_DBNAME} -l -q 2>/dev/null)" ]; do
        echo "**** PostgreSQL server is not available. Waiting $WAIT_TIMEOUT seconds..."
        sleep $WAIT_TIMEOUT
    done

    unset PGPASSWORD
}


psql_query() {
    query=$1
    db=${2:-$DB_SERVER_DBNAME}

    local result=""

    if [ -n "${DB_SERVER_PASS}" ]; then
        export PGPASSWORD="${DB_SERVER_PASS}"
    fi

    result=$(psql -A -q -t -h ${DB_SERVER_HOST} -p ${DB_SERVER_PORT} \
             -U ${DB_SERVER_ROOT_USER} -c "$query" $db 2>/dev/null);

    unset PGPASSWORD

    echo $result
}

create_db_user() {
    [ "${CREATE_DB_USER}" == "true" ] || return

    echo "** Creating '${DB_SERVER_USER}' user in PostgreSQL database"

    USER_EXISTS=$(psql_query "SELECT 1 FROM pg_roles WHERE rolname='${DB_SERVER_USER}'")

    if [ -z "$USER_EXISTS" ]; then
        psql_query "CREATE USER ${DB_SERVER_USER} WITH PASSWORD '${DB_SERVER_PASS}'" 1>/dev/null
    else
        psql_query "ALTER USER ${DB_SERVER_USER} WITH ENCRYPTED PASSWORD '${DB_SERVER_PASS}'" 1>/dev/null
    fi
}

create_db_database() {
    DB_EXISTS=$(psql_query "SELECT 1 AS result FROM pg_database WHERE datname='${DB_SERVER_DBNAME}'")

    if [ -z ${DB_EXISTS} ]; then
        echo "** Database '${DB_SERVER_DBNAME}' does not exist. Creating..."
        psql_query "CREATE DATABASE ${DB_SERVER_DBNAME} WITH OWNER ${DB_SERVER_USER} ENCODING='UTF8' LC_CTYPE='en_US.utf8' LC_COLLATE='en_US.utf8'" 1>/dev/null
    else
        echo "** Database '${DB_SERVER_DBNAME}' already exists. Please be careful with database owner!"
    fi
}

create_db_schema() {
    DBVERSION_TABLE_EXISTS=$(psql_query "SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid =
                                         c.relnamespace WHERE  n.nspname = 'public' AND c.relname = 'dbversion'" "${DB_SERVER_DBNAME}")

    if [ -n "${DBVERSION_TABLE_EXISTS}" ]; then
        echo "** Table '${DB_SERVER_DBNAME}.dbversion' already exists."
        DB_VERSION=$(psql_query "SELECT mandatory FROM public.dbversion" "${DB_SERVER_DBNAME}")
    fi

    if [ -z "${DB_VERSION}" ]; then
        echo "** Creating '${DB_SERVER_DBNAME}' schema in PostgreSQL"

        if [ -n "${DB_SERVER_PASS}" ]; then
            export PGPASSWORD="${DB_SERVER_PASS}"
        fi

        psql -X -q -1 -v ON_ERROR_STOP=1 -f /home/dancer/app/sql/db_create.sql \
            -h ${DB_SERVER_HOST} -p ${DB_SERVER_PORT} \
            -U ${DB_SERVER_USER} ${DB_SERVER_DBNAME} 1>/dev/null

        psql -X -q -1 -v ON_ERROR_STOP=1 -f /home/dancer/app/sql/development_data.sql \
            -h ${DB_SERVER_HOST} -p ${DB_SERVER_PORT} \
            -U ${DB_SERVER_USER} ${DB_SERVER_DBNAME} 1>/dev/null

        unset PGPASSWORD
    fi
}

update_dancer_config() {
    echo "** Preparing Dancer configuration file"

    DCR_CONFIG="/home/dancer/app/config.yml"

    update_config_var $DCR_CONFIG "host" "${DB_SERVER_HOST}"
    update_config_var $DCR_CONFIG "database" "${DB_SERVER_DBNAME}"
    update_config_var $DCR_CONFIG "username" "${DB_SERVER_USER}"
    update_config_var $DCR_CONFIG "port" "${DB_SERVER_PORT}"
    update_config_var $DCR_CONFIG "password" "${DB_SERVER_PASS}"
}



#################################################

echo "** Preparing application"

check_variables
check_db_connect
create_db_user
create_db_database
create_db_schema

update_dancer_config

echo "########################################################"

if [ "$1" != "" ]; then
    echo "** Executing '$@'"
    exec "starman $1"
else
    echo "Starting application on container"
    exec /usr/local/bin/starman /home/dancer/app/bin/app.psgi
fi

#################################################
