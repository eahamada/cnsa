#!/bin/bash -e

unset CONF_PATH_WS CONF_PATH_WEB JBOSS_HOME JBOSS_PASSWORD JBOSS_USER KEYSTORE_PATH KEYSTORE_PASSWORD WORKDIR
export CONF_PATH_WS=${CONF_PATH_WS:=/tmp}
export CONF_PATH_WEB=${CONF_PATH_WEB:=/tmp/web}
export JBOSS_HOME=${JBOSS_HOME:=/usr/share/jboss-as}
export JBOSS_PASSWORD=${JBOSS_PASSWORD:=passw0rd}
export JBOSS_GROUP=${JBOSS_GROUP:=jboss}
export JBOSS_USER=${JBOSS_USER:=jboss}
export KEYSTORE_PATH=${KEYSTORE_PATH:=/root/.keystore}
export KEYSTORE_PASSWORD=${KEYSTORE_PASSWORD:=passw0rd}
export WORKDIR=${WORKDIR:=`mktemp -d`}
rm -fr $WORKDIR/* $KEYSTORE_PATH
ps -o pid= -u $JBOSS_USER | xargs kill -1 2>/dev/null||true
userdel -fr $JBOSS_USER 2>/dev/null||true
groupdel $JBOSS_GROUP 2>/dev/null||true

cd $WORKDIR

groupadd jboss
useradd -s /bin/bash -g jboss $JBOSS_USER -d $JBOSS_HOME
wget http://download.jboss.org/jbossas/7.1/jboss-as-7.1.1.Final/jboss-as-7.1.1.Final.tar.gz
tar -xzf jboss-as-7.1.1.Final.tar.gz -C $JBOSS_HOME --strip-components=1

$JBOSS_HOME/bin/add-user.sh --silent=true jboss $JBOSS_PASSWORD
cp $JBOSS_HOME/bin/init.d/jboss-as-standalone.sh /etc/rc.d/init.d/jboss
chmod +x /etc/rc.d/init.d/jboss
chkconfig --add jboss
mkdir /etc/jboss-as && cat > /etc/jboss-as/jboss-as.conf <<EOF
JBOSS_HOME=$JBOSS_HOME
JBOSS_CONSOLE_LOG=/var/log/jboss-console.log
JBOSS_USER=$JBOSS_USER
EOF

keytool -genkey \
    -dname "CN=cnsa.fr,O=CNSA, L=Paris, ST=IDF, C=FR" \
    -alias tomcat \
    -validity 1825 \
    -keyalg RSA \
    -keystore $KEYSTORE_PATH \
    -keypass $KEYSTORE_PASSWORD \
    -storepass $KEYSTORE_PASSWORD
sed -i -e '258 i\<connector name="https" protocol="HTTP/1.1" scheme="https" socket-binding="https" secure="true">\n<ssl password="'${KEYSTORE_PASSWORD}'" key-alias="tomcat"/> \n</connector>' -- $JBOSS_HOME/standalone/configuration/standalone.xml

keytool -importcert \
    -file /etc/openldap/cacerts/ldap.crt \
    -alias ldap \
    -keystore ldapTrustStore \
    -storepass $KEYSTORE_PASSWORD \
    -noprompt
sed -i -e '29 i\<system-properties>\n<property name="javax.net.ssl.trustStore" value="'$KEYSTORE_PATH'/ldapTrustStore"/>\n <property name="javax.net.ssl.trustStorePassword" value="'$KEYSTORE_PASSWORD'"/>\n</system-propertes>' -- $JBOSS_HOME/standalone/configuration/standalone.xml
sed -i -e '284 i\<any-ipv4-address/>' -e '287 i\<any-ipv4-address/>'  -e '284d;287d' -- $JBOSS_HOME/standalone/configuration/standalone.xml
sed -i -e '200 i\<subsystem xmlns="urn:jboss:domain:naming:1.4">\n<bindings>\n<simple name="java:global/sepannuaire.ws.config.path" value="'$CONF_PATH_WS'" type="java.lang.String"/>\n<simple name="java:global/sepannuaire.web.config.path" value="'$CONF_PATH_WEB'" type="java.lang.String"/>\n</bindings>\n<remote-naming/>\n</subsystem>\n' -e '200d' -- $JBOSS_HOME/standalone/configuration/standalone.xml
chown -Rf jboss.jboss $JBOSS_HOME
service jboss start
