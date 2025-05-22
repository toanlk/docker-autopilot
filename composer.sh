#! /bin/bash

clear

docker compose down

docker compose build

docker compose up

sleep 2

docker ps -a --format="table {{.Names}}\t{{.Image}}\t{{.Status}}"