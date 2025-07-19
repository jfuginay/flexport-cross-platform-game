// @ts-nocheck
import * as THREE from 'three';
import { ShipType } from '../../types/game.types';

export function createShip3DModel(shipType: ShipType): THREE.Group {
  const shipGroup = new THREE.Group();
  
  // Materials
  const hullMaterial = new THREE.MeshPhongMaterial({ 
    color: 0x2c3e50,
    shininess: 100
  });
  
  const deckMaterial = new THREE.MeshPhongMaterial({ 
    color: 0x34495e
  });
  
  const containerMaterial = new THREE.MeshPhongMaterial({ 
    color: 0xe74c3c
  });
  
  const bridgeMaterial = new THREE.MeshPhongMaterial({ 
    color: 0xecf0f1,
    emissive: 0x2c3e50,
    emissiveIntensity: 0.1
  });
  
  // Base ship hull (common to all types)
  const hullShape = new THREE.Shape();
  hullShape.moveTo(-0.4, -1);
  hullShape.lineTo(-0.5, -0.8);
  hullShape.lineTo(-0.5, 0.8);
  hullShape.lineTo(-0.3, 1);
  hullShape.lineTo(0.3, 1);
  hullShape.lineTo(0.5, 0.8);
  hullShape.lineTo(0.5, -0.8);
  hullShape.lineTo(0.4, -1);
  hullShape.closePath();
  
  const extrudeSettings = {
    steps: 1,
    depth: 0.3,
    bevelEnabled: true,
    bevelThickness: 0.02,
    bevelSize: 0.02,
    bevelSegments: 3
  };
  
  const hullGeometry = new THREE.ExtrudeGeometry(hullShape, extrudeSettings);
  const hull = new THREE.Mesh(hullGeometry, hullMaterial);
  hull.rotation.x = Math.PI / 2;
  hull.position.y = -0.15;
  hull.castShadow = true;
  hull.receiveShadow = true;
  shipGroup.add(hull);
  
  // Ship-specific features
  switch (shipType) {
    case ShipType.CONTAINER:
      // Container ship with stacked containers
      const containerColors = [0xe74c3c, 0xf39c12, 0x3498db, 0x2ecc71];
      
      for (let row = 0; row < 3; row++) {
        for (let col = 0; col < 4; col++) {
          for (let stack = 0; stack < 2; stack++) {
            const container = new THREE.Mesh(
              new THREE.BoxGeometry(0.2, 0.15, 0.15),
              new THREE.MeshPhongMaterial({ 
                color: containerColors[(row + col + stack) % containerColors.length] 
              })
            );
            container.position.set(
              -0.3 + col * 0.2,
              stack * 0.15,
              -0.3 + row * 0.2
            );
            container.castShadow = true;
            shipGroup.add(container);
          }
        }
      }
      
      // Bridge at the back
      const containerBridge = new THREE.Mesh(
        new THREE.BoxGeometry(0.3, 0.4, 0.4),
        bridgeMaterial
      );
      containerBridge.position.set(0, 0.2, -0.6);
      containerBridge.castShadow = true;
      shipGroup.add(containerBridge);
      break;
      
    case ShipType.BULK:
      // Bulk carrier with cargo holds
      const cargoHolds = [];
      for (let i = 0; i < 4; i++) {
        const hold = new THREE.Mesh(
          new THREE.CylinderGeometry(0.2, 0.2, 0.1, 8),
          new THREE.MeshPhongMaterial({ color: 0x8b4513 })
        );
        hold.position.set(0, 0.05, -0.4 + i * 0.25);
        hold.rotation.z = Math.PI / 2;
        hold.castShadow = true;
        shipGroup.add(hold);
      }
      
      // Bridge
      const bulkBridge = new THREE.Mesh(
        new THREE.BoxGeometry(0.3, 0.3, 0.3),
        bridgeMaterial
      );
      bulkBridge.position.set(0, 0.15, -0.6);
      bulkBridge.castShadow = true;
      shipGroup.add(bulkBridge);
      break;
      
    case ShipType.TANKER:
      // Oil tanker with cylindrical tanks
      const tankMaterial = new THREE.MeshPhongMaterial({ 
        color: 0xe67e22,
        metalness: 0.7,
        roughness: 0.3
      });
      
      for (let i = 0; i < 3; i++) {
        const tank = new THREE.Mesh(
          new THREE.CylinderGeometry(0.25, 0.25, 0.8, 16),
          tankMaterial
        );
        tank.rotation.z = Math.PI / 2;
        tank.position.set(0, 0.1, -0.3 + i * 0.3);
        tank.castShadow = true;
        shipGroup.add(tank);
      }
      
      // Bridge
      const tankerBridge = new THREE.Mesh(
        new THREE.BoxGeometry(0.3, 0.35, 0.35),
        bridgeMaterial
      );
      tankerBridge.position.set(0, 0.175, -0.7);
      tankerBridge.castShadow = true;
      shipGroup.add(tankerBridge);
      
      // Add pipes
      const pipeMaterial = new THREE.MeshPhongMaterial({ color: 0x7f8c8d });
      for (let i = 0; i < 2; i++) {
        const pipe = new THREE.Mesh(
          new THREE.CylinderGeometry(0.02, 0.02, 0.8),
          pipeMaterial
        );
        pipe.rotation.z = Math.PI / 2;
        pipe.position.set(-0.1 + i * 0.2, 0.25, 0);
        shipGroup.add(pipe);
      }
      break;
      
    case ShipType.CARGO_PLANE:
      // Cargo plane with wings and engines
      const fuselage = new THREE.Mesh(
        new THREE.CylinderGeometry(0.15, 0.15, 1.2, 8),
        new THREE.MeshPhongMaterial({ color: 0x95a5a6 })
      );
      fuselage.rotation.z = Math.PI / 2;
      fuselage.position.y = 0.2;
      fuselage.castShadow = true;
      shipGroup.add(fuselage);
      
      // Wings
      const wingGeometry = new THREE.BoxGeometry(1.5, 0.02, 0.3);
      const wingMaterial = new THREE.MeshPhongMaterial({ color: 0x7f8c8d });
      
      const wings = new THREE.Mesh(wingGeometry, wingMaterial);
      wings.position.y = 0.15;
      wings.castShadow = true;
      shipGroup.add(wings);
      
      // Engines
      for (let i = -1; i <= 1; i += 2) {
        const engine = new THREE.Mesh(
          new THREE.CylinderGeometry(0.05, 0.05, 0.2, 8),
          new THREE.MeshPhongMaterial({ color: 0x2c3e50 })
        );
        engine.rotation.z = Math.PI / 2;
        engine.position.set(i * 0.3, 0.1, 0.1);
        shipGroup.add(engine);
      }
      
      // Tail
      const tail = new THREE.Mesh(
        new THREE.BoxGeometry(0.02, 0.3, 0.2),
        wingMaterial
      );
      tail.position.set(0, 0.35, -0.5);
      tail.castShadow = true;
      shipGroup.add(tail);
      break;
  }
  
  // Add a subtle glow effect
  const glowLight = new THREE.PointLight(0xffffff, 0.5, 2);
  glowLight.position.set(0, 0.5, 0);
  shipGroup.add(glowLight);
  
  return shipGroup;
}

// Simplified low-poly version for LOD
export function createShip3DModelLOD(shipType: ShipType): THREE.Group {
  const shipGroup = new THREE.Group();
  
  // Simple box representation
  const color = {
    [ShipType.CONTAINER]: 0x3498db,
    [ShipType.BULK]: 0x8b4513,
    [ShipType.TANKER]: 0xe67e22,
    [ShipType.CARGO_PLANE]: 0x95a5a6
  }[shipType];
  
  const simpleMesh = new THREE.Mesh(
    new THREE.BoxGeometry(1, 0.3, 0.4),
    new THREE.MeshPhongMaterial({ color })
  );
  simpleMesh.castShadow = true;
  shipGroup.add(simpleMesh);
  
  return shipGroup;
}