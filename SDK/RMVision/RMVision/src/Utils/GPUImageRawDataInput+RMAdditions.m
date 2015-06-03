////////////////////////////////////////////////////////////////////////////////
//                             _
//                            | | (_)
//   _ __ ___  _ __ ___   ___ | |_ ___   _____
//  | '__/ _ \| '_ ` _ \ / _ \| __| \ \ / / _ \
//  | | | (_) | | | | | | (_) | |_| |\ V /  __/
//  |_|  \___/|_| |_| |_|\___/ \__|_| \_/ \___|
//
////////////////////////////////////////////////////////////////////////////////
//
//  GPUImageRawDataInput+RMAdditions.m
//      Category for extending the GPUImageRawDataInput for
//  RMVision
//
//  Created on 10/29/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
////////////////////////////////////////////////////////////////////////////////

#import "GPUImageRawDataInput+RMAdditions.h"

@implementation GPUImageRawDataInput (RMAdditions)


- (id)initWithSize:(CGSize)imageSize
{
    return [self initWithSize:imageSize pixelFormat:GPUPixelFormatBGRA];
}

- (id)initWithSize:(CGSize)imageSize pixelFormat:(GPUPixelFormat)pixelFormat
{
    return [self initWithSize:imageSize pixelFormat:pixelFormat type:GPUPixelTypeUByte];
}

- (id)initWithSize:(CGSize)imageSize pixelFormat:(GPUPixelFormat)pixelFormat type:(GPUPixelType)pixelType
{

    unsigned int channels;
    
    switch (pixelFormat) {
        case GPUPixelFormatRGB:
            channels = 3;
            break;
            
        case GPUPixelFormatBGRA:
        case GPUPixelFormatRGBA:
            channels = 4;
            break;
            
        default:
            NSAssert(NO, @"pixelFormat not supported!");
            break;
    }
    
    size_t pixelSize;
    switch (pixelType) {
            case GPUPixelTypeUByte:
            pixelSize = sizeof(GLubyte);
            break;
            
            case GPUPixelTypeFloat:
            pixelSize = sizeof(GLfloat);
            break;
            
        default:
            NSAssert(NO, @"pixelType not supported!");
            break;
            
    }
    
    GLubyte *rawDataBytes = (GLubyte *)calloc(imageSize.width * imageSize.height * channels, pixelSize);

    self = [[GPUImageRawDataInput alloc] initWithBytes:rawDataBytes size:imageSize pixelFormat:pixelFormat type:pixelType];
    
    free(rawDataBytes);
    
    return self;
    
}


@end


