#!/bin/bash

dbname=$1$(date "+%m%d%H%M")

neo4j-admin database import full --nodes=Method="/bytecodedl/neo4j/CallNodeHeader.csv,/bytecodedl/output/.*CallNode.csv" --relationships=Call="/bytecodedl/neo4j/CallEdgeHeader.csv,/bytecodedl/output/CallEdge.csv" --relationships=Cha="/bytecodedl/neo4j/ChaEdgeHeader.csv,/bytecodedl/output/ChaEdge.csv" --delimiter="\t" $dbname

if grep -q "#initial.dbms.default_database" /var/lib/neo4j/conf/neo4j.conf; then
    sed -i -E "s/#initial.dbms.default_database=\w+/initial.dbms.default_database=$dbname/g" /var/lib/neo4j/conf/neo4j.conf
else
    sed -i -E "s/initial.dbms.default_database=\w+/initial.dbms.default_database=$dbname/g" /var/lib/neo4j/conf/neo4j.conf
fi
