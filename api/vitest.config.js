import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    // Integration tests share one database; running them in parallel would
    // make them fight over the same rows.
    fileParallelism: false,
    testTimeout: 30_000,
    hookTimeout: 60_000,
    reporters: ['default', 'junit'],
    outputFile: { junit: process.env.JUNIT_FILE || './reports/junit.xml' },
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov', 'json-summary'],
      reportsDirectory: './coverage',
      // Coverage thresholds for the domain layer, which is where the business
      // rules live.
      include: ['src/domain/**/*.js'],
      thresholds: {
        lines: 70,
        functions: 70,
        branches: 70,
        statements: 70,
      },
    },
  },
});
