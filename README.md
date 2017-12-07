# Mariadb 10.3 dockerized with replication

> MariaDB 10.3 dockerized with replication. Master/Slave setup in 30 seconds.


## How to use

### Docker run

@TODO

### Docker compose

Example docker-compose.yml for mariadb replication:

```yaml
version: '3'

services:
    db-master:
        image: caffeina/mariadb-replication
        restart: always
        volumes:
            - db-master-data:/var/lib/mysql:rw
        environment:
            MYSQL_DATABASE: "example"
            MYSQL_ROOT_PASSWORD: "mastersecret"

    db-slave:
        image: caffeina/mariadb-replication
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

@TODO

```bash
$ docker-compose up
```

@TODO

```bash
$ docker-compose -f docker-compose.yml -f docker-compose.dev.yml up --build
```


## Configuration

The `mariadb-replication` image is an extension of `mariadb:10.3`, you can use all the feature included in the original docker image. For more information look at mariadb documentation on [docker hub](https://hub.docker.com/_/mariadb/).

### Enviroment variables

@TODO Sets the connection parameters to the master. The `MYSQL_MASTER_HOST` variable is required.

```yaml
MYSQL_MASTER_HOST: "db-master"
MYSQL_MASTER_PORT: 3306 # (Optional) Default: 3306
MYSQL_MASTER_USER: "root" # (Optional) Default: 'root'
MYSQL_MASTER_PASSWORD: "secret" # (Optional) Default: ''
```

@TODO The generated user and password will be printed to stdout.

```yaml
MYSQL_GRANT_SLAVE_USER: "user" # (Optional) Default: *RANDOM STRING*
MYSQL_GRANT_SLAVE_PASSWORD: "secret" # (Optional) Default: *RANDOM STRING*
```

@TODO

```yaml
SERVER_ID: 2 # (Optional) Default: *RANDOM INT*
```

@TODO

```yaml
EXPIRE_LOGS_DAYS: 5 # (Optional) Default: '10'
```

@TODO

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


## Contributing

How to get involved:

1. [Star](https://github.com/gadiener/docker-mariadb-replication/stargazers) the project!
2. Answer questions that come through [GitHub issues](https://github.com/gadiener/docker-mariadb-replication/issues?state=open)
3. [Report a bug](https://github.com/gadiener/docker-mariadb-replication/issues/new) that you find

This project follows the [GitFlow branching model](http://nvie.com/posts/a-successful-git-branching-model). The ```master``` branch always reflects a production-ready state while the latest development is taking place in the ```develop``` branch.

Each time you want to work on a fix or a new feature, create a new branch based on the ```develop``` branch: ```git checkout -b BRANCH_NAME develop```. Only pull requests to the ```develop``` branch will be merged.

Pull requests are **highly appreciated**.

Solve a problem. Features are great, but even better is cleaning-up and fixing issues in the code that you discover.


## Versioning

This project is maintained by using the [Semantic Versioning Specification (SemVer)](http://semver.org).


## Copyright and license

Copyright 2017 [Caffeina](http://caffeina.com) srl under the [MIT license](LICENSE.md).