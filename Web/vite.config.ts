import { defineConfig } from 'vite'
import path from 'path'

export default defineConfig({
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
      '@/components': path.resolve(__dirname, './src/components'),
      '@/systems': path.resolve(__dirname, './src/systems'),
      '@/core': path.resolve(__dirname, './src/core'),
      '@/utils': path.resolve(__dirname, './src/utils'),
      '@/types': path.resolve(__dirname, './src/types'),
      '@/networking': path.resolve(__dirname, './src/networking'),
    },
  },
  server: {
    host: true,
    port: 3000,
  },
  build: {
    target: 'esnext',
    minify: 'terser',
    rollupOptions: {
      output: {
        manualChunks: {
          pixi: ['pixi.js'],
          vendor: ['zustand', 'chart.js'],
        },
      },
    },
  },
  optimizeDeps: {
    include: ['pixi.js', 'zustand', 'chart.js'],
  },
})