#!/bin/bash

export rsa_key_size=4096
export data_path="local/certbot"
export nginx_server_file="local/nginx/conf.d/00-worlds.conf"
export nginx_server_template_http="local/nginx/conf.d/worlds-http.conf.template"
export nginx_server_template_https="local/nginx/conf.d/worlds-https.conf.template"

leCertEmit() {
  if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
    echo "## Downloading recommended TLS parameters ..."
    mkdir -p "$data_path/conf"
    curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf >"$data_path/conf/options-ssl-nginx.conf"
    curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem >"$data_path/conf/ssl-dhparams.pem"
    echo
  fi

  echo " Creating dummy certificate for $nginx_url..."
  path="/etc/letsencrypt/live/$nginx_url"
  mkdir -p "$data_path/conf/live/$nginx_url"
  docker compose run --rm --entrypoint "\
    openssl req -x509 -nodes -newkey rsa:1024 -days 1\
      -keyout '$path/privkey.pem' \
      -out '$path/fullchain.pem' \
      -subj '/CN=localhost'" certbot

  echo -n "## Starting nginx ..."
  docker compose -f docker-compose.yml -f "platform.$(uname -s).yml" up --remove-orphans --force-recreate -d nginx

  if test $? -ne 0; then
    echo -n "Failed to start nginx...  "
    printMessage failed
    exit 1
  else
    echo -n "## Dummy certificates created ..."
    printMessage ok
  fi

  echo -n "## Deleting dummy certificate for $nginx_url ..."
  docker compose run --rm --entrypoint "\
            rm -Rf /etc/letsencrypt/live/$nginx_url && \
            rm -Rf /etc/letsencrypt/archive/$nginx_url && \
            rm -Rf /etc/letsencrypt/renewal/$nginx_url.conf" certbot
  echo

  if test $? -ne 0; then
    echo -n "Failed to remove files... "
    printMessage failed
    exit 1
  else
    echo -n "## Files deleted ... "
    printMessage ok
  fi

  echo "## Requesting Let's Encrypt certificate for $nginx_url... "
  domain_args=""
  domain_args="$domain_args -d ${nginx_url}"

  # Select appropriate EMAIL arg
  case "$EMAIL" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $EMAIL" ;;
  esac

  # wait until the server responds
  serverAlive=10
  until [ $serverAlive -lt 1 ]; do
    echo "Checking server liveness: ${SERVER_URL}"
    statusCode=$(curl --insecure -I -vv -s --http1.1 --output /dev/stderr --write-out "%{http_code}" "${SERVER_URL}")
    returnCode=$?
    echo ">> statusCode: ${statusCode} returnCode: ${returnCode}"
    if [ "$statusCode" -lt 500 ] && [ "$returnCode" -eq 0 ]; then
      serverAlive=0
      echo ">> Success"
    else
      ((serverAlive = serverAlive + 1))
      echo ">> Waiting..."
      sleep 6
    fi
  done

  docker compose run --rm --entrypoint "\
            certbot certonly --webroot -w /var/www/certbot \
            --no-eff-email \
            $email_arg \
            $domain_args \
            --rsa-key-size $rsa_key_size \
            --agree-tos \
            --force-renewal" certbot

  if test $? -ne 0; then
    echo -n "Failed to request certificates... "
    printMessage failed
    exit 1
  else
    echo -n "## Certificates issued "
    printMessage ok
  fi

  echo "## Reloading nginx ..."
  docker compose restart nginx
  if test $? -ne 0; then
    echo -n "Failed to reload nginx... "
    printMessage failed
    exit 1
  else
    echo -n "## Nginx Reloaded"
    printMessage ok
  fi

  echo "## Going for the real certs..."

  docker compose run --rm --entrypoint "\
        certbot certonly --webroot -w /var/www/certbot \
            $email_arg \
            $domain_args \
            --no-eff-email \
            --rsa-key-size $rsa_key_size \
            --agree-tos \
            --force-renewal" certbot

  if test $? -ne 0; then
    echo -n "Failed to request certificates. Handshake failed?, the URL is pointing to this server?: "
    printMessage failed
    exit 1
  else
    echo -n "Real certificates emitted "
    printMessage ok
  fi

  echo "## Reloading nginx with real certs..."
  docker compose restart nginx
  if test $? -ne 0; then
    echo -n "Failed to reload nginx... "
    printMessage failed
    exit 1
  else
    echo -n "## Nginx Reloaded"
    printMessage ok
  fi
}

printMessage() {
  Type=$1
  case ${Type} in
  ok) echo -e "[\e[92m OK \e[39m]" ;;
  failed) echo -e "[\e[91m FAILED \e[39m]" ;;
  *) echo "" ;;
  esac
}

clear
echo -n "## Loading env variables... "

if ! [ -f ".env" ]; then
  echo -n "Error: .env does not exist" >&2
  printMessage failed
  exit 1
