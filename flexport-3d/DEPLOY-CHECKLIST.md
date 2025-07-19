# 🚀 FlexPort Global - Quick Deploy Checklist

## ✅ Your app is ready for Vercel!

**Good news**: Everything you need runs in the browser. No backend required!

## 📋 Quick Deploy Steps:

### 1. Update Your Mapbox Token
```bash
# Edit .env.production
REACT_APP_MAPBOX_TOKEN=pk.eyJ1IjoiamZ1Z2luYXkiLCJhIjoiY21icmNha2hrMGE0azJscHVzdmVuZTVjOSJ9.oiJoYvc_G-tLUmaSzGVsVQ
```
⚠️ **Important**: This is your development token. For production, get a new token and add domain restrictions.

### 2. Deploy via Vercel CLI (Fastest)
```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
vercel --prod
```

### 3. Or Deploy via GitHub
1. Push to GitHub: `git push origin main`
2. Go to [vercel.com/new](https://vercel.com/new)
3. Import your repo
4. Add env variables in Vercel dashboard
5. Deploy!

## 🔑 What You Need:
- ✅ **Vercel account** (free)
- ✅ **Your existing Mapbox token** (already in .env)
- ✅ **5 minutes**

## 💡 Production Tips:
1. **Mapbox Token**: Add domain restrictions in Mapbox dashboard after deploy
2. **Custom Domain**: Add in Vercel settings (optional)
3. **Analytics**: Enable in Vercel dashboard (free)

## 🎮 Everything Works:
- ✅ 3D Globe
- ✅ Ship animations
- ✅ Weather effects
- ✅ Camera tracking
- ✅ Fleet management
- ✅ Contracts system

## 🆓 Costs:
- Vercel: **FREE** (100GB/month)
- Mapbox: **FREE** (50k loads/month)

---

**Ready to ship?** Just run `vercel --prod` and you're live in 2 minutes! 🚢