import { defineConfig } from 'vite';
import { fileURLToPath } from 'node:url';

export default defineConfig({
  base: './',
  worker: { format: 'es' },
  build: {
    target: 'es2022',
    outDir: fileURLToPath(new URL('../../web/assets/catalog-reader', import.meta.url)),
    emptyOutDir: false,
    rollupOptions: {
      preserveEntrySignatures: 'strict',
      input: fileURLToPath(new URL('./reader.js', import.meta.url)),
      output: { entryFileNames: 'reader.js', chunkFileNames: 'modules/[name]-[hash].js' },
    },
  },
});
