import {
  types,
  Client,
  type ClientConfig,
  CustomTypesConfig,
  QueryArrayConfig,
  Pool,
  DatabaseError,
} from "pg";
import dotenv from "dotenv";
// Load environment variables from .env file
dotenv.config();
/* CREATE DB Client Configuration */
const pool = new Pool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT),
  database: process.env.DB_DATABASE,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  keepAlive: true,
});

export default {
  pool,
};
