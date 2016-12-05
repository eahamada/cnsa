#!/bin/sh

wget http://download.jboss.org/jbossas/7.1/jboss-as-7.1.1.Final/jboss-as-7.1.1.Final.zip
unzip -q jboss-as-7.1.1.Final.zip -d /usr/share && rm -fr jboss-as-7.1.1.Final.zip
mv /usr/share/jboss-as-7.1.1.Final /usr/share/jboss-as
groupadd jboss
useradd -s /bin/bash -g jboss jboss
chown -Rf jboss.jboss /usr/share/jboss-as/
for i in ~/.bash_profile /home/jboss/.bash_profile;do 
cat >> ~/.bash_profile <<EOF
JAVA_HOME=/usr/java/jdk1.7.0_79
export JAVA_HOME  
PATH=\$JAVA_HOME/bin:\$PATH  
export PATH
EOF
done
. ~/.bash_profile
export JBOSS_HOME=/usr/share/jboss-as
$JBOSS_HOME/bin/add-user.sh --silent=true jboss ${JBOSS_PASSWORD:=passw0rd}
cp $JBOSS_HOME/bin/init.d/jboss-as-standalone.sh /etc/rc.d/init.d/jboss
sed -i -e '5s/-/234' -e '17i\\nJBOSS_USER=jboss \nexport JBOSS_USER' -- /etc/rc.d/init.d/jboss
chmod +x /etc/rc.d/init.d/jboss
chkconfig --add jboss
service jboss start

 keytool -genkey -dname "CN=cnsa.fr,O=CNSA, L=Paris, ST=IDF, C=FR" -alias tomcat -validity 1825 -keyalg RSA -keystore ${KEYSTORE_PATH:=/root/.keystore} -keypass ${KEYSTORE_PASSWORD:=passw0rd} -storepass ${KEYSTORE_PASSWORD}
 sed -i -e '258 i\<connector name="https" protocol="HTTP/1.1" scheme="https" socket-binding="https" secure="true">\n<ssl password="'${KEYSTORE_PASSWORD}'" key-alias="tomcat"/> \n</connector>' -- $JBOSS_HOME/standalone/configuration/standalone.xml
 keytool -importcert -file ~/ldap.crt -alias ldap -keystore ldapTrustStore -storepass ${KEYSTORE_PASSWORD} -noprompt
 sed -i -e '29 i\<system-properties>\n<property name="javax.net.ssl.trustStore" value="'${KEYSTORE_PATH}'/ldapTrustStore"/>\n <property name="javax.net.ssl.trustStorePassword" value="'${KEYSTORE_PASSWORD}'"/>\n</system-propertes>' -- $JBOSS_HOME/standalone/configuration/standalone.xml
 sed -i -e '200 i\<subsystem xmlns="urn:jboss:domain:naming:1.4">\n<bindings>\n<simple name="java:global/sepannuaire.ws.config.path" value="'${CONF_PATH_WS}'" type="java.lang.String"/>\n<simple name="java:global/sepannuaire.web.config.path" value="'${CONF_PATH_WEB}'" type="java.lang.String"/>\n</bindings>\n<remote-naming/>\n</subsystem>\n' -e '200d' -- $JBOSS_HOME/standalone/configuration/standalone.xml
 
