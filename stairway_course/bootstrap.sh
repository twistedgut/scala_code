#!/bin/bash

echo "Installing Ansible..."
sudo yum clean all -y
sudo yum install epel-release -y
sudo yum upgrade -y
sudo yum install ansible -y

#echo "Installing Docker..."
#sudo yum install docker-io -y

echo "Installing Scala..."
wget http://www.scala-lang.org/files/archive/scala-2.11.6.tgz
tar xvf scala-2.11.6.tgz
sudo mv scala-2.11.6 /usr/lib
sudo ln -s /usr/lib/scala-2.11.6 /usr/lib/scala
echo "export PATH=$PATH:/usr/lib/scala/bin" >> .bashrc

echo "Installing sbt..."
curl https://bintray.com/sbt/rpm/rpm | sudo tee /etc/yum.repos.d/bintray-sbt-rpm.repo
sudo yum install sbt -y
