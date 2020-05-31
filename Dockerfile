FROM ubuntu:20.10

LABEL maintainer="Jaya Sai Muppalla <jayasai470@gmail.com>"

ARG java_version=8
ARG node_version=12
ARG golang_version=1.13

ENV DEBIAN_FRONTEND="noninteractive"

RUN apt update

# ## java 8
RUN apt install -y \
  curl \
  openjdk-${java_version}-jdk \
  git
RUN export JAVA_HOME=/usr/lib/jvm/java-${java_version}-openjdk-amd64
RUN java -version
# maven
RUN apt install maven -y
RUN mvn -version

# ## Node 12
RUN curl -sL https://deb.nodesource.com/setup_$node_version.x | bash
RUN apt install -y nodejs
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt update
RUN apt install -y yarn
RUN apt install -y bzip2
RUN node -v
# serverless
RUN npm i -g serverless

## golang
RUN apt install golang -y
# RUN export GOROOT=/usr/lib/go-1.14
# RUN export PATH=$PATH:$GOROOT/bin
RUN go version

## python
RUN apt update \
   && apt install -y python-dev zip jq \
   && cd /tmp \
   && curl -O https://bootstrap.pypa.io/get-pip.py \
   && python get-pip.py \
   && pip install awscli --upgrade \
   && apt clean \
   && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN aws --version
RUN python --version

RUN rm -rf /var/lib/apt/lists/*