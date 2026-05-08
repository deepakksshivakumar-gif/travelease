const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const authRoutes = require('./routes/auth');

const app = express();
const PORT = process.env.PORT || 3001;

// Security middleware - helmet sets secure HTTP headers
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());

// Health check endpoint - Kubernetes needs this
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy', 
    service: 'auth-service',
    timestamp: new Date().toISOString()
  });
});

app.use('/api/auth', authRoutes);

app.listen(PORT, () => {
  console.log(`Auth service running on port ${PORT}`);
});

module.exports = app;
