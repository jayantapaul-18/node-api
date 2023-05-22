import { type Request, type Response, type NextFunction } from "express";
import axios, { type AxiosResponse } from "axios";
import dotenv from "dotenv";

// Load environment variables from .env file
dotenv.config();

/**
In this example, we define the FeatureFlag interface to represent each feature flag object,
which has a name and enabled property. The featureFlags array holds all the available feature flags.
**/
export interface FeatureFlag {
  /** Unique feature name */
  name: string;
  /** feature flag `true` / `false` */
  enabled: boolean;
  project: string;
  createdAt?: string | null;
}
// A feature flag named "show-feature" that is disabled by default.
// A feature flag named "hide-feature" that is enabled by default.
export const featureFlags: FeatureFlag[] = [
  { name: "new-feature", enabled: true, project: "api" },
  { name: "show-feature", enabled: false, project: "demo" },
  { name: "hide-feature", enabled: false, project: "dark" },
  // Add more feature flags as needed
];
