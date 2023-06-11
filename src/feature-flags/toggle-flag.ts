import { type Request, type Response, type NextFunction } from "express";
import axios, { type AxiosResponse } from "axios";
import log from "../logger/winston-logger";
import {
  types,
  Client,
  type ClientConfig,
  type QueryResult,
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
    const user_name = req.body.user_name;
    const color = "blue";
    const children = `${name} flag set as  ${enabled} by user ${user_name} AT ${updatedAt}`;
    const dot = "";
    const client = await PGDB.pool.connect();
    client.query(
      "UPDATE flags SET name = $1, enabled =$2 , lastToogle = $3 , updatedAt = $4 , description = $5 WHERE name = $1",
      [name, enabled, lastToogle, updatedAt, children],
      (err, results): void => {
        if (err) {
          if (err.message === "Client has already been connected") {
            console.log(
              "Client is already connected. Skipping connection step."
            );
            log.error("Client is already connected. Skipping connection step.");
            // Insert your data insertion logic here
          } else {
            console.error("Error updating data:", err);
            log.error("Error updating data:", err);
          }
          client.release();
          throw err;
        }
        // return response
        client.release();
        const data = {
          name: name,
          enabled: enabled,
          user_name: user_name,
          color: color,
          children: children,
          dot: dot,
          environment: environment,
          auditdate: updatedAt,
        };
        console.log(data);
        feature_audit_write(data);
        res.status(200).send(results);
      }
    );
  }
};

async function feature_audit_write(data: any): Promise<any[]> {
  const clientAudit = await PGDB.poolAudit.connect();
  try {
    const insertQuery =
      "INSERT INTO flag_audit (name, enabled,user_name, color,children ,dot, environment,auditdate) VALUES ($1, $2, $3, $4, $5, $6 , $7, $8)";
    const insertValues = [
      data.name,
      data.enabled,
      data.user_name,
      data.color,
      data.children,
      data.dot,
      data.environment,
      data.auditdate,
    ];
    const results: QueryResult = await clientAudit.query(
      insertQuery,
      insertValues
    );
    console.log("Audit insert successfully!");
    clientAudit.release();
    return results.rows;
  } catch (error: any) {
    console.error("Error inserting feature flag audit data:", error);
    log.error("Error inserting feature flag audit data:", error);
    clientAudit.release();
    throw error;
  }
}
export default {
  toggleFlag,
};
