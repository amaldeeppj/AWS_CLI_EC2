#!/bin/bash

# Define hostname
HN=europe.amaldeep.tech

yum update -y
hostnamectl set-hostname $HN
yum install git httpd -y 
amazon-linux-extras install php7.4  -y 
systemctl enable httpd.service
git clone https://github.com/amaldeeppj/webserver_sample_content_v1.git /var/website/
cp -r  /var/website/*  /var/www/html/
chown -R apache:apache /var/www/html/
systemctl restart httpd.service