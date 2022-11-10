# Worlds Management

Welcome to the Worlds management tool!

Here you will find everything you need to set up you our Worlds server.

## Set up

### Requirements

- You will need to have [docker](https://docs.docker.com/install/) installed.
- The initialization script runs on Bash. It has not been tested on Windows.

To run a public server, you will also need to:

- Have a public domain pointing to your server.
- Your server will need to have the HTTP and HTTPS ports open (80 and 443).


### What you will need to configure

To configure your node, you will have to set some variables in the [.env](.env) 
file:

| Name                             | Description                                                                                                                                    | Default | Required |
|----------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------|:-------:|:--------:|
| EMAIL                            | Needed to handle the TLS certificates. For example, you will be notified when they are about to expire.                                        |    -    |   yes    |
| HOSTNAME                         | The public hostname pointing to your server (e.g. `name.domain.com`).                                                                          |    -    |   yes    |
| WORLDS_CONTENT_SERVER_DOCKER_TAG | The tag of the docker image for the [Worlds Content Server](https://github.com/decentraland/worlds-content-server).                            | latest  |    no    |
| WS_ROOM_SERVICE_DOCKER_TAG       | The tag of the docker image for the [Room Service](https://github.com/decentraland/ws-room-service).                                           | latest  |    no    |
| MARKETPLACE_SUBGRAPH_URL         | The public URL of a Decentraland Marketplace subgraph instance. Defaults to `https://api.thegraph.com/subgraphs/name/decentraland/marketplace` |    -    |    no    |


## Running your Worlds server

After you have configured everything, all you need to do is run:

```bash
./init.sh
```

#### How to make sure that your Worlds server is running

Once you started your Worlds server, after a few seconds you should be able 
to test the content services by accessing the URL 
`https://your-host-name/content/about` in the browser.

## Updating your Worlds server

To update your Worlds server to a newer version, you can do the same as above:

```bash
./init.sh
```

## Stopping your Worlds server

To stop a specific container on your server:

```bash
docker compose stop container-name
```
where `container-name` can be one of `worlds-owner-nginx`, 
`worlds-owner-certbot`, `worlds-owner-content-server` or 
`worlds-owner-room-service`.

To stop the whole server:

```bash
docker compose stop
```
