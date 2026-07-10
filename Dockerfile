FROM node:24.4.1-alpine

WORKDIR /app

# Copy everything including pre-installed node_modules
COPY . .

ENV NODE_ENV=production

EXPOSE 3000

CMD ["npm", "start"]
