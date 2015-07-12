docker-centos6-redmine-ssh
========================

This repo contains a recipe for making Docker container for SSH and Redmine 2.6.6 on CentOS 6. 

Check your Docker version

    # docker version

Perform the build

    # docker build -rm -t <yourname>/docker-centos6-redmine-ssh .

Check the image out.

    # docker images

Run it:

    # docker run -d -p 80:80 -p 2222:22 <yourname>/docker-centos6-redmine-ssh

Get container ID:

    # docker ps

Keep in mind to change variables in config.sh #Variables section:

The default values are:

MYSQL_ROOT_PASSWORD='changerootpassword'

MYSQL_APP_DB_PASSWORD='changeuserpassword'

MYSQL_APP_DB_USERNAME='redmine_admin'

MYSQL_APP_DB_NAME='redmine_db'

SSH_ROOTPASS='changesshrootpassword'

SSH_USERNAME='sshin'

SSH_USERPASS='changesshuserpassword'

RUBY_BUILD='2.1.5'

PASSENDER_BUILD='5.0.10'

