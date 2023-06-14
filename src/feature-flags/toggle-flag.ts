import { type Request, type Response, type NextFunction } from "express";
import log from "../logger/winston-logger";
import { type QueryResult } from "pg";

import PGDB from "../DB/postgres-db";
import * as joi from "joi";

/* toggleFlag */
const toggleFlag = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  const schema = joi.object({
    enabled: joi.boolean().required(),
  });
  try {
    const { value } = schema.validate({ enabled: req.body.enabled });
    console.log("validate_value: ", value);
  } catch (err) {
    res.status(400).json({ error: err });
  }
  // Check if the request body is undefined or null
  if (req.body.enabled === undefined || req.body.enabled === null) {
    console.log(req.body);
    res.status(400).json({ error: "Request body is undefined or null" });
  }
  if (req.body.name === undefined || req.body.name === null) {
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
    try {
      const query =
        "UPDATE flags SET name = $1, enabled =$2 , lastToogle = $3 , updatedAt = $4 , description = $5 WHERE name = $1";
      const values = [name, enabled, lastToogle, updatedAt, children];
      // (err, results): void => {
      const result: QueryResult = await client.query(query, values);
      // eslint-disable-next-line @typescript-eslint/strict-boolean-expressions
      if (result) {
        console.log("RESULT: ", result.rowCount);
        // return success response
        client.release();
        const data = {
          name,
          enabled,
          user_name,
          color,
          children,
          dot,
          environment,
          auditdate: updatedAt,
        };
        console.log(data);
        feature_audit_write(data);
        res.status(200).send({ message: "feature toggle successfull", data });
      }
    } catch (err: any) {
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
      }
      if (err.code === "23502") {
        console.log("Error #23502 - null value in column");
        log.error("Error #23502 - null value in column");
        res.status(400).send({ message: "null value in column" });
      } else {
        console.error(`Error:" ${err}`);
        res.status(500).send({ message: "Internal server error" });
      }
      // if (err) {
      //   if (err.message === 'Client has already been connected') {
      //     console.log(
      //       'Client is already connected. Skipping connection step.'
      //     )
      //     log.error('Client is already connected. Skipping connection step.')
      //     res.status(500).send({ message: 'feature toggle failed', error: err })
      //     // Insert your data insertion logic here
      //   } if (err.code === '23502') {
      //     console.log(
      //       'Client is already connected. Skipping connection step.'
      //     )
      //     res.status(500).send({ message: 'feature toggle failed', error: err })
      //   }
      //   else {
      //     console.error('Error updating data:', err)
      //     log.error('Error updating data:', err)
      //     res.status(500).send({ message: 'feature toggle failed', error: err })
      //   }
      //   client.release()
      //   res.status(500).send({ message: 'feature toggle failed', error: err })
      //   throw err
      // }
      // // return response
      // client.release()
      // const data = {
      //   name,
      //   enabled,
      //   user_name,
      //   color,
      //   children,
      //   dot,
      //   environment,
      //   auditdate: updatedAt
      // }
      // console.log(data)
      // feature_audit_write(data)
      // res.status(200).send({message: 'feature toggle successfull', data: data})
    }
  }
};

// eslint-disable-next-line @typescript-eslint/naming-convention
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
