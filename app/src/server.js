'use strict';

const { createApp, log } = require('./app');

const PORT = parseInt(process.env.PORT || '3000', 10);
const server = createApp().listen(PORT, '0.0.0.0', () =>
  log('info', 'server_started', { port: PORT })
);

// Graceful shutdown: ECS sends SIGTERM and waits `stopTimeout` before SIGKILL.
function shutdown(signal) {
  log('info', 'shutdown_initiated', { signal });
  server.close(() => {
    log('info', 'shutdown_complete');
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 25000).unref();
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
