/**
 * Health, readiness, metrics and version.
 *
 * The distinction between /healthz and /readyz is the single most important
 * detail in this file, and it is worth being able to explain out loud:
 *
 *   /healthz  - is this process alive? Deliberately does NOT touch the
 *               database. If liveness checked the database, a brief database
 *               blip would restart the process and turn a recoverable
 *               dependency failure into an outage.
 *
 *   /readyz   - can this process usefully serve traffic right now? This one
 *               DOES check the database, so an instance with no database can
 *               be taken out of rotation without being restarted.
 */
import { Router } from 'express';
import config from '../config.js';
import { checkDatabase } from '../db.js';
import { checkCache, isConnected } from '../cache.js';
import { registry } from '../metrics.js';
import { asyncRoute } from '../middleware.js';

export const healthRouter = Router();

/** Liveness. Cheap, dependency-free, always 200 while the event loop runs. */
healthRouter.get('/healthz', (_req, res) => {
  res.status(200).json({
    status: 'ok',
    uptimeSeconds: Math.round(process.uptime()),
  });
});

/** Readiness. 200 only when dependencies are usable. */
healthRouter.get('/readyz', asyncRoute(async (_req, res) => {
  const checks = {};
  let ready = true;

  try {
    checks.database = await checkDatabase();
  } catch (err) {
    checks.database = { ok: false, error: err.message };
    ready = false;                       // no database means no useful work
  }

  try {
    checks.cache = await checkCache();
  } catch (err) {
    checks.cache = { ok: false, error: err.message };
  }

  // A missing cache is degradation, not unreadiness - unless it was declared
  // required. Latency suffers; availability does not.
  if (config.cache.required && !isConnected()) ready = false;

  res.status(ready ? 200 : 503).json({
    status: ready ? 'ready' : 'not-ready',
    degraded: ready && config.cache.enabled && !isConnected(),
    checks,
  });
}));

/** Process and business metrics in Prometheus text format. */
healthRouter.get('/metrics', asyncRoute(async (_req, res) => {
  res.set('Content-Type', registry.contentType);
  res.send(await registry.metrics());
}));

/**
 * Traceability. Reports the build identity injected at image build time.
 */
healthRouter.get('/version', (_req, res) => {
  res.json({
    version: config.version,
    gitSha: config.gitSha,
    builtAt: config.builtAt,
    imageTag: config.imageTag,
    nodeVersion: process.version,
    environment: config.env,
  });
});

export default healthRouter;
