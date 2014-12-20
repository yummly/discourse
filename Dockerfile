# Current version 1.0.6
FROM yummly/discourse_base:1.0.6

ADD . /var/www/discourse
WORKDIR /var/www/discourse
RUN bundle install
