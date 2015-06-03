//
//  RMGPUImageExampleModule.mm
//  RMVision
//
//  Created on 9/23/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "RMGPUImageExampleModule.h"
#import "RMVisionDebugBroker.h"

@interface RMGPUImageExampleModule ()

@property (nonatomic) GPUImageSepiaFilter *sepiaFilter;
@property (nonatomic) GPUImageGrayscaleFilter *grayscaleFilter;

@property (nonatomic) GPUImageRawDataOutput *rawDataOutput;
@property (nonatomic, readwrite) NSString *name;

@end

@implementation RMGPUImageExampleModule

// Remap the paused property to the GPUImageFilter's property named "enabled"
@synthesize paused = enabled;

// Synthesize the properties from RMVisionModuleProtocol
@synthesize vision = _vision;
@synthesize name = _name;
@synthesize frameNumber = _frameNumber;

// Initialize the module and set up the internal filtering pipeline
- (id)initWithVision:(RMVision *)core
{
    return [self initModule:@"RMGPUImageExampleModule" withVision:core];
}

// We are a subclass of GPUImageFilterGroup
// - Multiple filters can be set up inside of this group
// - The filters can be chained together in various ways (series/parallel/etc).
// - One or multiple initialFilters (input) and a single terminalFilter (output) should be set.
//------------------------------------------------------------------------------
- (id)initModule:(NSString *)moduleName withVision:(RMVision *)core
{
    self = [super init];
    if (self) {
        
        _name = moduleName;
        
        // Initialize the individual filters
        _sepiaFilter = [[GPUImageSepiaFilter alloc] init];
        _grayscaleFilter = [[GPUImageGrayscaleFilter alloc] init];
        _rawDataOutput = [[GPUImageRawDataOutput alloc] initWithImageSize:CGSizeMake(core.width, core.height)
                                                      resultsInBGRAFormat:YES];
        
        
        
        // An example of getting the processed pixel data after doing some processing with GPUImage
        // Typically, we can do lots of per pixel processing using GPUImage but if we need to then analyze
        // the results, we can pull the data into OpenCV.
        
        __weak RMGPUImageExampleModule *weakSelf = self;
        [_rawDataOutput setNewFrameAvailableBlock:^{
            
            GLubyte *outputBytes = [weakSelf.rawDataOutput rawBytesForImage];
            NSInteger bytesPerRow = [weakSelf.rawDataOutput bytesPerRowInOutput];
            NSLog(@"Bytes per row: %d", bytesPerRow);
            
            // Copy the data into a cv::Mat
            cv::Mat exampleMat(core.height, core.width, CV_8UC4, outputBytes);

            // Just print a few pixels from the matrix for debug purposes
            std::cout << exampleMat(cv::Range(0,3), cv::Range(0,4)) << std::endl;

            
        }];
        
        // Add the filters to the filter group
        [self addFilter:self.sepiaFilter];
        [self addFilter:self.grayscaleFilter];
        
        // Setup the internal pipeline
        [_sepiaFilter addTarget:_grayscaleFilter];
        [_grayscaleFilter addTarget:_rawDataOutput];

        // Input filters
        // Multiple filters can act as input filters
        self.initialFilters = [NSArray arrayWithObjects:_sepiaFilter, nil];
        
        // Output filter
        // There can only be one
        self.terminalFilter = _grayscaleFilter;
        

        
        
    }
    return self;
}


-(void)shutdown
{
    for (GPUImageOutput *filter in filters) {
        if ([filter respondsToSelector:@selector(removeAllTargets)]) {
            [filter removeAllTargets];
        }
    }
}

// This allows us to access the image data in the traditional RMVisionModule format. For GPUImage based modules, leave this method empty.
-(void)processFrame:(const cv::Mat)mat
          videoRect:(CGRect)rect
   videoOrientation:(AVCaptureVideoOrientation)videOrientation
{
    // stub
}

@end
