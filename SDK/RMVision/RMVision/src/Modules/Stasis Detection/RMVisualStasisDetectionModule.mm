//
//  RMVisualStasisDetectionModule.m
//  RMVision
//
//  Created on 9/16/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "RMVisualStasisDetectionModule.h"
#import "GPUImage.h"
#import "RMMath.h"

#ifdef VISUAL_STASIS_DEBUG
#import "DDLog.h"
// TODO: !! Figure out why this "needs" to be included here !!
static int ddLogLevel __unused = LOG_LEVEL_INFO;
// TODO: !! Figure out why this "needs" to be included here !!
#endif

// frame processing resolution
#define FRAME_WIDTH          144      // pixel width in portrait orientation

// Private members
@interface RMVisualStasisDetectionModule()

// frame's height is derrived from FRAME_WIDTH
@property (nonatomic) int frameHeight;

// required GPU filters
@property (nonatomic, strong) GPUImageFastBlurFilter *blurFilter;
@property (nonatomic, strong) GPUImageBuffer *imageBuffer;
@property (nonatomic, strong) GPUImageAverageColor *frameAverager;
@property (nonatomic, strong) GPUImageTwoInputFilter *crossComparisonFilter;

// frame data for GPU processing
@property (nonatomic, strong) GPUImageRawDataInput *rawDataInput;

// average pixel value of the most recently processed frame (average across
// frame and color channels)
@property (nonatomic) float averageFrameValue;

// sensor state indicator
@property (nonatomic) BOOL stasisDetected;

// low-pass filter used to filter sensor output
@property (nonatomic) float stasisLPFValue;

#ifdef VISUAL_STASIS_DEBUG
@property (nonatomic, strong) RMVisionDebugWindow *debugWindow;
#endif

@end


@implementation RMVisualStasisDetectionModule

#pragma mark - setup

- (id)initWithVision:(RMVision *)core
{
    self = [super initModule:@"RMVisionModule_StasisDetection" withVision:core ];
    
    if (self) {
        _stasisDetected = NO;
        
#ifdef VISUAL_STASIS_DEBUG
        // setup debugging interface
        _debugWindow = [[RMVisionDebugWindow alloc]
                        initWithFrame: CGRectMake(0, 0, 288, 352) ];
#endif
    }
    
    return self;
}

- (void)setupFilterPipelineWithBytes:(GLubyte *)bytes withSize:(CGSize)size
{
    // initialize GPU frame buffer
    self.rawDataInput = [[GPUImageRawDataInput alloc] initWithBytes:bytes
                                                               size:size ];
    // calc frame height
    self.frameHeight = self.vision.height * (FRAME_WIDTH/self.vision.width);
    
    // initialize GPU filters
    
    // blur makes pixel-by-pixel comparsion between frames (as performed by
    // cross-comparision filter) not care so much at the pixel level
    self.blurFilter = [[GPUImageFastBlurFilter alloc] init];
    [self.blurFilter forceProcessingAtSizeRespectingAspectRatio:CGSizeMake(FRAME_WIDTH, _frameHeight)];
    self.blurFilter.blurSize = 0.5;
    
    // this is used to compare the current frame to one from the past
    self.imageBuffer = [[GPUImageBuffer alloc] init];
    //    self.imageBufferFilter.bufferSize = 3; <-- this should work but doesn't
    //                                               due to a bug in GPUImage
    
    // this finds the average pixel value of the frame
    __weak RMVisualStasisDetectionModule *weakSelf = self;
    self.frameAverager = [[GPUImageAverageColor alloc] init];
    [self.frameAverager setColorAverageProcessingFinishedBlock:^(CGFloat redComponent, CGFloat greenComponent, CGFloat blueComponent, CGFloat alphaComponent, CMTime frameTime)
     {
         weakSelf.averageFrameValue = redComponent + greenComponent + blueComponent;
     } ];
    
    // this does a quick pixel-by-pixel comparision of the current image and one
    // taken in the past
    self.crossComparisonFilter = [[GPUImageTwoInputFilter alloc] initWithFragmentShaderFromString:kGPUImageMotionComparisonFragmentShaderString];
    
    // build filter pipeline
    
    // this is the new frame, blurred and primed to be compared to the old frame
    [self.rawDataInput addTarget:self.blurFilter];
    [self.blurFilter addTarget:self.crossComparisonFilter];
    
    // this is the old frame, blurred and primed to be compared to the old frame
    // (and then the average value of the differenced frame is taken)
    [self.blurFilter addTarget:self.imageBuffer];
    [self.imageBuffer addTarget:self.crossComparisonFilter];
    [self.crossComparisonFilter addTarget:self.frameAverager];
}

