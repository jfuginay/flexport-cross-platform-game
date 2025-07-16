import { createCanvas } from 'canvas';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Create directories if they don't exist
function ensureDir(dirPath) {
    if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true });
    }
}

// Generate ship sprite (64x32px)
function generateShipSprite() {
    const canvas = createCanvas(64, 32);
    const ctx = canvas.getContext('2d');
    
    // Clear canvas with transparent background
    ctx.clearRect(0, 0, 64, 32);
    
    // Hull (dark blue-gray)
    ctx.fillStyle = '#2d3748';
    ctx.fillRect(4, 18, 56, 10);
    
    // Ship bow (pointed front)
    ctx.beginPath();
    ctx.moveTo(60, 18);
    ctx.lineTo(62, 23);
    ctx.lineTo(60, 28);
    ctx.closePath();
    ctx.fill();
    
    // Ship stern (back)
    ctx.fillRect(4, 18, 2, 10);
    
    // Hull highlights
    ctx.fillStyle = '#4a5568';
    ctx.fillRect(4, 18, 56, 2);
    
    // Container stacks (colorful containers)
    const containerColors = ['#e53e3e', '#3182ce', '#38a169', '#d69e2e', '#805ad5'];
    
    // First container stack
    for (let i = 0; i < 3; i++) {
        ctx.fillStyle = containerColors[i % containerColors.length];
        ctx.fillRect(8 + i * 2, 12 - i * 2, 8, 6);
        // Container outline
        ctx.strokeStyle = '#1a202c';
        ctx.lineWidth = 0.5;
        ctx.strokeRect(8 + i * 2, 12 - i * 2, 8, 6);
    }
    
    // Second container stack
    for (let i = 0; i < 4; i++) {
        ctx.fillStyle = containerColors[(i + 2) % containerColors.length];
        ctx.fillRect(20 + i * 2, 14 - i * 2, 8, 6);
        ctx.strokeStyle = '#1a202c';
        ctx.lineWidth = 0.5;
        ctx.strokeRect(20 + i * 2, 14 - i * 2, 8, 6);
    }
    
    // Third container stack
    for (let i = 0; i < 2; i++) {
        ctx.fillStyle = containerColors[(i + 1) % containerColors.length];
        ctx.fillRect(32 + i * 2, 13 - i * 2, 8, 6);
        ctx.strokeStyle = '#1a202c';
        ctx.lineWidth = 0.5;
        ctx.strokeRect(32 + i * 2, 13 - i * 2, 8, 6);
    }
    
    // Fourth container stack
    for (let i = 0; i < 3; i++) {
        ctx.fillStyle = containerColors[(i + 3) % containerColors.length];
        ctx.fillRect(44 + i * 2, 12 - i * 2, 8, 6);
        ctx.strokeStyle = '#1a202c';
        ctx.lineWidth = 0.5;
        ctx.strokeRect(44 + i * 2, 12 - i * 2, 8, 6);
    }
    
    // Bridge/superstructure
    ctx.fillStyle = '#e2e8f0';
    ctx.fillRect(48, 8, 8, 8);
    ctx.strokeStyle = '#1a202c';
    ctx.lineWidth = 0.5;
    ctx.strokeRect(48, 8, 8, 8);
    
    // Bridge windows
    ctx.fillStyle = '#63b3ed';
    ctx.fillRect(49, 9, 2, 2);
    ctx.fillRect(53, 9, 2, 2);
    
    // Wake (white foam behind ship)
    ctx.fillStyle = 'rgba(255, 255, 255, 0.6)';
    ctx.fillRect(2, 20, 3, 2);
    ctx.fillRect(1, 22, 4, 2);
    ctx.fillRect(2, 26, 3, 2);
    
    return canvas;
}

// Generate port sprite (32x32px)
function generatePortSprite() {
    const canvas = createCanvas(32, 32);
    const ctx = canvas.getContext('2d');
    
    // Clear canvas
    ctx.clearRect(0, 0, 32, 32);
    
    // Port circle background (harbor water)
    ctx.fillStyle = '#3182ce';
    ctx.beginPath();
    ctx.arc(16, 16, 14, 0, 2 * Math.PI);
    ctx.fill();
    
    // Port outline
    ctx.strokeStyle = '#1e3a8a';
    ctx.lineWidth = 2;
    ctx.stroke();
    
    // Dock structures
    ctx.fillStyle = '#8b5a3c';
    ctx.fillRect(6, 14, 20, 4);
    ctx.fillRect(14, 6, 4, 20);
    
    // Dock highlights
    ctx.fillStyle = '#a0744a';
    ctx.fillRect(6, 14, 20, 1);
    ctx.fillRect(14, 6, 1, 20);
    
    // Port buildings/warehouses
    ctx.fillStyle = '#4a5568';
    ctx.fillRect(8, 8, 6, 6);
    ctx.fillRect(18, 8, 6, 6);
    ctx.fillRect(8, 18, 6, 6);
    ctx.fillRect(18, 18, 6, 6);
    
    // Building roofs
    ctx.fillStyle = '#e53e3e';
    ctx.fillRect(8, 8, 6, 2);
    ctx.fillRect(18, 8, 6, 2);
    ctx.fillRect(8, 18, 6, 2);
    ctx.fillRect(18, 18, 6, 2);
    
    // Cranes (simplified)
    ctx.strokeStyle = '#2d3748';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(11, 11);
    ctx.lineTo(11, 6);
    ctx.lineTo(16, 6);
    ctx.stroke();
    
    ctx.beginPath();
    ctx.moveTo(21, 11);
    ctx.lineTo(21, 6);
    ctx.lineTo(26, 6);
    ctx.stroke();
    
    // Port identification dot in center
    ctx.fillStyle = '#ffd700';
    ctx.beginPath();
    ctx.arc(16, 16, 2, 0, 2 * Math.PI);
    ctx.fill();
    
    return canvas;
}

