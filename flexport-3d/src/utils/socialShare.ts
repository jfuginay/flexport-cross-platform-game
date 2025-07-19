export const shareGameProgress = (stats: {
  fleet: number;
  money: number;
  routesCompleted: number;
}) => {
  const text = `🚢 My FlexPort 3D Empire:\n💰 $${stats.money.toLocaleString()}\n⚓ ${stats.fleet} Ships\n📦 ${stats.routesCompleted} Deliveries\n\nCan you beat my shipping empire?`;
  
  if (navigator.share) {
    navigator.share({
      title: 'FlexPort 3D - My Shipping Empire',
      text: text,
      url: 'https://flexport3d.com'
    });
  } else {
    // Fallback to Twitter
    const twitterUrl = `https://twitter.com/intent/tweet?text=${encodeURIComponent(text)}`;
    window.open(twitterUrl, '_blank');
  }
};

export const createShareableImage = async (canvas: HTMLCanvasElement) => {
  // Generate shareable image of their empire
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  
  // Add game logo, stats, and call-to-action
  ctx.fillStyle = '#0f172a';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  
  // Return as blob for sharing
  return new Promise<Blob>((resolve) => {
    canvas.toBlob((blob) => {
      if (blob) resolve(blob);
    });
  });
};