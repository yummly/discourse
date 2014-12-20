# Current version 1.0.6
FROM yummly/discourse_base:1.0.6

MAINTAINER Sam Saffron "https://twitter.com/samsaffron"

ADD . /var/www/discourse
WORKDIR /var/www/discourse
RUN bundle install
