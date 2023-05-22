/** src/index.ts */
// process.env['NODE_TLS_REJECT_UNAUTHORIZED'] = 0;
import http from "http";
import express, { type Express } from "express";
import { type Request, type Response, type NextFunction } from "express";
import type { ErrorRequestHandler } from "express";
import { HttpException } from "./error/HttpException";
import morgan from "morgan";
import helmet from "helmet";
import config from "./config";
import routes from "./routes/api";
import feature from "./routes/feature-api";
import logger from "./logger/winston-logger";
const dev = process.env.NODE_ENV !== "production";
const { PORT, ROOT_URL } = config;

const app: Express = express();

const errorHandler: ErrorRequestHandler = (
  err: any,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  // Error handling middleware functionality
  console.log(`err ${err.message}`); // log the error
  const status = err.status || 400;
  // send back an easily understandable error message to the caller
  res.status(status).send(err.message);
};

/** Logging */
app.use(morgan("dev"));
/** Parse the request */
app.use(express.urlencoded({ extended: false }));
/** Takes care of JSON data */
app.use(express.json());
app.use(helmet());
// app.use(errorHandler);

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

// Middleware to check if the feature flag is enabled
app.use((req, res, next) => {
  const enableNewFeature = process.env.ENABLE_NEW_FEATURE === "true";
  logger.info(`feature flag - ENABLE_NEW_FEATURE = ${enableNewFeature}`);
  // Check if the feature flag is enabled
  if (enableNewFeature) {
    // The feature is enabled, allow access to the new feature
    /** Feature API Routes */
    app.use("/", feature);
    next();
  } else {
    // The feature is disabled, return a 404 error
    res
      .status(404)
      .send({
        featureName: "ENABLE_NEW_FEATURE",
        status: enableNewFeature,
        message: "Feature not available",
      });
  }
});

/** Routes */
app.use("/", routes);

/** Error handling */
app.use((err: unknown, req: Request, res: Response, next: NextFunction) => {
  if (err instanceof HttpException) {
    // Do something more with the error here...
    logger.error("Error occurred *");
  }
  next(err);
});
app.use((req: Request, res: Response, next: NextFunction) => {
  const err = new HttpException(404, "Not Found");
  // Do something with error here...
  next(err);
});

/** API Server */
const httpServer = http.createServer(app);
httpServer.listen(PORT, (): void => {
  console.log(`The server is running on port ${PORT}`);
  console.log(`> Ready on ${ROOT_URL}`);
  logger.info(`The server is running on port ${PORT}`);
});

export default app;
