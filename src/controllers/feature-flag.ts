import { type Request, type Response, type NextFunction } from "express";
import axios, { type AxiosResponse } from "axios";
import dotenv from "dotenv";

// Load environment variables from .env file
dotenv.config();

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