else
  source ".env"
  printMessage ok
fi

echo -n "## Checking if email is configured... "
if test "${EMAIL}"; then
  printMessage ok
else
  echo -n "Failed to check the email."
  printMessage failed
  exit 1
fi

echo -n "## Checking if host name is configured... "
if test "${HOSTNAME}"; then
  if [ "${HOSTNAME}" == "localhost" ]; then
    SERVER_URL="http://localhost"
  else
    SERVER_URL="https://${HOSTNAME}"
  fi
  export SERVER_URL
  printMessage ok
else
  echo -n "Failed to check the server url."
  printMessage failed
  exit 1
fi

# Define defaults
export WORLDS_CONTENT_SERVER_DOCKER_TAG=${WORLDS_CONTENT_SERVER_DOCKER_TAG:-latest}
export ROOM_SERVICE_DOCKER_TAG=${ROOM_SERVICE_DOCKER_TAG:-latest}
REGENERATE=${REGENERATE:-0}

echo -n " - EMAIL:                            "
echo -e "\033[33m ${EMAIL} \033[39m"
echo -n " - HOSTNAME:                         "
echo -e "\033[33m ${HOSTNAME} \033[39m"
echo -n " - WORLDS_CONTENT_SERVER_DOCKER_TAG: "
echo -e "\033[33m ${WORLDS_CONTENT_SERVER_DOCKER_TAG} \033[39m"
echo -n " - ROOM_SERVICE_DOCKER_TAG:          "
echo -e "\033[33m ${ROOM_SERVICE_DOCKER_TAG} \033[39m"
echo -n " - SERVER_URL:                       "
echo -e "\033[33m ${SERVER_URL} \033[39m"
echo -n " - MARKETPLACE_SUBGRAPH_URL:         "
echo -e "\033[33m ${MARKETPLACE_SUBGRAPH_URL} \033[39m"
echo ""

if ! docker pull "nginx";
then
  echo -n "Failed to pull nginx"
  printMessage failed
  exit 1
fi
echo ""

if ! docker pull "quay.io/decentraland/worlds-content-server:${WORLDS_CONTENT_SERVER_DOCKER_TAG}";
then
  echo -n "Failed to pull quay.io/decentraland/worlds-content-server:${WORLDS_CONTENT_SERVER_DOCKER_TAG}"
  printMessage failed
  exit 1
fi
echo ""

if ! docker pull "quay.io/decentraland/ws-room-service:${ROOM_SERVICE_DOCKER_TAG}";
then
  echo -n "Failed to pull quay.io/decentraland/ws-room-service:${ROOM_SERVICE_DOCKER_TAG}"
  printMessage failed
  exit 1
fi
echo ""

if ! docker compose stop nginx; then
  echo -n "Failed to stop!"
  printMessage failed
  exit 1
fi

# If the server is localhost, do not enable https
# Setup the nginx conf file with plain http
# else, create new certs
nginx_url=${SERVER_URL##*/}
export nginx_url
if [ "${SERVER_URL}" != "http://localhost" ]; then
  echo "## Using HTTPS."
  echo -n "## Replacing value \"\$worlds_host\" on nginx server file with \"${nginx_url}\"... "
  sed "s/\$worlds_host/${nginx_url}/g" ${nginx_server_template_https} >${nginx_server_file}

  # This is the URL without the 'http/s'
  # Needed to place the server on nginx conf file
  if [ -d "$data_path/conf/live/$nginx_url" ]; then
    echo "Existing data found for \$nginx_url."

    if test "${REGENERATE}" -eq 1; then
      leCertEmit "$nginx_url"
    else
      echo "## Current certificates will be used."
    fi
  else
    echo "## No certificates found. Performing certificate creation... "
    leCertEmit "$nginx_url"

    if test $? -ne 0; then
      printMessage failed
      echo -n "Failed to deploy certificates. Take a look above for errors!"
      exit 1
    fi
  fi
  echo -n "## Finalizing Let's Encrypt setup... "
  printMessage ok

else
  echo "## Using HTTP because SERVER_URL is set to http://localhost"
  echo -n "## Replacing value \$worlds_host on nginx server file... "
  sed "s/\$worlds_host/${nginx_url}/g" ${nginx_server_template_http} >${nginx_server_file}
  printMessage ok
fi

matches=$(grep -c "${nginx_url}" ${nginx_server_file})
if test "$matches" -eq 0; then
  printMessage failed
  echo "Failed to perform changes on nginx server file, no changes found. Look into ${nginx_server_file} for more information"
  exit 1
fi

echo "## Restarting containers... "
docker compose down
docker compose -f docker-compose.yml -f "platform.$(uname -s).yml" up --remove-orphans -d nginx
if test $? -ne 0; then
  echo -n "Failed to start catalyst node"
  printMessage failed
  exit 1
fi
echo "## Catalyst server is up and running at ${SERVER_URL}"
