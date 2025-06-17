//
//  SKRenderer.m
//  SKRender
//
//  Created by Dimitri ALMON on 16/06/2025.
//

#import "SKRenderer.h"
#import "../Assets/SKModelLoader.h"
#import "../Controls/SKStormController.h"
#import <simd/simd.h>

typedef struct {
    matrix_float4x4 modelViewProjectionMatrix;
    matrix_float4x4 normalMatrix;
    float time;
    float lightningIntensity;
    float lightningFrequency;
    float rainIntensity;
    float windSpeed;
    float stormIntensity;
    vector_float3 lightningColor;
    vector_float3 skyTint;
    float flashDuration;
    float branchFactor;
    float electricGlow;
    float manualLightningTrigger;
    float padding[2];
} ControlledStormUniforms;

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
@property (nonatomic, assign) StormParameters currentStormParams;
@property (nonatomic, assign) float manualLightningTimer;
@property (nonatomic, assign) BOOL manualLightningActive;
@end

@implementation SKRenderer

- (instancetype)initWithView:(MTKView *)view {
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
        [self initializeStormParameters];
        
        self.startTime = CACurrentMediaTime();
        self.manualLightningTimer = 0.0f;
        self.manualLightningActive = NO;
    }
    return self;
}

- (void)initializeStormParameters {
    _currentStormParams = (StormParameters){
        .lightningIntensity = 0.8f,
        .lightningFrequency = 0.6f,
        .rainIntensity = 0.7f,
        .windSpeed = 0.5f,
        .stormIntensity = 0.8f,
        .lightningColor = {0.9f, 0.95f, 1.0f},
        .skyTint = {0.05f, 0.08f, 0.2f},
        .flashDuration = 0.15f,
        .branchFactor = 0.4f,
        .electricGlow = 0.9f
    };
}

- (void)updateStormParameters:(void *)parameters {
    if (parameters) {
        memcpy(&_currentStormParams, parameters, sizeof(StormParameters));
    }
}

- (void)triggerManualLightning {
    self.manualLightningActive = YES;
    self.manualLightningTimer = CACurrentMediaTime();
}

- (void)setupStormPipelines {
    id<MTLLibrary> library = [self.device newDefaultLibrary];
    if (!library) {
        return;
    }
    
    [self setupStormBackgroundPipeline:library];
    [self setupLightningPipeline:library];
    [self setupRainPipeline:library];
}

- (void)setupStormBackgroundPipeline:(id<MTLLibrary>)library {
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_background"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_storm_background"];
    
    if (!vertexFunction || !fragmentFunction) {
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
}

