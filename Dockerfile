FROM alpine:3.13 as build

ENV VERNEMQ_VERSION="1.12.5"

RUN \
  apk add \
    git \
    alpine-sdk \
    erlang-dev \
    snappy-dev \
    bsd-compat-headers \
    openssl-dev \
    tzdata

RUN git clone --depth 1 --branch ${VERNEMQ_VERSION} \
      https://github.com/vernemq/vernemq.git \
      /usr/src/vernemq

RUN cd /usr/src/vernemq && \
    make rel && \
    mv _build/default/rel/vernemq /vernemq && \
    chown -R 10000:10000 /vernemq

COPY --chown=10000:10000 files/vm.args /vernemq/etc/vm.args

FROM alpine:3.12

RUN apk --no-cache --update --available upgrade && \
    apk add --no-cache ncurses-libs openssl libstdc++ jq curl bash snappy-dev && \
    addgroup --gid 10000 vernemq && \
    adduser --uid 10000 -H -D -G vernemq -h /vernemq vernemq && \
    install -d -o vernemq -g vernemq /vernemq

# Defaults
ENV DOCKER_VERNEMQ_KUBERNETES_LABEL_SELECTOR="app=vernemq" \
    DOCKER_VERNEMQ_LOG__CONSOLE=console \
    PATH="/vernemq/bin:$PATH"

WORKDIR /vernemq

COPY --chown=10000:10000 bin/vernemq.sh /usr/sbin/start_vernemq
COPY --chown=10000:10000 --from=build /vernemq /vernemq

COPY --chown=10000:10000 files/mysql.lua /vernemq/share/lua/auth/mysql.lua

RUN ln -s /vernemq/etc /etc/vernemq && \
    ln -s /vernemq/data /var/lib/vernemq && \
    ln -s /vernemq/log /var/log/vernemq

# Ports
# 1883  MQTT
# 8883  MQTT/SSL
# 8080  MQTT WebSockets
# 44053 VerneMQ Message Distribution
# 4369  EPMD - Erlang Port Mapper Daemon
# 8888  Prometheus Metrics
# 9100 9101 9102 9103 9104 9105 9106 9107 9108 9109  Specific Distributed Erlang Port Range

EXPOSE 1883 8883 8080 44053 4369 8888 \
       9100 9101 9102 9103 9104 9105 9106 9107 9108 9109


VOLUME ["/vernemq/log", "/vernemq/data", "/vernemq/etc"]

HEALTHCHECK CMD vernemq ping | grep -q pong

USER vernemq
CMD ["start_vernemq"]
