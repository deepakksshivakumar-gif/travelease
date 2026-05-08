const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const hotelRoutes = require('./routes/hotels');

const app = express();
const PORT = process.env.PORT || 3003;

app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());

app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy', 
    service: 'hotel-service',
    timestamp: new Date().toISOString()
  });
});

app.use('/api/hotels', hotelRoutes);

app.listen(PORT, () => console.log(`Hotel service running on port ${PORT}`));
module.exports = app;
