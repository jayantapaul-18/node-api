import { type Request, type Response, type NextFunction } from "express";
import log from "../logger/winston-logger";
import { type QueryResult } from "pg";
import PGDB from "../DB/postgres-db";
import * as joi from "joi";

// Define a validation schema using Joi
const inputSchema = joi.object({
  name: joi.string().required(),
  enabled: joi.boolean().required(),
  project: joi.string().required(),
  environment: joi.string().required(),
  description: joi.string().required(),
  userName: joi.string().required(),
});

/* createFlag */
const createFlag = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  const { error } = inputSchema.validate(req.body);
  if (error != null) {
    res.status(400).json({ error: error.details[0].message });
  } else {
    const { name, enabled, project, environment, description, userName } =
      req.body;
    const createdAt = new Date();
    const client = await PGDB.pool.connect();

    try {
      const query =
        "INSERT INTO flags (name, enabled,project,environment,description,createdAt) VALUES ($1, $2, $3, $4, $5, $6)";
      const values = [
        name,
        enabled,
        project,
        environment,
        description,
        createdAt,
      ];
      const result: QueryResult = await client.query(query, values);
      // Check if the insert was successful
      if (result) {
        console.log(
          `Row inserted successfully for create-feature-flag: ${name}`
        );
        log.info(`Row inserted successfully for create-feature-flag: ${name}`);
      }
      res.status(201).send(result.rows);
    } catch (err: any) {
      // If the insert fails, check if the error is a duplicate key violation
      if (err.code === "23505") {
        console.log(
          "Error #23505 - duplicate key value violates unique constraint"
        );
        log.error(
          "Error #23505 - duplicate key value violates unique constraint"
        );
        res
          .status(409)
          .send({ message: "duplicate key value violates unique constraint" });
      } else {
        console.error(`Error:" ${err}`);
        res.status(500).send({ message: "Internal server error" });
      }
    } finally {
      client.release(); // Release the client back to the pool
    }
  }
};

export default {
  createFlag,
};
