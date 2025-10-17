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

// CPU-intensive stress test endpoint with minimal memory footprint
app.get('/stress', (req, res) => {
    logger.info('Stress test initiated');
    
    const startTime = Date.now();
    const duration = parseInt(req.query.duration) || 2000; // Default 2 seconds
    let result = 0;
    let iterations = 0;
    
    // CPU-intensive calculations without memory allocation
    // Using prime number calculation and mathematical operations
    const performCPUWork = () => {
        const endTime = startTime + duration;
        
        while (Date.now() < endTime) {
            // Prime number checking (CPU intensive)
            for (let i = 2; i < 10000; i++) {
                let isPrime = true;
                for (let j = 2; j <= Math.sqrt(i); j++) {
                    if (i % j === 0) {
                        isPrime = false;
                        break;
                    }
                }
                if (isPrime) result++;
            }
            
            // Additional CPU-intensive math operations
            for (let i = 0; i < 50000; i++) {
                result += Math.sqrt(i) * Math.sin(i) * Math.cos(i);
                result = result % 1000000; // Keep number manageable
            }
            
            iterations++;
            
            // Check if time is up
            if (Date.now() >= endTime) break;
        }
    };
    
    // Perform CPU work
    performCPUWork();
    
    const memUsage = process.memoryUsage();
    const cpuTime = Date.now() - startTime;
    
    res.status(200).json({
        message: 'Stress test completed',
        duration: `${cpuTime}ms`,
        iterations: iterations,
        cpuResult: Math.round(result),
        memoryUsed: `${Math.round(memUsage.heapUsed / 1024 / 1024)}MB`,
        timestamp: new Date().toISOString()
    });
});

// Light stress endpoint - non-blocking with setImmediate
app.get('/stress-light', async (req, res) => {
    logger.info('Light stress test initiated');
    
    const startTime = Date.now();
    const chunks = parseInt(req.query.chunks) || 5;
    let result = 0;
    let completedChunks = 0;
    
    // Function to perform work in chunks to avoid blocking event loop
    const performChunk = () => {
        return new Promise((resolve) => {
            setImmediate(() => {
                // CPU work for this chunk
                for (let i = 0; i < 100000; i++) {
                    result += Math.random() * Math.random();
                }
                completedChunks++;
                resolve();
            });
        });
    };
    
    // Execute chunks sequentially but non-blocking
    for (let i = 0; i < chunks; i++) {
        await performChunk();
    }
    
    const memUsage = process.memoryUsage();
    
    res.status(200).json({
        message: 'Light stress test completed',
        duration: `${Date.now() - startTime}ms`,
        chunks: completedChunks,
        cpuResult: Math.round(result),
        memoryUsed: `${Math.round(memUsage.heapUsed / 1024 / 1024)}MB`,
        timestamp: new Date().toISOString()
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

// Graceful shutdown
process.on('SIGTERM', () => {
    logger.info('SIGTERM received. Performing graceful shutdown...');
    server.close(() => {
        logger.info('HTTP server closed');
        process.exit(0);
    });
    
    // Force shutdown after 30 seconds
    setTimeout(() => {
        logger.error('Forced shutdown after timeout');
        process.exit(1);
    }, 30000);
});

process.on('SIGINT', () => {
    logger.info('SIGINT received. Performing graceful shutdown...');
    server.close(() => {
        logger.info('HTTP server closed');
        process.exit(0);
    });
});

module.exports = app;