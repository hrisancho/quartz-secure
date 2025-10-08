# Этап сборки сайта
FROM node:lts-slim AS builder
WORKDIR /app
COPY package*.json ./
RUN npm cache clean --force && npm install
COPY quartz.config.ts quartz.layout.ts ./
COPY content ./content
COPY quartz ./quartz
ENV NODE_OPTIONS="--experimental-specifier-resolution=node --experimental-modules"
RUN node ./quartz/bootstrap-cli.mjs build

# Финальный этап для приложения
FROM node:lts-slim
WORKDIR /app

# Устанавливаем gosu и curl для healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends gosu curl && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/public ./public
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY quartz.config.ts quartz.layout.ts ./
COPY quartz ./quartz
COPY content ./content

# Даем права пользователю 'node'
RUN chown -R node:node /app

EXPOSE 8080

ENV NODE_OPTIONS="--experimental-specifier-resolution=node --experimental-modules"
ENV NODE_ENV=production

# Запускаем приложение через gosu от имени пользователя 'node'
CMD ["gosu", "node", "./quartz/bootstrap-cli.mjs", "build", "--serve", "--port", "8080"]