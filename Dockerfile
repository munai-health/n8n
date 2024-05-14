ARG NODE_VERSION=18

# 1. Create an image to build n8n
FROM --platform=linux/amd64 n8nio/base:${NODE_VERSION} as builder

# Build the application from source
WORKDIR /src
COPY . /src
RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store --mount=type=cache,id=pnpm-metadata,target=/root/.cache/pnpm/metadata pnpm install --frozen-lockfile
RUN pnpm build

# Delete all dev dependencies
RUN jq 'del(.pnpm.patchedDependencies)' package.json > package.json.tmp; mv package.json.tmp package.json
RUN node scripts/trim-fe-packageJson.js

# Delete any source code, source-mapping, or typings
RUN find . -type f -name "*.ts" -o -name "*.js.map" -o -name "*.vue" -o -name "tsconfig.json" -o -name "*.tsbuildinfo" | xargs rm -rf

# Deploy the `n8n` package into /compiled
RUN mkdir /compiled
RUN NODE_ENV=production pnpm --filter=n8n --prod --no-optional deploy /compiled

# 2. Start with a new clean image with just the code that is needed to run n8n
FROM n8nio/base:${NODE_VERSION}
ENV NODE_ENV=production

ARG N8N_RELEASE_TYPE=dev
ENV N8N_RELEASE_TYPE=${N8N_RELEASE_TYPE}

WORKDIR /home/node
COPY --from=builder /compiled /usr/local/lib/node_modules/n8n
COPY docker/images/n8n/docker-entrypoint.sh /

RUN \
    pnpm rebuild --dir /usr/local/lib/node_modules/n8n sqlite3 && \
    ln -s /usr/local/lib/node_modules/n8n/bin/n8n /usr/local/bin/n8n && \
    mkdir .n8n && \
    chown node:node .n8n

RUN apk add --no-cache libaio wget unzip

RUN apk add --no-cache wget unzip libaio libnsl libc6-compat && \
    mkdir -p /opt/oracle && \
    wget https://download.oracle.com/otn_software/linux/instantclient/instantclient-basiclite-linuxx64.zip -O /opt/oracle/instantclient-basiclite-linuxx64.zip && \
    unzip /opt/oracle/instantclient-basiclite-linuxx64.zip -d /opt/oracle/ && \
    rm -f /opt/oracle/instantclient-basiclite-linuxx64.zip && \
    rm -f /opt/oracle/instantclient*/jdbc* /opt/oracle/instantclient*/occi* /opt/oracle/instantclient*/mysql* /opt/oracle/instantclient*/mql1* /opt/oracle/instantclient*/ipc1* /opt/oracle/instantclient*/*.jar /opt/oracle/instantclient*/uidrvci /opt/oracle/instantclient*/genezi /opt/oracle/instantclient*/adrci

RUN find /opt/oracle/instantclient* -type d -exec chmod 755 {} \; && \
    find /opt/oracle/instantclient* -type f -exec chmod 644 {} \; && \
    chown -R node:node /opt/oracle

# Configurar a variável de ambiente LD_LIBRARY_PATH diretamente, sem criar links simbólicos ou usar ldconfig
ENV LD_LIBRARY_PATH=/opt/oracle/instantclient_21_13

ENV SHELL /bin/sh
USER node
ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]
