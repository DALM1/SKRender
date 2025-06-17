//
//  SKModelLoader.m
//  SKRender
//
//  Created by Dimitri ALMON on 16/06/2025.
//

#import "SKModelLoader.h"
#import <simd/simd.h>

@implementation SKMesh
@end

@implementation SKModelLoader

+ (SKMesh *)loadModelFromPath:(NSString *)path withDevice:(id<MTLDevice>)device {
    if ([path.pathExtension.lowercaseString isEqualToString:@"glb"]) {
        return [self loadGLBFromPath:path withDevice:device];
    } else if ([path.pathExtension.lowercaseString isEqualToString:@"gltf"]) {
        return [self loadGLTFFromPath:path withDevice:device];
    }
    
    return [self createGlassmorphismCubeWithDevice:device];
}

+ (SKMesh *)loadGLTFFromPath:(NSString *)path withDevice:(id<MTLDevice>)device {
    NSData *gltfData = [NSData dataWithContentsOfFile:path];
    if (!gltfData) {
        return [self createGlassmorphismCubeWithDevice:device];
    }
    
    NSError *error;
    [NSJSONSerialization JSONObjectWithData:gltfData options:0 error:&error];
    if (error) {
        return [self createGlassmorphismCubeWithDevice:device];
    }
    
    NSString *binPath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"scene.bin"];
    NSData *binData = [NSData dataWithContentsOfFile:binPath];
    if (!binData) {
        return [self createGlassmorphismCubeWithDevice:device];
    }
    
    return [self createGlassmorphismCubeWithDevice:device];
}

+ (SKMesh *)loadGLBFromPath:(NSString *)path withDevice:(id<MTLDevice>)device {
    NSData *glbData = [NSData dataWithContentsOfFile:path];
    if (!glbData) {
        return [self createGlassmorphismCubeWithDevice:device];
    }
    
    return [self createGlassmorphismCubeWithDevice:device];
}

+ (SKMesh *)createColoredCubeWithDevice:(id<MTLDevice>)device {
    return [self createGlassmorphismCubeWithDevice:device];
}

+ (SKMesh *)createGlassmorphismCubeWithDevice:(id<MTLDevice>)device {
    typedef struct {
        vector_float3 position;
        vector_float3 normal;
        vector_float2 texCoord;
    } Vertex;
    
    float size = 1.5f;
    
    Vertex vertices[] = {
        {{-size, -size,  size}, {0, 0, 1}, {0, 0}},
        {{ size, -size,  size}, {0, 0, 1}, {1, 0}},
        {{ size,  size,  size}, {0, 0, 1}, {1, 1}},
        {{-size,  size,  size}, {0, 0, 1}, {0, 1}},
        
        {{-size, -size, -size}, {0, 0, -1}, {1, 0}},
        {{-size,  size, -size}, {0, 0, -1}, {1, 1}},
        {{ size,  size, -size}, {0, 0, -1}, {0, 1}},
        {{ size, -size, -size}, {0, 0, -1}, {0, 0}},
        
        {{-size, -size, -size}, {-1, 0, 0}, {0, 0}},
        {{-size, -size,  size}, {-1, 0, 0}, {1, 0}},
        {{-size,  size,  size}, {-1, 0, 0}, {1, 1}},
        {{-size,  size, -size}, {-1, 0, 0}, {0, 1}},
        
        {{ size, -size, -size}, {1, 0, 0}, {1, 0}},
        {{ size,  size, -size}, {1, 0, 0}, {1, 1}},
        {{ size,  size,  size}, {1, 0, 0}, {0, 1}},
        {{ size, -size,  size}, {1, 0, 0}, {0, 0}},
        
        {{-size, -size, -size}, {0, -1, 0}, {0, 1}},
        {{ size, -size, -size}, {0, -1, 0}, {1, 1}},
        {{ size, -size,  size}, {0, -1, 0}, {1, 0}},
        {{-size, -size,  size}, {0, -1, 0}, {0, 0}},
        
        {{-size,  size, -size}, {0, 1, 0}, {0, 0}},
        {{-size,  size,  size}, {0, 1, 0}, {0, 1}},
        {{ size,  size,  size}, {0, 1, 0}, {1, 1}},
        {{ size,  size, -size}, {0, 1, 0}, {1, 0}}
    };
    
    uint16_t indices[] = {
        0,  1,  2,   0,  2,  3,
        4,  5,  6,   4,  6,  7,
        8,  9,  10,  8,  10, 11,
        12, 13, 14,  12, 14, 15,
        16, 17, 18,  16, 18, 19,
        20, 21, 22,  20, 22, 23
    };
    
    id<MTLBuffer> vertexBuffer = [device newBufferWithBytes:vertices
                                                    length:sizeof(vertices)
                                                   options:MTLResourceStorageModeShared];
    
    id<MTLBuffer> indexBuffer = [device newBufferWithBytes:indices
                                                   length:sizeof(indices)
                                                  options:MTLResourceStorageModeShared];
    
    if (!vertexBuffer || !indexBuffer) {
        return nil;
    }
    
    SKMesh *mesh = [[SKMesh alloc] init];
    mesh.vertexBuffer = vertexBuffer;
    mesh.indexBuffer = indexBuffer;
    mesh.indexCount = sizeof(indices) / sizeof(uint16_t);
    
    return mesh;
}

