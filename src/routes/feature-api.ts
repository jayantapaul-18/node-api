/** src/routes/api.ts */
import express from "express";
// import featureAPI, { featureFlags } from "../controllers/feature-flag";
import getFeature from "../feature-flags/feature-flags";
import createFlag from "../feature-flags/create-flag";
import readFlag from "../feature-flags/read-flag";
import readFlagByQuery from "../feature-flags/get-feature-flag";
import toggleFlag from "../feature-flags/toggle-flag";

const feature = express.Router();

// Get the value of the feature flag.
// const isFeatureEnabled = featureFlags.find(f => f.name === "show-feature").enabled;

/*
The isFeatureEnabled function takes a flagName parameter and checks if there is a feature flag with a matching name.
If found, it returns the enabled value of that flag.
If the flag is not found, it returns false by default.

*/
// const isFeatureEnabled = (flagName: string): boolean => {
//   const featureFlag = featureFlags.find((flag) => flag.name === flagName);
//   return featureFlag != null ? featureFlag.enabled : false;
// };

// Example usage:
// const showFeatureEnabled = isFeatureEnabled("show-feature");
// console.log("Is 'show-feature' enabled?", showFeatureEnabled);

/*
 You can add as many feature flags as needed to the featureFlags array. To check if a specific feature is enabled, simply call isFeatureEnabled and pass the desired feature flag name as an argument.
 The function will return a boolean indicating whether the feature is enabled or not.
 */
// const newFeatureEnabled = isFeatureEnabled("new-feature");
// console.log("Is 'new-feature' enabled?", newFeatureEnabled);

// Use the value of the feature flag to control whether or not to show the feature.
// if (newFeatureEnabled) {
//   // Show the feature.
// } else {
//   // Hide the feature.
// }

feature.post("/feature-flags", getFeature.getFeature);
// feature.post("/feature-api", featureAPI.featureAPI);

/* Connected to PG DB  */
feature.post("/app/v1/create-feature-flag", createFlag.createFlag);
/* Connected to PG DB  */
feature.post("/app/v1/read-feature-flag", readFlag.readFlag);
/* Connected to PG DB  */
feature.get("/app/v1/read-feature-flag", readFlagByQuery.readFlagByQuery);
/* Connected to PG DB  */
feature.post("/app/v1/toggle-feature-flag", toggleFlag.toggleFlag);

export default feature;