- (void)setupLightningPipeline:(id<MTLLibrary>)library {
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_lightning"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_lightning"];
    
    if (!vertexFunction || !fragmentFunction) {
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
    self.stormUniformBuffer = [self.device newBufferWithLength:sizeof(ControlledStormUniforms) options:MTLResourceStorageModeShared];
    
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
    int maxLightningVertices = 1000;
    LightningVertex *lightningVertices = malloc(maxLightningVertices * sizeof(LightningVertex));
    
    int vertexIndex = 0;
    
    for (int bolt = 0; bolt < 5; bolt++) {
        float startX = (bolt - 2) * 6.0f;
        float startY = 15.0f;
        float currentX = startX;
        float currentY = startY;
        float timeOffset = bolt * 0.2f;
        
        for (int segment = 0; segment < 100 && vertexIndex < maxLightningVertices - 1; segment++) {
            float progress = (float)segment / 100.0f;
            float branchChance = 0.08f + progress * 0.15f;
            
            float deltaX = (drand48() - 0.5f) * 1.5f;
            float deltaY = -0.3f - drand48() * 0.25f;
            
            currentX += deltaX;
            currentY += deltaY;
            
            lightningVertices[vertexIndex] = (LightningVertex){
                {currentX, currentY, 0},
                1.0f - progress * 0.2f,
                branchChance,
                timeOffset
            };
            vertexIndex++;
            
            if (drand48() < branchChance && vertexIndex < maxLightningVertices - 15) {
                float branchX = currentX;
                float branchY = currentY;
                int branchLength = 5 + drand48() * 12;
                
                for (int b = 0; b < branchLength && vertexIndex < maxLightningVertices - 1; b++) {
                    branchX += (drand48() - 0.5f) * 1.2f;
                    branchY -= 0.15f + drand48() * 0.15f;
                    
                    lightningVertices[vertexIndex] = (LightningVertex){
                        {branchX, branchY, 0},
                        (1.0f - progress * 0.2f) * 0.7f,
                        0.0f,
                        timeOffset + b * 0.05f
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
}

- (void)generateRainParticles {
    typedef struct {
        vector_float3 position;
        vector_float3 normal;
        vector_float2 texCoord;
    } RainVertex;
    
    int particleCount = 1200;
    RainVertex *rainVertices = malloc(particleCount * sizeof(RainVertex));
    
    for (int i = 0; i < particleCount; i++) {
        float x = (drand48() - 0.5f) * 60.0f;
        float y = 25.0f + drand48() * 15.0f;
        float z = (drand48() - 0.5f) * 60.0f;
        
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
}

- (void)drawInMTKView:(MTKView *)view {
    @autoreleasepool {
        id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
        if (!commandBuffer) return;
        
        MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
        if (!renderPassDescriptor) return;
        
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(
            self.currentStormParams.skyTint.x * 0.5f,
            self.currentStormParams.skyTint.y * 0.5f,
            self.currentStormParams.skyTint.z * 0.5f,
            1.0
        );
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
    if (!self.rainPipeline || !self.rainParticleBuffer || self.currentStormParams.rainIntensity < 0.01f) return;
    
    [encoder setRenderPipelineState:self.rainPipeline];
    [encoder setDepthStencilState:self.depthStencilState];
    [encoder setVertexBuffer:self.stormUniformBuffer offset:0 atIndex:1];
    [encoder setFragmentBuffer:self.stormUniformBuffer offset:0 atIndex:1];
    [encoder setVertexBuffer:self.rainParticleBuffer offset:0 atIndex:0];
    
    int activeParticles = (int)(self.rainParticleCount * self.currentStormParams.rainIntensity);
    [encoder drawPrimitives:MTLPrimitiveTypePoint vertexStart:0 vertexCount:activeParticles];
}

- (void)renderLightning:(id<MTLRenderCommandEncoder>)encoder {
    if (!self.lightningPipeline || !self.lightningBuffer || self.currentStormParams.lightningIntensity < 0.01f) return;
    
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
    
    float flashCycle = fmodf(time * self.currentStormParams.lightningFrequency, 4.0f);
    float automaticLightning = 0.0f;
    
    if (flashCycle < self.currentStormParams.flashDuration) {
        automaticLightning = self.currentStormParams.lightningIntensity;
    } else if (flashCycle < self.currentStormParams.flashDuration * 1.5f) {
        automaticLightning = self.currentStormParams.lightningIntensity * 0.3f;
    } else if (flashCycle < self.currentStormParams.flashDuration * 2.0f) {
        automaticLightning = self.currentStormParams.lightningIntensity * 0.8f;
    }
    
    float manualLightning = 0.0f;
    if (self.manualLightningActive) {
        float timeSinceManual = currentTime - self.manualLightningTimer;
        if (timeSinceManual < self.currentStormParams.flashDuration * 3.0f) {
            float manualProgress = timeSinceManual / (self.currentStormParams.flashDuration * 3.0f);
            manualLightning = self.currentStormParams.lightningIntensity * (1.0f - manualProgress);
        } else {
            self.manualLightningActive = NO;
        }
    }
    
    float totalLightning = fmaxf(automaticLightning, manualLightning);
    
    ControlledStormUniforms *uniformsPtr = (ControlledStormUniforms *)self.stormUniformBuffer.contents;
    uniformsPtr->time = time;
    uniformsPtr->lightningIntensity = totalLightning;
    uniformsPtr->lightningFrequency = self.currentStormParams.lightningFrequency;
    uniformsPtr->rainIntensity = self.currentStormParams.rainIntensity;
    uniformsPtr->windSpeed = self.currentStormParams.windSpeed;
    uniformsPtr->stormIntensity = self.currentStormParams.stormIntensity;
    uniformsPtr->lightningColor = self.currentStormParams.lightningColor;
    uniformsPtr->skyTint = self.currentStormParams.skyTint;
    uniformsPtr->flashDuration = self.currentStormParams.flashDuration;
    uniformsPtr->branchFactor = self.currentStormParams.branchFactor;
    uniformsPtr->electricGlow = self.currentStormParams.electricGlow;
    uniformsPtr->manualLightningTrigger = manualLightning;
    
    matrix_float4x4 modelViewProjectionMatrix = matrix_multiply(self.projectionMatrix, self.viewMatrix);
    uniformsPtr->modelViewProjectionMatrix = modelViewProjectionMatrix;
    uniformsPtr->normalMatrix = self.viewMatrix;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    self.viewportSize = size;
    [self setupMatrices];
}

@end
