//
//  SKRenderer.m
//  SKRender
//
//  Created by Dimitri ALMON on 16/06/2025.
//

#import "SKRenderer.h"
#import "../Assets/SKModelLoader.h"
#import <simd/simd.h>

typedef struct {
    matrix_float4x4 modelViewProjectionMatrix;
    matrix_float4x4 normalMatrix;
    float time;
    float lightningIntensity;
    float stormPhase;
    float flashTiming;
} StormUniforms;

typedef struct {
    vector_float2 position;
    vector_float2 texCoord;
} QuadVertex;

typedef struct {
    vector_float3 position;
    float intensity;
    float branchFactor;
    float timeOffset;
} LightningVertex;

@interface SKRenderer ()
@property (nonatomic, strong) id<MTLRenderPipelineState> stormBackgroundPipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> lightningPipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> rainPipeline;
@property (nonatomic, strong) id<MTLDepthStencilState> depthStencilState;
@property (nonatomic, strong) id<MTLDepthStencilState> noDepthStencilState;
@property (nonatomic, strong) id<MTLBuffer> stormUniformBuffer;
@property (nonatomic, strong) id<MTLBuffer> backgroundQuadBuffer;
@property (nonatomic, strong) id<MTLBuffer> lightningBuffer;
@property (nonatomic, strong) id<MTLBuffer> rainParticleBuffer;
@property (nonatomic, assign) CFTimeInterval startTime;
@property (nonatomic, assign) matrix_float4x4 projectionMatrix;
@property (nonatomic, assign) matrix_float4x4 viewMatrix;
@property (nonatomic, assign) CGSize viewportSize;
@property (nonatomic, assign) int lightningVertexCount;
@property (nonatomic, assign) int rainParticleCount;
@end

@implementation SKRenderer

- (instancetype)initWithView:(MTKView *)view {
    NSLog(@"=== Lightning Storm Init ===");
    if (self = [super init]) {
        self.device = view.device;
        self.commandQueue = [self.device newCommandQueue];
        
        if (!self.commandQueue) {
            return nil;
        }
        
        self.viewportSize = view.drawableSize;
        [self setupStormPipelines];
        [self setupDepthStencil];
        [self setupStormBuffers];
        [self setupMatrices];
        [self generateLightningGeometry];
        [self generateRainParticles];
        
        self.startTime = CACurrentMediaTime();
        NSLog(@"⚡ Lightning storm renderer ready");
    }
    return self;
}

- (void)setupStormPipelines {
    id<MTLLibrary> library = [self.device newDefaultLibrary];
    if (!library) {
        NSLog(@"❌ Failed to create library");
        return;
    }
    
    [self setupStormBackgroundPipeline:library];
    [self setupLightningPipeline:library];
    [self setupRainPipeline:library];
    
    NSLog(@"⚡ Storm pipelines configured");
}

- (void)setupStormBackgroundPipeline:(id<MTLLibrary>)library {
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_background"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_storm_background"];
    
    if (!vertexFunction || !fragmentFunction) {
        NSLog(@"⚠️ Storm background shaders not found, using fallback");
        fragmentFunction = [library newFunctionWithName:@"fragment_background"];
    }
    
    MTLRenderPipelineDescriptor *descriptor = [[MTLRenderPipelineDescriptor alloc] init];
    descriptor.vertexFunction = vertexFunction;
    descriptor.fragmentFunction = fragmentFunction;
    descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    descriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    
    MTLVertexDescriptor *vertexDescriptor = [[MTLVertexDescriptor alloc] init];
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[1].offset = 8;
    vertexDescriptor.attributes[1].bufferIndex = 0;
    vertexDescriptor.layouts[0].stride = 16;
    
    descriptor.vertexDescriptor = vertexDescriptor;
    
    NSError *error;
    self.stormBackgroundPipeline = [self.device newRenderPipelineStateWithDescriptor:descriptor error:&error];
    if (error) {
        NSLog(@"❌ Storm background pipeline error: %@", error);
    }
}

