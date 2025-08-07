# vim:set ft=dockerfile:
# docker build -t yzkj/freeswitch:1.10.12 .
ARG DEBIAN_VERSION=bookworm
FROM debian:${DEBIAN_VERSION}

# ARGs are cleared after every FROM
# see: https://docs.docker.com/engine/reference/builder/#understand-how-arg-and-from-interact
ARG DEBIAN_VERSION

# explicitly set user/group IDs
ARG FREESWITCH_UID=499
ARG FREESWITCH_GID=499
RUN groupadd -r freeswitch --gid=${FREESWITCH_GID} && useradd -r -g freeswitch --uid=${FREESWITCH_UID} freeswitch

# make the "en_US.UTF-8" locale so freeswitch will be utf-8 enabled by default
RUN sed -i 's|http://deb.debian.org/debian|http://mirrors.aliyun.com/debian|g' /etc/apt/sources.list.d/debian.sources && \
    apt-get update -qq \
    && apt-get install -y --no-install-recommends git lsb-release uuid-dev libtiff-dev libspeex-dev libpcre3-dev ca-certificates gnupg2 gosu locales wget \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# 安装依赖
RUN apt-get install -y \
        libldns-dev \
        build-essential \
        libavformat-dev \
        libswscale-dev \
        libsndfile-dev \
        autoconf \
        automake \
        libtool \
        cmake \
        git \
        wget \
        curl \
        libssl-dev \
        libedit-dev \
        libncurses5-dev \
        libspeexdsp-dev \
        libopus-dev \
        libsqlite3-dev \
        libpq-dev \
        libcurl4 \
        libcurl4-openssl-dev \
        liblua5.2-dev \
        yasm \
        libjpeg-dev \
        pkg-config \
        python3 

## 测试cmake 版本信息
RUN cmake --version

# https://freeswitch.org/confluence/display/FREESWITCH/Debian
# https://developer.signalwire.com/freeswitch/FreeSWITCH-Explained/Installation/Linux/Debian_67240088/

# RUN wget --no-verbose --http-user=signalwire --http-password=${TOKEN} \
#       -O /usr/share/keyrings/signalwire-freeswitch-repo.gpg \
#       https://freeswitch.signalwire.com/repo/deb/debian-release/signalwire-freeswitch-repo.gpg \
#     && echo "machine freeswitch.signalwire.com login signalwire password ${TOKEN}" > /etc/apt/auth.conf \
#     && echo "deb [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ ${DEBIAN_VERSION} main" > /etc/apt/sources.list.d/freeswitch.list \
#     && apt-get -qq update \
#     && apt-get install -y ${FS_META_PACKAGE} \
#     && apt-get purge -y --auto-remove \
#     && apt-get clean && rm -rf /var/lib/apt/lists/*


# COPY libks-2.0.6.tar.gz /usr/local/src
WORKDIR /usr/local/src

# 从git目录下载
RUN git clone https://github.com/signalwire/libks.git libks && \
    cd libks && \
    cmake . && \
    make && \
    make install && \
    cd .. && \
    rm -rf libks

# RUN tar -xzf libks-2.0.6.tar.gz && \
#     cd libks-2.0.6 && \
#     cmake . && \
#     make && \
#     make install && \
#     cd .. && \
#     rm -rf libks-2.0.6.tar.gz

# COPY spandsp /usr/local/src/
# RUN cd spandsp && \
#     cmake . && \
#     make install && \
#     cd .. && \
#     rm -rf spandsp
RUN git clone https://github.com/freeswitch/spandsp.git spandsp && \
    cd spandsp && \
    ## 解决一个v18_init two few arguments的错误
    git checkout 0d2e6ac && \
    sh autogen.sh && \
    ./bootstrap.sh && \
    ./configure && \
    make install && \
    cd .. && \
    rm -rf spandsp

COPY package/sofia-sip-1.13.17.tar.gz /usr/local/src
# RUN git clone https://github.com/freeswitch/sofia-sip.git sofia-sip && \
#     cd sofia-sip && \
#     ./bootstrap.sh && \
#     ./configure && \
#     make && \
#     make install && \
#     cd .. && \
#     rm -rf sofia-sip

RUN tar -xzf sofia-sip-1.13.17.tar.gz && \
    cd sofia-sip-1.13.17 && \
    ./bootstrap.sh && \
    ./configure && \
    make && \
    make install && \
    cd .. && \
    rm -rf sofia-sip-1.13.17

    # 克隆 signalwire-client-c2 (推荐较新的版本)
