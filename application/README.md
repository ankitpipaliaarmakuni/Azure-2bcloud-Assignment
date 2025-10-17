# Node.js Express Application

A production-ready Node.js Express application designed for containerized deployment to Kubernetes.

## Features

- Express web server with health check endpoint
- Security middleware (helmet, cors)
- Logging with Winston and Morgan
- Compression for optimized responses
- Docker containerization

## Directory Structure

- `src/` - Application source code
  - `app.js` - Main application entry point
- `Dockerfile` - Container image definition
- `package.json` - Node.js dependencies and scripts

## Docker Build

```bash
docker build -t your-registry/node-docker-app:tag .
docker push your-registry/node-docker-app:tag
```

## Endpoints

- `GET /` - Root endpoint returning a simple greeting
- `GET /healthz` - Health check endpoint with memory and uptime metrics
- `GET /stress` - Endpoint to simulate CPU load for testing