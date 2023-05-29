import {
  types,
  Client,
  type ClientConfig,
  CustomTypesConfig,
  QueryArrayConfig,
  Pool,
  DatabaseError,
} from "pg";

/* CREATE DB Client Configuration */
const pool = new Pool({
  host: "localhost",
  port: 5433,
  database: "feature_flag",
  user: "postgres",
  password: "my_password",
  // application_name: 'feature_flag',
  keepAlive: true,
});
// /* WRITE TO DB */
// // eslint-disable-next-line @typescript-eslint/explicit-function-return-type
// async function writeFeatureFlag (featureFlag: {
//   name: string
//   enabled: boolean
// }) {
//   const connection = await pool.getConnection()

//   try {
//     const statement = `
//       INSERT INTO feature_flags (name, enabled)
//       VALUES ($1, $2)
//     `

//     await connection.query(statement, [featureFlag.name, featureFlag.enabled])
//   } finally {
//     await connection.release()
//   }
// }

// // eslint-disable-next-line @typescript-eslint/explicit-function-return-type
// async function writeToDB () {
//   const featureFlag = {
//     name: 'my_feature_flag',
//     enabled: true
//   }

//   await writeFeatureFlag(featureFlag)
// }

// writeToDB()

/* READ FROM DB */
// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
// async function readFeatureFlags () {
//   const connection = await pool.getConnection()

//   try {
//     const statement = `
//         SELECT name, enabled
//         FROM feature_flags
//       `

//     const results = await connection.query(statement)

//     return results.rows
//   } finally {
//     await connection.release()
//   }
// }

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
// async function readFromDB () {
//   const featureFlags = await readFeatureFlags()

//   for (const featureFlag of featureFlags) {
//     console.log(featureFlag.name, featureFlag.enabled)
//   }
// }

// readFromDB()

// const getFlags = (request, response) => {
//   pool.query('SELECT * FROM flag ORDER BY id ASC', (error, results) => {
//     if (error) {
//       throw error
//     }
//     response.status(200).json(results.rows)
//   })
// }

export default {
  pool,
};
