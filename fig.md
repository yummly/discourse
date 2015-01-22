Running discourse in dev mode using [fig](http://www.fig.sh/)

This will use local postgres and redis running in separate docker images. You can also point it to external postgres and redis by editing fig.yml.

If you are running on linux, the server will listen on http://localhost:3000. If you are on mac using boot2docker, you can find the server's ip address by doing `boot2docker ip`.

This configuration doesn't use nginx.

1. [Install fig](http://www.fig.sh/install.html)
2. Check `fig.yml`, you may need to edit it.
3. `fig build`
4. `fig run discourse bundle exec rake db:create db:migrate db:test:prepare db:seed_fu`
5. `fig up`
6. The server should be up.
7. To run tests: `fig run web rake test`

You can edit the source code as usual and it will be reflected in the running server (no need to rebuild, restart, or attach to the docker container).
