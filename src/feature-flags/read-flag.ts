import { type Request, type Response, type NextFunction } from "express";
import log from "../logger/winston-logger";
import { type QueryResult } from "pg";
import PGDB from "../DB/postgres-db";
import * as joi from "joi";

// Define a validation schema using Joi
const inputSchema = joi.object({
  name: joi.string().required(),
  environment: joi.string().required(),
  userName: joi.string().required(),
});

/* readFlag */
const readFlag = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  const { error } = inputSchema.validate(req.body);
  if (error != null) {
    res.status(400).json({ error: error.details[0].message });
  } else {
    const { name, environment, userName } = req.body;
    let dataObject;
    // eslint-disable-next-line prefer-const
    dataObject = { name, environment };
    console.log("dataObject:", dataObject);

    readData(dataObject)
      .then((featureFlags) => {
        console.log("Feature flag data:", featureFlags);
        res.status(200).send(featureFlags);
      })
      .catch((error: any) => {
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
    const insertQuery =
      "SELECT * FROM flags WHERE name = $1 AND environment= $2";
    const insertValues = [data.name, data.environment];
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