// Generate realistic ocean wave particle sprite (16x16px)
function generateWaveParticle() {
    const canvas = createCanvas(16, 16);
    const ctx = canvas.getContext('2d');
    
    // Clear canvas
    ctx.clearRect(0, 0, 16, 16);
    
    // Create main ocean water gradient (deep blue to lighter blue)
    const oceanGradient = ctx.createRadialGradient(8, 8, 0, 8, 8, 7);
    oceanGradient.addColorStop(0, 'rgba(30, 58, 138, 0.8)');    // Deep ocean blue
    oceanGradient.addColorStop(0.4, 'rgba(59, 130, 246, 0.7)'); // Medium blue
    oceanGradient.addColorStop(0.7, 'rgba(96, 165, 250, 0.5)'); // Light blue
    oceanGradient.addColorStop(1, 'rgba(147, 197, 253, 0.2)');  // Very light blue fade
    
    // Main water bubble/droplet
    ctx.fillStyle = oceanGradient;
    ctx.beginPath();
    ctx.arc(8, 8, 6.5, 0, 2 * Math.PI);
    ctx.fill();
    
    // Create foam/whitecap gradient for realistic wave crests
    const foamGradient = ctx.createRadialGradient(8, 6, 0, 8, 6, 4);
    foamGradient.addColorStop(0, 'rgba(255, 255, 255, 0.9)');
    foamGradient.addColorStop(0.6, 'rgba(255, 255, 255, 0.6)');
    foamGradient.addColorStop(1, 'rgba(255, 255, 255, 0.1)');
    
    // Foam crest at top of wave
    ctx.fillStyle = foamGradient;
    ctx.beginPath();
    ctx.ellipse(8, 6, 4, 2.5, 0, 0, 2 * Math.PI);
    ctx.fill();
    
    // Smaller ocean water bubbles for texture
    ctx.fillStyle = 'rgba(37, 99, 235, 0.6)';
    ctx.beginPath();
    ctx.arc(5, 10, 1.8, 0, 2 * Math.PI);
    ctx.fill();
    
    ctx.fillStyle = 'rgba(29, 78, 216, 0.5)';
    ctx.beginPath();
    ctx.arc(11, 9, 1.2, 0, 2 * Math.PI);
    ctx.fill();
    
    ctx.fillStyle = 'rgba(59, 130, 246, 0.4)';
    ctx.beginPath();
    ctx.arc(6, 5, 1, 0, 2 * Math.PI);
    ctx.fill();
    
    // Small foam bubbles for realistic effect
    ctx.fillStyle = 'rgba(255, 255, 255, 0.8)';
    ctx.beginPath();
    ctx.arc(9, 5, 0.8, 0, 2 * Math.PI);
    ctx.fill();
    
    ctx.beginPath();
    ctx.arc(6, 7, 0.6, 0, 2 * Math.PI);
    ctx.fill();
    
    ctx.beginPath();
    ctx.arc(11, 6, 0.5, 0, 2 * Math.PI);
    ctx.fill();
    
    // Subtle wave texture lines with ocean blue tint
    ctx.strokeStyle = 'rgba(147, 197, 253, 0.6)';
    ctx.lineWidth = 0.8;
    ctx.beginPath();
    ctx.moveTo(2, 9);
    ctx.quadraticCurveTo(8, 7, 14, 9);
    ctx.stroke();
    
    ctx.strokeStyle = 'rgba(191, 219, 254, 0.4)';
    ctx.lineWidth = 0.6;
    ctx.beginPath();
    ctx.moveTo(3, 11);
    ctx.quadraticCurveTo(8, 13, 13, 11);
    ctx.stroke();
    
    // Add subtle highlight for water surface reflection
    ctx.fillStyle = 'rgba(219, 234, 254, 0.3)';
    ctx.beginPath();
    ctx.ellipse(8, 7, 3, 1, 0, 0, 2 * Math.PI);
    ctx.fill();
    
    return canvas;
}

