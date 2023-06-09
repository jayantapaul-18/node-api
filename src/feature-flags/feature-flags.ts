import { type Request, type Response, type NextFunction } from "express";
import axios, { type AxiosResponse } from "axios";
import dotenv from "dotenv";
import * as fs from "fs";
import * as path from "path";
import moment from "moment";
import log from "../logger/winston-logger";
import PGDB from "../DB/postgres-db";
moment.utc().format();
// Load environment variables from .env file
dotenv.config();

/**
In this example, we define the FeatureFlag interface to represent each feature flag object,
which has a name and enabled property. The allFeatureFlags array holds all the available feature flags.
**/
export interface FeatureFlag {
  /** Unique feature name */
  name: string;
  /** feature flag `true` / `false` */
  enabled: boolean;
  project: string;
  createdAt?: string | null;
  updatedAt?: string | null;
  environment?: string | null;
  description?: string | null;
  lastToogle?: any | null;
}
// A feature flag named "show-feature" that is disabled by default.
// A feature flag enabled true / false that is defined the flag toggle value.
// project defined the project name
const datTime = new Date();
const environment = "prod";

export const featureFlags: FeatureFlag[] = [
  {
    name: "new-feature",
    enabled: true,
    project: "api",
    environment,
    description: "new api",
    lastToogle: datTime,
  },
  {
    name: "show-feature",
    enabled: false,
    project: "demo",
    environment,
    description: "demo project",
    lastToogle: datTime,
  },
  {
    name: "hide-feature",
    enabled: false,
    project: "dark",
    environment,
    description: "dark project",
    lastToogle: datTime,
  },
  {
    name: "security-feature",
    enabled: true,
    project: "dark",
    environment,
    description: "dark project",
    lastToogle: datTime,
  },
  {
    name: "cicd-feature",
    enabled: true,
    project: "dark",
    environment,
    description: "dark project",
    lastToogle: datTime,
  },
  {
    name: "monitoring-feature",
    enabled: true,
    project: "api",
    environment,
    description: "api for auth",
    lastToogle: datTime,
  },
  {
    name: "monitoring-feature",
    enabled: true,
    project: "server",
    environment: "local",
    description: "node server",
    lastToogle: datTime,
  },
  // Add more feature flags as needed
];

/* isFeatureEnabled takes flagName = string and return all the flag by name */
const isFeatureEnabled = (flagName: string): boolean => {
  const featureFlag = featureFlags.find((flag) => flag.name === flagName);
  return featureFlag != null ? featureFlag.enabled : false;
};
/* showAllFeatureByFlag takes flagEnable = true / false boolean and return all the flag by vaules */
const showAllFeatureByFlag = (flagEnable: boolean): any => {
  const featureFlag = featureFlags.filter(
    (flag) => flag.enabled === flagEnable
  );
  return featureFlag;
};
/* showAllFeatureByProject takes projectName string and return all the flag by matched project name */
const showAllFeatureByProject = (projectName: string): any => {
  const featureFlag = featureFlags.filter(
    (flag) => flag.project === projectName
  );
  return featureFlag;
};

const writeFlagsToFile = (data: any): any => {
  fs.writeFile("./FEATURE_CONFIG.json", JSON.stringify(data), (err) => {
    if (err != null) {
      console.log(err);
    } else {
      console.log("Local File written successfully");
    }
  });
};

// const data = JSON.parse(fs.readFileSync('data.json'));

// allallFeatureFlags post
const getFeature = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  // Check if the request body is undefined or null
  if (req.body.featureEnable === undefined || req.body.featureEnable === null) {
    res.status(400).json({ error: "Request body is undefined or null" });
  } else {
    const featureEnable: boolean = req.body.featureEnable;
    const showFeaturebyFlag = showAllFeatureByFlag(featureEnable);
    console.log("Show all the feature' enabled?", showFeaturebyFlag);
    writeFlagsToFile(showFeaturebyFlag);

    const featureByProject: string = req.body.featureByProject;
    const getFeatureByProject = showAllFeatureByProject(featureByProject);
    console.log("Show all the feature' by project name", getFeatureByProject);

    const response: AxiosResponse = await axios.post(
      "http://localhost:3009/health",
      {
        featureEnable,
      }
    );
    const configData = fs.readFileSync("./FEATURE_CONFIG.json", {
      encoding: "utf8",
      flag: "r",
    });
    console.log("From Local File: ", configData);
    // return response
    res.status(200).json({
      message: showFeaturebyFlag,
      getFeatureByProject,
    });
  }
};
("");

export default {
  getFeature,
};
