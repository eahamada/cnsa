#!/bin/sh
. ./passwords
wget http://download.jboss.org/jbossas/7.1/jboss-as-7.1.1.Final/jboss-as-7.1.1.Final.zip
unzip jboss-as-7.1.1.Final.zip -d /opt
export JBOSS_HOME=/opt/jboss-as-7.1.1.Final
$JBOSS_HOME/bin/add-user.sh --silent=true jboss $JBOSS_PASSWORD
vi /etc/rc.d/init.d/jbossas7
cp $JBOSS_HOME/bin/init.d/jboss-as-standalone.sh /etc/rc.d/init.d/jboss
chmod +x /etc/rc.d/init.d/jboss
chkconfig --add jboss
service jboss start
service jboss stop
