import React, { useRef } from 'react';
import { 
  EffectComposer, 
  Bloom, 
  ChromaticAberration,
  DepthOfField,
  Noise,
  Vignette,
  BrightnessContrast,
  HueSaturation,
  SSAO,
  ToneMapping,
  GodRays
} from '@react-three/postprocessing';
import { BlendFunction, ToneMappingMode } from 'postprocessing';
import { Vector2 } from 'three';

export const PostProcessingEffects: React.FC = () => {
  const sunRef = useRef<any>(null);
  
  // Adjust effects based on weather
  const bloomIntensity = 1.2;
  const vignetteIntensity = 0.4;
  
  return (
    <EffectComposer multisampling={4}>
      {/* Bloom for glowing lights and highlights */}
      <Bloom
        intensity={bloomIntensity}
        luminanceThreshold={0.6}
        luminanceSmoothing={0.9}
        height={300}
        mipmapBlur
      />
      
      {/* Screen Space Ambient Occlusion for depth */}
      <SSAO
        samples={16}
        radius={0.05}
        intensity={15}
        luminanceInfluence={0.3}
      />
      
      {/* Depth of Field for cinematic focus */}
      <DepthOfField
        focusDistance={0.02}
        focalLength={0.05}
        bokehScale={3}
        height={480}
      />
      
      {/* Tone Mapping for HDR-like visuals */}
      <ToneMapping
        mode={ToneMappingMode.ACES_FILMIC}
        resolution={256}
        whitePoint={4.0}
        middleGrey={0.5}
      />
      
      {/* Chromatic Aberration for lens distortion */}
      <ChromaticAberration
        blendFunction={BlendFunction.NORMAL}
        offset={new Vector2(0.001, 0.001)}
      />
      
      {/* Vignette for darkened edges */}
      <Vignette
        offset={0.3}
        darkness={vignetteIntensity}
        blendFunction={BlendFunction.NORMAL}
      />
      
      {/* Brightness and Contrast adjustments */}
      <BrightnessContrast
        brightness={0.05}
        contrast={0.1}
      />
      
      {/* Hue and Saturation for color grading */}
      <HueSaturation
        hue={0}
        saturation={0.1}
      />
      
      {/* Film grain for cinematic texture */}
      <Noise
        premultiply
        blendFunction={BlendFunction.ADD}
        opacity={0.02}
      />
    </EffectComposer>
  );
};