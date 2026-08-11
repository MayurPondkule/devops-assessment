const test = require("node:test");
const assert = require("node:assert/strict");
const http = require("node:http");

process.env.DB_HOST = "localhost";
process.env.DB_USER = "test";
process.env.DB_PASSWORD = "test";
process.env.DB_NAME = "test";
process.env.JWT_SECRET = "test-secret";
process.env.DEMO_OTP = "123456";

const { app } = require("../server");

function request(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const server = app.listen(0, () => {
      const { port } = server.address();

      const data = body
        ? JSON.stringify(body)
        : null;

      const req = http.request(
        {
          host: "127.0.0.1",
          port,
          path,
          method,

          headers: data
            ? {
                "Content-Type": "application/json",
                "Content-Length": Buffer.byteLength(data),
              }
            : {},
        },

        (res) => {
          let response = "";

          res.on("data", (chunk) => {
            response += chunk;
          });

          res.on("end", () => {
            server.close();

            let parsedBody = null;

            try {
              parsedBody = response
                ? JSON.parse(response)
                : null;
            } catch {
              parsedBody = response;
            }

            resolve({
              status: res.statusCode,
              body: parsedBody,
            });
          });
        }
      );

      req.on("error", reject);

      if (data) {
        req.write(data);
      }

      req.end();
    });
  });
}


test("health endpoint returns 200", async () => {
  const result = await request(
    "GET",
    "/health"
  );

  assert.equal(result.status, 200);

  assert.equal(
    result.body.status,
    "ok"
  );
});


test("unknown route returns 404", async () => {
  const result = await request(
    "GET",
    "/does-not-exist"
  );

  assert.equal(result.status, 404);

  assert.equal(
    result.body.error,
    "route not found"
  );
});


test("invalid ping payload returns 400", async () => {
  const result = await request(
    "POST",
    "/api/fleet/ping",
    {
      vehicleId: "",
      lat: 100,
      lng: 200
    }
  );

  assert.equal(result.status, 400);

  assert.equal(
    result.body.error,
    "invalid request"
  );
});


test("admin endpoint requires authentication", async () => {
  const result = await request(
    "GET",
    "/api/admin/drivers"
  );

  assert.equal(result.status, 401);
});


test("login rejects invalid OTP", async () => {
  const result = await request(
    "POST",
    "/api/auth/login",
    {
      phone: "9999999999",
      otp: "000000"
    }
  );

  assert.equal(result.status, 401);
});