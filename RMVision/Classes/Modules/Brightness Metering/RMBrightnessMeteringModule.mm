//
//  RMBrightnessMeteringModule.m
//  RMVision
//

#import "RMBrightnessMeteringModule.h"
#import <ImageIO/ImageIO.h>

/** Brightness values darker than this are considered dark */
static const float brightThreshold = -1.05;

/** Brightness values darker than this are too dark */
static const float tooDarkThreshold = -4.10;

/** Brightness values brighter than this are too bright */
static const float tooBrightThreshold = 6.10;

/**
 Values must drift by at least this much from limit
 to jump out of a state
 */
static const float switchStateWindowSize = 0.4;

/** Higher weight leads to a slower rolling average, [0.0, 1.0] */
static const float lowPassFilterWeightFastDevice = 0.98;
static const float lowPassFilterWeightSlowDevice = 0.95;

@interface RMBrightnessMeteringModule ()

@property (nonatomic, readwrite) RMVisionBrightnessState brightnessState;
@property (nonatomic) float lowPassBrightessValue;

@end

@implementation RMBrightnessMeteringModule

- (id)initModule:(NSString *)name withVision:(RMVision *)core
{
    self = [super initModule:name withVision:core];
    if (self) {
        _brightnessState = RMVisionBrightnessStateUnknown;
    }
    return self;
}

- (void)processSampleBuffer:(CMSampleBufferRef)samplebuffer
{
    NSDictionary *metadata = (__bridge NSDictionary *)CMGetAttachment(samplebuffer, kCGImagePropertyExifDictionary, NULL);
    float brightnessValue = [metadata[@"BrightnessValue"] floatValue];
    float filterWeight = self.vision.isSlow ? lowPassFilterWeightSlowDevice : lowPassFilterWeightFastDevice;
    self.lowPassBrightessValue = (filterWeight * self.lowPassBrightessValue) + ((1.0 - filterWeight) * brightnessValue);
    
    // Figure out the state for this exact reading
    RMVisionBrightnessState instantaneousState = RMVisionBrightnessStateUnknown;
    if (self.lowPassBrightessValue < tooDarkThreshold) {
        instantaneousState = RMVisionBrightnessStateTooDark;
    } else if (self.lowPassBrightessValue < brightThreshold) {
        instantaneousState = RMVisionBrightnessStateDark;
    } else if (self.lowPassBrightessValue < tooBrightThreshold) {
        instantaneousState = RMVisionBrightnessStateBright;
    } else {
        instantaneousState = RMVisionBrightnessStateTooBright;
    }
    
    if (self.brightnessState == RMVisionBrightnessStateUnknown || instantaneousState < self.brightnessState) {
        // If we're moving down a state (darker), switch state immediately
        self.brightnessState = instantaneousState;
    } else if (instantaneousState > self.brightnessState) {
        // Otherwise, make sure we've increased by at least the window size before flipping states to prevent rapid switching
        float thresholdToPass = 0;
        
        // For each current state, set the appropriate boundary to exit this state to a brighter state
        // Note: we can't ever be brighter than "too bright"
        switch (self.brightnessState) {
            case RMVisionBrightnessStateTooDark: thresholdToPass = tooDarkThreshold; break;
            case RMVisionBrightnessStateDark: thresholdToPass = brightThreshold; break;
            case RMVisionBrightnessStateBright: thresholdToPass = tooBrightThreshold; break;
            default: break;
        }
        
        if (self.lowPassBrightessValue > thresholdToPass + switchStateWindowSize) {
            self.brightnessState = instantaneousState;
        }
    }
}

- (NSString *)name
{
    return NSStringFromClass(self.class);
}

- (void)setBrightnessState:(RMVisionBrightnessState)brightnessState
{
    if (brightnessState != _brightnessState) {
        RMVisionBrightnessState previousState = _brightnessState;
        _brightnessState = brightnessState;
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(brightnessMeteringModule:didDetectBrightnessChangeFromState:toState:)]) {
                [self.delegate brightnessMeteringModule:self didDetectBrightnessChangeFromState:previousState toState:brightnessState];
            }
        });
    }
}

-(void) processFrame:(const cv::Mat)mat
           videoRect:(CGRect)rect
    videoOrientation:(AVCaptureVideoOrientation)videoOrientation
{
    // stub
}

- (void)shutdown
{
}

- (NSString *)nameForState:(RMVisionBrightnessState)state
{
    switch (state) {
        case RMVisionBrightnessStateUnknown: return @"Unknown";
        case RMVisionBrightnessStateTooBright: return @"Too Bright";
        case RMVisionBrightnessStateTooDark: return @"Too Dark";
        case RMVisionBrightnessStateDark: return @"Dark";
        case RMVisionBrightnessStateBright: return @"Bright";
    }
}

#pragma mark - Private Methods

@end