#pragma mark - sensing

// This module tries to detect if the robot is not moving by comparing how much
// the value of each pixel in the image has changed since the previous frame.
// If the average value of the pixel differences is small then the image is
// unchanging and we assume the robot is not moving.  In order to smooth the
// virtual sensor output the "stasis score" is put through a low-pass filter
// and a threshold is applied there in order to determine the stasis state.
- (void)processFrame:(const cv::Mat)mat
           videoRect:(CGRect)rect
    videoOrientation:(AVCaptureVideoOrientation)videOrientation
{
    const float kTargetProcessingPeriod = 1/6.; // frequency to run this loop
    
    const float kLPFAlpha = 0.4;                // low-pass filter parameter
    const float kStasisThreshold = 0.13;        // stasis threshold (empirical)
    
    static double lastFrameProcessedTime = -1;
    double now = currentTime();
    
    
    // initialize
    if(lastFrameProcessedTime < 0)
    {
        lastFrameProcessedTime = now;
    }
    
    // make sure this algorithm does not run faster than intended (otherwise
    // low-pass filter won't work right)
    if((now - lastFrameProcessedTime) >= kTargetProcessingPeriod)
    {
        lastFrameProcessedTime = now;
        
        // put the current frame into the GPU
        if(self.rawDataInput)
        {
            // create & load frame buffer
            [self.rawDataInput updateDataFromBytes:(GLubyte *)mat.data
                                              size:rect.size ];
        }
        else
        {
            // load in new frame (first time only)
            [self setupFilterPipelineWithBytes:(GLubyte *)mat.data
                                      withSize:rect.size ];
        }
        
        // apply GPU filtering
        [self.rawDataInput processData];
        
        // update low-pass filter
        self.stasisLPFValue += kLPFAlpha *
        (self.averageFrameValue - self.stasisLPFValue);
        
        // set stasis state
        if(self.stasisLPFValue < kStasisThreshold)
        {
            if(self.stasisDetected == NO)
            {
                self.stasisDetected = YES;
                
                [[NSNotificationCenter defaultCenter]
                 postNotificationName:@"RMVisualStasisDetected" object:nil ];
            }
        }
        else
        {
            if(self.stasisDetected == YES)
            {
                self.stasisDetected = NO;
                
                [[NSNotificationCenter defaultCenter]
                 postNotificationName:@"RMVisualStasisCleared" object:nil ];
            }
        }
        
#ifdef VISUAL_STASIS_DEBUG
        // show differenced image on screen
        [self.debugWindow displayWithImage:[self.crossComparisonFilter imageFromCurrentlyProcessedOutputWithOrientation:
                                            UIImageOrientationUp ] ];
#endif
    }
}

#pragma mark - cross comparison filter

// NOTE:  This block of code was lifted from the top of Brad Larson's
//        GPUImageMotionDetector.h file.  It is a very fast way to find the
//        differences between two images
NSString *const kGPUImageMotionComparisonFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 varying highp vec2 textureCoordinate2;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;
 
 uniform highp float intensity;
 
 void main()
 {
     lowp vec3 currentImageColor = texture2D(inputImageTexture, textureCoordinate).rgb;
     lowp vec3 oldImageColor = texture2D(inputImageTexture2, textureCoordinate2).rgb;
     mediump float colorDistance = distance(currentImageColor, oldImageColor); // * 0.57735
     lowp float movementThreshold = step(0.2, colorDistance);
     gl_FragColor = movementThreshold * vec4(textureCoordinate2.x, textureCoordinate2.y, 1.0, 1.0);
 }
 );

@end


#pragma mark - RMVisionDebugWindow Class

#ifdef VISUAL_STASIS_DEBUG
@implementation RMVisionDebugWindow

// NOTE:  UIView take a _very_ long time before it displays the first
//        time.  Backgrouding and then foregrounding the app will cause
//        it to appear immediately

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if(!self) {return nil;}
    
    _view = [[UIImageView alloc] initWithFrame:frame];
    
    [self addSubview:_view];
    
    [self present];
    
    return self;
}

// display image
- (void)displayWithImage:(UIImage*)image
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.view.image = image;
        [self.view sizeToFit];
    } );
}

// show window
- (void)present
{
    // set window to be on top
    self.windowLevel = UIWindowLevelAlert;
    [self makeKeyAndVisible];
}

// hide window
- (void)dismiss
{
    [super removeFromSuperview];
    self.hidden = YES;
}

@end
#endif