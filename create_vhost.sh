#!/bin/bash
SERVERNAME=""
SERVERALIAS=""
HOMEDIR=""
USERNAME=""
USERPASS=""
DBUSER=""
DBPASS=""
DBNAME=""
while :
do
	echo "Domain name ?"
	read SERVERNAME
	if [ ! -z ${SERVERNAME} ]
	then
		break
	fi
done
echo "Domain Aliases ? (multiple alias on one ligne, separated by a simple space, none if empty"
read SERVERALIAS

while : 
do
	echo "Username FTP/SSH ?"
	read USERNAME
	if [ ! -z ${USERNAME} ]
	then
		break
	fi
done

while : 
do
	echo "Password ?"
	read USERPASS
	if [ ! -z ${USERPASS} ]
	then
		break
	fi
done

while :
do
	echo "Home directory ? (document_root will be automatilly generated, at HOMEDIR/public_html)"
	read HOMEDIR
	if [ ! -z ${HOMEDIR} ]
	then
		DOCUMENTROOT=$(echo /home/${HOMEDIR}/public_html)
		break
	fi
done

while :
do
	echo "Database ? <y/n>"
	read IS_DB
	if [ ${IS_DB} == "y" ]	
	then
		echo "database name ?"
		read DBNAME
		echo "DB user ?"
		read DBUSER
		echo "DB user pass ?"
		read DBPASS
		if [ ! -z ${DBNAME} ] && [ ! -z ${DBUSER} ] && [ ! -z ${DBPASS} ]
		then
			break
		fi
	elif [ ${IS_DB} == "n" ]
	then
		break
	fi
done


echo "creating user"
useradd -d /home/$HOMEDIR -s /bin/bash $USERNAME
mkdir -p $DOCUMENTROOT
chown -R $USERNAME: /home/$HOMEDIR
echo $USERNAME:$USERPASS | chpasswd

echo "creating PHP pool"
cp /etc/php/7.0/fpm/pool.d/TEMPLATE /etc/php/7.0/fpm/pool.d/${USERNAME}.conf
sed -i "s@USERNAME@${USERNAME}@g" /etc/php/7.0/fpm/pool.d/${USERNAME}.conf
echo "restarting FPM"
systemctl restart php7.0-fpm.service

echo "Creating website"
cp /etc/apache2/sites-available/TEMPLATE /etc/apache2/sites-available/${USERNAME}.conf
sed -i "s@SERVERNAME@${SERVERNAME}@g" /etc/apache2/sites-available/${USERNAME}.conf
if [ ! -z ${SERVERALIAS} ]
then
	sed -i "s@SERVERALIAS@${SERVERALIAS}@g" /etc/apache2/sites-available/${USERNAME}.conf
else
	sed -i "s@.*ServerAlias SERVERALIAS.*@@g" /etc/apache2/sites-available/${USERNAME}.conf
fi
sed -i "s@DOCUMENTROOT@${DOCUMENTROOT}@g" /etc/apache2/sites-available/${USERNAME}.conf
sed -i "s@USERNAME@${USERNAME}@g" /etc/apache2/sites-available/${USERNAME}.conf
a2ensite ${USERNAME}.conf
apachectl configtest
apache2ctl graceful

if [ ! -z ${DBNAME} ] && [ ! -z ${DBUSER} ] && [ ! -z ${DBPASS} ]
then
	echo "Creating database"
	mysql -e "CREATE DATABASE ${DBNAME}; GRANT ALL PRIVILEGES ON ${DBNAME}.* TO '${DBUSER}'@'localhost' IDENTIFIED BY '${DBPASS}';"
else
	echo "No database"
fi