- (void)setupLightningPipeline:(id<MTLLibrary>)library {
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_lightning"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_lightning"];
    
    if (!vertexFunction || !fragmentFunction) {
        NSLog(@"⚠️ Lightning shaders not found, using fallback");
        vertexFunction = [library newFunctionWithName:@"vertex_main"];
        fragmentFunction = [library newFunctionWithName:@"fragment_main"];
    }
    
    MTLRenderPipelineDescriptor *descriptor = [[MTLRenderPipelineDescriptor alloc] init];
    descriptor.vertexFunction = vertexFunction;
    descriptor.fragmentFunction = fragmentFunction;
    descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    descriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    
    descriptor.colorAttachments[0].blendingEnabled = YES;
    descriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    descriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    descriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    descriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;
    
    MTLVertexDescriptor *vertexDescriptor = [[MTLVertexDescriptor alloc] init];
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat3;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat;
    vertexDescriptor.attributes[1].offset = 12;
    vertexDescriptor.attributes[1].bufferIndex = 0;
    vertexDescriptor.attributes[2].format = MTLVertexFormatFloat;
    vertexDescriptor.attributes[2].offset = 16;
    vertexDescriptor.attributes[2].bufferIndex = 0;
    vertexDescriptor.attributes[3].format = MTLVertexFormatFloat;
    vertexDescriptor.attributes[3].offset = 20;
    vertexDescriptor.attributes[3].bufferIndex = 0;
    vertexDescriptor.layouts[0].stride = 24;
    
    descriptor.vertexDescriptor = vertexDescriptor;
    
    NSError *error;
    self.lightningPipeline = [self.device newRenderPipelineStateWithDescriptor:descriptor error:&error];
    if (error) {
        NSLog(@"❌ Lightning pipeline error: %@", error);
    }
}

- (void)setupRainPipeline:(id<MTLLibrary>)library {
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_rain"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_rain"];
    
    if (!vertexFunction || !fragmentFunction) {
        vertexFunction = [library newFunctionWithName:@"vertex_main"];
        fragmentFunction = [library newFunctionWithName:@"fragment_glassmorphism"];
    }
    
    MTLRenderPipelineDescriptor *descriptor = [[MTLRenderPipelineDescriptor alloc] init];
    descriptor.vertexFunction = vertexFunction;
    descriptor.fragmentFunction = fragmentFunction;
    descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    descriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    
    descriptor.colorAttachments[0].blendingEnabled = YES;
    descriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    descriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    
    MTLVertexDescriptor *vertexDescriptor = [[MTLVertexDescriptor alloc] init];
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat3;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat3;
    vertexDescriptor.attributes[1].offset = 12;
    vertexDescriptor.attributes[1].bufferIndex = 0;
    vertexDescriptor.attributes[2].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[2].offset = 24;
    vertexDescriptor.attributes[2].bufferIndex = 0;
    vertexDescriptor.layouts[0].stride = 32;
    
    descriptor.vertexDescriptor = vertexDescriptor;
    
    NSError *error;
    self.rainPipeline = [self.device newRenderPipelineStateWithDescriptor:descriptor error:&error];
    if (error) {
        NSLog(@"❌ Rain pipeline error: %@", error);
    }
}

- (void)setupDepthStencil {
    MTLDepthStencilDescriptor *depthDescriptor = [[MTLDepthStencilDescriptor alloc] init];
    depthDescriptor.depthCompareFunction = MTLCompareFunctionLess;
    depthDescriptor.depthWriteEnabled = YES;
    self.depthStencilState = [self.device newDepthStencilStateWithDescriptor:depthDescriptor];
    
    MTLDepthStencilDescriptor *noDepthDescriptor = [[MTLDepthStencilDescriptor alloc] init];
    noDepthDescriptor.depthCompareFunction = MTLCompareFunctionAlways;
    noDepthDescriptor.depthWriteEnabled = NO;
    self.noDepthStencilState = [self.device newDepthStencilStateWithDescriptor:noDepthDescriptor];
}

- (void)setupStormBuffers {
    self.stormUniformBuffer = [self.device newBufferWithLength:sizeof(StormUniforms) options:MTLResourceStorageModeShared];
    
    QuadVertex quadVertices[] = {
        {{-1.0f, -1.0f}, {0.0f, 1.0f}},
        {{ 1.0f, -1.0f}, {1.0f, 1.0f}},
        {{-1.0f,  1.0f}, {0.0f, 0.0f}},
        {{ 1.0f,  1.0f}, {1.0f, 0.0f}},
    };
    
    self.backgroundQuadBuffer = [self.device newBufferWithBytes:quadVertices
                                                        length:sizeof(quadVertices)
                                                       options:MTLResourceStorageModeShared];
}

