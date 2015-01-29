#!/bin/bash

set -e

discourse=`dirname $0`/..
root=`cat $discourse/tmp/root`

echo removing unused and stale files
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/conf.d/*
mkdir -p /var/nginx/cache /var/run /var/log/nginx

echo generating nginx.conf
cat $discourse/config/nginx.sample.conf |
    sed 's|server unix:/var/www/discourse/tmp/sockets/thin.[0-9]*.sock;|server discourse:3000;|' |
    sed "s|/var/www/discourse|$discourse|g" |
    sed 's/server_name.+$/server_name _/' |
    sed "s|location / |location $root |" |
    sed 's/root \$public;/alias $public;/' > /etc/nginx/conf.d/discourse.conf

if [[ ! -f /etc/nginx/nginx.crt ]]
then
    echo generating SSL certificate
    apt-get -q update
    apt-get -q install openssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -subj '/C=US/ST=CA/L=San Francisco/O=discourse/OU=discourse.org' -keyout /etc/nginx/nginx.key -out /etc/nginx/nginx.crt
else
    echo using an existing SSL certificate
fi

exec nginx -g 'daemon off;'
