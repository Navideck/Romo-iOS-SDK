//
//  GPUImageRawDataInput_RMAdditions.h
//  RMVision
//
//  Created on 10/29/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "GPUImageRawDataInput.h"

@interface GPUImageRawDataInput (RMAdditions)

- (id)initWithSize:(CGSize)imageSize;
- (id)initWithSize:(CGSize)imageSize pixelFormat:(GPUPixelFormat)pixelFormat;
- (id)initWithSize:(CGSize)imageSize pixelFormat:(GPUPixelFormat)pixelFormat type:(GPUPixelType)pixelType;

@end
