Running discourse in dev mode using [fig](http://www.fig.sh/)

This will use local postgres, redis, and nginx running in separate docker containers. You can also point it to external postgres and redis by editing fig.yml. Nginx is used to serve static assets.

If you are running on linux, the server will listen on http://localhost. If you are on mac using boot2docker, you can find the server's ip address by doing `boot2docker ip`. You can access the rails application directly (bypassing nginx) by using port 3000 instead of 80.

1. [Install fig](http://www.fig.sh/install.html)
2. Check `fig.yml`, you may need to edit it.
3. `fig build`
4. `fig run discourse bundle exec rake db:create db:migrate db:seed_fu`
5. `fig up`
6. The server should be up.
7. To run tests: `fig run discourse bash -c 'RAILS_ENV=test bundle exec rake db:drop db:create db:migrate'`, then `fig run discourse bash -c 'bundle exec rake autospec p l=5'`

You can edit the source code as usual and it will be reflected in the running server (no need to rebuild, restart, or attach to the docker container).
