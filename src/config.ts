import dotenv from "dotenv";
// Load environment variables from .env file
dotenv.config();

export default {
  PORT: process.env.PORT || 3009,
  LOG_LEVEL: process.env.LOG_LEVEL || "info",
  NODE_ENV: process.env.NODE_ENV,
  ROOT_URL: process.env.ROOT_URL || "http://localhost:3009",
  DB: process.env.DB,
};
