import { type Request, type Response, type NextFunction } from "express";
import axios, { type AxiosResponse } from "axios";
import log from "../logger/winston-logger";
import {
  types,
  Client,
  type QueryResult,
  type ClientConfig,
  CustomTypesConfig,
  QueryArrayConfig,
  Pool,
  DatabaseError,
} from "pg";
import PGDB from "../DB/postgres-db";

/* readFlagByQuery */
const readFlagByQuery = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    // Extract the query parameters from the request
    const { name, enabled, project, environment } = req.query;
    // Construct the WHERE clause based on the provided parameters
    const conditions: string[] = [];
    const values: any[] = [];

    if (name) {
      conditions.push("name = $1");
      values.push(name);
    }
    if (enabled) {
      conditions.push("enabled = $2");
      values.push(enabled);
    }
    if (project) {
      conditions.push("project = $3");
      values.push(project);
    }
    if (environment) {
      conditions.push("environment = $4");
      values.push(environment);
    }

    // Build the SQL query
    const query = `
      SELECT *
      FROM flags
      ${conditions.length > 0 ? "WHERE " + conditions.join(" AND ") : ""}
    `;

    // Connect to the database
    const client = await PGDB.pool.connect();
    // Execute the query with the provided values
    const result: QueryResult = await client.query(query, values);
    // Release the client connection
    client.release();
    // Return the query result
    res.status(200).json(result.rows);
  } catch (error) {
    // Handle any errors
    console.error("Error retrieving data:", error);
    log.error("Error retrieving data: ", error);
    res.status(500).send("Internal server error");
  }
};

export default {
  readFlagByQuery,
};
