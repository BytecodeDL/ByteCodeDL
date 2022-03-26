#!/bin/bash

docker-compose exec neo bash /bytecodedl/neoImport.sh $1
docker-compose restart neo