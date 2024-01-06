From neo4j:5.12.0

LABEL version="1.0.1"
LABEL maintainer="yxxx <yxwuman@gmail.com>"

RUN wget https://github.com/BytecodeDL/bytecodedl-pathfinder-neo4j-procedure/releases/download/v1.0.1/bytecodedl-pathfinder-1.0.1.jar -O /var/lib/neo4j/plugins/bytecodedl-pathfinder-1.0.1.jar

ENV NEO4J_AUTH=neo4j/bytecodedl \
    NEO4J_dbms_security_procedures_unrestricted=bytecodedl.*