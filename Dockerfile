# syntax=docker/dockerfile:1.7

FROM node:25-bookworm-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable && corepack install --global pnpm@11.17.0
WORKDIR /app

FROM base AS dependencies
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY scripts/install-hooks.mjs ./scripts/install-hooks.mjs
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    CI=true pnpm install --frozen-lockfile

FROM dependencies AS build
COPY . .
RUN pnpm build

FROM base AS production-dependencies
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --prod --frozen-lockfile --ignore-scripts

FROM base AS migrations
ENV NODE_ENV=production
COPY --from=dependencies /app/node_modules ./node_modules
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml drizzle.config.ts ./
COPY drizzle ./drizzle
COPY src ./src
USER node
CMD ["./node_modules/.bin/drizzle-kit", "migrate"]

FROM base AS development
ENV NODE_ENV=development
COPY --from=dependencies /app/node_modules ./node_modules
COPY . .
CMD ["pnpm", "dev"]

FROM node:25-bookworm-slim AS production
LABEL org.opencontainers.image.title="Express + PostgreSQL Boilerplate" \
      org.opencontainers.image.description="Production-ready Express 5 and TypeScript API boilerplate with PostgreSQL and Drizzle ORM" \
      org.opencontainers.image.url="https://github.com/mzubair481/express-boilerplate" \
      org.opencontainers.image.source="https://github.com/mzubair481/express-boilerplate" \
      org.opencontainers.image.documentation="https://github.com/mzubair481/express-boilerplate#readme" \
      org.opencontainers.image.version="2.0.0" \
      org.opencontainers.image.licenses="MIT"
ENV NODE_ENV=production
WORKDIR /app
COPY --from=production-dependencies --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
COPY --chown=node:node package.json ./
USER node
EXPOSE 4300
CMD ["node", "--enable-source-maps", "dist/bootstrap/server.js"]
