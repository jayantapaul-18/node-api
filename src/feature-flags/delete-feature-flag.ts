import { type Request, type Response, type NextFunction } from "express";
import log from "../logger/winston-logger";
import { type QueryResult } from "pg";
import PGDB from "../DB/postgres-db";
import Ajv, { type JSONSchemaType, type DefinedError } from "ajv";
const ajv = new Ajv();

interface DeleteReq {
  featureName: string;
  environment: string;
}

const schema: JSONSchemaType<DeleteReq> = {
  type: "object",
  properties: {
    featureName: { type: "string" },
    environment: { type: "string" },
  },
  required: ["featureName", "environment"],
  additionalProperties: false,
};

/* deleteFlag */
const deleteFlag = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  // validate is a type guard for DeleteReq - type is inferred from schema type
  const validate = ajv.compile(schema);
  if (validate(schema)) {
    console.log(schema);
    console.log(schema.featureName);
    console.log(schema.environment);
  } else {
    console.log(validate.errors);
  }
  // Check if the request body is undefined or null
  if (req.body.featureName === undefined || req.body.featureName === null) {
    console.log(req.body);
    res.status(400).json({ error: "Request body is undefined or null" });
  } else {
    const name: string = req.body.featureName;
    const environment: string = req.body.environment;
    const deleteTime = new Date();
    const client = await PGDB.pool.connect();

    try {
      const query = "DELETE FROM flags WHERE name = $1 AND environment = $2";
      const values = [name, environment];
      const result: QueryResult = await client.query(query, values);
      // eslint-disable-next-line @typescript-eslint/strict-boolean-expressions
      if (result) {
        console.log(
          `Row deleated successfully for feature-flag: ${name} at ${deleteTime}`
        );
        log.info(
          `Row deleated successfully for feature-flag: ${name} at ${deleteTime}`
        );
      }
      res.status(200).send(result.rows);
    } catch (err: any) {
      // If the insert fails, check if the error is a duplicate key violation
      if (err) {
        console.log(`Error: ${err}`);
        log.error(`Error: ${err}`);
        res.status(500).send({ message: err });
      } else {
        console.error(`Error: ${err}`);
        res.status(500).send({ message: "Internal server error" });
      }
    } finally {
      client.release(); // Release the client back to the pool
    }
  }
};

export default {
  deleteFlag,
};
