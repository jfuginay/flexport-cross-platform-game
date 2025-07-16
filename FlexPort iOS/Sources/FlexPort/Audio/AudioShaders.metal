#include <metal_stdlib>
using namespace metal;

// MARK: - Audio Processing Structures

struct AudioSource {
    float3 position;
    float3 velocity;
    float volume;
    float pitch;
    float distance;
    float attenuation;
    float dopplerShift;
    uint isActive;
};

struct ListenerData {
    float3 position;
    float3 forward;
    float3 up;
    float3 right;
};

struct AudioProcessingParams {
    uint sourceCount;
    float spatialBlendDistance;
    float dopplerFactor;
    float rolloffFactor;
    float speedOfSound;
    float deltaTime;
};

// MARK: - Utility Functions

float calculateDistance(float3 sourcePos, float3 listenerPos) {
    float3 diff = sourcePos - listenerPos;
    return length(diff);
}

float calculateAttenuation(float distance, float rolloffFactor, float spatialBlendDistance) {
    float reference = 1.0;
    
    if (distance <= reference) {
        return 1.0;
    }
    
    if (distance >= spatialBlendDistance) {
        return 0.0;
    }
    
    // Logarithmic rolloff
    return reference / (reference + rolloffFactor * (distance - reference));
}

float calculateDopplerShift(float3 sourceVel, float3 listenerVel, float3 direction, float dopplerFactor, float speedOfSound) {
    float3 relativeVelocity = sourceVel - listenerVel;
    float radialVelocity = dot(relativeVelocity, direction);
    
    return (speedOfSound + dopplerFactor * radialVelocity) / speedOfSound;
}

float3 calculatePanningVector(float3 sourcePos, float3 listenerPos, float3 listenerForward, float3 listenerRight, float3 listenerUp) {
    float3 toSource = normalize(sourcePos - listenerPos);
    
    float pan_x = dot(toSource, listenerRight);    // Left(-1) to Right(+1)
    float pan_y = dot(toSource, listenerUp);       // Down(-1) to Up(+1)
    float pan_z = dot(toSource, listenerForward);  // Back(-1) to Front(+1)
    
    return float3(pan_x, pan_y, pan_z);
}

// MARK: - Main Audio Processing Kernels

/// Process spatial audio for multiple sources efficiently
kernel void spatialAudioProcessor(device AudioSource* sources [[buffer(0)]],
                                device const ListenerData& listener [[buffer(1)]],
                                device const AudioProcessingParams& params [[buffer(2)]],
                                uint sourceIndex [[thread_position_in_grid]]) {
    
    if (sourceIndex >= params.sourceCount) {
        return;
    }
    
    device AudioSource& source = sources[sourceIndex];
    
    if (!source.isActive) {
        return;
    }
    
    // Calculate distance
    source.distance = calculateDistance(source.position, listener.position);
    
    // Calculate attenuation
    source.attenuation = calculateAttenuation(source.distance, params.rolloffFactor, params.spatialBlendDistance);
    
    // Calculate doppler shift
    float3 direction = normalize(source.position - listener.position);
    source.dopplerShift = calculateDopplerShift(source.velocity, float3(0, 0, 0), direction, 
                                               params.dopplerFactor, params.speedOfSound);
    
    // Clamp values
    source.attenuation = clamp(source.attenuation, 0.0, 1.0);
    source.dopplerShift = clamp(source.dopplerShift, 0.5, 2.0);
}

/// Advanced reverb processing for environmental audio
kernel void environmentalReverbProcessor(device float* audioBuffer [[buffer(0)]],
                                        device float* reverbBuffer [[buffer(1)]],
                                        device const float* environmentParams [[buffer(2)]],
                                        uint bufferIndex [[thread_position_in_grid]],
                                        uint bufferSize [[threads_per_grid]]) {
    
    if (bufferIndex >= bufferSize) {
        return;
    }
    
    float wetness = environmentParams[0];
    float roomSize = environmentParams[1];
    float damping = environmentParams[2];
    float spread = environmentParams[3];
    
    // Simple reverb implementation
    float input = audioBuffer[bufferIndex];
    float reverb = reverbBuffer[bufferIndex] * damping;
    
    // Combine dry and wet signals
    float output = input * (1.0 - wetness) + reverb * wetness;
    
    audioBuffer[bufferIndex] = output;
    
    // Update reverb buffer for next frame
    reverbBuffer[bufferIndex] = input + reverb * roomSize;
}

