# syntax=docker/dockerfile:1

# Build imapfilter from source
FROM alpine:3.21.3 AS build

RUN apk add --no-cache \
    git \
    alpine-sdk \
    lua5.4 \
    lua5.4-dev \
    openssl \
    openssl-dev \
    pcre2 \
    pcre2-dev

# Pin to a tag/commit as desired
# Example: ARG IMAPFILTER_REF=v2.8.3
ARG IMAPFILTER_REF=master

RUN git clone https://github.com/lefcha/imapfilter.git /src \
    && cd /src \
    && git checkout "${IMAPFILTER_REF}"

# Makefile lives in src/, binary and Lua files are built there
WORKDIR /src/src

RUN make \
    INCDIRS=-I/usr/include/lua5.4 \
    LDFLAGS='-L/usr/lib/lua5.4' \
    LIBLUA=-llua \
    LUA_CFLAGS=-I/usr/include/lua5.4


# Minimal runtime image
FROM alpine:3.21.3 AS final

RUN apk add --no-cache \
    lua5.4 \
    openssl \
    pcre2 \
    ca-certificates

ENV PREFIX=/usr/local \
    BINDIR=/usr/local/bin \
    SHAREDIR=/usr/local/share/imapfilter

# Ensure target dirs exist
RUN mkdir -p "${BINDIR}" "${SHAREDIR}"

# Binary
COPY --from=build /src/src/imapfilter ${BINDIR}/imapfilter

# Lua modules (from the Makefile's LUA variable)
COPY --from=build /src/src/common.lua /src/src/set.lua /src/src/regex.lua \
                  /src/src/account.lua /src/src/mailbox.lua /src/src/message.lua \
                  /src/src/options.lua /src/src/auxiliary.lua \
                  ${SHAREDIR}/

RUN chmod 0755 ${BINDIR}/imapfilter \
    && chmod 0644 ${SHAREDIR}/*

# Non-root user
RUN addgroup -S imapfilter \
    && adduser -S \
        -h /home/imapfilter \
        -s /sbin/nologin \
        -G imapfilter \
        imapfilter

USER imapfilter:imapfilter
WORKDIR /home/imapfilter

ENTRYPOINT ["/usr/local/bin/imapfilter"]
CMD ["-c", "/config.lua"]
