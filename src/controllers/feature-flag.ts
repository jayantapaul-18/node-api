import { type Request, type Response, type NextFunction } from "express";
import axios, { type AxiosResponse } from "axios";
import dotenv from "dotenv";

// Load environment variables from .env file
dotenv.config();

/**
In this example, we define the FeatureFlag interface to represent each feature flag object,
which has a name and enabled property. The featureFlags array holds all the available feature flags.
 * */
export interface FeatureFlag {
  name: string;
  enabled: boolean;
}
// A feature flag named "show-feature" that is disabled by default.
// A feature flag named "hide-feature" that is enabled by default.
export const featureFlags: FeatureFlag[] = [
  { name: "new-feature", enabled: true },
  { name: "show-feature", enabled: false },
  { name: "hide-feature", enabled: false },
  // Add more feature flags as needed
];

// featureAPI post
const featureAPI = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  const title: string = req.body.title;
  const body: string = req.body.body;
  // Adding Feature Flag
  const enableNewFeature = process.env.ENABLE_NEW_FEATURE === "true";
  // add the post
  const response: AxiosResponse = await axios.post(
    "https://jsonplaceholder.typicode.com/posts",
    {
      title,
      body,
    }
  );
  // return response
  res.status(200).json({
    message: response.data,
  });
};

export default {
  featureAPI,
};
