FROM node:18-slim AS builder

# Install dependencies required for Prisma and build
RUN apt-get update && \
    apt-get install -y openssl libssl-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install pnpm
RUN npm install -g pnpm

WORKDIR /app

# Copy package files and prisma schema first
COPY package.json pnpm-lock.yaml ./
COPY prisma ./prisma/

# Install dependencies and generate Prisma Client
RUN pnpm install --frozen-lockfile && \
    pnpm add -D prisma && \
    pnpm prisma generate

# Copy the rest of the application
COPY . .

# Build the application
RUN pnpm run build

# Production stage
FROM node:18-slim AS runner

WORKDIR /app

# Install production dependencies
RUN apt-get update && \
    apt-get install -y openssl libssl-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    npm install -g pnpm

# Copy necessary files from builder
COPY --from=builder /app/next.config.js ./
COPY --from=builder /app/package.json ./
COPY --from=builder /app/pnpm-lock.yaml ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/node_modules ./node_modules

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

EXPOSE 3000

CMD ["node", "server.js"]