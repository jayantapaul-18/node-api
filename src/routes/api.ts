/** src/routes/api.ts */
import express from "express";
import controller from "../controllers/api";
import featureFlag from "../controllers/feature-flag";

const router = express.Router();

router.get("/", controller.defaultGet);
router.get("/health", controller.getHealth);
router.get("/posts", controller.getPosts);
router.get("/posts/:id", controller.getPost);
router.put("/posts/:id", controller.updatePost);
router.delete("/posts/:id", controller.deletePost);
router.post("/posts", controller.addPost);
router.post("/feature-flag", featureFlag.featureAPI);

export default router;
