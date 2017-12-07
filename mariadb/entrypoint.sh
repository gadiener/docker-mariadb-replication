#!/bin/bash

set -eo pipefail
shopt -s nullglob

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
	set -- mysqld "$@"
fi

# skip setup if they want an option that stops mysqld
wantHelp=
for arg; do
	case "$arg" in
		-'?'|--help|--print-defaults|-V|--version)
			wantHelp=1
			break
			;;
	esac
done

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

_check_config() {
	toRun=( "$@" --verbose --help --log-bin-index="$(mktemp -u)" )
	if ! errors="$("${toRun[@]}" 2>&1 >/dev/null)"; then
		cat >&2 <<-EOM

			ERROR: mysqld failed while attempting to check config
			command was: "${toRun[*]}"

			$errors
		EOM
		exit 1
	fi
}

# Fetch value from server config
# We use mysqld --verbose --help instead of my_print_defaults because the
# latter only show values present in config files, and not server defaults
_get_config() {
	local conf="$1"; shift
	"$@" --verbose --help --log-bin-index="$(mktemp -u)" 2>/dev/null | awk '$1 == "'"$conf"'" { print $2; exit }'
}

if [ "$1" = 'mysqld' -a -z "$wantHelp" ]; then
	_check_config "$@"
	
	DATADIR="$(_get_config 'datadir' "$@")"

	if [ ! -d "$DATADIR/mysql" ]; then

		file_env "SERVER_ID" $RANDOM
		file_env "EXPIRE_LOGS_DAYS" "10"
		file_env "MAX_BINLOG_SIZE" "100M"

		if [ ! -z "$MYSQL_DATABASE" ]; then
			
			# @TODO
			# Move that config in other path
			# @see README.md
			CONFIG_FILE="/etc/mysql/conf.d/master-slave.cnf"

			cat <<-EOF > $CONFIG_FILE
				[mysqld]
				expire_logs_days = $EXPIRE_LOGS_DAYS
				max_binlog_size = $MAX_BINLOG_SIZE

				server_id = $SERVER_ID
				binlog_do_db = $MYSQL_DATABASE

				relay_log = /var/log/mysql/relay-bin.log
				relay_log_index = /var/log/mysql/relay-bin.index
				relay_log_info_file = /var/log/mysql/relay-bin.info

				log_bin = /var/log/mysql/mariadb-bin.log
				log_bin_index = /var/log/mysql/mariadb-bin.index

				binlog-ignore-db = information_schema
				binlog-ignore-db = mysql

				replicate-ignore-db = information_schema
				replicate-ignore-db = mysql

				binlog_format = ROW
			EOF

			if [ ! -z "$MYSQL_MASTER_HOST" ]; then

				if [ ! -z "$MYSQL_SLAVE_SKIP_ERRORS" ]; then
					cat <<-EOF >> $CONFIG_FILE
						slave-skip-errors = $MYSQL_SLAVE_SKIP_ERRORS
					EOF
				fi
				
				# @TODO
				# innodb_change_buffering = 0
				# innodb-read-only = 1
				cat <<-EOF >> $CONFIG_FILE
					log_slave_updates = 1
					read_only = 1
				EOF
			fi
			
			chown -R mysql:mysql "$CONFIG_FILE"
		else
			echo >&2 'error: master/slave feature is uninitialized. MYSQL_DATABASE variable is not defined.'
		fi
	fi
fi

docker-entrypoint.sh $@