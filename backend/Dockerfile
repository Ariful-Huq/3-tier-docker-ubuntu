# Use Node.js 18 Alpine for smaller image size
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm install --production

# Copy source code
COPY src/ ./src/

# Expose backend port
EXPOSE 3000

# Start the application
CMD ["node", "src/server.js"]
