# Multi-stage build to avoid npm issues
FROM node:24.4.1-alpine as builder

WORKDIR /build
COPY package*.json ./
RUN npm install --only=prod --legacy-peer-deps || true

FROM node:24.4.1-alpine

WORKDIR /app
COPY --from=builder /build/node_modules ./node_modules
COPY . .

ENV NODE_ENV=production
EXPOSE 3000
CMD ["npm", "start"]
