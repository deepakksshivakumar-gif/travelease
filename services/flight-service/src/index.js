const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const flightRoutes = require('./routes/flights');

const app = express();
const PORT = process.env.PORT || 3002;

app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());

app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy', 
    service: 'flight-service',
    timestamp: new Date().toISOString()
  });
});

app.use('/api/flights', flightRoutes);

app.listen(PORT, () => console.log(`Flight service running on port ${PORT}`));
module.exports = app;
