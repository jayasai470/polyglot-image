FROM alpine:3.12 as core

LABEL maintainer="Jaya Sai Muppalla <jayasai470@gmail.com>"

## base tools

# RUN apk add --no-cache curl tar bash procps
RUN apk add --no-cache --virtual .build-deps \
        curl \
        tar \
        libstdc++ \
        binutils \
        bash \
        gcc \
        musl-dev \
        openssl \
        go\
        ca-certificates

## =================== java coretto alpine ===================================
from core as core_java

ARG CORRETTO_VERSION=8.252.09.1
ARG CORRETTO_VERSION_RELEASE=${CORRETTO_VERSION}-r0

RUN wget -c -O amazon-corretto-8-jre-${CORRETTO_VERSION_RELEASE}.apk https://d3pxv6yz143wms.cloudfront.net/ea/${CORRETTO_VERSION}/amazon-corretto-8-jre-${CORRETTO_VERSION_RELEASE}.apk && \
    wget -c -O amazon-corretto-8-${CORRETTO_VERSION_RELEASE}.apk https://d3pxv6yz143wms.cloudfront.net/ea/${CORRETTO_VERSION}/amazon-corretto-8-${CORRETTO_VERSION_RELEASE}.apk && \
    wget -c -O /etc/apk/keys/amazoncorretto.rsa.pub https://d3pxv6yz143wms.cloudfront.net/ea/${CORRETTO_VERSION}/amazoncorretto.rsa.pub && \
    apk add amazon-corretto-8-jre-${CORRETTO_VERSION_RELEASE}.apk && \
    apk add amazon-corretto-8-${CORRETTO_VERSION_RELEASE}.apk && \
    rm -rf amazon-corretto-8-jre-${CORRETTO_VERSION_RELEASE}.apk && \
    rm -rf amazon-corretto-8-${CORRETTO_VERSION_RELEASE}.apk

ENV LANG C.UTF-8
ENV JAVA_HOME=/usr/lib/jvm/default-jvm
ENV PATH=$PATH:/usr/lib/jvm/default-jvm/bin

## ------------------------ maven -----------------------------
FROM core_java as core_java_maven

ARG MAVEN_VERSION=3.6.3
ARG USER_HOME_DIR="/root"
ARG BASE_URL=https://archive.apache.org/dist/maven/maven-3/$MAVEN_VERSION/binaries

RUN mkdir -p /usr/share/maven /usr/share/maven/ref \
  && echo "$" \
  && echo "Downlaoding maven from $BASE_URL/apache-maven-$MAVEN_VERSION-bin.tar.gz" \
  && curl -fsSL -o /tmp/apache-maven.tar.gz "$BASE_URL/apache-maven-$MAVEN_VERSION-bin.tar.gz" \
  && curl -fsSL -o /tmp/apache-maven.tar.gz.sha1 "$BASE_URL/apache-maven-$MAVEN_VERSION-bin.tar.gz.sha512" \
  \
  && echo "Checking download hash" \
  && echo -e "$(cat /tmp/apache-maven.tar.gz.sha1)  /tmp/apache-maven.tar.gz" | sha512sum -c - \
  \
  && echo "Unziping maven" \
  && tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 \
  \
  && echo "Cleaning and setting links" \
  && rm -f /tmp/apache-maven.tar.gz \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

ENV MAVEN_HOME /usr/share/maven
ENV MAVEN_CONFIG "$USER_HOME_DIR/.m2"

RUN mvn -version

# ## ----------------------------- node -------------------------------
From core_java_maven as core_java_maven_nodejs

ARG NODE_VERSION=12.17.0

RUN addgroup -g 1000 node \
    && adduser -u 1000 -G node -s /bin/sh -D node \
    && ARCH= && alpineArch="$(apk --print-arch)" \
      && case "${alpineArch##*-}" in \
        x86_64) \
          ARCH='x64' \
          CHECKSUM="fbd8916cc5a3c85dc503cc1fe9606cf8860152c4e8b2f2fcc729e48db3e3d654" \
          ;; \
        *) ;; \
      esac \
  && if [ -n "${CHECKSUM}" ]; then \
    set -eu; \
    curl -fsSLO --compressed "https://unofficial-builds.nodejs.org/download/release/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz"; \
    echo "$CHECKSUM  node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" | sha256sum -c - \
      && tar -xJf "node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
      && ln -s /usr/local/bin/node /usr/local/bin/nodejs; \
  else \
    echo "Building from source" \
    && apk add --no-cache --virtual .build-deps-full \
        binutils-gold \
        g++ \
        gcc \
        gnupg \
        libgcc \
        linux-headers \
        make \
        python \
    # gpg keys listed at https://github.com/nodejs/node#release-keys
    && for key in \
      94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
      FD3A5288F042B6850C66B31F09FE44734EB7990E \
      71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
      DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
      C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
      B9AE9905FFD7803F25714661B63B535A4C206CA9 \
      77984A986EBC2AA786BC0F66B01FBB92821C587A \
      8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
      4ED778F539E3634C779C87C6D7062848A1AB005C \
      A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
      B9E2F5981AA6E0CD28160D9FF13993A75599653C \
    ; do \
      gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
      gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
      gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
    done \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.xz" \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
    && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
    && grep " node-v$NODE_VERSION.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
    && tar -xf "node-v$NODE_VERSION.tar.xz" \
    && cd "node-v$NODE_VERSION" \
    && ./configure \
    && make -j$(getconf _NPROCESSORS_ONLN) V= \
    && make install \
    && apk del .build-deps-full \
    && cd .. \
    && rm -Rf "node-v$NODE_VERSION" \
    && rm "node-v$NODE_VERSION.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt; \
  fi \
  && rm -f "node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" \
  # smoke tests
  && node --version \
  && npm --version

