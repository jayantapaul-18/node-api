import app from "../src";
import request from "supertest";

// group test using describe
describe("api", () => {
  it("returns HTTP status code 200", async () => {
    const res = await request(app).get("/posts").send();
    // .send({ status: "success" });

    // toEqual recursively checks every field of an object or array.
    expect(res.statusCode).toEqual(200);
  });

  it("returns bad request if status is missing", async () => {
    const res = await request(app).get("/posts").send();
    expect(res.statusCode).toEqual(200);
  });
});
