import { type Request, type Response, type NextFunction } from "express";
import axios, { type AxiosResponse } from "axios";
import {
  types,
  Client,
  type ClientConfig,
  CustomTypesConfig,
  QueryArrayConfig,
  Pool,
  DatabaseError,
} from "pg";
import PGDB from "../DB/postgres-db";
/* createFlag */
const createFlag = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  // Check if the request body is undefined or null
  if (req.body.enabled === undefined || req.body.enabled === null) {
    console.log(req.body);
    res.status(400).json({ error: "Request body is undefined or null" });
  } else {
    console.log("name: ", req.body.name);
    const name: string = req.body.name;
    const enabled: boolean = req.body.enabled;
    const project: string = req.body.project;
    const environment: string = req.body.environment;
    const description: string = req.body.description;

    const client = await PGDB.pool.connect();
    client.query(
      "INSERT INTO flags (name, enabled,project,environment,description) VALUES ($1, $2, $3, $4, $5)",
      [name, enabled, project, environment, description],
      (err, results): void => {
        if (err) {
          if (err.message === "Client has already been connected") {
            console.log(
              "Client is already connected. Skipping connection step."
            );
            // Insert your data insertion logic here
          } else {
            console.error("Error inserting data:", err);
          }
          client.release();
          throw err;
        }
        // return response
        client.release();
        res.status(201).send(results);
      }
    );
  }
};

export default {
  createFlag,
};