- (void)setupMatrices {
    float aspect = self.viewportSize.width / self.viewportSize.height;
    float fovY = M_PI_4;
    float nearZ = 0.1f;
    float farZ = 100.0f;
    
    float ys = 1.0f / tanf(fovY * 0.5f);
    float xs = ys / aspect;
    float zs = farZ / (nearZ - farZ);
    
    self.projectionMatrix = (matrix_float4x4){{
        {xs,  0,  0,  0},
        {0,  ys,  0,  0},
        {0,   0, zs, -1},
        {0,   0, zs * nearZ, 0}
    }};
    
    vector_float3 eye = {0, 2, 12};
    vector_float3 target = {0, 0, 0};
    vector_float3 up = {0, 1, 0};
    
    vector_float3 zAxis = vector_normalize(eye - target);
    vector_float3 xAxis = vector_normalize(vector_cross(up, zAxis));
    vector_float3 yAxis = vector_cross(zAxis, xAxis);
    
    self.viewMatrix = (matrix_float4x4){{
        {xAxis.x, yAxis.x, zAxis.x, 0},
        {xAxis.y, yAxis.y, zAxis.y, 0},
        {xAxis.z, yAxis.z, zAxis.z, 0},
        {-vector_dot(xAxis, eye), -vector_dot(yAxis, eye), -vector_dot(zAxis, eye), 1}
    }};
}

- (void)generateLightningGeometry {
    int maxLightningVertices = 500;
    LightningVertex *lightningVertices = malloc(maxLightningVertices * sizeof(LightningVertex));
    
    int vertexIndex = 0;
    
    for (int bolt = 0; bolt < 3; bolt++) {
        float startX = (bolt - 1) * 8.0f;
        float startY = 15.0f;
        float currentX = startX;
        float currentY = startY;
        float timeOffset = bolt * 0.3f;
        
        for (int segment = 0; segment < 80 && vertexIndex < maxLightningVertices - 1; segment++) {
            float progress = (float)segment / 80.0f;
            float branchChance = 0.1f + progress * 0.2f;
            
            float deltaX = (drand48() - 0.5f) * 2.0f;
            float deltaY = -0.4f - drand48() * 0.3f;
            
            currentX += deltaX;
            currentY += deltaY;
            
            lightningVertices[vertexIndex] = (LightningVertex){
                {currentX, currentY, 0},
                1.0f - progress * 0.3f,
                branchChance,
                timeOffset
            };
            vertexIndex++;
            
            if (drand48() < branchChance && vertexIndex < maxLightningVertices - 10) {
                float branchX = currentX;
                float branchY = currentY;
                int branchLength = 3 + drand48() * 8;
                
                for (int b = 0; b < branchLength && vertexIndex < maxLightningVertices - 1; b++) {
                    branchX += (drand48() - 0.5f) * 1.5f;
                    branchY -= 0.2f + drand48() * 0.2f;
                    
                    lightningVertices[vertexIndex] = (LightningVertex){
                        {branchX, branchY, 0},
                        (1.0f - progress * 0.3f) * 0.6f,
                        0.0f,
                        timeOffset + b * 0.1f
                    };
                    vertexIndex++;
                }
            }
        }
    }
    
    self.lightningVertexCount = vertexIndex;
    self.lightningBuffer = [self.device newBufferWithBytes:lightningVertices
                                                   length:vertexIndex * sizeof(LightningVertex)
                                                  options:MTLResourceStorageModeShared];
    
    free(lightningVertices);
    NSLog(@"⚡ Generated %d lightning vertices", self.lightningVertexCount);
}

- (void)generateRainParticles {
    typedef struct {
        vector_float3 position;
        vector_float3 normal;
        vector_float2 texCoord;
    } RainVertex;
    
    int particleCount = 800;
    RainVertex *rainVertices = malloc(particleCount * sizeof(RainVertex));
    
    for (int i = 0; i < particleCount; i++) {
        float x = (drand48() - 0.5f) * 50.0f;
        float y = 20.0f + drand48() * 10.0f;
        float z = (drand48() - 0.5f) * 50.0f;
        
        rainVertices[i] = (RainVertex){
            {x, y, z},
            {0, -1, 0},
            {drand48(), drand48()}
        };
    }
    
    self.rainParticleCount = particleCount;
    self.rainParticleBuffer = [self.device newBufferWithBytes:rainVertices
                                                       length:particleCount * sizeof(RainVertex)
                                                      options:MTLResourceStorageModeShared];
    
    free(rainVertices);
    NSLog(@"🌧️ Generated %d rain particles", self.rainParticleCount);
}

