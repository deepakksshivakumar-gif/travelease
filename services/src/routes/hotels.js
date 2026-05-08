const express = require('express');
const router = express.Router();

const hotels = [
  { id: 'h001', name: 'Taj Palace', city: 'DEL', stars: 5, pricePerNight: 12000, rooms: 5, amenities: ['pool', 'spa', 'gym'] },
  { id: 'h002', name: 'OYO Rooms BLR', city: 'BLR', stars: 2, pricePerNight: 1200, rooms: 20, amenities: ['wifi', 'ac'] },
  { id: 'h003', name: 'Marriott Mumbai', city: 'MUM', stars: 5, pricePerNight: 15000, rooms: 3, amenities: ['pool', 'spa', 'restaurant'] },
  { id: 'h004', name: 'Ibis Bengaluru', city: 'BLR', stars: 3, pricePerNight: 4500, rooms: 15, amenities: ['wifi', 'restaurant', 'gym'] },
  { id: 'h005', name: 'Lemon Tree Delhi', city: 'DEL', stars: 3, pricePerNight: 5500, rooms: 8, amenities: ['wifi', 'pool', 'ac'] },
];

router.get('/search', (req, res) => {
  const { city, stars, maxPrice } = req.query;
  
  let results = hotels;
  if (city)     results = results.filter(h => h.city === city.toUpperCase());
  if (stars)    results = results.filter(h => h.stars >= parseInt(stars));
  if (maxPrice) results = results.filter(h => h.pricePerNight <= parseInt(maxPrice));

  res.json({ count: results.length, hotels: results });
});

router.get('/:id', (req, res) => {
  const hotel = hotels.find(h => h.id === req.params.id);
  if (!hotel) return res.status(404).json({ error: 'Hotel not found' });
  res.json(hotel);
});

module.exports = router;
