//
//  RMMotionDetectionModule.mm
//  RMVision
//

#import "RMMotionDetectionModule.h"
#import "RMVision_Internal.h"
#import "RMMotionTriggeredColorTrainingModule.h"
#import <RMShared/RMMath.h>

using namespace cv;

static const float scaleFactorSlowDevice = 32.0;
static const float scaleFactorFastDevice = 16.0;

static const float percentOfPixelsMovingThreshold = 2.5; // percent

static const int consecutiveTriggerCountForConfirmedMotion = 5; // # of frames

@interface RMMotionDetectionModule ()

@property (nonatomic) int consecutiveTriggerCount;

@property (nonatomic, readwrite, getter=isDetectingMotion) BOOL detectingMotion;

@end

@implementation RMMotionDetectionModule

// Remap the paused property to the GPUImageFilter's property named "enabled"
@synthesize paused = enabled;

// Synthesize the properties from RMVisionModuleProtocol
@synthesize vision = _vision;
@synthesize name = _name;
@synthesize frameNumber = _frameNumber;

- (id)initWithVision:(RMVision *)vision
{
    return [self initModule:NSStringFromClass(self.class) withVision:vision];
}

- (id)initModule:(NSString *)name withVision:(RMVision *)vision
{
    self = [super init];
    if (self) {
        _vision = vision;
        _name = name;
        
        _minimumConsecutiveTriggerCount = consecutiveTriggerCountForConfirmedMotion;
        _minimumPercentageOfPixelsMoving = percentOfPixelsMovingThreshold;
        
        float scaleFactor = 1.0;
        if (self.vision.isSlow) {
            scaleFactor = 1.0 / scaleFactorSlowDevice;
        } else {
            scaleFactor = 1.0 / scaleFactorFastDevice;
        }
        CGSize processingSize = CGSizeMake(vision.width * scaleFactor, vision.height * scaleFactor);
        
        GPUImageMotionDetector *motionDetector = [[GPUImageMotionDetector alloc] init];
        [self addFilter:motionDetector];
        [motionDetector forceProcessingAtSize:processingSize];
        
        __weak RMMotionDetectionModule *weakSelf = self;
        motionDetector.motionDetectionBlock = ^(CGPoint motionCentroid, CGFloat motionIntensity, CMTime frameTime){
            float percentOfPixelsThatAreMoving = 100.0 * motionIntensity;
            
            // Scale the trigger count by the framerate to result in the same amount of time
            int minimumConsecutiveTriggerCount = ceilf((float)self.minimumConsecutiveTriggerCount * self.vision.targetFrameRate / 24.0);
            
            if (percentOfPixelsThatAreMoving >= self.minimumPercentageOfPixelsMoving)  {
                // If enough are moving, increment the consecutive count
                weakSelf.consecutiveTriggerCount = MIN(minimumConsecutiveTriggerCount, weakSelf.consecutiveTriggerCount + 1);
                
                if (!self.isDetectingMotion && weakSelf.consecutiveTriggerCount >= minimumConsecutiveTriggerCount) {
                    // If we've hit enough consecutive frames, then we have confirmed motion
                    // We tell our delegate
                    self.detectingMotion = YES;

                    dispatch_async(dispatch_get_main_queue(), ^(void){
                        [weakSelf.delegate motionDetectionModuleDidDetectMotion:weakSelf];
                    });
                }
            } else {
                // If we're not seeing motion, decrement the consecutive count
                weakSelf.consecutiveTriggerCount--;
                if (weakSelf.consecutiveTriggerCount <= 0) {
                    self.consecutiveTriggerCount = 0;
                    if (self.detectingMotion) {
                        self.detectingMotion = NO;
                        // Once that count hits zero, confirm with our delegate that we're not seeing motion
                        dispatch_async(dispatch_get_main_queue(), ^(void){
                            [weakSelf.delegate motionDetectionModuleDidDetectEndOfMotion:weakSelf];
                        });
                    }
                }
            }
        };
        
        self.initialFilters = @[motionDetector];
        self.terminalFilter = nil;
    }
    return self;
}

- (void)shutdown
{
    for (GPUImageOutput *filter in filters) {
        if ([filter respondsToSelector:@selector(removeAllTargets)]) {
            [filter removeAllTargets];
        }
    }
}

#pragma mark - Frame Processing

- (void)processFrame:(const cv::Mat)mat
           videoRect:(CGRect)rect
    videoOrientation:(AVCaptureVideoOrientation)videoOrientation
{
    // stub
}

@end
