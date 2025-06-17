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
    float padding[3];
} Uniforms;

typedef struct {
    vector_float2 position;
    vector_float2 texCoord;
} QuadVertex;

@interface SKRenderer ()
@property (nonatomic, strong) id<MTLRenderPipelineState> glassPipelineState;
@property (nonatomic, strong) id<MTLRenderPipelineState> backgroundPipelineState;
@property (nonatomic, strong) id<MTLDepthStencilState> depthStencilState;
@property (nonatomic, strong) id<MTLDepthStencilState> noDepthStencilState;
@property (nonatomic, strong) id<MTLBuffer> uniformBuffer;
@property (nonatomic, strong) id<MTLBuffer> backgroundQuadBuffer;
@property (nonatomic, strong) SKMesh *mainCube;
@property (nonatomic, strong) SKMesh *smallCube;
@property (nonatomic, assign) CFTimeInterval startTime;
@property (nonatomic, assign) matrix_float4x4 projectionMatrix;
@property (nonatomic, assign) matrix_float4x4 viewMatrix;
@property (nonatomic, assign) CGSize viewportSize;
@end

@implementation SKRenderer

- (instancetype)initWithView:(MTKView *)view {
    NSLog(@"=== Glassmorphism Renderer Init ===");
    if (self = [super init]) {
        self.device = view.device;
        self.commandQueue = [self.device newCommandQueue];
        
        if (!self.commandQueue) {
            return nil;
        }
        
        self.viewportSize = view.drawableSize;
        [self setupPipelines];
        [self setupDepthStencil];
        [self setupBuffers];
        [self setupMatrices];
        [self loadModels];
        
        self.startTime = CACurrentMediaTime();
        NSLog(@"⚪️ Glassmorphism renderer ready");
    }
    return self;
}

- (void)setupPipelines {
    id<MTLLibrary> library = [self.device newDefaultLibrary];
    if (!library) {
        NSLog(@"⚫️ Failed to create library");
        return;
    }
    
    [self setupGlassPipeline:library];
    [self setupBackgroundPipeline:library];
    
    NSLog(@"⚪️ All pipelines configured correctly");
}

