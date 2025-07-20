// Real-world port data with accurate coordinates and traffic volumes
export const realWorldPortsGeoJSON = {
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [121.4956, 31.2270]
      },
      "properties": {
        "name": "Port of Shanghai",
        "country": "China",
        "details": "Busiest container port globally, handles vast trade volume, major gateway for China, located on Yangtze River Delta.",
        "container_traffic_2022_teu": 47303000, // Convert to actual TEUs (thousands)
        "rank": 1
      }
    },
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [103.8631, 1.2814]
      },
      "properties": {
        "name": "Port of Singapore",
        "country": "Singapore",
        "details": "Leading global transshipment hub, connects major shipping lanes, renowned for efficiency.",
        "container_traffic_2022_teu": 37289000,
        "rank": 2
      }
    },
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [121.5515, 29.8661]
      },
      "properties": {
        "name": "Port of Ningbo-Zhoushan",
        "country": "China",
        "details": "Strategic location on China's eastern coast, known for deepwater berths, important hub in Asia.",
        "container_traffic_2022_teu": 33351000,
        "rank": 3
      }
    },
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [114.1667, 22.3080]
      },
      "properties": {
        "name": "Port of Hong Kong",
        "country": "China",
        "details": "Rich maritime history, significant logistics hub despite competition from nearby ports.",
        "container_traffic_2022_teu": 16685000,
        "rank": 7
      }
    },
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [4.47917, 51.9225]
      },
      "properties": {
        "name": "Port of Rotterdam",
        "country": "Netherlands",
        "details": "Europe's largest port, crucial gateway for goods, particularly for trade with Asia.",
        "container_traffic_2022_teu": 14455000,
        "rank": 8
      }
    },
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [-118.2619, 33.7366]
      },
      "properties": {
        "name": "Port of Los Angeles",
        "country": "United States",
        "details": "Busiest container port in the U.S., major global gateway for trade, particularly from Asia.",
        "container_traffic_2022_teu": 19044000,
        "rank": 6
      }
    },
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [-74.0532, 40.6865]
      },
      "properties": {
        "name": "Port of New York and New Jersey",
        "country": "United States",
        "details": "Largest port on the U.S. East Coast, key gateway for international trade with Europe, Asia, and Latin America.",
        "container_traffic_2022_teu": 9493000,
        "rank": 12
      }
    },
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [129.0525, 35.0872]
      },
      "properties": {
        "name": "Port of Busan",
        "country": "South Korea",
        "details": "Advanced facilities and strategic location, key transshipment hub for Northeast Asia.",
        "container_traffic_2022_teu": 22078000,
        "rank": 5
      }
    },
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [55.0280, 24.9857]
      },
      "properties": {
        "name": "Port of Jebel Ali",
        "country": "United Arab Emirates",
        "details": "Largest in the Middle East, world's largest artificial harbor, deepwater port.",
        "container_traffic_2022_teu": 13970000,
        "rank": 9
      }
    },
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [4.3997, 51.2217]
      },
      "properties": {
        "name": "Port of Antwerp-Bruges",
        "country": "Belgium",
        "details": "Europe's second-largest port, significant hub for container and bulk cargo.",
        "container_traffic_2022_teu": 13500000,
        "rank": 10
      }
    }
  ]
};

// Additional major ports to expand the network
export const additionalMajorPorts = [
  {
    name: "Port of Hamburg",
    country: "Germany",
    coordinates: [9.9675, 53.5445],
    container_traffic_2022_teu: 8300000,
    details: "Germany's largest port, known as 'Gateway to the World'"
  },
  {
    name: "Port of Long Beach",
    country: "United States",
    coordinates: [-118.2149, 33.7520],
    container_traffic_2022_teu: 9133000,
    details: "Second busiest U.S. port, adjacent to Los Angeles"
  },
  {
    name: "Port of Tokyo",
    country: "Japan",
    coordinates: [139.7744, 35.6329],
    container_traffic_2022_teu: 4300000,
    details: "Japan's major port serving the greater Tokyo area"
  },
  {
    name: "Port of Santos",
    country: "Brazil",
    coordinates: [-46.3067, -23.9608],
    container_traffic_2022_teu: 4700000,
    details: "Latin America's largest port"
  },
  {
    name: "Port of Durban",
    country: "South Africa",
    coordinates: [31.0292, -29.8587],
    container_traffic_2022_teu: 2700000,
    details: "Africa's busiest container port"
  }
];

// Helper function to convert GeoJSON to game port format
export function convertGeoJSONToGamePort(feature: any, index: number, earthRadius: number = 100) {
  const [lng, lat] = feature.geometry.coordinates;
  const properties = feature.properties;
  
  // Convert lat/lng to 3D coordinates on sphere
  const phi = (90 - lat) * (Math.PI / 180);
  const theta = (lng + 180) * (Math.PI / 180);
  
  const x = -(earthRadius * Math.sin(phi) * Math.cos(theta));
  const y = earthRadius * Math.cos(phi);
  const z = earthRadius * Math.sin(phi) * Math.sin(theta);
  
  return {
    id: `port-${index}`,
    name: properties.name,
    position: { x, y, z, lat, lng },
    country: properties.country,
    capacity: Math.floor(properties.container_traffic_2022_teu / 10000), // Scale down for game
    currentLoad: Math.floor(Math.random() * 0.7 * properties.container_traffic_2022_teu / 10000),
    isPlayerOwned: properties.name === "Port of Los Angeles", // Player starts with LA
    berths: Math.floor(properties.container_traffic_2022_teu / 1000000) + 5,
    availableBerths: Math.floor(Math.random() * 5) + 3,
    loadingSpeed: 50 + Math.floor(properties.container_traffic_2022_teu / 500000),
    dockedShips: [],
    contracts: [],
    details: properties.details,
    realTrafficTEU: properties.container_traffic_2022_teu,
    worldRank: properties.rank || null
  };
}