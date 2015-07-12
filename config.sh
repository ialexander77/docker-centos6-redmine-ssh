#!/bin/bash

#Variables
MYSQL_ROOT_PASSWORD='changerootpassword'
MYSQL_APP_DB_PASSWORD='changeuserpassword'
MYSQL_APP_DB_USERNAME='redmine_admin'
MYSQL_APP_DB_NAME='redmine_db'
SSH_ROOTPASS='changesshrootpassword'
SSH_USERNAME='sshin'
SSH_USERPASS='changesshuserpassword'
RUBY_BUILD='2.1.5'
PASSENDER_BUILD='5.0.10'

__create_ssh_user() {
# Create a user to SSH into as.
/usr/sbin/useradd $SSH_USERNAME
echo -e "$SSH_USERPASS\n$SSH_USERPASS" | (passwd --stdin $SSH_USERNAME)
echo ssh $SSH_USERNAME password: $SSH_USERPASS
}

__fix_ssh_root() {
# Change root password and SSH login fix. Otherwise user is kicked off after login (uncomment sed for Ubuntu)
echo root:$SSH_ROOTPASS
echo root:$SSH_ROOTPASS | chpasswd
mkdir /var/run/sshd
/usr/bin/ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ''
/usr/bin/ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key -N ''
#sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
#sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
}

__ruby_install() {
cd ~
curl -L https://get.rvm.io | bash
source /etc/profile.d/rvm.sh
rvm install $RUBY_BUILD
yum -y install rubygems
gem install passenger --version $PASSENDER_BUILD
passenger-install-apache2-module --auto
cat <<EOF >/etc/httpd/conf.d/passenger.conf
LoadModule passenger_module /usr/local/rvm/gems/ruby-$RUBY_BUILD/gems/passenger-$PASSENDER_BUILD/buildout/apache2/mod_passenger.so
 <IfModule mod_passenger.c>
    PassengerRoot /usr/local/rvm/gems/ruby-$RUBY_BUILD/gems/passenger-$PASSENDER_BUILD
    PassengerDefaultRuby /usr/local/rvm/gems/ruby-$RUBY_BUILD/wrappers/ruby
 </IfModule>
EOF
}

__mysql_config() {
# Hack to get MySQL up and running... I need to look into it more.
echo "Running the mysql_config function."
mysql_install_db
chown -R mysql:mysql /var/lib/mysql
/usr/bin/mysqld_safe & 
sleep 10
}

__start_mysql() {
echo "Running the start_mysql function."
mysqladmin -u root password $MYSQL_ROOT_PASSWORD
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE $MYSQL_APP_DB_NAME"
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT USAGE ON $MYSQL_APP_DB_NAME.* TO $MYSQL_APP_DB_USERNAME@localhost IDENTIFIED BY '$MYSQL_APP_DB_PASSWORD'; FLUSH PRIVILEGES;"
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON $MYSQL_APP_DB_NAME.* TO $MYSQL_APP_DB_USERNAME@localhost; FLUSH PRIVILEGES;"
#DB Import
#mysql -uroot -p$MYSQL_ROOT_PASSWORD somedatabasename < /tmp/dump.sql
}

