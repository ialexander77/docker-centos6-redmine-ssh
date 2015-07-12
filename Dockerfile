# This Dockerfile will install Redmine stack
#  !!! Important !!!
# Please modify all variables in the Variables section in config.sh

FROM centos:centos6

MAINTAINER Alex Ivanov <ialexander77@gmail.com>

# Update and install epel repo
RUN yum -y update --nogpgcheck && yum -y install epel-release --nogpgcheck

# System packages
RUN yum -y install --nogpgcheck which nano wget bash-completion psmisc net-tools git zip unzip tar openssh-server passwd pwgen

#Application packages
RUN yum -y install --nogpgcheck httpd mysql mysql-server supervisor libyaml-devel zlib-devel curl-devel openssl-devel httpd-devel apr-devel apr-util-devel mysql-devel gcc ruby-devel gcc-c++ make postgresql-devel ImageMagick-devel sqlite-devel perl-LDAP mod_perl perl-Digest-SHA; yum clean all

# Copy files to image
ADD ./start.sh /start.sh
ADD ./config.sh /config.sh

# Run commands inside image
RUN echo "ServerName localhost" >> /etc/httpd/conf/httpd.conf
RUN chmod 755 /*.sh
RUN /config.sh && rm -rf /config.sh

#VOLUME /var/lib/mysql

EXPOSE 80 2222

CMD ["/bin/bash", "/start.sh"]