/// Real-time convolution for impulse response reverb
kernel void convolutionReverb(device const float* inputBuffer [[buffer(0)]],
                            device const float* impulseResponse [[buffer(1)]],
                            device float* outputBuffer [[buffer(2)]],
                            device const uint& inputSize [[buffer(3)]],
                            device const uint& impulseSize [[buffer(4)]],
                            uint outputIndex [[thread_position_in_grid]]) {
    
    if (outputIndex >= inputSize + impulseSize - 1) {
        return;
    }
    
    float sum = 0.0;
    
    for (uint i = 0; i < impulseSize; i++) {
        int inputIndex = int(outputIndex) - int(i);
        
        if (inputIndex >= 0 && inputIndex < int(inputSize)) {
            sum += inputBuffer[inputIndex] * impulseResponse[i];
        }
    }
    
    outputBuffer[outputIndex] = sum;
}

/// Dynamic range compression for consistent audio levels
kernel void dynamicRangeCompressor(device float* audioBuffer [[buffer(0)]],
                                 device float* compressorState [[buffer(1)]],
                                 device const float* compressionParams [[buffer(2)]],
                                 uint sampleIndex [[thread_position_in_grid]],
                                 uint bufferSize [[threads_per_grid]]) {
    
    if (sampleIndex >= bufferSize) {
        return;
    }
    
    float threshold = compressionParams[0];
    float ratio = compressionParams[1];
    float attackTime = compressionParams[2];
    float releaseTime = compressionParams[3];
    float makeup = compressionParams[4];
    
    float input = audioBuffer[sampleIndex];
    float inputLevel = abs(input);
    
    // Get previous envelope state
    float envelope = compressorState[0];
    
    // Envelope follower
    if (inputLevel > envelope) {
        envelope = inputLevel * attackTime + envelope * (1.0 - attackTime);
    } else {
        envelope = inputLevel * releaseTime + envelope * (1.0 - releaseTime);
    }
    
    // Calculate compression gain
    float gainReduction = 1.0;
    if (envelope > threshold) {
        float overThreshold = envelope - threshold;
        gainReduction = threshold + overThreshold / ratio;
        gainReduction = gainReduction / envelope;
    }
    
    // Apply compression and makeup gain
    float output = input * gainReduction * makeup;
    
    audioBuffer[sampleIndex] = output;
    compressorState[0] = envelope;
}

/// Multi-band equalizer processing
kernel void multibandEqualizer(device float* audioBuffer [[buffer(0)]],
                             device float* filterStates [[buffer(1)]],
                             device const float* eqParams [[buffer(2)]],
                             uint sampleIndex [[thread_position_in_grid]],
                             uint bufferSize [[threads_per_grid]]) {
    
    if (sampleIndex >= bufferSize) {
        return;
    }
    
    float input = audioBuffer[sampleIndex];
    float output = input;
    
    // Process through multiple EQ bands
    for (uint band = 0; band < 10; band++) {
        float frequency = eqParams[band * 4 + 0];
        float gain = eqParams[band * 4 + 1];
        float q = eqParams[band * 4 + 2];
        float type = eqParams[band * 4 + 3];
        
        // Simple biquad filter implementation
        float a0 = 1.0;
        float a1 = -2.0 * cos(2.0 * M_PI_F * frequency / 48000.0);
        float a2 = 1.0;
        float b0 = gain;
        float b1 = 0.0;
        float b2 = 0.0;
        
        // Apply filter
        uint stateOffset = band * 4;
        float x1 = filterStates[stateOffset + 0];
        float x2 = filterStates[stateOffset + 1];
        float y1 = filterStates[stateOffset + 2];
        float y2 = filterStates[stateOffset + 3];
        
        float filteredOutput = b0 * output + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
        
        // Update filter states
        filterStates[stateOffset + 0] = output;
        filterStates[stateOffset + 1] = x1;
        filterStates[stateOffset + 2] = filteredOutput;
        filterStates[stateOffset + 3] = y1;
        
        output = filteredOutput;
    }
    
    audioBuffer[sampleIndex] = output;
}

