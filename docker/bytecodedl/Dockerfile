From ubuntu:22.04

LABEL version="1.0.2"
LABEL maintainer="yxxx <yxwuman@gmail.com>"

RUN apt-get update \
    && apt-get install -y vim \
    && apt-get install -y wget \
    && apt-get install -y git \
    && apt-get install -y openjdk-8-jdk

RUN wget https://souffle-lang.github.io/ppa/souffle-key.public -O /usr/share/keyrings/souffle-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/souffle-archive-keyring.gpg] https://souffle-lang.github.io/ppa/ubuntu/ stable main" | tee /etc/apt/sources.list.d/souffle.list \
    && apt update && apt install -y souffle

RUN wget https://github.com/BytecodeDL/soot-fact-generator/releases/download/v1.4.2/soot-fact-generator-1.4.2.jar