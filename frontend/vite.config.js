import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react(), {
    name: 'bundle-budget',
    generateBundle(_options, bundle) {
      for (const asset of Object.values(bundle)) {
        if (asset.type === 'chunk' && Buffer.byteLength(asset.code) > 250 * 1024) {
          this.error(`JavaScript chunk ${asset.fileName} exceeds the 250 KiB budget`);
        }
      }
    },
  }],

  server: {
    port: 5173,
    host: true,
    // Vite proxies /api to the API process. The container image uses nginx
    // for the same proxy, so the frontend never needs an API hostname.
    proxy: {
      '/api': { target: process.env.API_URL || 'http://localhost:3000', changeOrigin: true },
    },
  },

  build: {
    outDir: 'dist',
    sourcemap: false,
    // Users are on 2 GB Android phones over 240 kbps 3G. A bundle-size budget
    // is a functional requirement here (NFR-04), not a nicety.
    chunkSizeWarningLimit: 250,
    rollupOptions: {
      output: {
        manualChunks: { vendor: ['react', 'react-dom'] },
      },
    },
  },

  test: {
    environment: 'node',
    include: ['src/**/*.test.js'],
    reporters: ['default', 'junit'],
    outputFile: { junit: process.env.JUNIT_FILE || './reports/junit.xml' },
    coverage: { provider: 'v8', reporter: ['text', 'lcov'] },
  },
});
