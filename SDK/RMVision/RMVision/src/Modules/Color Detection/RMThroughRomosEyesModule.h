//
//  RMThroughRomosEyesModule.h
//  RMVision
//

#import "RMVisionModule.h"
#import "RMVisionModuleProtocol.h"
#import "GPUImage.h"

@class GPUImageBoxBlurFilter;

@interface RMThroughRomosEyesModule : GPUImageFilterGroup <RMVisionModuleProtocol, GPUImageInput>

@property (nonatomic) UIView *outputView;

// You can set the blur size (default is 1.0)
@property (nonatomic) float blurSize;

- (id)initModule:(NSString *)moduleName withVision:(RMVision *)core;

@end