+ (SKMesh *)createGlassmorphismSphereWithDevice:(id<MTLDevice>)device {
    typedef struct {
        vector_float3 position;
        vector_float3 normal;
        vector_float2 texCoord;
    } Vertex;
    
    int segments = 24;
    int rings = 16;
    float radius = 1.0f;
    
    int vertexCount = (rings + 1) * (segments + 1);
    int indexCount = rings * segments * 6;
    
    Vertex *vertices = malloc(vertexCount * sizeof(Vertex));
    uint16_t *indices = malloc(indexCount * sizeof(uint16_t));
    
    int vertexIndex = 0;
    for (int ring = 0; ring <= rings; ring++) {
        float phi = M_PI * ring / rings;
        float y = cosf(phi) * radius;
        float ringRadius = sinf(phi) * radius;
        
        for (int segment = 0; segment <= segments; segment++) {
            float theta = 2.0f * M_PI * segment / segments;
            float x = cosf(theta) * ringRadius;
            float z = sinf(theta) * ringRadius;
            
            vector_float3 position = {x, y, z};
            vector_float3 normal = vector_normalize(position);
            vector_float2 texCoord = {(float)segment / segments, (float)ring / rings};
            
            vertices[vertexIndex].position = position;
            vertices[vertexIndex].normal = normal;
            vertices[vertexIndex].texCoord = texCoord;
            vertexIndex++;
        }
    }
    
    int indexIdx = 0;
    for (int ring = 0; ring < rings; ring++) {
        for (int segment = 0; segment < segments; segment++) {
            int current = ring * (segments + 1) + segment;
            int next = current + segments + 1;
            
            indices[indexIdx++] = current;
            indices[indexIdx++] = next;
            indices[indexIdx++] = current + 1;
            
            indices[indexIdx++] = current + 1;
            indices[indexIdx++] = next;
            indices[indexIdx++] = next + 1;
        }
    }
    
    id<MTLBuffer> vertexBuffer = [device newBufferWithBytes:vertices
                                                    length:vertexCount * sizeof(Vertex)
                                                   options:MTLResourceStorageModeShared];
    
    id<MTLBuffer> indexBuffer = [device newBufferWithBytes:indices
                                                   length:indexCount * sizeof(uint16_t)
                                                  options:MTLResourceStorageModeShared];
    
    free(vertices);
    free(indices);
    
    if (!vertexBuffer || !indexBuffer) {
        return nil;
    }
    
    SKMesh *mesh = [[SKMesh alloc] init];
    mesh.vertexBuffer = vertexBuffer;
    mesh.indexBuffer = indexBuffer;
    mesh.indexCount = indexCount;
    
    return mesh;
}

+ (SKMesh *)createSimpleTriangleWithDevice:(id<MTLDevice>)device {
    typedef struct {
        vector_float3 position;
        vector_float3 normal;
        vector_float2 texCoord;
    } Vertex;
    
    Vertex vertices[] = {
        {{0.0f,  1.5f, 0.0f}, {0, 0, 1}, {0.5f, 0.0f}},
        {{-1.5f, -1.5f, 0.0f}, {0, 0, 1}, {0.0f, 1.0f}},
        {{1.5f, -1.5f, 0.0f}, {0, 0, 1}, {1.0f, 1.0f}}
    };
    
    uint16_t indices[] = {
        0, 1, 2
    };
    
    id<MTLBuffer> vertexBuffer = [device newBufferWithBytes:vertices
                                                    length:sizeof(vertices)
                                                   options:MTLResourceStorageModeShared];
    
    id<MTLBuffer> indexBuffer = [device newBufferWithBytes:indices
                                                   length:sizeof(indices)
                                                  options:MTLResourceStorageModeShared];
    
    if (!vertexBuffer || !indexBuffer) {
        return nil;
    }
    
    SKMesh *mesh = [[SKMesh alloc] init];
    mesh.vertexBuffer = vertexBuffer;
    mesh.indexBuffer = indexBuffer;
    mesh.indexCount = sizeof(indices) / sizeof(uint16_t);
    
    return mesh;
}

@end
