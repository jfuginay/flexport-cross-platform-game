// @ts-nocheck
import * as THREE from 'three';

export function createPort3DModel(capacity: number): THREE.Group {
  const portGroup = new THREE.Group();
  portGroup.name = 'port';
  
  // Materials
  const concreteMaterial = new THREE.MeshPhongMaterial({ 
    color: 0x95a5a6,
    roughness: 0.8
  });
  
  const buildingMaterial = new THREE.MeshPhongMaterial({ 
    color: 0xecf0f1
  });
  
  const roofMaterial = new THREE.MeshPhongMaterial({ 
    color: 0x34495e
  });
  
  const craneMaterial = new THREE.MeshPhongMaterial({ 
    color: 0xe74c3c,
    metalness: 0.6,
    roughness: 0.4
  });
  
  const containerMaterial = new THREE.MeshPhongMaterial({ 
    color: 0x3498db
  });
  
  // Port platform/dock
  const dock = new THREE.Mesh(
    new THREE.BoxGeometry(2, 0.1, 1.5),
    concreteMaterial
  );
  dock.position.y = -0.05;
  dock.receiveShadow = true;
  portGroup.add(dock);
  
  // Main warehouse building
  const warehouse = new THREE.Mesh(
    new THREE.BoxGeometry(0.8, 0.4, 0.6),
    buildingMaterial
  );
  warehouse.position.set(-0.4, 0.2, 0);
  warehouse.castShadow = true;
  warehouse.receiveShadow = true;
  portGroup.add(warehouse);
  
  // Warehouse roof
  const warehouseRoof = new THREE.Mesh(
    new THREE.ConeGeometry(0.5, 0.2, 4),
    roofMaterial
  );
  warehouseRoof.rotation.y = Math.PI / 4;
  warehouseRoof.position.set(-0.4, 0.5, 0);
  warehouseRoof.castShadow = true;
  portGroup.add(warehouseRoof);
  
  // Storage tanks (for larger ports)
  if (capacity > 5000) {
    const tankMaterial = new THREE.MeshPhongMaterial({ 
      color: 0x7f8c8d,
      metalness: 0.7,
      roughness: 0.3
    });
    
    for (let i = 0; i < 2; i++) {
      const tank = new THREE.Mesh(
        new THREE.CylinderGeometry(0.15, 0.15, 0.3, 12),
        tankMaterial
      );
      tank.position.set(0.3, 0.15, -0.3 + i * 0.3);
      tank.castShadow = true;
      portGroup.add(tank);
      
      // Tank top
      const tankTop = new THREE.Mesh(
        new THREE.ConeGeometry(0.15, 0.1, 12),
        tankMaterial
      );
      tankTop.position.set(0.3, 0.35, -0.3 + i * 0.3);
      tankTop.castShadow = true;
      portGroup.add(tankTop);
    }
  }
  
  // Container cranes
  const numCranes = Math.min(Math.floor(capacity / 3000), 3);
  for (let i = 0; i < numCranes; i++) {
    const craneGroup = new THREE.Group();
    craneGroup.name = 'crane';
    
    // Crane base
    const craneBase = new THREE.Mesh(
      new THREE.BoxGeometry(0.1, 0.6, 0.1),
      craneMaterial
    );
    craneBase.position.y = 0.3;
    craneBase.castShadow = true;
    craneGroup.add(craneBase);
    
    // Crane arm
    const craneArm = new THREE.Mesh(
      new THREE.BoxGeometry(0.5, 0.08, 0.08),
      craneMaterial
    );
    craneArm.position.set(0.2, 0.55, 0);
    craneArm.castShadow = true;
    craneGroup.add(craneArm);
    
    // Crane cable
    const cableGeometry = new THREE.CylinderGeometry(0.01, 0.01, 0.3);
    const cable = new THREE.Mesh(
      cableGeometry,
      new THREE.MeshPhongMaterial({ color: 0x2c3e50 })
    );
    cable.position.set(0.4, 0.4, 0);
    craneGroup.add(cable);
    
    // Hanging container
    const hangingContainer = new THREE.Mesh(
      new THREE.BoxGeometry(0.15, 0.1, 0.1),
      containerMaterial
    );
    hangingContainer.position.set(0.4, 0.2, 0);
    hangingContainer.castShadow = true;
    craneGroup.add(hangingContainer);
    
    craneGroup.position.set(0.5 - i * 0.3, 0, 0.4);
    portGroup.add(craneGroup);
  }
  
  // Stacked containers
  const containerColors = [0xe74c3c, 0xf39c12, 0x3498db, 0x2ecc71];
  const stackHeight = Math.min(Math.floor(capacity / 2000), 4);
  
  for (let x = 0; x < 3; x++) {
    for (let z = 0; z < 2; z++) {
      for (let y = 0; y < stackHeight; y++) {
        const container = new THREE.Mesh(
          new THREE.BoxGeometry(0.15, 0.1, 0.1),
          new THREE.MeshPhongMaterial({ 
            color: containerColors[(x + z + y) % containerColors.length] 
          })
        );
        container.position.set(
          -0.2 + x * 0.16,
          0.05 + y * 0.11,
          -0.5 + z * 0.12
        );
        container.castShadow = true;
        portGroup.add(container);
      }
    }
  }
  
  // Office building (for larger ports)
  if (capacity > 7000) {
    const office = new THREE.Mesh(
      new THREE.BoxGeometry(0.3, 0.5, 0.3),
      buildingMaterial
    );
    office.position.set(-0.7, 0.25, -0.4);
    office.castShadow = true;
    portGroup.add(office);
    
    // Windows
    const windowMaterial = new THREE.MeshPhongMaterial({ 
      color: 0x3498db,
      emissive: 0x3498db,
      emissiveIntensity: 0.2
    });
    
    for (let floor = 0; floor < 4; floor++) {
      for (let window = 0; window < 3; window++) {
        const windowMesh = new THREE.Mesh(
          new THREE.PlaneGeometry(0.05, 0.08),
          windowMaterial
        );
        windowMesh.position.set(
          -0.549,
          0.1 + floor * 0.12,
          -0.5 + window * 0.1
        );
        windowMesh.rotation.y = Math.PI / 2;
        portGroup.add(windowMesh);
      }
    }
  }
  
  // Port lights
  const lightPole = new THREE.Mesh(
    new THREE.CylinderGeometry(0.02, 0.02, 0.4),
    new THREE.MeshPhongMaterial({ color: 0x7f8c8d })
  );
  lightPole.position.set(0.8, 0.2, 0.5);
  portGroup.add(lightPole);
  
  const light = new THREE.PointLight(0xfff5e6, 0.8, 3);
  light.position.set(0.8, 0.4, 0.5);
  portGroup.add(light);
  
  // Add a subtle glow to indicate activity
  const portGlow = new THREE.PointLight(0x3498db, 0.5, 5);
  portGlow.position.set(0, 0.5, 0);
  portGroup.add(portGlow);
  
  return portGroup;
}

// Simplified low-poly version for LOD
export function createPort3DModelLOD(): THREE.Group {
  const portGroup = new THREE.Group();
  
  // Simple box representation
  const simpleDock = new THREE.Mesh(
    new THREE.BoxGeometry(1.5, 0.1, 1),
    new THREE.MeshPhongMaterial({ color: 0x95a5a6 })
  );
  simpleDock.position.y = -0.05;
  portGroup.add(simpleDock);
  
  const simpleBuilding = new THREE.Mesh(
    new THREE.BoxGeometry(0.5, 0.4, 0.4),
    new THREE.MeshPhongMaterial({ color: 0xecf0f1 })
  );
  simpleBuilding.position.y = 0.2;
  portGroup.add(simpleBuilding);
  
  return portGroup;
}