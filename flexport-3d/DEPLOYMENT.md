# FlexPort Global - Deployment Guide

## 🚀 Deploying to Vercel

This app is fully compatible with Vercel deployment. No backend services are required - everything runs in the browser!

### Prerequisites

1. **Vercel Account**: Sign up at [vercel.com](https://vercel.com)
2. **Mapbox Token**: Get a free token at [mapbox.com](https://www.mapbox.com)
3. **Git Repository**: Push your code to GitHub/GitLab/Bitbucket

### Step 1: Prepare Environment Variables

1. Copy `.env` to `.env.production`
2. Replace the Mapbox token with your production token:
   ```
   REACT_APP_MAPBOX_TOKEN=your_production_mapbox_token_here
   ```

### Step 2: Test Production Build Locally

```bash
# Build the production version
npm run build

# Test it locally
npx serve -s build
```

Visit http://localhost:3000 to ensure everything works.

### Step 3: Deploy to Vercel

#### Option A: Via Vercel CLI

```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
vercel

# Follow the prompts
# - Link to existing project or create new
# - Use default settings (auto-detected as Create React App)
```

#### Option B: Via GitHub Integration

1. Push your code to GitHub
2. Go to [vercel.com/new](https://vercel.com/new)
3. Import your GitHub repository
4. Vercel will auto-detect Create React App
5. Add environment variables in Vercel dashboard:
   - `REACT_APP_MAPBOX_TOKEN` = your_mapbox_token
   - `REACT_APP_MAPTILER_KEY` = your_maptiler_key (optional)
6. Click "Deploy"

### Step 4: Configure Environment Variables in Vercel

1. Go to your project settings in Vercel
2. Navigate to "Environment Variables"
3. Add:
   ```
   REACT_APP_MAPBOX_TOKEN = pk.your_production_token_here
   REACT_APP_MAPTILER_KEY = your_maptiler_key (optional)
   ```

### Step 5: Custom Domain (Optional)

1. In Vercel project settings, go to "Domains"
2. Add your custom domain
3. Follow DNS configuration instructions

## 🔧 Build Optimization

The app is already optimized for production:

- ✅ Code splitting enabled
- ✅ Tree shaking for Three.js
- ✅ Minified and compressed
- ✅ Service worker ready
- ✅ Static assets cached

## 📱 Progressive Web App

The app can be installed as a PWA:

1. Visit your deployed site on mobile
2. Click "Add to Home Screen"
3. Enjoy native-like experience

## 🚨 Important Notes

1. **API Keys Security**: 
   - Mapbox tokens are client-side and will be visible
   - Use token restrictions in Mapbox dashboard (domain restrictions)
   - Monitor usage in Mapbox dashboard

2. **Performance**:
   - The app uses WebGL for 3D rendering
   - Requires modern browsers (Chrome, Firefox, Safari, Edge)
   - Mobile devices need decent GPU for smooth performance

3. **Storage**:
   - Game state is saved in browser localStorage
   - No backend database needed
   - Progress persists across sessions

## 🐛 Troubleshooting

### Build Fails
- Ensure all dependencies are installed: `npm install`
- Clear cache: `rm -rf node_modules package-lock.json && npm install`

### Mapbox Not Loading
- Verify token is set in environment variables
- Check token permissions in Mapbox dashboard
- Ensure token isn't URL-restricted during testing

### 3D Performance Issues
- The app requires WebGL 2 support
- Disable browser extensions that might interfere
- Try different browser or update graphics drivers

## 📊 Monitoring

After deployment, monitor your app:

1. **Vercel Analytics**: Built-in performance monitoring
2. **Mapbox Dashboard**: Track map usage and costs
3. **Browser DevTools**: Check for console errors

## 🎮 Game Features Working in Production

- ✅ 3D Globe visualization with Mapbox
- ✅ Ship movement and animations
- ✅ Fleet management
- ✅ Contract system
- ✅ Weather effects
- ✅ Camera tracking
- ✅ Local save/load
- ✅ Responsive design

## 💰 Costs

- **Vercel**: Free tier includes 100GB bandwidth/month
- **Mapbox**: Free tier includes 50,000 map loads/month
- **Total Cost**: $0 for moderate usage

---

🚢 Happy shipping! Your global logistics empire awaits deployment!