"use strict";

const express = require("express");
const helmet = require("helmet");
const pino = require("pino");

const logger = pino({ level: process.env.LOG_LEVEL || "info" });
const app = express();
const PORT = process.env.PORT || 3000;

// Security headers
app.use(helmet());

// Disable fingerprinting
app.disable("x-powered-by");

// Health check — used by Kubernetes liveness and readiness probes
app.get("/healthz", (_req, res) => {
  res.status(200).json({ status: "healthy", timestamp: new Date().toISOString() });
});

// Readiness check — confirms the app is ready to serve traffic
app.get("/readyz", (_req, res) => {
  res.status(200).json({ status: "ready", timestamp: new Date().toISOString() });
});

// Application root
app.get("/", (_req, res) => {
  res.status(200).json({
    service: "supply-chain-demo",
    version: process.env.APP_VERSION || "1.0.0",
    message: "Supply chain security pipeline demo application",
    endpoints: {
      health: "/healthz",
      ready: "/readyz",
      supply_chain: "/supply-chain/status",
    },
  });
});

// Supply chain metadata endpoint — returns build provenance info injected at build time
app.get("/supply-chain/status", (_req, res) => {
  res.status(200).json({
    build: {
      image_digest: process.env.IMAGE_DIGEST || "unknown",
      commit_sha: process.env.COMMIT_SHA || "unknown",
      build_timestamp: process.env.BUILD_TIMESTAMP || "unknown",
      slsa_level: process.env.SLSA_LEVEL || "unknown",
    },
    attestations: {
      signed: process.env.IMAGE_SIGNED === "true",
      sbom_attached: process.env.SBOM_ATTACHED === "true",
      provenance_attached: process.env.PROVENANCE_ATTACHED === "true",
    },
  });
});

// Graceful shutdown
const server = app.listen(PORT, "0.0.0.0", () => {
  logger.info({ port: PORT }, "Server started");
});

const shutdown = (signal) => {
  logger.info({ signal }, "Shutdown signal received");
  server.close(() => {
    logger.info("Server closed");
    process.exit(0);
  });
  // Force exit if graceful shutdown takes too long
  setTimeout(() => process.exit(1), 10000);
};

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));

module.exports = app;
