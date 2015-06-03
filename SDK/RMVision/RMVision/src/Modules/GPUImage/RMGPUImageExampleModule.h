//
//  RMGPUImageExampleModule.h
//  RMVision
//
//  Created on 9/23/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "RMVisionModule.h"
#import "RMVisionModuleProtocol.h"
#import "GPUImage.h"

@interface RMGPUImageExampleModule : GPUImageFilterGroup <RMVisionModuleProtocol, GPUImageInput>

@property (nonatomic) BOOL paused;
@property (nonatomic, readonly) NSString *name;

- (id)initModule:(NSString *)moduleName withVision:(RMVision *)core;


@end
