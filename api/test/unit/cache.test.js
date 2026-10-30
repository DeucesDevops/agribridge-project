import { afterEach, describe, expect, it, vi } from 'vitest';

const mock = vi.hoisted(() => ({
  client: { on: vi.fn(), connect: vi.fn(), disconnect: vi.fn(), isOpen: true },
}));
vi.mock('redis', () => ({ createClient: () => mock.client }));
vi.mock('../../src/logger.js', () => ({ default: { info: vi.fn(), warn: vi.fn() } }));
vi.mock('../../src/config.js', () => ({ default: {
  cache: { enabled: true, url: 'redis://unavailable:6379' },
} }));
vi.mock('../../src/metrics.js', () => ({ cacheOperations: { inc: vi.fn() } }));
import { initCache, closeCache, isConnected } from '../../src/cache.js';

afterEach(() => vi.useRealTimers());
describe('cache degradation', () => {
  it('allows startup when redis keeps reconnecting forever', async () => {
    vi.useFakeTimers();
    mock.client.connect.mockReturnValue(new Promise(() => {}));
    const startup = initCache();
    await vi.advanceTimersByTimeAsync(3000);
    await expect(startup).resolves.toBe(mock.client);
    expect(isConnected()).toBe(false);
  });
  it('disconnects a reconnecting client on shutdown', async () => {
    await closeCache();
    expect(mock.client.disconnect).toHaveBeenCalledOnce();
  });
});
