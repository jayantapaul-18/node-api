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

/* toggleFlag */
const toggleFlag = async (
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
    const lastToogle = new Date();
    const updatedAt = new Date();

    const client = await PGDB.pool.connect();
    client.query(
      "UPDATE flags SET name = $1, enabled =$2 , lastToogle = $3 , updatedAt = $4 WHERE name = $1",
      [name, enabled, lastToogle, updatedAt],
      (err, results): void => {
        if (err) {
          if (err.message === "Client has already been connected") {
            console.log(
              "Client is already connected. Skipping connection step."
            );
            // Insert your data insertion logic here
          } else {
            console.error("Error updating data:", err);
          }
          client.release();
          throw err;
        }
        // return response
        client.release();
        res.status(200).send(results);
      }
    );
  }
};

export default {
  toggleFlag,
};
