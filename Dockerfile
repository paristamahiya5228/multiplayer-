# Production Dockerfile for Multiplayer Server & Static Host
FROM node:20-alpine

WORKDIR /app

# Install dependencies first for efficient layer caching
COPY package.json ./
RUN npm install --omit=dev

# Copy application files
COPY server/ ./server/
COPY client/ ./client/
COPY demo/ ./demo/

# Expose port (can be overridden by $PORT at runtime)
EXPOSE 3000

ENV PORT=3000
ENV NODE_ENV=production

# Non-root user for security
USER node

CMD ["node", "server/server.js"]
