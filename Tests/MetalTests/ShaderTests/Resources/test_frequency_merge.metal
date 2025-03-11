#include <metal_stdlib>
using namespace metal;

kernel void wiener_merge(
    device float4* input1 [[buffer(0)]],
    device float4* input2 [[buffer(1)]],
    device float* params [[buffer(2)]],
    device float4* output [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]])
{
    int width = int(params[0]);
    int height = int(params[1]);
    float noise = params[2];
    
    // Check bounds
    if (gid.x >= width || gid.y >= height) {
        return;
    }
    
    // Get index
    uint index = gid.y * width + gid.x;
    
    // In a real implementation, this would do a frequency domain merge with Wiener filtering
    // Here we just do a basic weighted average for testing
    float4 color1 = input1[index];
    float4 color2 = input2[index];
    
    // Simple weighted average based on signal-to-noise ratio
    float signal1 = length(color1.rgb);
    float signal2 = length(color2.rgb);
    
    float weight1 = signal1 / (signal1 + noise);
    float weight2 = signal2 / (signal2 + noise);
    
    float totalWeight = weight1 + weight2;
    if (totalWeight > 0) {
        weight1 /= totalWeight;
        weight2 /= totalWeight;
    } else {
        weight1 = weight2 = 0.5;
    }
    
    // Blend colors
    float4 result;
    result.rgb = color1.rgb * weight1 + color2.rgb * weight2;
    result.a = 1.0; // Preserve alpha
    
    output[index] = result;
} 