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

/* readFlag */
const readFlag = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  // Check if the request body is undefined or null
  if (req.body.name === undefined || req.body.name === null) {
    console.log(req.body);
    res.status(400).json({ error: "Request body is undefined or null" });
  } else {
    console.log("name: ", req.body.name);
    const name: string = req.body.name;
    const enabled: boolean = req.body.enabled;
    const project: string = req.body.project;
    const environment: string = req.body.environment;
    let dataObject;
    if (req.body.enabled != undefined || req.body.enabled != null) {
      dataObject = { enabled, name };
      console.log("dataObject:", dataObject);
    } else {
      dataObject = { name };
      console.log("dataObject:", dataObject);
    }

    readData(dataObject)
      .then((featureFlags) => {
        console.log("Feature flag data:", featureFlags);
        res.status(200).send(featureFlags);
        // Process the feature flag data as needed
      })
      .catch((error) => {
        console.error("Error:", error);
        log.error("Error:", error);
        res.status(500).json({
          message: `${error}`,
        });
      });
  }
};

// Create a function to handle the database connection and insertion
async function readData(data: any): Promise<any[]> {
  const client = await PGDB.pool.connect();
  try {
    // Connect to the database
    // await client.connect()
    const insertQuery = "SELECT * FROM flags WHERE name = $1 AND enabled= $2";
    const insertValues = [data.name, data.enabled];
    const results: QueryResult = await client.query(insertQuery, insertValues);
    console.log("Data fetch successfully!");
    // Release the client connection
    client.release();
    // Return the feature flag data
    return results.rows;
  } catch (error: any) {
    console.error("Error retrieving feature flag data:", error);
    log.error("Error retrieving feature flag data:", error);
    client.release();
    throw error;
  }
}

export default {
  readFlag,
};
