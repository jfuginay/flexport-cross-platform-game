// @ts-nocheck
import React from 'react';
import { Canvas } from '@react-three/fiber';

export const SimpleScene: React.FC = () => {
  return (
    <div style={{ width: '100%', height: '400px', background: 'black' }}>
      <Canvas>
        <ambientLight />
        <pointLight position={[10, 10, 10]} />
        <mesh>
          <boxGeometry />
          <meshStandardMaterial color="orange" />
        </mesh>
      </Canvas>
    </div>
  );
};