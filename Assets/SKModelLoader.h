#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <simd/simd.h>

typedef struct {
    vector_float3 position;
    vector_float3 normal;
    vector_float2 texCoord;
} SKVertex;

@interface SKMesh : NSObject
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> indexBuffer;
@property (nonatomic, assign) NSUInteger indexCount;
@property (nonatomic, assign) NSUInteger vertexCount;
@end

@interface SKModelLoader : NSObject
+ (SKMesh *)loadGLBFromPath:(NSString *)path device:(id<MTLDevice>)device;
@end
