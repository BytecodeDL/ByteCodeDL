#!/bin/bash

docker-compose exec neo bash /bytecodedl/$1 $2
docker-compose restart neo