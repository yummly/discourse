# Current version 1.0.6
FROM yummly/discourse_base:1.0.6

ADD . /opt/discourse
WORKDIR /opt/discourse
RUN mkdir -p /var/log && rm -rf log && ln -sf /var/log log

RUN bundle install

# RUN RAILS_ENV=production bundle exec rake assets:precompile