#!/bin/bash
# Add docker-compose to startup
set -eo pipefail
usage() {
	echo "Usage: $0 {PROJECT_NAME} {COMPOSE_DIR}"
}
if [[ -z $2 ]];then
	usage
	exit 1
fi

PROJECT=$1
COMPOSE_DIR=$(realpath $2)
SYSTEMCTL_FILE=/etc/systemd/system/docker-compose@.service
PROJECT_DIR=/etc/docker/compose/$PROJECT
if ! [[ -f $COMPOSE_DIR/docker-compose.yml ]];then
	echo "THERE'S NO DOCKER COMPOSE FILE IN THE GIVEN DIRECTORY: $COMPOSE_DIR"
	echo "Exiting"
	exit 1
fi
if ! [[ -f $SYSTEMCTL_FILE ]];then
	cat <<-EOF > $SYSTEMCTL_FILE
	[Unit]
	Description=%i service with docker compose
	Requires=docker.service
	After=docker.service

	[Service]
	Restart=always

	WorkingDirectory=/etc/docker/compose/%i

	# Remove old containers, images and volumes
	ExecStartPre=/usr/local/bin/docker-compose down -v
	ExecStartPre=/usr/local/bin/docker-compose rm -fv
	ExecStartPre=-/bin/bash -c 'docker volume ls -qf "name=%i_" | xargs docker volume rm'
	ExecStartPre=-/bin/bash -c 'docker network ls -qf "name=%i_" | xargs docker network rm'
	ExecStartPre=-/bin/bash -c 'docker ps -aqf "name=%i_*" | xargs docker rm'

	# Compose up
	ExecStart=/usr/local/bin/docker-compose up

	# Compose down, remove containers and volumes
	ExecStop=/usr/local/bin/docker-compose down -v

	[Install]
	WantedBy=multi-user.target
fi

if [[ -d $PROJECT_DIR ]];then
	echo "Directory $PROJECT_DIR ALREADY EXISTS"
else
	mkdir -p ${PROJECT_DIR%/*}
	ln -s $COMPOSE_DIR $PROJECT_DIR
fi


echo -e "Service added!\nYou can start by typing `tput smul`systemctl start docker-compose@$PROJECT`tput rmul`\nOr to add it to startup by typing `tput smul`systemctl enable docker-compose@$PROJECT`tput rmul`"
exit 0
