import app from "../src";
import request from "supertest";

// group test using describe
describe("get", () => {
  it("/ (GET)", () => {
    return request(app).get("/").expect(200);
  });

  it("returns HTTP status code 200", async () => {
    const res = await request(app).get("/health").send();
    // .send({ status: "success" });

    // toEqual recursively checks every field of an object or array.
    expect(res.statusCode).toEqual(200);
  });

  it("returns bad request if status is missing", async () => {
    const res = await request(app).get("/health").send();
    expect(res.statusCode).toEqual(200);
  });
});
