# intersectRaven/nextcloud-php8-cron

This is a docker image of the Nextcloud server using PHP8 with JIT being enabled and Cron.

#Usage

The simplest way to start a nextcloud server is:

    docker run -d intersectraven/nextcloud-php8-cron

This will run the server. It will only be reachable from the docker host by using the container ip address.

Exposing the ports from the host:

    docker run -d -p 8080:80 intersectraven/nextcloud-php8-cron

This will make Nextcloud reachable under [http://localhost:8080](http://localhost:8080) from your host system.


For information to further configuration, please consult the official [Nextcloud documentation](https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/email_configuration.html).
