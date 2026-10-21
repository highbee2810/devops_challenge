'use strict';

const express = require('express');

const VERSION = process.env.APP_VERSION || 'dev';
const STARTED_AT = new Date().toISOString();

// Structured (JSON) logging so CloudWatch Logs Insights / metric filters can query fields.
function log(level, message, extra = {}) {
  process.stdout.write(
    JSON.stringify({ ts: new Date().toISOString(), level, message, ...extra }) + '\n'
  );
}

function createApp() {
  const app = express();
  app.disable('x-powered-by');

  // Request logging with latency
  app.use((req, res, next) => {
    const start = process.hrtime.bigint();
    res.on('finish', () => {
      if (req.path === '/health') return; // keep ALB health checks out of the logs
      const ms = Number(process.hrtime.bigint() - start) / 1e6;
      log('info', 'request', {
        method: req.method,
        path: req.path,
        status: res.statusCode,
        duration_ms: Math.round(ms * 100) / 100
      });
    });
    next();
  });

  // Liveness/readiness endpoint used by the ALB target group and the ECS container health check
  app.get('/health', (_req, res) => res.status(200).json({ status: 'ok' }));

  app.get('/', (_req, res) =>
    res.json({
      service: 'devops-challenge-app',
      version: VERSION,
      environment: process.env.NODE_ENV || 'development',
      startedAt: STARTED_AT
    })
  );

  app.get('/api/time', (_req, res) => res.json({ now: new Date().toISOString() }));

  app.use((_req, res) => res.status(404).json({ error: 'not_found' }));

  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    log('error', 'unhandled_error', { error: err.message });
    res.status(500).json({ error: 'internal_error' });
  });

  return app;
}

module.exports = { createApp, log };
