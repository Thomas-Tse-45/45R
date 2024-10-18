const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

// Middleware to parse incoming JSON data
app.use(express.json());

// Route to handle Telegram webhook POST requests
app.post('/webhook', (req, res) => {
  console.log('Received Telegram message:', req.body);
  // Process the Telegram message here (e.g., extract Product ID, etc.)
  res.status(200).send('Webhook received');
});

// Start the server
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
