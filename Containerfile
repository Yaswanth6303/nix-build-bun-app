FROM oven/bun:1 AS base

WORKDIR /usr/src/app

COPY package.json bun.lock ./

RUN bun install --frozen-lockfile

COPY src ./src

EXPOSE 3000

CMD ["bun", "run", "src/index.ts"]