# ## ======================== golang ==================================
from core_java_maven_nodejs as core_java_maven_nodejs_golang

ARG GOLANG_VERSION=1.14.3

# set up nsswitch.conf for Go's "netgo" implementation
# - https://github.com/golang/go/blob/go1.9.1/src/net/conf.go#L194-L275
# - docker run --rm debian:stretch grep '^hosts:' /etc/nsswitch.conf
RUN [ ! -e /etc/nsswitch.conf ] && echo 'hosts: files dns' > /etc/nsswitch.conf

RUN export \
# set GOROOT_BOOTSTRAP such that we can actually build Go
		GOROOT_BOOTSTRAP="$(go env GOROOT)" \
# ... and set "cross-building" related vars to the installed system's values so that we create a build targeting the proper arch
# (for example, if our build host is GOARCH=amd64, but our build env/image is GOARCH=386, our build needs GOARCH=386)
		GOOS="$(go env GOOS)" \
		GOARCH="$(go env GOARCH)" \
		GOHOSTOS="$(go env GOHOSTOS)" \
		GOHOSTARCH="$(go env GOHOSTARCH)" \
	; \
# also explicitly set GO386 and GOARM if appropriate
# https://github.com/docker-library/golang/issues/184
	apkArch="$(apk --print-arch)"; \
	case "$apkArch" in \
		armhf) export GOARM='6' ;; \
		armv7) export GOARM='7' ;; \
		x86) export GO386='387' ;; \
	esac; \
	\
	wget -O go.tgz "https://golang.org/dl/go$GOLANG_VERSION.src.tar.gz"; \
	echo '93023778d4d1797b7bc6a53e86c3a9b150c923953225f8a48a2d5fabc971af56 *go.tgz' | sha256sum -c -; \
	tar -C /usr/local -xzf go.tgz; \
	rm go.tgz; \
	\
	cd /usr/local/go/src; \
	./make.bash; \
	\
	rm -rf \
# https://github.com/golang/go/blob/0b30cf534a03618162d3015c8705dd2231e34703/src/cmd/dist/buildtool.go#L121-L125
		/usr/local/go/pkg/bootstrap \
# https://golang.org/cl/82095
# https://github.com/golang/build/blob/e3fe1605c30f6a3fd136b561569933312ede8782/cmd/release/releaselet.go#L56
		/usr/local/go/pkg/obj \
	; \
	# apk del .build-deps; \
	\
	export PATH="/usr/local/go/bin:$PATH"; \
	go version

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
WORKDIR $GOPATH

## ================ awscliv2 ========================= 
# install glibc compatibility for alpine
from core_java_maven_nodejs_golang as core_java_maven_nodejs_golang_awscliv2

ARG GLIBC_VER=2.31-r0

RUN curl -sL https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub -o /etc/apk/keys/sgerrand.rsa.pub \
    && curl -sLO https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VER}/glibc-${GLIBC_VER}.apk \
    && curl -sLO https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VER}/glibc-bin-${GLIBC_VER}.apk \
    && apk add --no-cache \
        glibc-${GLIBC_VER}.apk \
        glibc-bin-${GLIBC_VER}.apk \
    && curl -sL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip \
    && unzip awscliv2.zip \
    && aws/install \
    && rm -rf \
        awscliv2.zip \
        aws \
        /usr/local/aws-cli/v2/*/dist/aws_completer \
        /usr/local/aws-cli/v2/*/dist/awscli/data/ac.index \
        /usr/local/aws-cli/v2/*/dist/awscli/examples \
    && rm glibc-${GLIBC_VER}.apk \
    && rm glibc-bin-${GLIBC_VER}.apk \
    && rm -rf /var/cache/apk/*

RUN aws --version


#### clean up
RUN rm -rf /var/lib/apt/lists/* /tmp
RUN apk del .build-deps