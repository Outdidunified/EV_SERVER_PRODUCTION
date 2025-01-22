const express = require('express');
const app = express();
const http = require('http');
const dotenv = require('dotenv');
const logger = require('./logger');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

// Load environment variables from .env file
dotenv.config();

// Routers
const SuperAdminRouter = require('./router/Super_Admin_Router.js');
const ResellerAdminRouter = require('./router/ReSeller_Admin_Router.js');
const ClientAdminRouter = require('./router/Client_Admin_Router.js');
const AssociationAdminRouter = require('./router/Association_Admin_Router.js');

// Middleware: Secure HTTP Headers with Helmet
app.use(helmet());

// Middleware: Enable CORS
app.use(cors());

// Middleware: JSON Parsing
app.use(express.json());

// Rate Limiting to avoid DoS attacks
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // Limit each IP to 100 requests per windowMs
    message: 'Too many requests from this IP, please try again later.',
});
app.use(limiter);

// Logger Middleware
app.use((req, res, next) => {
    console.log(`${req.method} request for '${req.url}'`);
    next();
});

// Routers
app.use('/superadmin', SuperAdminRouter);
app.use('/reselleradmin', ResellerAdminRouter);
app.use('/clientadmin', ClientAdminRouter);
app.use('/associationadmin', AssociationAdminRouter);

// Error Handling Middleware to prevent leaking stack traces
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ message: 'An error occurred, please try again later.' });
});

// Create an HTTP server using Express app
const httpServer = http.createServer(app);

// Define HTTP server port
const HTTP_PORT = process.env.HTTP_PORT || 6778;

// Start the HTTP server
httpServer.listen(HTTP_PORT, () => {
    console.log(`HTTP Server listening on port ${HTTP_PORT}`);
    logger.info(`HTTP Server listening on port ${HTTP_PORT}`);
});
