#!/bin/bash

dbname=$1$(date "+%m%d%H%M")

neo4j-admin import --relationships=Call=/bytecodedl/neo4j/CallEdgeHeader.csv,/bytecodedl/output/CallEdge.csv --nodes=/bytecodedl/neo4j/CallNodeHeader.csv,/bytecodedl/output/CallNode.csv --database=$dbname --delimiter="\t"

if grep -q "dbms.active_database" /var/lib/neo4j/conf/neo4j.conf; then
    sed sed -i -E "s/dbms.active_database=\w+/dbms.active_database=$dbname/g" /var/lib/neo4j/conf/neo4j.conf
else
    echo "dbms.active_database=$dbname" >> /var/lib/neo4j/conf/neo4j.conf
fi