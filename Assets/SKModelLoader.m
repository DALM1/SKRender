#import "SKModelLoader.h"
#import <ModelIO/ModelIO.h>
#import <MetalKit/MetalKit.h>

@implementation SKMesh
@end

@implementation SKModelLoader

+ (SKMesh *)loadGLBFromPath:(NSString *)path device:(id<MTLDevice>)device {
    NSLog(@"Loading real GLB model from: %@", path);
    
    // Vérifier que le fichier existe
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSLog(@"ERROR: GLB file not found at path: %@", path);
        return [self createTestCubeWithDevice:device];
    }
    
    NSURL *modelURL = [NSURL fileURLWithPath:path];
    
    // Utiliser Model I/O pour charger le GLB
    MDLAsset *asset = [[MDLAsset alloc] initWithURL:modelURL];
    
    if (!asset || asset.count == 0) {
        NSLog(@"ERROR: Could not load GLB asset");
        return [self createTestCubeWithDevice:device];
    }
    
    // Prendre le premier mesh de l'asset
    MDLObject *object = [asset objectAtIndex:0];
    if (![object isKindOfClass:[MDLMesh class]]) {
        NSLog(@"ERROR: First object is not a mesh");
        return [self createTestCubeWithDevice:device];
    }
    
    MDLMesh *mdlMesh = (MDLMesh *)object;
    
    // Convertir en Metal mesh
    return [self convertMDLMesh:mdlMesh device:device];
}

+ (SKMesh *)convertMDLMesh:(MDLMesh *)mdlMesh device:(id<MTLDevice>)device {
    // Créer un MTKMesh depuis MDLMesh
    NSError *error;
    MTKMesh *mtkMesh = [[MTKMesh alloc] initWithMesh:mdlMesh 
                                              device:device 
                                               error:&error];
    
    if (error) {
        NSLog(@"ERROR creating MTKMesh: %@", error.localizedDescription);
        return [self createTestCubeWithDevice:device];
    }
    
    if (mtkMesh.submeshes.count == 0) {
        NSLog(@"ERROR: No submeshes found");
        return [self createTestCubeWithDevice:device];
    }
    
    // Convertir en notre format SKMesh
    SKMesh *mesh = [[SKMesh alloc] init];
    
    // Prendre le premier submesh
    MTKSubmesh *submesh = mtkMesh.submeshes[0];
    
    // Récupérer les buffers
    mesh.vertexBuffer = mtkMesh.vertexBuffers[0].buffer;
    mesh.indexBuffer = submesh.indexBuffer.buffer;
    mesh.indexCount = submesh.indexCount;
    mesh.vertexCount = mtkMesh.vertexCount;
    
    NSLog(@"✅ LA model loaded successfully!");
    NSLog(@"   - Vertices: %lu", mesh.vertexCount);
    NSLog(@"   - Indices: %lu", mesh.indexCount);
    NSLog(@"   - Submeshes: %lu", mtkMesh.submeshes.count);
    
    return mesh;
}

+ (SKMesh *)createTestCubeWithDevice:(id<MTLDevice>)device {
    NSLog(@"⚠️ Fallback: Creating test cube instead of LA model");
    
    // Ton code de cube existant...
    SKVertex vertices[] = {
        {{-0.5, -0.5,  0.5}, {0, 0, 1}, {0, 0}},
        {{ 0.5, -0.5,  0.5}, {0, 0, 1}, {1, 0}},
        {{ 0.5,  0.5,  0.5}, {0, 0, 1}, {1, 1}},
        {{-0.5,  0.5,  0.5}, {0, 0, 1}, {0, 1}},
    };
    
    uint16_t indices[] = {0, 1, 2, 2, 3, 0};
    
    SKMesh *mesh = [[SKMesh alloc] init];
    mesh.vertexBuffer = [device newBufferWithBytes:vertices length:sizeof(vertices) options:MTLResourceStorageModeShared];
    mesh.indexBuffer = [device newBufferWithBytes:indices length:sizeof(indices) options:MTLResourceStorageModeShared];
    mesh.vertexCount = 4;
    mesh.indexCount = 6;
    
    return mesh;
}

@end
