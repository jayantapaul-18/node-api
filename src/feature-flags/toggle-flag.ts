import { type Request, type Response, type NextFunction } from "express";
import log from "../logger/winston-logger";
import { type QueryResult } from "pg";
import PGDB from "../DB/postgres-db";
import * as joi from "joi";

// Define a validation schema using Joi
const inputSchema = joi.object({
  name: joi.string().required(),
  enabled: joi.boolean().required(),
  environment: joi.string().required(),
  userName: joi.string().required(),
});

/* toggleFlag */
const toggleFlag = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  const { error } = inputSchema.validate(req.body);
  if (error != null) {
    res.status(400).json({ error: error.details[0].message });
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
    const { name, enabled, environment, userName } = req.body;
    const lastToogle = new Date();
    const updatedAt = new Date();
    // const user_name = req.body.user_name
    const color = "blue";
    // eslint-disable-next-line @typescript-eslint/restrict-template-expressions
    const children = `${name} flag set as  ${enabled} by user ${userName} AT ${updatedAt}`;
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
          userName,
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
      data.userName,
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
