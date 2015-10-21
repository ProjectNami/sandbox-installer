#!/bin/bash

# get command line args
while getopts d:s: opt; do
  case $opt in
  d)
      database=$OPTARG
      ;;
  s)
      server=$OPTARG
      ;;
  esac
done
shift $((OPTIND - 1))

if [ -z "$database" ]; then
	echo "Missing '-d databasename'"
	exit 1
fi

if [ -z "$server" ]; then
	echo "Missing '-s serverhost'"
	exit 1
fi

# make sure there isn't already an install present so we don't blow it away
if [ -f /usr/share/nginx/www/wp-load.php ] || [ -d /usr/share/nginx/www/.git ]; then
	echo "WordPress is already installed.
If you want to re-install, delete the contents (including .git folder) from /usr/share/nginx/www/ and run this script again."
	exit 1
fi

# make sure we're up to date
apt-get update
apt-get upgrade

# install nginx
apt-get install -y nginx

# make sure nginx starts on boot
update-rc.d nginx defaults

# remove default nginx html files
rm -rf /usr/share/nginx/www/*

# configure nginx
nginx_config="# Configured for use as a Project Nami sandbox
server {
        listen   80;
     

        root /usr/share/nginx/www;
        index index.php index.html index.htm;

        server_name _;

        location / {
                try_files \$uri \$uri/ /index.php;
        }

        error_page 404 /404.html;

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
              root /usr/share/nginx/www;
        }

        # pass the PHP scripts to FastCGI server listening on the php-fpm socket
        location ~ \.php$ {
                try_files \$uri =404;
                fastcgi_pass unix:/var/run/php5-fpm.sock;
                fastcgi_index index.php;
                fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
                include fastcgi_params;
                
        }

}"

# write nginx config
printf "%s" "$nginx_config" > /etc/nginx/sites-available/default

# start nginx
service nginx start

# install php 5
apt-get install -y php5-fpm

# install git
apt-get install -y git

# install project nami sandbox
cd /usr/share/nginx/www/
git clone https://github.com/ProjectNami/projectnami.git .
git checkout sandbox

# set file/folder ownership to the user running the script
chown -R $SUDO_USER *
chown -R $SUDO_USER .git

#install free tds and odbc
apt-get install tdsodbc

# configure free tds
freetds_config="#   \$Id: freetds.conf,v 1.12 2007/12/25 06:02:36 jklowden Exp $
#
# This file is installed by FreeTDS if no file by the same 
# name is found in the installation directory.  
#
# For information about the layout of this file and its settings, 
# see the freetds.conf manpage \"man freetds.conf\".  

# Global settings are overridden by those in a database
# server specific section
[projectnami]
        host = $server
        port = 1433
        tds version = 7.1

        # If you get out-of-memory errors, it may mean that your client
        # is trying to allocate a huge buffer for a TEXT field.  
        # Try setting 'text size' to a more reasonable limit 
        text size = 64512"

# write free tds config
printf "%s" "$freetds_config" > /etc/freetds/freetds.conf

# configure odbcinst
odbcinst_config="[FreeTDS]
Description = FreeTDS Driver
Driver = /usr/lib/x86_64-linux-gnu/odbc/libtdsodbc.so"

# write odbcinst config
printf "%s" "$odbcinst_config" > /etc/odbcinst.ini

odbc_config="#Set DSN
[projectnami]
Driver = FreeTDS
Servername = projectnami
Port = 1433
Database = $database"

# write odbc config
printf "%s" "$odbc_config" > /etc/odbc.ini

cat << "EOF"
  _____           _           _     _   _                 _ 
 |  __ \         (_)         | |   | \ | |               (_)
 | |__) | __ ___  _  ___  ___| |_  |  \| | __ _ _ __ ___  _ 
 |  ___/ '__/ _ \| |/ _ \/ __| __| | . ` |/ _` | '_ ` _ \| |
 | |   | | | (_) | |  __/ (__| |_  | |\  | (_| | | | | | | |
 |_|   |_|  \___/| |\___|\___|\__| |_| \_|\__,_|_| |_| |_|_|
                _/ |                                        
               |__/                                         

All done. Happy sandboxing!*

~ Spencer Cameron-Morin

* Unless it's broken. In which case, :sadface:. Let me know on github.com/ProjectNami.
EOF
