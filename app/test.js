"use strict";

const http = require("http");

const BASE_URL = `http://localhost:${process.env.PORT || 3000}`;

const tests = [
  { path: "/", expected: 200, description: "Root endpoint returns 200" },
  { path: "/healthz", expected: 200, description: "Health check returns 200" },
  { path: "/readyz", expected: 200, description: "Readiness check returns 200" },
  { path: "/supply-chain/status", expected: 200, description: "Supply chain status returns 200" },
];

let passed = 0;
let failed = 0;

function runTest(test) {
  return new Promise((resolve) => {
    http
      .get(`${BASE_URL}${test.path}`, (res) => {
        if (res.statusCode === test.expected) {
          console.log(`  PASS: ${test.description}`);
          passed++;
        } else {
          console.log(`  FAIL: ${test.description} (got ${res.statusCode}, expected ${test.expected})`);
          failed++;
        }
        res.resume();
        resolve();
      })
      .on("error", (err) => {
        console.log(`  FAIL: ${test.description} (${err.message})`);
        failed++;
        resolve();
      });
  });
}

async function main() {
  console.log("\nRunning tests...\n");
  for (const test of tests) {
    await runTest(test);
  }
  console.log(`\nResults: ${passed} passed, ${failed} failed\n`);
  process.exit(failed > 0 ? 1 : 0);
}

main();
