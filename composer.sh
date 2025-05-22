#! /bin/bash

clear

docker compose down

docker compose build

docker compose up -d

sleep 2

docker ps -a --format="table {{.Names}}\t{{.Image}}\t{{.Status}}"