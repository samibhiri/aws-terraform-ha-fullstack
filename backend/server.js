const express = require("express");
const cors = require("cors");
const mysql = require("mysql2/promise");

const app = express();
app.use(cors());
app.use(express.json());

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
});

async function initDb() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS messages (
      id INT AUTO_INCREMENT PRIMARY KEY,
      content VARCHAR(255) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);
}

// Health check used by the ALB target group
app.get("/health", (req, res) => res.status(200).send("OK"));

app.get("/api/messages", async (req, res) => {
  const [rows] = await pool.query("SELECT * FROM messages ORDER BY id DESC");
  res.json(rows);
});

app.post("/api/messages", async (req, res) => {
  const { content } = req.body;
  if (!content) return res.status(400).json({ error: "content is required" });
  await pool.query("INSERT INTO messages (content) VALUES (?)", [content]);
  res.status(201).json({ status: "created" });
});

const port = Number(process.env.PORT || 3000);

initDb()
  .then(() => app.listen(port, () => console.log(`API listening on ${port}`)))
  .catch((err) => {
    console.error("Database initialisation failed:", err);
    process.exit(1);
  });