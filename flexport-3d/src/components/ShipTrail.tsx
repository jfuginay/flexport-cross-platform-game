// @ts-nocheck
import React, { useRef, useMemo } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';

interface ShipTrailProps {
  shipPosition: THREE.Vector3;
  isMoving: boolean;
}

export const ShipTrail: React.FC<ShipTrailProps> = ({ shipPosition, isMoving }) => {
  const trailRef = useRef<THREE.Mesh>(null);
  const trailPositions = useRef<THREE.Vector3[]>([]);
  const maxTrailLength = 50;
  
  const trailGeometry = useMemo(() => {
    const geometry = new THREE.BufferGeometry();
    const positions = new Float32Array(maxTrailLength * 6 * 3); // 2 triangles per segment
    geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    
    const uvs = new Float32Array(maxTrailLength * 6 * 2);
    geometry.setAttribute('uv', new THREE.BufferAttribute(uvs, 2));
    
    return geometry;
  }, []);
  
  const trailMaterial = useMemo(() => {
    return new THREE.ShaderMaterial({
      transparent: true,
      side: THREE.DoubleSide,
      uniforms: {
        time: { value: 0 },
      },
      vertexShader: `
        varying vec2 vUv;
        void main() {
          vUv = uv;
          gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        }
      `,
      fragmentShader: `
        uniform float time;
        varying vec2 vUv;
        void main() {
          float foam = sin(vUv.x * 10.0 + time * 2.0) * 0.5 + 0.5;
          float alpha = (1.0 - vUv.x) * 0.6 * foam;
          gl_FragColor = vec4(1.0, 1.0, 1.0, alpha);
        }
      `,
    });
  }, []);
  
  useFrame((state, delta) => {
    if (!trailRef.current || !isMoving) return;
    
    // Update trail positions
    trailPositions.current.unshift(shipPosition.clone());
    if (trailPositions.current.length > maxTrailLength) {
      trailPositions.current.pop();
    }
    
    // Update geometry
    const positions = trailRef.current.geometry.attributes.position;
    const uvs = trailRef.current.geometry.attributes.uv;
    
    for (let i = 0; i < trailPositions.current.length - 1; i++) {
      const current = trailPositions.current[i];
      const next = trailPositions.current[i + 1];
      
      const direction = new THREE.Vector3().subVectors(next, current).normalize();
      const perpendicular = new THREE.Vector3(-direction.z, 0, direction.x);
      
      const width = 2 * (1 - i / trailPositions.current.length);
      
      const v1 = current.clone().add(perpendicular.clone().multiplyScalar(width));
      const v2 = current.clone().sub(perpendicular.clone().multiplyScalar(width));
      const v3 = next.clone().add(perpendicular.clone().multiplyScalar(width));
      const v4 = next.clone().sub(perpendicular.clone().multiplyScalar(width));
      
      const index = i * 6;
      
      // First triangle
      positions.setXYZ(index, v1.x, 0.1, v1.z);
      positions.setXYZ(index + 1, v2.x, 0.1, v2.z);
      positions.setXYZ(index + 2, v3.x, 0.1, v3.z);
      
      // Second triangle
      positions.setXYZ(index + 3, v2.x, 0.1, v2.z);
      positions.setXYZ(index + 4, v4.x, 0.1, v4.z);
      positions.setXYZ(index + 5, v3.x, 0.1, v3.z);
      
      // UVs
      const u = i / trailPositions.current.length;
      uvs.setXY(index, u, 0);
      uvs.setXY(index + 1, u, 1);
      uvs.setXY(index + 2, u + 1 / trailPositions.current.length, 0);
      uvs.setXY(index + 3, u, 1);
      uvs.setXY(index + 4, u + 1 / trailPositions.current.length, 1);
      uvs.setXY(index + 5, u + 1 / trailPositions.current.length, 0);
    }
    
    positions.needsUpdate = true;
    uvs.needsUpdate = true;
    
    // Update time uniform
    trailMaterial.uniforms.time.value = state.clock.elapsedTime;
  });
  
  return <mesh ref={trailRef} geometry={trailGeometry} material={trailMaterial} />;
};