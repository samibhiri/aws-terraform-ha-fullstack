const express = require("express");
const cors = require("cors");
const mysql = require("mysql2/promise");
const {
  SecretsManagerClient,
  GetSecretValueCommand,
} = require("@aws-sdk/client-secrets-manager");

const app = express();
app.use(cors());
app.use(express.json());

// The SDK authenticates with the IAM role of the instance: no key is stored here
const secrets = new SecretsManagerClient({ region: process.env.AWS_REGION });
let pool;

// Read the database credentials from Secrets Manager (generated and rotated by RDS)
async function createPool() {
  const result = await secrets.send(
    new GetSecretValueCommand({ SecretId: process.env.DB_SECRET_ARN })
  );
  const { username, password } = JSON.parse(result.SecretString);

  pool = mysql.createPool({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 3306),
    user: username,
    password: password,
    database: process.env.DB_NAME,
  });
}

// Run a query. If RDS has rotated the password, reload the secret once and retry.
async function query(sql, params) {
  try {
    return await pool.query(sql, params);
  } catch (err) {
    if (err.code !== "ER_ACCESS_DENIED_ERROR") throw err;
    console.log("Database credentials rejected, reloading the secret");
    await pool.end();
    await createPool();
    return pool.query(sql, params);
  }
}

async function initDb() {
  await query(`
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
  const [rows] = await query("SELECT * FROM messages ORDER BY id DESC");
  res.json(rows);
});

app.post("/api/messages", async (req, res) => {
  const { content } = req.body;
  if (!content) return res.status(400).json({ error: "content is required" });
  await query("INSERT INTO messages (content) VALUES (?)", [content]);
  res.status(201).json({ status: "created" });
});

const port = Number(process.env.PORT || 3000);

createPool()
  .then(initDb)
  .then(() => app.listen(port, () => console.log(`API listening on ${port}`)))
  .catch((err) => {
    console.error("Startup failed:", err);
    process.exit(1);
  });
