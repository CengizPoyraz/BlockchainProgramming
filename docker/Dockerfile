# syntax=docker/dockerfile:1
FROM ubuntu:20.04
ENV TZ=TR \
    DEBIAN_FRONTEND=noninteractive \
    BLOCKCHAIN_HOME=/home/root/blockchain \
    BLOCKCHAIN_GIT_URL=https://github.com/CengizPoyraz/BlockchainProgramming.git
WORKDIR $BLOCKCHAIN_HOME
SHELL ["/bin/bash", "-c"]

RUN apt-get update && apt upgrade -y
RUN apt-get install -y software-properties-common
RUN add-apt-repository -y ppa:ethereum/ethereum
RUN apt-get update
RUN apt install -y ethereum git curl nano
RUN (type -p wget >/dev/null || ( apt update &&  apt-get install wget -y)) \
	&&  mkdir -p -m 755 /etc/apt/keyrings \
        && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        && cat $out |  tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&&  chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |  tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&&  apt update \
	&&  apt install gh -y

RUN git clone $BLOCKCHAIN_GIT_URL $BLOCKCHAIN_HOME