- (void)setupGlassPipeline:(id<MTLLibrary>)library {
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_glassmorphism"];
    
    if (!fragmentFunction) {
        NSLog(@"⚠️ fragment_glassmorphism not found, using fragment_main");
        fragmentFunction = [library newFunctionWithName:@"fragment_main"];
    }
    
    if (!vertexFunction || !fragmentFunction) {
        NSLog(@"⚫️ Glass shader functions not found");
        return;
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
    descriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
    descriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    descriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    
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
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    
    descriptor.vertexDescriptor = vertexDescriptor;
    
    NSError *error;
    self.glassPipelineState = [self.device newRenderPipelineStateWithDescriptor:descriptor error:&error];
    if (error) {
        NSLog(@"⚫️ Glass pipeline error: %@", error);
    } else {
        NSLog(@"⚪️ Glass pipeline created");
    }
}

- (void)setupBackgroundPipeline:(id<MTLLibrary>)library {
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_background"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_background"];
    
    if (!vertexFunction || !fragmentFunction) {
        NSLog(@"⚠️ Background shaders not found, creating simple background");
        return;
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
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    
    descriptor.vertexDescriptor = vertexDescriptor;
    
    NSError *error;
    self.backgroundPipelineState = [self.device newRenderPipelineStateWithDescriptor:descriptor error:&error];
    if (error) {
        NSLog(@"⚫️ Background pipeline error: %@", error);
    } else {
        NSLog(@"⚪️ Background pipeline created with depth format");
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
    
    NSLog(@"⚪️ Depth stencil states configured");
}

- (void)setupBuffers {
    self.uniformBuffer = [self.device newBufferWithLength:sizeof(Uniforms) options:MTLResourceStorageModeShared];
    
    QuadVertex quadVertices[] = {
        {{-1.0f, -1.0f}, {0.0f, 1.0f}},
        {{ 1.0f, -1.0f}, {1.0f, 1.0f}},
        {{-1.0f,  1.0f}, {0.0f, 0.0f}},
        {{ 1.0f,  1.0f}, {1.0f, 0.0f}},
    };
    
    self.backgroundQuadBuffer = [self.device newBufferWithBytes:quadVertices
                                                        length:sizeof(quadVertices)
                                                       options:MTLResourceStorageModeShared];
    
    NSLog(@"⚪️ Buffers created");
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
    
    vector_float3 eye = {0, 3, 8};
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
    
    NSLog(@"⚪️ Matrices configured");
}

- (void)loadModels {
    self.mainCube = [SKModelLoader createGlassmorphismCubeWithDevice:self.device];
    self.smallCube = [SKModelLoader createGlassmorphismCubeWithDevice:self.device];
    
    if (self.mainCube && self.smallCube) {
        NSLog(@"⚪️ Glass models loaded");
    } else {
        NSLog(@"⚫️ Failed to load models");
    }
}

- (void)drawInMTKView:(MTKView *)view {
    static int frameCount = 0;
    frameCount++;
    
    @autoreleasepool {
        id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
        if (!commandBuffer) return;
        
        MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
        if (!renderPassDescriptor) return;
        
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        
        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        if (!encoder) return;
        
        [self updateUniforms];
        
        [self renderBackground:encoder];
        [self renderFloatingParticles:encoder];
        [self renderMainObjects:encoder];
        
        [encoder endEncoding];
        
        if (view.currentDrawable) {
            [commandBuffer presentDrawable:view.currentDrawable];
        }
        
        [commandBuffer commit];
        
        if (frameCount <= 3) {
            NSLog(@"⚪️ Glassmorphism frame %d rendered", frameCount);
        }
    }
}

- (void)renderBackground:(id<MTLRenderCommandEncoder>)encoder {
    if (!self.backgroundPipelineState || !self.backgroundQuadBuffer) return;
    
    [encoder setRenderPipelineState:self.backgroundPipelineState];
    [encoder setDepthStencilState:self.noDepthStencilState];
    [encoder setFragmentBuffer:self.uniformBuffer offset:0 atIndex:1];
    [encoder setVertexBuffer:self.backgroundQuadBuffer offset:0 atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
}

- (void)renderFloatingParticles:(id<MTLRenderCommandEncoder>)encoder {
    if (!self.glassPipelineState || !self.smallCube) return;
    
    [encoder setRenderPipelineState:self.glassPipelineState];
    [encoder setDepthStencilState:self.depthStencilState];
    [encoder setVertexBuffer:self.uniformBuffer offset:0 atIndex:1];
    [encoder setFragmentBuffer:self.uniformBuffer offset:0 atIndex:1];
    [encoder setVertexBuffer:self.smallCube.vertexBuffer offset:0 atIndex:0];
    
    CFTimeInterval currentTime = CACurrentMediaTime();
    float time = (float)(currentTime - self.startTime);
    
    for (int i = 0; i < 6; i++) {
        float angle = (float)i / 6.0f * M_PI * 2.0f + time * 0.2f;
        float radius = 5.0f + sinf(time * 0.3f + i) * 1.5f;
        float height = sinf(time * 0.25f + i * 0.5f) * 2.0f;
        
        vector_float3 position = {
            cosf(angle) * radius,
            height,
            sinf(angle) * radius
        };
        
        float scale = 0.25f + sinf(time * 0.4f + i) * 0.15f;
        matrix_float4x4 scaleMatrix = (matrix_float4x4){{
            {scale, 0, 0, 0},
            {0, scale, 0, 0},
            {0, 0, scale, 0},
            {0, 0, 0, 1}
        }};
        
        matrix_float4x4 translationMatrix = (matrix_float4x4){{
            {1, 0, 0, 0},
            {0, 1, 0, 0},
            {0, 0, 1, 0},
            {position.x, position.y, position.z, 1}
        }};
        
        matrix_float4x4 modelMatrix = matrix_multiply(translationMatrix, scaleMatrix);
        matrix_float4x4 modelViewMatrix = matrix_multiply(self.viewMatrix, modelMatrix);
        matrix_float4x4 mvp = matrix_multiply(self.projectionMatrix, modelViewMatrix);
        
        Uniforms *uniformsPtr = (Uniforms *)self.uniformBuffer.contents;
        uniformsPtr->modelViewProjectionMatrix = mvp;
        uniformsPtr->normalMatrix = modelViewMatrix;
        
        [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                            indexCount:self.smallCube.indexCount
                             indexType:MTLIndexTypeUInt16
                           indexBuffer:self.smallCube.indexBuffer
                     indexBufferOffset:0];
    }
}

- (void)renderMainObjects:(id<MTLRenderCommandEncoder>)encoder {
    if (!self.glassPipelineState || !self.mainCube) return;
    
    [encoder setRenderPipelineState:self.glassPipelineState];
    [encoder setDepthStencilState:self.depthStencilState];
    [encoder setVertexBuffer:self.uniformBuffer offset:0 atIndex:1];
    [encoder setFragmentBuffer:self.uniformBuffer offset:0 atIndex:1];
    [encoder setVertexBuffer:self.mainCube.vertexBuffer offset:0 atIndex:0];
    
    CFTimeInterval currentTime = CACurrentMediaTime();
    float time = (float)(currentTime - self.startTime);
    
    float rotationY = time * 0.15f;
    float rotationX = time * 0.1f;
    
    float cosY = cosf(rotationY), sinY = sinf(rotationY);
    float cosX = cosf(rotationX), sinX = sinf(rotationX);
    
    matrix_float4x4 rotationMatrixY = (matrix_float4x4){{
        {cosY, 0, sinY, 0},
        {0, 1, 0, 0},
        {-sinY, 0, cosY, 0},
        {0, 0, 0, 1}
    }};
    
    matrix_float4x4 rotationMatrixX = (matrix_float4x4){{
        {1, 0, 0, 0},
        {0, cosX, -sinX, 0},
        {0, sinX, cosX, 0},
        {0, 0, 0, 1}
    }};
    
    matrix_float4x4 modelMatrix = matrix_multiply(rotationMatrixY, rotationMatrixX);
    matrix_float4x4 modelViewMatrix = matrix_multiply(self.viewMatrix, modelMatrix);
    matrix_float4x4 modelViewProjectionMatrix = matrix_multiply(self.projectionMatrix, modelViewMatrix);
    
    Uniforms *uniformsPtr = (Uniforms *)self.uniformBuffer.contents;
    uniformsPtr->modelViewProjectionMatrix = modelViewProjectionMatrix;
    uniformsPtr->normalMatrix = modelViewMatrix;
    
    [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                        indexCount:self.mainCube.indexCount
                         indexType:MTLIndexTypeUInt16
                       indexBuffer:self.mainCube.indexBuffer
                 indexBufferOffset:0];
}

- (void)updateUniforms {
    CFTimeInterval currentTime = CACurrentMediaTime();
    float time = (float)(currentTime - self.startTime);
    
    Uniforms *uniformsPtr = (Uniforms *)self.uniformBuffer.contents;
    uniformsPtr->time = time;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    self.viewportSize = size;
    [self setupMatrices];
}

@end
