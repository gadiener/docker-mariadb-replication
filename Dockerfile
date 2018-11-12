FROM mariadb:10.3

COPY mariadb/init.sh /usr/local/bin/
COPY mariadb/entrypoint.sh /usr/local/bin/master-slave-entrypoint.sh

RUN mkdir -p /status

ENTRYPOINT ["master-slave-entrypoint.sh"]

CMD ["mysqld"]
