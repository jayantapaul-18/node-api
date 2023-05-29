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
    // const lastToogle = new Date();
    const createdAt = new Date();

    const client = await PGDB.pool.connect();
    try {
      client.query(
        "INSERT INTO flags (name, enabled,project,environment,description,createdAt) VALUES ($1, $2, $3, $4, $5, $6)",
        [name, enabled, project, environment, description, createdAt],
        (err: any, results: any): void => {
          if (err) {
            if (err.message === "Client has already been connected") {
              console.log(
                "Client is already connected. Skipping connection step."
              );
              res.status(500).send(err);
            } else {
              console.error("Error inserting data:", err);
              res.status(500).send(err);
            }
            client.release();
            console.error("throw error :", err);
            throw err;
          }
          // return response
          client.release();
          res.status(201).send(results);
        }
      );
    } catch (error) {
      client.release();
      console.error("Error --- :", error);
      res.status(500).send(error);
    }
  }
};

export default {
  createFlag,
};