# 注意：请检查 SignalWire/FreeSWITCH 官方文档，以获取最新的仓库URL和构建说明
# RUN git clone https://github.com/signalwire/signalwire-c.git signalwire-c && \
# cd signalwire-c && \
# cmake . && \
# make && \
# make install && \
# cd .. && \
# rm -rf signalwire-c 
COPY package/signalwire-c-2.0.0.tar.gz /usr/local/src
WORKDIR /usr/local/src
RUN  tar -xzf signalwire-c-2.0.0.tar.gz signalwire-c-2.0.0 && \
cd signalwire-c-2.0.0 && \
cmake . && \
make && \
make install && \
cd .. && \
rm -rf signalwire-c-2.0.0
# 可选，安装后移除源码

COPY package/freeswitch-1.10.12.-release.tar.gz /usr/local/src
WORKDIR /usr/local/src
RUN tar -xzf freeswitch-1.10.12.-release.tar.gz && \
    cd freeswitch-1.10.12.-release && \
    ./rebootstrap.sh -j && \
    ./configure && \
    make && \
    make install && \
    # make install-sounds && \
    # make install-lang-sounds && \
    # make hd-sounds-install && \
    cd .. && \
    rm -rf freeswitch-1.10.12.-release.tar.gz

WORKDIR /usr/local/src
RUN mkdir -p /usr/share/freeswitch/conf/vanilla && \
    cp -R freeswitch-1.10.12.-release/conf/vanilla/* /usr/share/freeswitch/conf/vanilla/ && \
    mkdir -p /etc/freeswitch && \
    chown -R freeswitch:freeswitch /etc/freeswitch && \
    chmod -R 770 /etc/freeswitch

RUN mkdir -p /var/run/freeswitch && \
    chown -R freeswitch:freeswitch /var/run/freeswitch && \
    mkdir -p /var/lib/freeswitch && \
    chown -R freeswitch:freeswitch /var/lib/freeswitch && \
    chown -R freeswitch:freeswitch /usr/local/freeswitch/log && \
    chown -R freeswitch:freeswitch /usr/local/freeswitch/conf && \
    chown -R freeswitch:freeswitch /usr/local/freeswitch/db

RUN mkdir -p /usr/local/freeswitch/storage && \
    chown -R freeswitch:freeswitch /usr/local/freeswitch/storage && \
    chmod -R 770 /usr/local/freeswitch/storage

# 创建软链接
RUN ln -s /usr/local/freeswitch/bin/freeswitch /usr/bin/freeswitch && \
    ln -s /usr/local/freeswitch/bin/fs_cli /usr/bin/fs_cli

RUN chmod +x /usr/local/freeswitch/bin/freeswitch

    # 清理构建依赖和源码
RUN apt-get remove -y \
    build-essential \
    autoconf \
    automake \
    libtool \
    git \
    wget \
    curl \
    cmake \
    pkg-config \
    yasm \
    libedit-dev \
    libopus-dev \
    python3 \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /usr/local/src/* \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/local/freeswitch/run && chown -R freeswitch:freeswitch /usr/local/freeswitch/run && chmod -R 770 /usr/local/freeswitch/run

COPY docker-entrypoint.sh /
# Add anything else here

## Ports
# Document ports used by this container
### 8021 fs_cli, 5060 5061 5080 5081 sip and sips, 5066 ws, 7443 wss, 8081 8082 verto, 16384-32768, 64535-65535 rtp
EXPOSE 8021/tcp
EXPOSE 5060/tcp 5060/udp 5080/tcp 5080/udp
EXPOSE 5061/tcp 5061/udp 5081/tcp 5081/udp
EXPOSE 5066/tcp
EXPOSE 7443/tcp
EXPOSE 8081/tcp 8082/tcp
EXPOSE 64535-65535/udp
EXPOSE 16384-32768/udp

# Volumes
## Freeswitch Configuration
VOLUME ["/etc/freeswitch"]
## Tmp so we can get core dumps out
VOLUME ["/tmp"]

# Limits Configuration
COPY    build/freeswitch.limits.conf /etc/security/limits.d/

# Healthcheck to make sure the service is running
SHELL       ["/bin/bash", "-c"]
HEALTHCHECK --interval=15s --timeout=5s \
    CMD  fs_cli -x status | grep -q ^UP || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
# 切换到 freeswitch 用户运行
# USER freeswitch
CMD ["freeswitch"]
