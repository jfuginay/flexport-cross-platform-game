# FlexPort Global - Deployment Guide

The production build has been created in the `build/` directory. Here are deployment options:

## Quick Deployment Options

### 1. Vercel (Recommended)
```bash
# Install Vercel CLI if you haven't
npm i -g vercel

# Deploy
vercel --prod
```

### 2. Netlify
```bash
# Install Netlify CLI
npm i -g netlify-cli

# Deploy
netlify deploy --prod --dir=build
```

### 3. GitHub Pages
Add to package.json:
```json
"homepage": "https://yourusername.github.io/flexport-3d"
```

Install gh-pages:
```bash
npm install --save-dev gh-pages
```

Add deploy scripts to package.json:
```json
"scripts": {
  "predeploy": "npm run build",
  "deploy": "gh-pages -d build"
}
```

Deploy:
```bash
npm run deploy
```

## Serving Locally

To test the production build locally:
```bash
npm install -g serve
serve -s build
```
