const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// --- STANDARD MIDDLEWARE ---

// Enable Cross-Origin Resource Sharing (CORS) for API access
app.use(cors());

// Parse incoming JSON payloads (Built-in Express middleware)
app.use(express.json());

// Parse URL-encoded bodies (useful for form submissions)
app.use(express.urlencoded({ extended: true }));

// --- PLACEHOLDER FOR ENDPOINTS ---

// Example: app.get('/api/tasks', ...)

// --- SERVER INITIALIZATION ---

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT} (2025 Standard)`);
});
