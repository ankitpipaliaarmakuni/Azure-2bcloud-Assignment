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
app.use(helmet());
app.use(morgan('combined'));
app.use(cors());
app.use(compression());
app.use(express.json());

// Global memory store to gradually increase memory usage
let memoryStore = [];

// Root endpoint
app.get('/', (req, res) => {
    logger.info('Root endpoint accessed');
    res.send('Hello from Node.js Application!');
});

// Health check endpoint
app.get('/health', (req, res) => {
    const memUsage = process.memoryUsage();
    logger.info('Health check performed');
    res.status(200).json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        memory: {
            heapUsed: `${Math.round(memUsage.heapUsed / 1024 / 1024)}MB`,
            heapTotal: `${Math.round(memUsage.heapTotal / 1024 / 1024)}MB`
        }
    });
});

// Stress test endpoint - gradual memory consumption
app.get('/stress', (req, res) => {
    logger.info('Stress test initiated');
    
    const startTime = Date.now();
    let result = 0;
    
    // Gradually allocate memory in smaller chunks (10MB chunks instead of 100MB at once)
    // This gives HPA time to react before OOMKill
    const chunkSize = 1e6; // 1MB chunks
    const chunks = 10; // Total 10MB per request
    
    for (let i = 0; i < chunks; i++) {
        memoryStore.push(new Array(chunkSize).fill(`stress-${Date.now()}`));
    }
    
    // CPU-intensive operation (reduced from 5s to 3s to avoid liveness probe failures)
    const endTime = startTime + 3000;
    while (Date.now() < endTime) {
        result += Math.random() * Math.random();
        // Small delay to prevent blocking event loop completely
        if (result % 1000000 === 0) {
            setImmediate(() => {});
        }
    }
    
    const memUsage = process.memoryUsage();
    
    res.status(200).json({
        message: 'Stress test completed',
        duration: `${Date.now() - startTime}ms`,
        memoryUsed: `${Math.round(memUsage.heapUsed / 1024 / 1024)}MB`,
        totalMemoryStored: `${Math.round(memoryStore.length * chunkSize * 8 / 1024 / 1024)}MB`,
        result: Math.round(result)
    });
});

// Endpoint to clear memory store
app.get('/clear', (req, res) => {
    const before = process.memoryUsage().heapUsed;
    memoryStore = [];
    global.gc && global.gc(); // Manual GC if --expose-gc flag is set
    const after = process.memoryUsage().heapUsed;
    
    res.status(200).json({
        message: 'Memory cleared',
        freed: `${Math.round((before - after) / 1024 / 1024)}MB`
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

const server = app.listen(PORT, () => {
    logger.info(`Server is running on port ${PORT}`);
});

// Graceful shutdown with proper cleanup
process.on('SIGTERM', () => {
    logger.info('SIGTERM received. Performing graceful shutdown...');
    server.close(() => {
        logger.info('HTTP server closed');
        memoryStore = []; // Clear memory
        process.exit(0);
    });
    
    // Force shutdown after 30 seconds
    setTimeout(() => {
        logger.error('Forced shutdown after timeout');
        process.exit(1);
    }, 30000);
});

module.exports = app;