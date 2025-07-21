# FlexPort Global 🌍🚢

<!-- Vercel deployment configured -->

[![Version](https://img.shields.io/badge/version-1.0.0--beta.1-blue.svg)](https://github.com/yourusername/flexport-global)
[![React](https://img.shields.io/badge/React-18.3.1-61dafb.svg)](https://reactjs.org/)
[![TypeScript](https://img.shields.io/badge/TypeScript-4.9.5-3178c6.svg)](https://www.typescriptlang.org/)
[![Three.js](https://img.shields.io/badge/Three.js-latest-black.svg)](https://threejs.org/)
[![Mapbox](https://img.shields.io/badge/Mapbox-3.8.0-4264fb.svg)](https://www.mapbox.com/)

> **Beta Release**: This is the first official beta release (v1.0.0-beta.1) of FlexPort Global. Join us in building the future of shipping simulation!

## 🎮 Overview

FlexPort Global is a sophisticated 3D global shipping simulation game where you build and manage your own shipping empire. Navigate real-world trade routes, manage diverse fleets, and compete in a dynamic global economy.

![FlexPort Global Screenshot](https://via.placeholder.com/800x400?text=FlexPort+Global+Beta)

## ✨ Key Features

### 🌐 Dual Globe Visualization
- **Mapbox GL Globe**: Beautiful satellite imagery with real Earth data (default)
- **Three.js 3D Globe**: Custom procedural Earth with optimized performance

### 🚢 Fleet Management
- Container Ships, Bulk Carriers, Tankers, and Cargo Planes
- Real-time vessel tracking with animated movements
- Dynamic route planning and optimization

### 🏭 Global Port Network
- 50+ real-world major ports
- Realistic capacity and berth management
- Port ownership and upgrades

### 📊 Economic Simulation
- Dynamic contract generation based on trade patterns
- Supply and demand fluctuations
- Competitive AI shipping companies
- Market events and global crises

## 🚀 Quick Start

### Prerequisites
- Node.js 16+ and npm
- A Mapbox account and API token (free tier available)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/flexport-global.git
cd flexport-global
```

2. Install dependencies:
```bash
npm install
```

3. Create a `.env` file from the example:
```bash
cp .env.example .env
```

4. Add your Mapbox token to `.env`:
```
REACT_APP_MAPBOX_TOKEN=your_mapbox_token_here
```

5. Start the development server:
```bash
npm start
```

6. Open [http://localhost:3000](http://localhost:3000) and start building your empire!

## 🎯 How to Play

1. **Start Small**: Begin with a single ship and limited capital
2. **Accept Contracts**: Choose profitable routes between ports
3. **Expand Fleet**: Purchase new vessels as you earn money
4. **Manage Operations**: Balance fuel, maintenance, and crew
5. **Grow Empire**: Buy ports, research technology, dominate trade routes

## 🛠️ Technology Stack

- **Frontend**: React 18 + TypeScript
- **3D Graphics**: Three.js + React Three Fiber
- **Mapping**: Mapbox GL JS v3
- **State Management**: Zustand
- **Styling**: Tailwind CSS + Custom CSS
- **Build Tool**: Create React App

## 📱 Platform Support

- ✅ Desktop Browsers (Chrome, Firefox, Safari, Edge)
- 🚧 Mobile Web (Performance optimization in progress)
- 📋 Native Apps (Planned via Capacitor)

## 🗺️ Roadmap

### Current (Beta)
- [x] Core gameplay mechanics
- [x] Globe visualization
- [x] Fleet management
- [x] Contract system
- [x] Basic AI competitors

### Coming Soon
- [ ] Weather systems affecting routes
- [ ] Advanced AI with personalities
- [ ] Multiplayer support
- [ ] Mobile app release
- [ ] Steam integration
- [ ] Mod support

## 🐛 Known Issues

- Tile loading optimization needed for Three.js view
- Performance on older GPUs needs improvement
- Mobile touch controls need refinement

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- NASA for Earth imagery references
- OpenStreetMap contributors
- Mapbox for mapping services
- Three.js community
- All beta testers and contributors

## 📞 Contact

- GitHub Issues: [Report bugs or request features](https://github.com/yourusername/flexport-global/issues)
- Discord: [Join our community](https://discord.gg/flexportglobal)
- Twitter: [@FlexPortGlobal](https://twitter.com/flexportglobal)

---

Built with ❤️ by the FlexPort Global team

🤖 Generated with [Claude Code](https://claude.ai/code)