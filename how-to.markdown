Title:          How-to: Master/Master replication for MySQL
Author:         Pedro Melo
Date:           2008-06-26
Copyright:      2008 Pedro Melo.  
                This work is licensed under a Creative Commons License.  
                http://creativecommons.org/licenses/by-sa/2.5/
Keywords:       mysql, master/master, replication
XMP:            CCAttributionShareAlike

Introduction
============

This How-To will walk you through the steps to create a MySQL master/master
setup.

Before you setup your database like this, make sure your application supports this. You should
[read this FAQ entry](http://dev.mysql.com/doc/refman/5.0/en/replication-faq.html#qandaitem-17-3-4-5 "MySQL ::   MySQL 5.0 Reference Manual :: 16.3.4 Replication FAQ").


Master/Master replication pre-setup
===================================

This will create two mysql servers, running on the same hardware, on
ports 7001 and 7002.

To make the process easier, define these two environment variables:

 * `MY_DIR`: the directory where the mysql is installed, usually
   `/usr/local/mysql`;
 * `HOWTO_DIR`: the directory where this file is located.


Schema files
------------

I'll use the Tigase MySQL schema file as my example schema.

The sample data I'll insert into the database, are just made up values
and probably not even valid from the point of view of Tigase.


Configuration files
-------------------

The two configuration files available in the `etc/` directory are based
on the `my-small.cnf` standard configuration file.

The following changes where done:

 * all paths where changed to enable two MySQL servers running
   simultaneously on the same hardware;
 * the `server-id` setting of each server is different: for a sucessful
   replication setup, each server on the replication group must have a
   different `server-id`;
 * "binlogs" are activated: they record all updates to the database;
 * `port` and `socket` settings: updated to be different for each
   server.

For any mysql command to use a specific server, you just need to
add a `--defaults-file=$HOWTO_DIR/etc/server-1.cnf`.


Start two servers
-----------------

Setup the two new servers:

    sudo -s
    mkdir -p /tmp/server-{1,2}
    chown mysql:wheel /tmp/server-{1,2}
    cd $MY_DIR
    ./scripts/mysql_install_db --defaults-file=$HOWTO_DIR/etc/server-1.cnf --user=mysql
    ./scripts/mysql_install_db --defaults-file=$HOWTO_DIR/etc/server-2.cnf --user=mysql

Start them up:

    cd $MY_DIR
    ./bin/mysqld_safe --defaults-file=$HOWTO_DIR/etc/server-1.cnf --user=mysql
    ./bin/mysqld_safe --defaults-file=$HOWTO_DIR/etc/server-2.cnf --user=mysql

At this point in time, both servers should be running. You can test by
connecting to each one:

    mysql --defaults-file=$HOWTO_DIR/etc/server-1.cnf -u root
    mysql --defaults-file=$HOWTO_DIR/etc/server-2.cnf -u root

*Please note* that this procedure did not set a `root` account password.
This means that anybody can connect as `root` to your database.

For production environments it is *strongly recommended* that you change
the `root` password, and delete the anonymous accounts.

For our tests purposes, we will not do that.


Create sample db with data on server1
-------------------------------------

On server-1, connect as root, and create the user used by the slave:

    mysql --defaults-file=$HOWTO_DIR/etc/server-1.cnf -u root < $HOWTO_DIR/sql/repl_user.sql

We will also create the test database, and load our test schema:

    mysqladmin --defaults-file=$HOWTO_DIR/etc/server-1.cnf -u root create tigasedb
    mysql --defaults-file=$HOWTO_DIR/etc/server-1.cnf -u root tigasedb < $HOWTO_DIR/sql/tigase-mysql-schema.sql

We should be able to see the `tigasedb` database and its tables. Lets
insert some data on them to test:

    mysql --defaults-file=$HOWTO_DIR/etc/server-1.cnf -u root tigasedb < $HOWTO_DIR/sql/test-data-1.sql


Server 1 as Master
==================

We need to obtain the current master replication position, create a
stable snapshot of the data.

Connect as root:

    mysql --defaults-file=$HOWTO_DIR/etc/server-1.cnf -u root tigasedb

This connection must be left open for the rest of this procedure. This
is required to leave the LOCK in place.

Execute the following statements:

    FLUSH TABLES WITH READ LOCK;
    SHOW MASTER STATUS;
    
    +---------------------------+----------+--------------+------------------+
    | File                      | Position | Binlog_Do_DB | Binlog_Ignore_DB |
    +---------------------------+----------+--------------+------------------+
    | mysql-server-1-bin.000003 |     4514 |              |                  |
    +---------------------------+----------+--------------+------------------+
    1 row in set (0.00 sec)

This information tells you that the master position is the
`mysql-server-1-bin.000003` file at 4514.

Now create a dump of the data in the master:

    mysqldump --defaults-file=$HOWTO_DIR/etc/server-1.cnf \
              -u root \
              --lock-all-tables \
              tigasedb > tigasedb_dump.sql

Now we need to setup the slave. First, create the tigasedb database and
load the dump taken on the master:

    mysqladmin --defaults-file=$HOWTO_DIR/etc/server-2.cnf -u root create tigasedb
    mysql --defaults-file=$HOWTO_DIR/etc/server-2.cnf -u root tigasedb < tigasedb_dump.sql

You should have the same data on both servers now.

To finish the setup, you need to set the other master parameters on the
slave. Connect as root:

    mysql --defaults-file=$HOWTO_DIR/etc/server-2.cnf -u root

And setup the master link:

    CHANGE MASTER TO
           MASTER_HOST='127.0.0.1',
           MASTER_PORT=7001,
           MASTER_USER='repl_tig',
           MASTER_PASSWORD='pray4sync',
           MASTER_LOG_FILE='mysql-server-1-bin.000003',
           MASTER_LOG_POS=4514;
    START SLAVE;

You can now end the server 1 session where the LOCK was created.

You should have a proper master/slave relation working between server-1
and server-2.

If you look at `SHOW MASTER STATUS` on server-1 and compare to
`SHOW SLAVE STATUS\G` (use `\G` query terminator for a more useful layout)
on server-2, you should see the same `File` and `Position` on server-1
as `Master_Log_File` and `Read_Master_Log_Pos` on server-2.

To test, insert a new row in the `tig_user` table.

    INSERT INTO tig_users (uid, user_id) VALUES (3, 'user3'); 

If you SELECT * FROM tig_users on server-2, you should see the `user3`.

You can also re-check the `SHOW MASTER STATUS`/`SHOW SLAVE STATUS` and
compare the `File`/`Position`.


Server 2 as Master
==================

The last step is to set server 2 as master of server 1.


Before we procede, some cautions
--------------------------------

A master/master setup requires some configuration to make `AUTO_INCREMENT`
work correctly.

Our config files already include the proper `auto_increment_increment` and
`auto_increment_offset` values.

You should read:

 * [Explanation for `auto_increment_*` variables](http://dev.mysql.com/doc/refman/5.0/en/server-system-variables.html#option_mysqld_auto-increment-increment "MySQL ::   MySQL 5.0 Reference Manual :: 5.1.3 System Variables");
 * [Notes about `AUTO_INCREMENT` and replication](http://dev.mysql.com/doc/refman/5.0/en/replication-features-auto-increment.html "MySQL ::   MySQL 5.0 Reference Manual :: 16.3.1.1 Replication and AUTO_INCREMENT").

It boils down to this:

 * `auto_increment_increment` should be equal to the number of masters you have, N;
 * `auto_increment_offset` should be different, from 1 to N, on each master.


Make server 1 slave to server 2
-------------------------------

You need a replication user on server 2. I'll use the same one:

    mysql --defaults-file=$HOWTO_DIR/etc/server-2.cnf -u root < $HOWTO_DIR/sql/repl_user.sql

Connect to server 2, lock tables and record the master position:

    mysql --defaults-file=$HOWTO_DIR/etc/server-2.cnf -u root tigasedb
    
    FLUSH TABLES WITH READ LOCK;
    SHOW MASTER STATUS;
    
    +---------------------------+----------+--------------+------------------+
    | File                      | Position | Binlog_Do_DB | Binlog_Ignore_DB |
    +---------------------------+----------+--------------+------------------+
    | mysql-server-2-bin.000004 |      482 |              |                  | 
    +---------------------------+----------+--------------+------------------+
    1 row in set (0.00 sec)

Then hop over to server 1, and connect as root:

    mysql --defaults-file=$HOWTO_DIR/etc/server-1.cnf -u root tigasedb

Make server 1 a slave with the proper master position:

    CHANGE MASTER TO
           MASTER_HOST='127.0.0.1',
           MASTER_PORT=7002,
           MASTER_USER='repl_tig',
           MASTER_PASSWORD='pray4sync',
           MASTER_LOG_FILE='mysql-server-2-bin.000004',
           MASTER_LOG_POS=482;
    START SLAVE;

Release the lock on server 2. The easiest way is just quiting the mysql shell.

You should have a proper master/master relation working between server-1
and server-2.

If you look at `SHOW MASTER STATUS` on server-2 and compare to
`SHOW SLAVE STATUS\G` (use `\G` query terminator for a more useful layout)
on server-1, you should see the same `File` and `Position` on server-2
as `Master_Log_File` and `Read_Master_Log_Pos` on server-1.

Do the same procedure inverting server-1 and server-2. You should also
see equal values.


Final tests
-----------

I recommend that you start two new connections, one to server-1 and the other to server-2.

Select, insert, update, delete from each table, and see if everything is working.

Also try on one of the connections:

    CREATE TABLE test_ainc ( id INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY);

And then insert rows with:

    INSERT INTO test_ainc VALUES (null), (null), (null);

Do this on both connections and see how the AUTO_INCREMENT columns just work.


Final Notes
===========

innodb_flush_log_at_trx_commit
------------------------------

[One of the recommendations for InnoDB performance](http://www.mysqlperformanceblog.com/2007/11/01/innodb-performance-optimization-basics/ "Innodb Performance Optimization Basics | MySQL Performance Blog")
is to set `innodb_flush_log_at_trx_commit` to 2. The
[MySQL documentation recommends setting to 1 as the most safe option](http://dev.mysql.com/doc/refman/5.0/en/replication-howto-masterbaseconfig.html "MySQL ::   MySQL 5.0 Reference Manual :: 16.1.1.2 Setting the Replication Master Configuration").


replicate-do-db
---------------

You could limit the replication to just the `tigasedb` database with a:

    replicate-do-db = tigasedb

in the configuration file, `mysqld` section.

Alternative, you could use this:

    replicate-ignore-db=mysql

This will replicate all the databases, except the system mysql. This is
usefull because it will replicate everything except users, passwords and
`GRANT`/`REVOKE` statements.


master config
-------------

You should notice that I didn't set the master host, port and other
settings on the configuration file.

The `CHANGE MASTER` command writes that information in a `master.info`
file. This file takes precedence over the configuration file.


Links
=====

First, the best resource for all about replication will probably be the
[High Performance MySQL (2nd. ed.) book](http://www.highperfmysql.com/ "High Performance MySQL &raquo; Home").
You should buy it.

A list of useful links:

 * [The MySQL documentation about replication is very good](http://dev.mysql.com/doc/refman/5.0/en/replication.html "MySQL ::   MySQL 5.0 Reference Manual :: 16 Replication").
   If you follow each step carefuly you should be ok;
 * [The High-Performance MySQL site](http://www.mysqlperformanceblog.com/ "MySQL Performance Blog")
   is one of the best for all things MySQL. Make sure you
   [search for `replication`](http://www.mysqlperformanceblog.com/?s=replication "replication  | MySQL Performance Blog");
 * Browse
   [the Notes and Tips section](http://dev.mysql.com/doc/refman/5.0/en/replication-notes.html "MySQL ::   MySQL 5.0 Reference Manual :: 16.3 Replication Notes and Tips");
 * [An old article about MySQL replication at OnLamp.com](http://www.onlamp.com/pub/a/onlamp/2006/04/20/advanced-mysql-replication.html "ONLamp.com -- Advanced MySQL Replication Techniques").
   You should double-check the commands, but the graphics are pretty and usefull.

The top hit on
[Google for MySQL master/master setup](http://www.google.com/search?q=master/master+replication+mysql "master/master replication mysql - Google Search")
is a 
[how-to at HowtoForge](http://www.howtoforge.com/mysql5_master_master_replication_debian_etch "Setting Up Master-Master Replication With MySQL 5 On Debian Etch | HowtoForge - Linux Howtos and Tutorials").
Personally I found it a bit dense, but that's just me.
