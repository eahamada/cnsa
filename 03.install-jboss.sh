#!/bin/sh
JBOSS_PASSWORD=passw0rD
export JBOSS_PASSWORD
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
$JBOSS_HOME/bin/add-user.sh --silent=true jboss $JBOSS_PASSWORD
cp $JBOSS_HOME/bin/init.d/jboss-as-standalone.sh /etc/rc.d/init.d/jboss
sed -i -e '5s/-/234' -e '17i\\nJBOSS_USER=jboss \nexport JBOSS_USER' -- /etc/rc.d/init.d/jboss
chmod +x /etc/rc.d/init.d/jboss
chkconfig --add jboss
service jboss start