/// Advanced HRTF processing for binaural spatial audio
kernel void hrtfProcessor(device const float* monoInput [[buffer(0)]],
                        device float* leftOutput [[buffer(1)]],
                        device float* rightOutput [[buffer(2)]],
                        device const float* leftHRTF [[buffer(3)]],
                        device const float* rightHRTF [[buffer(4)]],
                        device const uint& hrtfSize [[buffer(5)]],
                        uint outputIndex [[thread_position_in_grid]],
                        uint bufferSize [[threads_per_grid]]) {
    
    if (outputIndex >= bufferSize) {
        return;
    }
    
    float leftSum = 0.0;
    float rightSum = 0.0;
    
    // Convolve with HRTF impulse responses
    for (uint i = 0; i < hrtfSize; i++) {
        int inputIndex = int(outputIndex) - int(i);
        
        if (inputIndex >= 0 && inputIndex < int(bufferSize)) {
            float inputSample = monoInput[inputIndex];
            leftSum += inputSample * leftHRTF[i];
            rightSum += inputSample * rightHRTF[i];
        }
    }
    
    leftOutput[outputIndex] = leftSum;
    rightOutput[outputIndex] = rightSum;
}

/// Ambient occlusion for audio (sound blocking by geometry)
kernel void audioOcclusionProcessor(device AudioSource* sources [[buffer(0)]],
                                  device const float3* geometry [[buffer(1)]],
                                  device const ListenerData& listener [[buffer(2)]],
                                  device const uint& geometryCount [[buffer(3)]],
                                  uint sourceIndex [[thread_position_in_grid]],
                                  uint sourceCount [[threads_per_grid]]) {
    
    if (sourceIndex >= sourceCount) {
        return;
    }
    
    device AudioSource& source = sources[sourceIndex];
    
    if (!source.isActive) {
        return;
    }
    
    float3 sourceToListener = listener.position - source.position;
    float distance = length(sourceToListener);
    float3 direction = sourceToListener / distance;
    
    float occlusion = 1.0;
    
    // Simple ray-casting for occlusion
    for (uint i = 0; i < geometryCount; i += 3) {
        float3 v0 = geometry[i];
        float3 v1 = geometry[i + 1];
        float3 v2 = geometry[i + 2];
        
        // Ray-triangle intersection test (simplified)
        float3 edge1 = v1 - v0;
        float3 edge2 = v2 - v0;
        float3 h = cross(direction, edge2);
        float a = dot(edge1, h);
        
        if (a > -0.00001 && a < 0.00001) {
            continue; // Ray is parallel to triangle
        }
        
        float f = 1.0 / a;
        float3 s = source.position - v0;
        float u = f * dot(s, h);
        
        if (u < 0.0 || u > 1.0) {
            continue;
        }
        
        float3 q = cross(s, edge1);
        float v = f * dot(direction, q);
        
        if (v < 0.0 || u + v > 1.0) {
            continue;
        }
        
        float t = f * dot(edge2, q);
        
        if (t > 0.00001 && t < distance) {
            occlusion *= 0.7; // Reduce volume for each obstacle
        }
    }
    
    source.attenuation *= occlusion;
}

/// Weather-based audio processing (wind, rain, etc.)
kernel void weatherAudioProcessor(device float* audioBuffer [[buffer(0)]],
                                device const float* weatherParams [[buffer(1)]],
                                device float* noiseBuffer [[buffer(2)]],
                                uint sampleIndex [[thread_position_in_grid]],
                                uint bufferSize [[threads_per_grid]]) {
    
    if (sampleIndex >= bufferSize) {
        return;
    }
    
    float windStrength = weatherParams[0];
    float rainIntensity = weatherParams[1];
    float fogDensity = weatherParams[2];
    float temperature = weatherParams[3];
    
    float input = audioBuffer[sampleIndex];
    
    // Apply weather effects
    float weatherAttenuation = 1.0 - (fogDensity * 0.3);
    float windNoise = noiseBuffer[sampleIndex] * windStrength * 0.1;
    float rainNoise = noiseBuffer[(sampleIndex + 1000) % bufferSize] * rainIntensity * 0.05;
    
    // Temperature affects sound propagation
    float temperatureEffect = 1.0 + (temperature - 20.0) * 0.001;
    
    float output = (input * weatherAttenuation + windNoise + rainNoise) * temperatureEffect;
    
    audioBuffer[sampleIndex] = output;
}