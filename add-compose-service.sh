#!/bin/bash
# Add docker-compose to startup
usage() {
	echo "Usage: $0 {PROJECT_NAME} {COMPOSE_FILE}"
}
if [[ -z $2 ]];then
	usage
	exit 1
fi

PROJECT=$1
COMPOSE_FILE=$2
SYSTEMCTL_FILE=/etc/systemd/system/docker-compose@.service
PROJECT_DIR=/etc/docker/compose/$PROJECT/
COMPOSE_FILE_NAME=${COMPOSE_FILE##*/}
if [[ $COMPOSE_FILE_NAME != "docker-compose.yml" ]];then
	echo "DOCKER COMPOSE FILE HAS AN UNUSUAL NAME: $COMPOSE_FILE_NAME"
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
	ExecStartPre=/bin/docker-compose down -v
	ExecStartPre=/bin/docker-compose rm -fv
	ExecStartPre=-/bin/bash -c 'docker volume ls -qf "name=%i_" | xargs docker volume rm'
	ExecStartPre=-/bin/bash -c 'docker network ls -qf "name=%i_" | xargs docker network rm'
	ExecStartPre=-/bin/bash -c 'docker ps -aqf "name=%i_*" | xargs docker rm'

	# Compose up
	ExecStart=/usr/bin/docker-compose up

	# Compose down, remove containers and volumes
	ExecStop=/usr/bin/docker-compose down -v

	[Install]
	WantedBy=multi-user.target
	EOF
fi

if [[ -d $PROJECT_DIR ]];then
	echo "Directory $PROJECT_DIR ALREADY EXISTS"
else
	mkdir $PROJECT_DIR/
fi

if [[ -f $PROJECT_DIR/$COMPOSE_FILE_NAME ]];then
	echo "$COMPOSE_FILE_NAME ALREADY EXISTS IN THE DESTINATION DIRECTORY: $PROJECT_DIR"
else
	ln -s $COMPOSE_FILE $PROJECT_DIR/
fi

echo -e "Service added!\nYou can start by typing `tput smul`systemctl start docker-compose@$PROJECT`tput rmul`\nOr to add it to startup by typing `tput smul`systemctl enable docker-compose@$PROJECT`tput rmul`"
exit 0