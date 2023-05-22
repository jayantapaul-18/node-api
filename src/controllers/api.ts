/** src/controllers/api.ts */
import { type Request, type Response, type NextFunction } from "express";
import axios, { type AxiosResponse } from "axios";

interface Post {
  userId: number;
  id: number;
  title: string;
  body: string;
}

// defaultGet
const defaultGet = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  res.status(200).json({
    status: "success",
  });
};
// getHealth
const getHealth = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  res.status(200).json({
    status: "success",
  });
};

// getting all posts
const getPosts = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  // get some posts
  const result: AxiosResponse = await axios.get(
    "https://jsonplaceholder.typicode.com/posts"
  );
  const posts: [Post] = result.data;
  res.status(200).json({
    message: posts,
  });
};

// getting a single post
const getPost = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  // get the post id from the req
  const id: string = req.params.id;
  // get the post
  const result: AxiosResponse = await axios.get(
    `https://jsonplaceholder.typicode.com/posts/${id}`
  );
  const post: Post = result.data;
  res.status(200).json({
    message: post,
  });
};

// updating a post
const updatePost = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  const id: string = req.params.id;
  const title: string = req.body.title ?? null;
  const body: string = req.body.body ?? null;
  // update the post
  const response: AxiosResponse = await axios.put(
    `https://jsonplaceholder.typicode.com/posts/${id}`,
    {
      ...(title && { title }),
      ...(body && { body }),
    }
  );
  // return response
  res.status(200).json({
    message: response.data,
  });
};

// deleting a post
const deletePost = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  // get the post id from req.params
  const id: string = req.params.id;
  // delete the post
  const response: AxiosResponse = await axios.delete(
    `https://jsonplaceholder.typicode.com/posts/${id}`
  );
  // return response
  res.status(200).json({
    message: response,
  });
};

// adding a post
const addPost = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  const title: string = req.body.title;
  const body: string = req.body.body;
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
  defaultGet,
  getHealth,
  getPosts,
  getPost,
  updatePost,
  deletePost,
  addPost,
};
