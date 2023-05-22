/** src/routes/api.ts */
import express from "express";
import featureFlag from "../controllers/feature-flag";

const feature = express.Router();

feature.post("/feature-flag", featureFlag.featureAPI);

export default feature;
