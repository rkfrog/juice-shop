# Base image from 
ARG REGISTRY_URL DOCKER_REPO_NAME

# Base image from 
FROM ${REGISTRY_URL}/${DOCKER_REPO_NAME}/node:20-buster as installer

COPY . /juice-shop
WORKDIR /juice-shop

RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm i -g typescript ts-node
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm ci --omit=dev
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm dedupe --omit=dev
RUN rm -rf frontend/node_modules
RUN rm -rf frontend/.angular
RUN rm -rf frontend/src/assets
RUN mkdir logs
RUN chown -R 65532 logs
RUN chgrp -R 0 ftp/ frontend/dist/ logs/ data/ i18n/
RUN chmod -R g=u ftp/ frontend/dist/ logs/ data/ i18n/
RUN rm data/chatbot/botDefaultTrainingData.json || true
RUN rm ftp/legal.md || true
RUN rm i18n/*.json || true

# workaround for libxmljs startup error
FROM ${REGISTRY_URL}/${DOCKER_REPO_NAME}/node:20-buster as libxmljs-builder
WORKDIR /juice-shop
RUN apt-get update && apt-get install -y build-essential python3
COPY --from=installer /juice-shop/node_modules ./node_modules
RUN rm -rf node_modules/libxmljs/build && \
  cd node_modules/libxmljs && \
  npm run build

FROM gcr.io/distroless/nodejs20-debian11
WORKDIR /juice-shop
COPY --from=installer --chown=65532:0 /juice-shop .
COPY --chown=65532:0 --from=libxmljs-builder /juice-shop/node_modules/libxmljs ./node_modules/libxmljs
USER 65532
EXPOSE 3000
CMD ["/juice-shop/build/app.js"]