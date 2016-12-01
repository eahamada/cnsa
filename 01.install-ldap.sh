#!/bin/sh
. ./passwords
yum -y remove openldap-servers openldap-clients
rm -fr /var/lib/ldap/*
rm -fr /etc/openldap/*
rm -fr /tmp/openldap
## Récupérer Openldap*.tar et l'extraire 
mkdir -p /tmp/openldap && tar -xf  Openldap_20160517.tar -C /tmp/openldap && cd /tmp/openldap

## supprimer les ^M des fichiers sh
sed -i 's/\r//' ./*.sh

## Supprimer les mots de passe en dur dans les shell par les variables exportées
sed -i 's/dataCnsa\*!/$DATA_ADMIN_PASSWORD/' ./*.sh
sed -i 's/configCnsa\*!/$DATA_CONFIG_PASSWORD/' ./*.sh

## Mettre les ldif d'équerre
sed -i 's/^\([^ :]\+ \)/ \1/' /tmp/openldap/*.ldif

#4.3	LDAP
yum -y install openldap-servers openldap-clients

# 5.	PRE-INSTALLATION
for i in ldap*; do chmod +x $i;done

## 5.1.1	SUPPRESSION DE LA BASE ET DES DONNEES D’EXEMPLE
rm -rf /var/lib/ldap/*
rm -rf /etc/openldap/slapd.d/cn=config/olcDatabase={2}bdb.ldif

## Redémarrer le serveur OpenLDAP
service slapd start

## 5.1.2	MISE EN PLACE DES LOGS
cat >> /etc/rsyslog.conf <<EOF
# Log Openldap
local4.*    /var/log/slapd.log
EOF

## Pour la rotation des logs configurer logrotate comme ci dessous :
cat > /etc/logrotate.d/openldap <<EOF
# OpenLDAP
/var/log/slapd.log {
   missingok
   notifempty
   compress
   daily
   rotate 10
   size=50M
   sharedscripts
   postrotate
 # OpenLDAP logs via syslog, restart syslog if running
   /etc/init.d/rsyslog restart
 endscript
}
EOF

## Redémarrer les services 
service rsyslog restart
service slapd restart

## Définir le mot de passe dans le fichier create_config_password.ldif
cat > create_config_password.ldif <<EOF
dn: cn=config
changetype: modify
dn: olcDatabase={0}config,cn=config
changetype: modify
replace: olcRootDN
olcRootDN: cn=admin,cn=config
dn: olcDatabase={0}config,cn=config
changetype: modify
add: olcRootPW
olcRootPW: $DATA_CONFIG_PASSWORD
EOF

## Créer un mot de passe pour l’utilisateur cn=admin,cn=config via le ldif « create_config_password.ldif »
ldapadd -Y EXTERNAL -H ldapi:/// -f create_config_password.ldif

## 5.1.4	CREER UN LE BACKEND, INTEGRER LE SCHEMA ET LES DONNEES

## Augmenter le loglevel d’openldap
## ./loglevel.ldif: No such file or directory 
./ldapadd_config.sh 389 loglevel.ldif

## Redémarrer Openldap
service slapd restart

## mdb.ldif
cat > mdb.ldif <<EOF
dn: olcDatabase=mdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcMdbConfig
olcDatabase: mdb
olcSuffix: dc=annuaire,dc=cnsa
olcDbDirectory: /var/lib/ldap
olcRootDN: cn=Manager,dc=annuaire,dc=cnsa
olcRootPW: $DATA_ADMIN_PASSWORD
olcAccess: to attrs=userPassword
  by self write
  by anonymous auth
  by dn.base="cn=Manager,dc=annuaire,dc=cnsa" write
  by dn.base="uid=service_administration,ou=gestion,dc=annuaire,dc=cnsa" write
  by * none
olcAccess: to *
  by self write
  by dn.base="cn=Manager,dc=annuaire,dc=cnsa" write
  by dn.base="uid=service_administration,ou=gestion,dc=annuaire,dc=cnsa" write
  by * read
olcDbMaxSize: 1073741824
EOF

## cnsa-data.ldif
sed -i -e '/uid: service_administration/{n;s/.*/userPassword: '$DATA_SERVICE_PASSWORD'\n/;}' cnsa-data.ldif

## Créer le dossier accesslog 
mkdir /var/lib/ldap/accesslog
chown -R ldap:ldap /var/lib/ldap

## Lancer le script global sur le port 389. Ce script effectue les actions suivantes :
sed -i '9d' ldapadd_all.sh
sed -i -e '/BASEDIR=/a $BASEDIR\/ldapadd_config.sh $1 module.ldif' ldapadd_all.sh


./ldapadd_all.sh 389
## Vérifier que la commande n’a retourné aucun code erreur

## Fixer les droits du dossier ldap
chown -R ldap:ldap /var/lib/ldap

## Générer les certificats
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=FR/ST=IDF/L=PARIS/O=CNSA/CN=cnsa.fr" -keyout ./ldap.key -out ./ldap.crt
cp ldap.crt ldap_ca.crt

mkdir /etc/openldap/cacerts
mv ldap_ca.crt ldap.crt ldap.key /etc/openldap/cacerts
sed -i 's/yes/no/g' /etc/sysconfig/ldap
sed -i '/^#SLAPD_URLS/d' /etc/sysconfig/ldap
cat >> /etc/sysconfig/ldap <<EOF
SLAPD_URLS="ldaps://192.168.56.102 ldap://localhost ldap://192.168.56.102 ldapi:///"
EOF

cat > /etc/openldap/ldap.conf <<EOF
TLS_CACERT /etc/openldap/cacerts/ldap.crt
TLS_REQCERT allow
EOF

service slapd restart
