#!/bin/bash

set -eo pipefail
shopt -s nullglob

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

if [ ! -z "$MYSQL_MASTER_HOST" ]; then
	echo
	echo 'MySQL slave process in progress...'
	echo

	file_env 'MYSQL_MASTER_USER' 'root'

	master_mysql=( mysql -h "$MYSQL_MASTER_HOST" -u "$MYSQL_MASTER_USER" )
	master_mysqldump=( mysqldump -h "$MYSQL_MASTER_HOST" -u "$MYSQL_MASTER_USER" --opt )

	MYSQL_STATUS="/tmp/mysql-status.log"
	MYSQL_EXPORT="/tmp/mysql-export.log"

	if [ ! -z "$MYSQL_MASTER_PORT" ]; then
		master_mysql+=( -P"$MYSQL_MASTER_PORT" )
		master_mysqldump+=( -P"$MYSQL_MASTER_PORT" )
	fi

	if [ ! -z "$MYSQL_MASTER_PASSWORD" ]; then
		master_mysql+=( -p"$MYSQL_MASTER_PASSWORD" )
		master_mysqldump+=( -p"$MYSQL_MASTER_PASSWORD" )
	fi

	if [ ! -z "$MYSQL_DATABASE" ]; then
		master_mysql+=( "$MYSQL_DATABASE" )
		master_mysqldump+=( "$MYSQL_DATABASE" )
	fi
	
	for i in {30..0}; do
		if echo 'SELECT 1' | "${master_mysql[@]}" &> /dev/null; then
			echo 'MySQL master init process is complete...'
			break
		fi
		echo 'Waiting MySQL master init process...'
		sleep 1
	done

	if [ ! -z "$MYSQL_GRANT_SLAVE_USER" -a ! -z "$MYSQL_GRANT_SLAVE_PASSWORD" ]; then
		export MYSQL_GRANT_SLAVE_USER="$(pwgen -1 16)"
		echo "GENERATED SLAVE USER: $MYSQL_GRANT_SLAVE_USER"

		export MYSQL_GRANT_SLAVE_PASSWORD="$(pwgen -1 32)"
		echo "GENERATED SLAVE PASSWORD: $MYSQL_GRANT_SLAVE_PASSWORD"
	

		"${master_mysql[@]}" <<-EOSQL
			GRANT REPLICATION SLAVE ON *.* TO '$MYSQL_GRANT_SLAVE_USER'@'%' IDENTIFIED BY '$MYSQL_GRANT_SLAVE_PASSWORD';
			FLUSH PRIVILEGES;
		EOSQL

	fi

	"${master_mysql[@]}" <<-EOSQL > $MYSQL_STATUS 2>&1
		FLUSH TABLES WITH READ LOCK;
		SHOW MASTER STATUS;
	EOSQL

	"${master_mysqldump[@]}" > $MYSQL_EXPORT 2>&1

	"${master_mysql[@]}" <<-EOSQL
		UNLOCK TABLES;
	EOSQL

	## SLAVE

	slave_mysql=( mysql -u root )

	if [ ! -z "$MYSQL_ROOT_PASSWORD" ]; then
		slave_mysql+=( -p"${MYSQL_ROOT_PASSWORD}" )
	fi

	if [ ! -z "$MYSQL_DATABASE" ]; then
		slave_mysql+=( "$MYSQL_DATABASE" )
	fi

	file_env "MYSQL_MASTER_BIN_LOG" $( head -n 2 $MYSQL_STATUS | tail -n 1 | awk '{print $1}' )
	file_env "MYSQL_MASTER_BIN_LOG_POS" $( head -n 2 $MYSQL_STATUS | tail -n 1 | awk '{print $2}' )
	
	"${slave_mysql[@]}" < $MYSQL_EXPORT

	file_env "MYSQL_MASTER_PORT" "3306"
	file_env "MYSQL_MASTER_CONNECT_RETRY" "10"

	"${slave_mysql[@]}" <<-EOSQL
		STOP SLAVE;
		CHANGE MASTER TO 
			MASTER_HOST='$MYSQL_MASTER_HOST',
			MASTER_PORT=$MYSQL_MASTER_PORT,
			MASTER_USER='$MYSQL_GRANT_SLAVE_USER', 
			MASTER_PASSWORD='$MYSQL_GRANT_SLAVE_PASSWORD', 
			MASTER_LOG_FILE='$MYSQL_MASTER_BIN_LOG', 
			MASTER_LOG_POS=$MYSQL_MASTER_BIN_LOG_POS,
			MASTER_CONNECT_RETRY=$MYSQL_MASTER_CONNECT_RETRY;
		START SLAVE;
		SHOW SLAVE STATUS\G
	EOSQL

	if [ -e "$MYSQL_STATUS" ]; then
		rm -f $MYSQL_STATUS
	fi

	if [ -e "$MYSQL_EXPORT" ]; then
		rm -f $MYSQL_EXPORT
	fi

	echo
	echo 'MySQL slave process done. Ready for replication.'
	echo

else
	echo
	echo 'MySQL master process in progress...'
	echo

	master_mysql=( mysql -u root )

	if [ ! -z "$MYSQL_ROOT_PASSWORD" ]; then
		master_mysql+=( -p"${MYSQL_ROOT_PASSWORD}" )
	fi

	if [ ! -z "$MYSQL_DATABASE" ]; then
		master_mysql+=( "$MYSQL_DATABASE" )
	fi

	"${master_mysql[@]}" <<-EOSQL
		SHOW MASTER STATUS\G
	EOSQL

	echo
	echo 'MySQL master process done. Ready for replication.'
	echo
fi