- (void)drawInMTKView:(MTKView *)view {
    @autoreleasepool {
        id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
        if (!commandBuffer) return;
        
        MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
        if (!renderPassDescriptor) return;
        
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.02, 0.02, 0.05, 1.0);
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        
        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        if (!encoder) return;
        
        [self updateStormUniforms];
        
        [self renderStormBackground:encoder];
        [self renderRainParticles:encoder];
        [self renderLightning:encoder];
        
        [encoder endEncoding];
        
        if (view.currentDrawable) {
            [commandBuffer presentDrawable:view.currentDrawable];
        }
        
        [commandBuffer commit];
    }
}

- (void)renderStormBackground:(id<MTLRenderCommandEncoder>)encoder {
    if (!self.stormBackgroundPipeline) return;
    
    [encoder setRenderPipelineState:self.stormBackgroundPipeline];
    [encoder setDepthStencilState:self.noDepthStencilState];
    [encoder setFragmentBuffer:self.stormUniformBuffer offset:0 atIndex:1];
    [encoder setVertexBuffer:self.backgroundQuadBuffer offset:0 atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
}

- (void)renderRainParticles:(id<MTLRenderCommandEncoder>)encoder {
    if (!self.rainPipeline || !self.rainParticleBuffer) return;
    
    [encoder setRenderPipelineState:self.rainPipeline];
    [encoder setDepthStencilState:self.depthStencilState];
    [encoder setVertexBuffer:self.stormUniformBuffer offset:0 atIndex:1];
    [encoder setFragmentBuffer:self.stormUniformBuffer offset:0 atIndex:1];
    [encoder setVertexBuffer:self.rainParticleBuffer offset:0 atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypePoint vertexStart:0 vertexCount:self.rainParticleCount];
}

- (void)renderLightning:(id<MTLRenderCommandEncoder>)encoder {
    if (!self.lightningPipeline || !self.lightningBuffer) return;
    
    [encoder setRenderPipelineState:self.lightningPipeline];
    [encoder setDepthStencilState:self.noDepthStencilState];
    [encoder setVertexBuffer:self.stormUniformBuffer offset:0 atIndex:1];
    [encoder setFragmentBuffer:self.stormUniformBuffer offset:0 atIndex:1];
    [encoder setVertexBuffer:self.lightningBuffer offset:0 atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeLineStrip vertexStart:0 vertexCount:self.lightningVertexCount];
}

- (void)updateStormUniforms {
    CFTimeInterval currentTime = CACurrentMediaTime();
    float time = (float)(currentTime - self.startTime);
    
    float flashCycle = fmodf(time * 0.8f, 4.0f);
    float lightningIntensity = 0.0f;
    
    if (flashCycle < 0.1f) {
        lightningIntensity = 1.0f;
    } else if (flashCycle < 0.15f) {
        lightningIntensity = 0.3f;
    } else if (flashCycle < 0.2f) {
        lightningIntensity = 0.8f;
    } else if (flashCycle > 2.0f && flashCycle < 2.05f) {
        lightningIntensity = 0.6f;
    }
    
    float stormPhase = sin(time * 0.2f) * 0.5f + 0.5f;
    float flashTiming = sin(time * 3.0f);
    
    StormUniforms *uniformsPtr = (StormUniforms *)self.stormUniformBuffer.contents;
    uniformsPtr->time = time;
    uniformsPtr->lightningIntensity = lightningIntensity;
    uniformsPtr->stormPhase = stormPhase;
    uniformsPtr->flashTiming = flashTiming;
    
    matrix_float4x4 modelViewProjectionMatrix = matrix_multiply(self.projectionMatrix, self.viewMatrix);
    uniformsPtr->modelViewProjectionMatrix = modelViewProjectionMatrix;
    uniformsPtr->normalMatrix = self.viewMatrix;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    self.viewportSize = size;
    [self setupMatrices];
}

@end
