const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

// Middleware to parse incoming JSON data
app.use(express.json());

app.post('/webhook', (req, res) => {
  const message = req.body.message;  // Extract the message payload from Telegram
  
  if (message && message.text) {
    const chatId = message.chat.id;   // Extract the chat ID for responding
    const text = message.text;        // Extract the text of the message

    // Look for the Product ID in the message after the colon
    const regex = /Track your order with this link:\s*(\d+)/;  // Regex to extract the Product ID
    const match = text.match(regex);  // Apply the regex to the message text

    if (match && match[1]) {
      const productId = match[1];     // Extracted Product ID
      console.log('Extracted Product ID:', productId);
      
      // You can add code here to send a response back to the user if needed
      // For example:
      // sendMessageToTelegram(chatId, `We have received your order. Product ID: ${productId}`);

      res.status(200).send('Webhook received and processed');  // Respond to Telegram
    } else {
      console.log('No Product ID found in the message');
      res.status(200).send('No Product ID found');
    }
  } else {
    res.status(200).send('No valid message received');
  }
});


// Start the server
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
