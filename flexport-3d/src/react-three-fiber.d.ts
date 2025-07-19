import { ReactThreeFiber } from '@react-three/fiber'

declare global {
  namespace JSX {
    interface IntrinsicElements {
      group: ReactThreeFiber.Object3DNode<THREE.Group, typeof THREE.Group>
      mesh: ReactThreeFiber.Object3DNode<THREE.Mesh, typeof THREE.Mesh>
      primitive: ReactThreeFiber.Object3DNode<any, any>
      sphereGeometry: ReactThreeFiber.Object3DNode<THREE.SphereGeometry, typeof THREE.SphereGeometry>
      boxGeometry: ReactThreeFiber.Object3DNode<THREE.BoxGeometry, typeof THREE.BoxGeometry>
      planeGeometry: ReactThreeFiber.Object3DNode<THREE.PlaneGeometry, typeof THREE.PlaneGeometry>
      shaderMaterial: ReactThreeFiber.MaterialNode<THREE.ShaderMaterial, typeof THREE.ShaderMaterial>
      meshBasicMaterial: ReactThreeFiber.MaterialNode<THREE.MeshBasicMaterial, typeof THREE.MeshBasicMaterial>
      meshStandardMaterial: ReactThreeFiber.MaterialNode<THREE.MeshStandardMaterial, typeof THREE.MeshStandardMaterial>
      ambientLight: ReactThreeFiber.Object3DNode<THREE.AmbientLight, typeof THREE.AmbientLight>
      directionalLight: ReactThreeFiber.Object3DNode<THREE.DirectionalLight, typeof THREE.DirectionalLight>
      pointLight: ReactThreeFiber.Object3DNode<THREE.PointLight, typeof THREE.PointLight>
      spotLight: ReactThreeFiber.Object3DNode<THREE.SpotLight, typeof THREE.SpotLight>
    }
  }
}

export {}