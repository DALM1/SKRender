//
//  SKModelLoader.h
//  SKRender
//
//  Created by Dimitri ALMON on 16/06/2025.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

@interface SKMesh : NSObject
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> indexBuffer;
@property (nonatomic, assign) NSUInteger indexCount;
@end

@interface SKModelLoader : NSObject

+ (SKMesh *)loadModelFromPath:(NSString *)path withDevice:(id<MTLDevice>)device;
+ (SKMesh *)loadGLTFFromPath:(NSString *)path withDevice:(id<MTLDevice>)device;
+ (SKMesh *)loadGLBFromPath:(NSString *)path withDevice:(id<MTLDevice>)device;
+ (SKMesh *)createColoredCubeWithDevice:(id<MTLDevice>)device;
+ (SKMesh *)createGlassmorphismCubeWithDevice:(id<MTLDevice>)device;
+ (SKMesh *)createGlassmorphismSphereWithDevice:(id<MTLDevice>)device;
+ (SKMesh *)createSimpleTriangleWithDevice:(id<MTLDevice>)device;

@end
