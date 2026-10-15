# Production Dockerfile for Academic Portfolio Web Application
FROM node:20-alpine AS base

# Set working directory
WORKDIR /app

# Ensure security: Don't run as root in production
# Alpine node image comes with built-in unprivileged user 'node'
RUN chown -R node:node /app

# Copy dependency configuration and source files
COPY --chown=node:node package.json ./
COPY --chown=node:node src/ ./src/
COPY --chown=node:node test/ ./test/

# Run automated tests during image build to enforce quality gate
RUN node --test test/app.test.js

# Switch to non-root user
USER node

# Expose application port
EXPOSE 3000

# Set environment defaults
ENV PORT=3000 \
    NODE_ENV=production

# Healthcheck for container runtimes
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://127.0.0.1:3000/health || exit 1

# Start the application
CMD ["node", "src/server.js"]
