// Real-time weather service using Open-Meteo API
interface WeatherAlert {
  id: string;
  type: 'STORM' | 'HURRICANE' | 'FOG' | 'HIGH_WAVES' | 'EXTREME_WEATHER';
  severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'EXTREME';
  location: {
    lat: number;
    lng: number;
    name: string;
  };
  description: string;
  windSpeed: number;
  waveHeight: number;
  visibility: number;
  affectedRoutes: string[];
  startTime: Date;
  endTime: Date;
}

class WeatherService {
  private readonly API_BASE = 'https://api.open-meteo.com/v1';
  private weatherAlerts: Map<string, WeatherAlert> = new Map();
  private updateInterval: NodeJS.Timer | null = null;

  // Major shipping route coordinates to monitor
  private readonly SHIPPING_ROUTES = [
    { name: 'North Atlantic', lat: 40, lng: -40, routes: ['Rotterdam-New York', 'Europe-US East'] },
    { name: 'South China Sea', lat: 15, lng: 115, routes: ['Singapore-Shanghai', 'Asia Trade'] },
    { name: 'Indian Ocean', lat: -10, lng: 80, routes: ['Jebel Ali-Singapore', 'Middle East-Asia'] },
    { name: 'Pacific Ocean', lat: 30, lng: -140, routes: ['Los Angeles-Shanghai', 'Trans-Pacific'] },
    { name: 'Mediterranean', lat: 35, lng: 20, routes: ['Europe-Middle East', 'Suez Canal'] },
    { name: 'Caribbean', lat: 18, lng: -75, routes: ['Panama Canal', 'US-South America'] },
    { name: 'North Pacific', lat: 45, lng: 180, routes: ['Asia-US West', 'Japan-California'] },
    { name: 'Cape of Good Hope', lat: -35, lng: 20, routes: ['Europe-Asia Alternative', 'Africa Route'] }
  ];

  public async startWeatherMonitoring(callback: (alert: WeatherAlert) => void): Promise<void> {
    // Initial fetch
    await this.fetchWeatherData(callback);
    
    // Update every 30 minutes
    this.updateInterval = setInterval(() => {
      this.fetchWeatherData(callback);
    }, 30 * 60 * 1000);
  }

  public stopWeatherMonitoring(): void {
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
      this.updateInterval = null;
    }
  }

  private async fetchWeatherData(callback: (alert: WeatherAlert) => void): Promise<void> {
    try {
      // Fetch weather for each major shipping route
      const weatherPromises = this.SHIPPING_ROUTES.map(route => 
        this.fetchRouteWeather(route)
      );

      const weatherData = await Promise.all(weatherPromises);
      
      // Process weather data and create alerts
      weatherData.forEach((data, index) => {
        if (data) {
          const route = this.SHIPPING_ROUTES[index];
          const alert = this.processWeatherData(data, route);
          
          if (alert) {
            this.weatherAlerts.set(alert.id, alert);
            callback(alert);
          }
        }
      });
    } catch (error) {
      console.error('Error fetching weather data:', error);
    }
  }

  private async fetchRouteWeather(route: any): Promise<any> {
    // Use regular forecast API with valid parameters
    const params = new URLSearchParams({
      latitude: route.lat.toString(),
      longitude: route.lng.toString(),
      current_weather: 'true',
      hourly: 'temperature_2m,precipitation,weathercode,windspeed_10m,winddirection_10m,visibility',
      forecast_days: '3'
    });

    try {
      const response = await fetch(`${this.API_BASE}/forecast?${params}`);
      if (!response.ok) {
        console.warn(`Weather API returned ${response.status} for ${route.name}`);
        return null;
      }
      return response.json();
    } catch (error) {
      console.error(`Error fetching weather for ${route.name}:`, error);
      return null;
    }
  }

  private processWeatherData(data: any, route: any): WeatherAlert | null {
    const current = data.current_weather;
    if (!current) return null;

    const windSpeed = current.windspeed || 0;
    const weatherCode = current.weathercode || 0;
    
    // Estimate wave height if not available
    const waveHeight = data.hourly?.wave_height?.[0] || this.estimateWaveHeight(windSpeed);
    const visibility = data.hourly?.visibility?.[0] || 10000;

    // Determine if this constitutes a weather alert
    const alert = this.evaluateWeatherConditions(
      windSpeed,
      waveHeight,
      visibility,
      weatherCode,
      route
    );

    return alert;
  }

  private estimateWaveHeight(windSpeed: number): number {
    // Rough estimation: wave height in meters based on wind speed
    if (windSpeed < 20) return 1;
    if (windSpeed < 40) return 2 + (windSpeed - 20) * 0.15;
    if (windSpeed < 60) return 5 + (windSpeed - 40) * 0.2;
    return 9 + (windSpeed - 60) * 0.3;
  }

  private evaluateWeatherConditions(
    windSpeed: number,
    waveHeight: number,
    visibility: number,
    weatherCode: number,
    route: any
  ): WeatherAlert | null {
    let type: WeatherAlert['type'] | null = null;
    let severity: WeatherAlert['severity'] = 'LOW';
    let description = '';

    // Evaluate conditions
    if (windSpeed > 100 || weatherCode >= 95) {
      type = 'HURRICANE';
      severity = 'EXTREME';
      description = `Hurricane conditions detected in ${route.name}. All vessels should seek immediate shelter.`;
    } else if (windSpeed > 60 || waveHeight > 8) {
      type = 'STORM';
      severity = 'HIGH';
      description = `Severe storm in ${route.name}. Wind speeds ${Math.round(windSpeed)} km/h, waves ${waveHeight.toFixed(1)}m.`;
    } else if (waveHeight > 5) {
      type = 'HIGH_WAVES';
      severity = 'MEDIUM';
      description = `High seas in ${route.name}. Wave height ${waveHeight.toFixed(1)}m. Exercise caution.`;
    } else if (visibility < 1000) {
      type = 'FOG';
      severity = 'MEDIUM';
      description = `Dense fog in ${route.name}. Visibility reduced to ${visibility}m.`;
    } else if (windSpeed > 40) {
      type = 'STORM';
      severity = 'LOW';
      description = `Rough conditions in ${route.name}. Wind speeds ${Math.round(windSpeed)} km/h.`;
    }

    if (!type) return null;

    return {
      id: `weather-${route.name.replace(/\s+/g, '-')}-${Date.now()}`,
      type,
      severity,
      location: {
        lat: route.lat,
        lng: route.lng,
        name: route.name
      },
      description,
      windSpeed,
      waveHeight,
      visibility,
      affectedRoutes: route.routes,
      startTime: new Date(),
      endTime: new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 hours
    };
  }

  public getActiveAlerts(): WeatherAlert[] {
    const now = Date.now();
    return Array.from(this.weatherAlerts.values()).filter(
      alert => alert.endTime.getTime() > now
    );
  }

  public getAlertAtLocation(lat: number, lng: number, radius: number = 500): WeatherAlert | null {
    const activeAlerts = this.getActiveAlerts();
    
    for (const alert of activeAlerts) {
      const distance = this.calculateDistance(lat, lng, alert.location.lat, alert.location.lng);
      if (distance <= radius) {
        return alert;
      }
    }
    
    return null;
  }

  private calculateDistance(lat1: number, lng1: number, lat2: number, lng2: number): number {
    const R = 6371; // Earth's radius in km
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLng = (lng2 - lng1) * Math.PI / 180;
    const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
              Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
              Math.sin(dLng/2) * Math.sin(dLng/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    return R * c;
  }
}

export const weatherService = new WeatherService();
export type { WeatherAlert };