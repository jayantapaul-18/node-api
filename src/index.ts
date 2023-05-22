/** src/index.ts */
// process.env['NODE_TLS_REJECT_UNAUTHORIZED'] = 0;
import http from "http";
import express, { type Express } from "express";
// import { query, validationResult } from 'express-validator'
import morgan from "morgan";
import helmet from "helmet";
// import config from './config';
import routes from "./routes/api";
const env = process.env.NODE_ENV;
const dev = process.env.NODE_ENV !== "production";
const PORT = process.env.PORT ?? 3009;
const ROOT_URL = dev ? `http://localhost:${PORT}` : "https://gen.com";

const app: Express = express();

/** Logging */
app.use(morgan("dev"));
/** Parse the request */
app.use(express.urlencoded({ extended: false }));
/** Takes care of JSON data */
app.use(express.json());
app.use(helmet());

/** API Middelware */
app.use((req, res, next) => {
  res.set({
    "Cache-Control": "no-store, no-cache, must-revalidate, proxy-revalidate",
    Pragma: "no-cache",
    Expires: "0",
    "Surrogate-Control": "no-store",
  });
  // set the CORS policy
  res.header("Access-Control-Allow-Origin", "*");
  // set the CORS headers
  res.header(
    "Access-Control-Allow-Headers",
    "origin, X-Requested-With,Content-Type,Accept, Authorization"
  );
  // set the CORS method headers
  if (req.method === "OPTIONS") {
    res.header("Access-Control-Allow-Methods", "GET PATCH DELETE POST");
    return res.status(200).json({});
  }
  next();
});

/** Routes */
app.use("/", routes);

/** Error handling */
app.use((req, res, next) => {
  const error = new Error("not found");
  return res.status(404).json({
    message: error.message,
  });
});

// app.get('/', query('tls').notEmpty(), (req, res) => {
//     const result = validationResult(req);
//     if (result.isEmpty()) {
//         return res.send(`Hello, ${req.query.tls}!`);
//     }
//     res.send({ errors: result.array() });
// });

/** API Server */
const httpServer = http.createServer(app);
httpServer.listen(PORT, (): void => {
  console.log(`The server is running on port ${PORT}`);
  console.log(`> Ready on ${ROOT_URL}`);
});

export default app;
