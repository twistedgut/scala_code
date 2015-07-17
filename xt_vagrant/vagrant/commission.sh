#!/bin/bash

echo "Comissioning environment.."

echo "connecting net-a-porter yum repositories.."
cp /vagrant/vagrant/yum.repos.d/* /etc/yum.repos.d/

echo "disabling gpg key checking..."
sed -i "s/gpgcheck=1/gpgcheck=0/g" /etc/yum.repos.d/*

echo "parsing dependencies..."

DEPLIST=`awk '/Requires:/ { print $2 }'  /vagrant/xt-uni.spec.in | grep -vE "xt-uni|perl-nap"`
yum install -y -- $DEPLIST

# manually add badly specified dependencies
# todo: fix.
yum install -y -- XT-Common

echo "enhancing bashrc for vagrant user"
cat < /vagrant/vagrant/bashrc >> /home/vagrant/.bashrc

yum install postgresql-server -y
service postgresql-9.3 initdb
cp /vagrant/vagrant/pg_hba.conf /var/lib/pgsql/9.3/data/pg_hba.conf
service postgresql-9.3 start
chkconfig postgresql-9.3 on
createuser -U postgres -D -R -S www