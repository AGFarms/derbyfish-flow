# Use Python 3.11 slim image as base
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (required for the TypeScript CLI)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

# Copy package.json and install Node.js dependencies
COPY package.json ./
RUN npm install

# Copy TypeScript source and build
COPY src/typescript/ ./src/typescript/
COPY tsconfig.json ./
RUN npm run build

# Copy Python requirements and install
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY src/python/ ./src/python/
COPY flow/ ./flow/
COPY migrations/ ./migrations/

# Copy the mainnet-agfarms private key file
COPY flow/mainnet-agfarms.pkey ./flow/mainnet-agfarms.pkey

# Create necessary directories
RUN mkdir -p flow/accounts/pkeys

# Set environment variables
ENV PYTHONPATH=/app/src/python
ENV FLASK_APP=src/python/app.py
ENV FLASK_ENV=production

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Run the application
CMD ["python", "src/python/app.py"]
