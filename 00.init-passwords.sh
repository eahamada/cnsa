#!/bin/sh
#
## Fonction pour générer un password.
## "randpw" pour générer un mot de passe aléatoire de 32 caractères
## "randpw <n>" pour générer un mot de passe aléatoire de <n> caractères
randpw(){ < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32};echo;}
## Définir les mots de passe et les exporter pour qu'ils soient visibles des scripts.
cat > passwords << EOF
export DATA_CONFIG_PASSWORD=`randpw`		
export DATA_ADMIN_PASSWORD=`randpw`		
export DATA_SERVICE_PASSWORD=`randpw`	
export JBOSS_PASSWORD=`randpw 8`
EOF
