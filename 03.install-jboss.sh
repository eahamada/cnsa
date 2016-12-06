#!/bin/bash -e

unset CONF_PATH_WS CONF_PATH_WEB JBOSS_HOME JBOSS_PASSWORD JBOSS_USER KEYSTORE_PATH KEYSTORE_PASSWORD WORKDIR
export CONF_PATH_WS=${CONF_PATH_WS:=/tmp}
export CONF_PATH_WEB=${CONF_PATH_WEB:=/tmp/web}
export JAVA_HOME=${JAVA_HOME:=/usr/java/jdk1.7.0_79}
export JBOSS_HOME=${JBOSS_HOME:=/usr/share/jboss-as}
export JBOSS_PASSWORD=${JBOSS_PASSWORD:=passw0rd}
export JBOSS_GROUP=${JBOSS_GROUP:=jboss}
export JBOSS_USER=${JBOSS_USER:=jboss}
export KEYSTORE_PATH=${KEYSTORE_PATH:=$JBOSS_HOME/standalone/configuration}
export KEYSTORE_PASSWORD=${KEYSTORE_PASSWORD:=passw0rd}

rm -fr /etc/jboss-as
ps -o pid= -u $JBOSS_USER | xargs kill -1 2>/dev/null||true
userdel -fr $JBOSS_USER 2>/dev/null||true
groupdel $JBOSS_GROUP 2>/dev/null||true

groupadd jboss
useradd -s /bin/bash -g jboss $JBOSS_USER -d $JBOSS_HOME
passwd jboss << EOF
$JBOSS_PASSWORD
$JBOSS_PASSWORD
EOF
cat >> $JBOSS_HOME/.bash_profile << EOF
JAVA_HOME=$JAVA_HOME
export JAVA_HOME
PATH=\$JAVA_HOME/bin:$PATH
export PATH
EOF
mkdir -p /etc/jboss-as && cat > /etc/jboss-as/jboss-as.conf <<EOF
JBOSS_HOME=$JBOSS_HOME
JBOSS_CONSOLE_LOG=/var/log/jboss-console.log
JBOSS_USER=$JBOSS_USER
EOF
wget http://download.jboss.org/jbossas/7.1/jboss-as-7.1.1.Final/jboss-as-7.1.1.Final.tar.gz
tar -xzf jboss-as-7.1.1.Final.tar.gz -C $JBOSS_HOME --strip-components=1
cp $JBOSS_HOME/bin/init.d/jboss-as-standalone.sh /etc/rc.d/init.d/jboss-as
chmod +x /etc/rc.d/init.d/jboss-as
chkconfig --add jboss-as
$JBOSS_HOME/bin/add-user.sh --silent=true $JBOSS_USER $JBOSS_PASSWORD
cd $JBOSS_HOME
keytool -genkey \
    -dname "CN=cnsa.fr,O=CNSA, L=Paris, ST=IDF, C=FR" \
    -alias tomcat \
    -validity 1825 \
    -keyalg RSA \
    -keystore $KEYSTORE_PATH/tomcat \
    -keypass $KEYSTORE_PASSWORD \
    -storepass $KEYSTORE_PASSWORD
sed -i -e '258 i\<connector name="https" protocol="HTTP/1.1" scheme="https" socket-binding="https" secure="true" keystoreFile="'$KEYSTORE_PATH'/tomcat">\n<ssl password="'${KEYSTORE_PASSWORD}'" key-alias="tomcat" /> \n</connector>' -- $JBOSS_HOME/standalone/configuration/standalone.xml

keytool -importcert \
    -file /etc/openldap/cacerts/ldap.crt \
    -alias ldap \
    -keystore  $KEYSTORE_PATH/ldapTrusStore \
    -storepass $KEYSTORE_PASSWORD \
    -noprompt
sed -i -e '29 i\<system-properties>\n<property name="javax.net.ssl.trustStore" value="'$KEYSTORE_PATH'/ldapTrusStore"/>\n <property name="javax.net.ssl.trustStorePassword" value="'$KEYSTORE_PASSWORD'"/>\n</system-properties>' -- $JBOSS_HOME/standalone/configuration/standalone.xml
sed -i -e '284 i\<inet-address value="${jboss.bind.address.management:0.0.0.0}"/>' -e '287 i\<inet-address value="${jboss.bind.address:0.0.0.0}"/>'  -e '284d;287d' -- $JBOSS_HOME/standalone/configuration/standalone.xml
sed -i -e '200 i\<subsystem xmlns="urn:jboss:domain:naming:1.1">\n<bindings>\n<simple name="java:global/sepannuaire.ws.config.path" value="'$CONF_PATH_WS'" type="java.lang.String"/>\n<simple name="java:global/sepannuaire.web.config.path" value="'$CONF_PATH_WEB'" type="java.lang.String"/>\n</bindings>\n</subsystem>\n' -e '200d' -- $JBOSS_HOME/standalone/configuration/standalone.xml
chown -Rf $JBOSS_USER:$JBOSS_GROUP $JBOSS_HOME
service jboss start
 

## 5.2.5	CONFIGURATION DE L’APPLICATION
# mkdir -p $CONF_PATH_WS && mv ldap.properties mail.properties web-services.properties rest-services.properties traces.properties web-services-finess.properties applications.properties $CONF_PATH_WS
# mkdir -p $CONF_PATH_WEB && mv traces-web.properties sep-annuaire-web.properties $CONF_PATH_WEB
