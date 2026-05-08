const express = require('express');
const router = express.Router();

// Mock flight data - simulates real airline API response
const flights = [
  { id: 'f001', from: 'BLR', to: 'DEL', airline: 'IndiGo', price: 4500, duration: '2h 45m', date: '2025-06-15', seats: 45 },
  { id: 'f002', from: 'BLR', to: 'DEL', airline: 'Air India', price: 5200, duration: '2h 50m', date: '2025-06-15', seats: 12 },
  { id: 'f003', from: 'BLR', to: 'MUM', airline: 'SpiceJet', price: 3200, duration: '1h 45m', date: '2025-06-15', seats: 30 },
  { id: 'f004', from: 'DEL', to: 'BLR', airline: 'IndiGo', price: 4800, duration: '2h 50m', date: '2025-06-16', seats: 60 },
  { id: 'f005', from: 'MUM', to: 'DEL', airline: 'Vistara', price: 6100, duration: '2h 10m', date: '2025-06-16', seats: 8 },
];

// Search flights
router.get('/search', (req, res) => {
  const { from, to, date } = req.query;
  
  let results = flights;
  if (from) results = results.filter(f => f.from === from.toUpperCase());
  if (to)   results = results.filter(f => f.to === to.toUpperCase());
  if (date) results = results.filter(f => f.date === date);

  res.json({ 
    count: results.length,
    flights: results,
    searchedAt: new Date().toISOString()
  });
});

// Get single flight
router.get('/:id', (req, res) => {
  const flight = flights.find(f => f.id === req.params.id);
  if (!flight) return res.status(404).json({ error: 'Flight not found' });
  res.json(flight);
});

module.exports = router;
