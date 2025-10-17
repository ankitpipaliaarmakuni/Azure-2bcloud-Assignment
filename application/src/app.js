const express = require('express');
const helmet = require('helmet');
const morgan = require('morgan');
const winston = require('winston');
const cors = require('cors');
const compression = require('compression');

// Initialize logger
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
    ),
    transports: [
        new winston.transports.Console(),
        new winston.transports.File({ filename: 'error.log', level: 'error' }),
        new winston.transports.File({ filename: 'combined.log' })
    ]
});

const app = express();

// Middleware
app.use(helmet()); // Security headers
app.use(morgan('combined')); // HTTP request logging
app.use(cors()); // Enable CORS
app.use(compression()); // Compress responses
app.use(express.json()); // Parse JSON bodies

// Root endpoint
app.get('/', (req, res) => {
    logger.info('Root endpoint accessed');
    res.send('Hello from Node.js Application!');
});

// Health check endpoint
app.get('/health', (req, res) => {
    logger.info('Health check performed');
    res.status(200).json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// Stress test endpoint
app.get('/stress', (req, res) => {
    logger.info('Stress test initiated');
    
    // CPU-intensive operation
    const startTime = Date.now();
    let result = 0;
    
    // Allocate memory (about 100MB)
    const memoryHog = new Array(1e7).fill('x');
    
    // CPU-intensive loop for 5 seconds
    while (Date.now() - startTime < 5000) {
        result += Math.random() * Math.random();
    }
    
    res.status(200).json({
        message: 'Stress test completed',
        cpuTime: `${Date.now() - startTime}ms`,
        memoryUsed: `${Math.round(process.memoryUsage().heapUsed / 1024 / 1024)}MB`,
        result: result
    });
});

// Error handling middleware
app.use((err, req, res, next) => {
    logger.error('Error occurred:', err);
    res.status(500).json({
        error: 'Internal Server Error',
        message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong'
    });
});

const PORT = process.env.PORT || 80;

app.listen(PORT, () => {
    logger.info(`Server is running on port ${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    logger.info('SIGTERM received. Performing graceful shutdown...');
    // Close server, DB connections, etc.
    process.exit(0);
});

module.exports = app; // For testing purposes