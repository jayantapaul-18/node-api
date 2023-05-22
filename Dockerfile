# Base image
FROM node:18-alpine3.17 as builder

# Create app directory
WORKDIR /app

# A wildcard is used to ensure both package.json AND package-lock.json are copied
COPY package*.json ./
# Install app dependencies
RUN npm install
# Bundle app source
COPY . .

# Creates a "dist" folder with the production build
RUN npm run build

FROM node:18-alpine3.17
WORKDIR /app
COPY --from=builder /app/ /app/
ENV NODE_ENV=production
EXPOSE 3009
# Start the server using the production build
CMD [ "node", "/app/build/src/index.js" ]