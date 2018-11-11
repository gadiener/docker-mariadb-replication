# Mariadb 10.3 dockerized with replication

> MariaDB 10.3 dockerized with replication. Master/Slave setup in 30 seconds.

> Added features for Docker swarm setups

## How to use

### Docker compose

Example docker-compose.yml for mariadb replication:

```yaml
version: '3'

services:
    db-master:
        image: *your docker registry*
        restart: always
        volumes:
            - db-master-data:/var/lib/mysql:rw
        environment:
            MYSQL_DATABASE: "example"
            MYSQL_ROOT_PASSWORD: "mastersecret"

    db-slave:
        image: *your docker registry*
        restart: always
        depends_on:
            - db-master
        volumes:
            - db-slave-data:/var/lib/mysql:rw
        environment:
            MYSQL_DATABASE: "example"
            MYSQL_ROOT_PASSWORD: "slavesecret"
            MYSQL_MASTER_HOST: "db-master"
            MYSQL_MASTER_PASSWORD: "mastersecret"

volumes:
    db-master-data:
    db-slave-data:
```

```bash
$ docker-compose up
```

# Build and run

```bash
$ docker-compose -f docker-compose.yml up --build
```


## Configuration

The `mariadb-replication` image is an extension of `mariadb:10.3`, you can use all the feature included in the original docker image. For more information look at mariadb documentation on [docker hub](https://hub.docker.com/_/mariadb/).

### Enviroment variables

Sets the connection parameters to the master (for slave container). The `MYSQL_MASTER_HOST` variable is required.

```yaml
MYSQL_MASTER_HOST: "db-master"
MYSQL_MASTER_PORT: 3306 # (Optional) Default: 3306
MYSQL_MASTER_USER: "root" # (Optional) Default: 'root'
MYSQL_MASTER_PASSWORD: "secret" # (Optional) Default: ''
```

The generated user and password will be printed to stdout.

```yaml
MYSQL_GRANT_SLAVE_USER: "user" # (Optional) Default: *RANDOM STRING*
MYSQL_GRANT_SLAVE_PASSWORD: "secret" # (Optional) Default: *RANDOM STRING*
```

```yaml
SERVER_ID: 2 # (Optional) Default: *RANDOM INT*
```

```yaml
EXPIRE_LOGS_DAYS: 5 # (Optional) Default: '10'
```

```yaml
MAX_BINLOG_SIZE: "50M" # (Optional) Default: '100M'
```

Set `slave-skip-errors` option in mysql config file. Look at [mysql documentation](https://dev.mysql.com/doc/refman/5.7/en/replication-options-slave.html#option_mysqld_slave-skip-errors) for more details.

```yaml
MYSQL_SLAVE_SKIP_ERRORS: "all" # (Optional) Default: 'OFF'
```

## Todo

- Improve documentation;
- Add `innodb-read-only` parameter (Service restart on first run is needed);
- Move `/etc/mysql/conf.d/master-slave.cnf` in other path (So the user can bind a volume to `/etc/mysql/conf.d/` for custom configuration);
- Permit replication on existing database.