// Main function to generate and save all sprites
function generateAllSprites() {
    console.log('🚢 Generating FlexPort maritime sprites...\n');
    
    // Define output directories
    const webSpritesDir = path.join(__dirname, 'public', 'assets', 'sprites');
    const iosShipsDir = path.join(__dirname, '..', 'FlexPort iOS', 'Sources', 'FlexPort', 'Assets', 'Sprites', 'Ships');
    const iosPortsDir = path.join(__dirname, '..', 'FlexPort iOS', 'Sources', 'FlexPort', 'Assets', 'Sprites', 'Ports');
    const iosEffectsDir = path.join(__dirname, '..', 'FlexPort iOS', 'Sources', 'FlexPort', 'Assets', 'Sprites', 'Effects');
    
    // Ensure directories exist
    ensureDir(webSpritesDir);
    ensureDir(iosShipsDir);
    ensureDir(iosPortsDir);
    ensureDir(iosEffectsDir);
    
    // Generate sprites
    const shipCanvas = generateShipSprite();
    const portCanvas = generatePortSprite();
    const waveCanvas = generateWaveParticle();
    
    // Save ship sprite
    const shipBuffer = shipCanvas.toBuffer('image/png');
    fs.writeFileSync(path.join(webSpritesDir, 'ship.png'), shipBuffer);
    fs.writeFileSync(path.join(iosShipsDir, 'ship.png'), shipBuffer);
    console.log('✅ Ship sprite generated (64x32px)');
    console.log(`   - Web: ${path.join(webSpritesDir, 'ship.png')}`);
    console.log(`   - iOS: ${path.join(iosShipsDir, 'ship.png')}`);
    
    // Save port sprite
    const portBuffer = portCanvas.toBuffer('image/png');
    fs.writeFileSync(path.join(webSpritesDir, 'port.png'), portBuffer);
    fs.writeFileSync(path.join(iosPortsDir, 'port.png'), portBuffer);
    console.log('✅ Port sprite generated (32x32px)');
    console.log(`   - Web: ${path.join(webSpritesDir, 'port.png')}`);
    console.log(`   - iOS: ${path.join(iosPortsDir, 'port.png')}`);
    
    // Save wave particle
    const waveBuffer = waveCanvas.toBuffer('image/png');
    fs.writeFileSync(path.join(webSpritesDir, 'wave.png'), waveBuffer);
    fs.writeFileSync(path.join(iosEffectsDir, 'wave.png'), waveBuffer);
    console.log('✅ Wave particle generated (16x16px)');
    console.log(`   - Web: ${path.join(webSpritesDir, 'wave.png')}`);
    console.log(`   - iOS: ${path.join(iosEffectsDir, 'wave.png')}`);
    
    // Generate base64 data URLs for embedding
    const shipDataUrl = 'data:image/png;base64,' + shipBuffer.toString('base64');
    const portDataUrl = 'data:image/png;base64,' + portBuffer.toString('base64');
    const waveDataUrl = 'data:image/png;base64,' + waveBuffer.toString('base64');
    
    // Save data URLs to a JSON file for easy access
    const dataUrls = {
        ship: shipDataUrl,
        port: portDataUrl,
        wave: waveDataUrl,
        metadata: {
            ship: { width: 64, height: 32, description: 'Top-down view of modern container ship' },
            port: { width: 32, height: 32, description: 'Circular port icon with docks and buildings' },
            wave: { width: 16, height: 16, description: 'Realistic ocean blue wave particle with foam highlights for water effects' }
        }
    };
    
    fs.writeFileSync(path.join(webSpritesDir, 'sprite-data-urls.json'), JSON.stringify(dataUrls, null, 2));
    console.log('✅ Base64 data URLs saved to sprite-data-urls.json');
    
    console.log('\n🎮 All sprites generated successfully!');
    console.log('\nSprite Details:');
    console.log('- Ship: 64x32px container ship with cargo containers and bridge');
    console.log('- Port: 32x32px circular harbor with docks, buildings, and cranes');
    console.log('- Wave: 16x16px realistic ocean blue particle with foam highlights for water effects');
    console.log('\nFiles are ready for use in both web and iOS versions of FlexPort!');
}

// Check if running as script
if (import.meta.url === `file://${process.argv[1]}`) {
    try {
        generateAllSprites();
    } catch (error) {
        console.error('❌ Error generating sprites:', error.message);
        if (error.message.includes('canvas')) {
            console.log('\n💡 Note: This script requires the "canvas" package.');
            console.log('Install it with: npm install canvas');
        }
        process.exit(1);
    }
}

export {
    generateShipSprite,
    generatePortSprite,
    generateWaveParticle,
    generateAllSprites
};