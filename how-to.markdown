Title:          How-to: Master/Master replication for MySQL
Subtitle:       
Author:         Pedro Melo
Affiliation:    
Date:           2008-06-26
Copyright:      2008 Pedro Melo.  
                This work is licensed under a Creative Commons License.  
                http://creativecommons.org/licenses/by-sa/2.5/
Keywords:       mysql, master/master, replication
XMP:            CCAttributionShareAlike

Master/Master replication setup
===============================

This will create two mysql servers, running on the same hardware, on ports 7001 and 7002.

To make the process easier, define these two environment variables:

 * `MY_DIR`: the directory where the mysql is installed, usually `/usr/local/mysql`;
 * `HOWTO_DIR`: the directory where this file is located.


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


Configure the first server
--------------------------