__redmine_install() {
cd /tmp
wget http://www.redmine.org/releases/redmine-2.6.6.zip
unzip redmine-2.6.6.zip
mv /tmp/redmine-2.6.6 /var/www/redmine
cat <<EOF >/var/www/redmine/config/database.yml
production:
  adapter: mysql2
  database: $MYSQL_APP_DB_NAME
  host: localhost
  username: $MYSQL_APP_DB_USERNAME
  password: $MYSQL_APP_DB_PASSWORD
  encoding: utf8

development:
  adapter: mysql2
  database: redmine_development
  host: localhost
  username: root
  password: ""
  encoding: utf8

test:
  adapter: mysql2
  database: redmine_test
  host: localhost
  username: root
  password: ""
  encoding: utf8
EOF
cat <<EOF >/var/www/redmine/config/configuration.yml
# = Redmine configuration file
default:
  email_delivery:
  attachments_storage_path: /opt/redmine/files
  autologin_cookie_name:
  autologin_cookie_path:
  autologin_cookie_secure:
  scm_subversion_command:
  scm_mercurial_command:
  scm_git_command:
  scm_cvs_command:
  scm_bazaar_command:
  scm_darcs_command:
  scm_stderr_log_file:
  database_cipher_key:
  rmagick_font_path:

production:

development:
EOF
cd /var/www/redmine
gem install bundler
bundle install
rake generate_secret_token
RAILS_ENV=production rake db:migrate
RAILS_ENV=production REDMINE_LANG=en rake redmine:load_default_data
cd /var/www/redmine/public
mkdir -p plugin_assets
cp dispatch.fcgi.example dispatch.fcgi
cp htaccess.fcgi.example .htaccess
yum -y install mod_fcgid
mkdir -p /opt/redmine/files
chown -R apache:apache /opt/redmine
cd /var/www
chown -R apache:apache redmine
find /var/www/redmine -type d -exec chmod 755 {} \;
find /var/www/redmine -type f -exec chmod 644 {} \;
cat <<EOF >/etc/httpd/conf.d/redmine.conf
<VirtualHost *:80>
        ServerName redmine.mydomain.com
        ServerAdmin email@address.com
        DocumentRoot /var/www/redmine/public/
        ErrorLog logs/redmine_error_log
        <Directory "/var/www/redmine/public/">
                Options Indexes ExecCGI FollowSymLinks
                Order allow,deny
                Allow from all
                AllowOverride all
        </Directory>
       RequestHeader set X_FORWARDED_PROTO 'https'
</VirtualHost>
EOF
killall mysqld
sleep 10
}

__show_variables() {
echo "========================================================================"
echo "    You can now connect to this MySQL Server using:"
echo ""
echo "    mysql -u$MYSQL_APP_DB_USERNAME -p$MYSQL_APP_DB_PASSWORD -h$HOSTNAME -P3306"
echo ""
echo "    Please remember to change the above password as soon as possible!"
echo "========================================================================"
echo ""
echo "========================================================================"
echo "    You can now connect to this SSH Server using:"
echo "    While runing container please use -p 2222:22 option"
echo "    ssh -p 2222 root:$SSH_ROOTPASS@$HOSTNAME "
echo ""
echo "    Please remember to change the above password as soon as possible!"
echo "========================================================================"
}

__supervisord_config() {
mkdir -p /var/log/supervisor
cat <<EOF >/etc/supervisord.conf
; Sample supervisor config file.

[unix_http_server]
file=/tmp/supervisor.sock   ; (the path to the socket file)

[supervisord]
logfile=/var/log/supervisor/supervisord.log ; (main log file;default $CWD/supervisord.log)
logfile_maxbytes=50MB        ; (max main logfile bytes b4 rotation;default 50MB)
logfile_backups=10           ; (num of main logfile rotation backups;default 10)
loglevel=info                ; (log level;default info; others: debug,warn,trace)
pidfile=/tmp/supervisord.pid ; (supervisord pidfile;default supervisord.pid)
nodaemon=false               ; (start in foreground if true;default false)
minfds=1024                  ; (min. avail startup file descriptors;default 1024)
minprocs=200                 ; (min. avail process descriptors;default 200)

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///tmp/supervisor.sock ; use a unix:// URL  for a unix socket

[program:mysqld]
command=/usr/bin/mysqld_safe
stdout_logfile=/var/log/supervisor/%(program_name)s.log
stderr_logfile=/var/log/supervisor/%(program_name)s.log
autorestart=true

[program:httpd]
command=/usr/sbin/apachectl -D FOREGROUND
stdout_logfile=/var/log/supervisor/%(program_name)s.log
stderr_logfile=/var/log/supervisor/%(program_name)s.log
autorestart=true

[program:sshd]
command=/usr/sbin/sshd -D
stdout_logfile=/var/log/supervisor/%(program_name)s.log
stderr_logfile=/var/log/supervisor/%(program_name)s.log
autorestart=true

## Add more startup services below
EOF
}

# Call all functions
__create_ssh_user
__fix_ssh_root
__mysql_config
__start_mysql
__ruby_install
__redmine_install
__supervisord_config
__show_variables
