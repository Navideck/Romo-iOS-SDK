//
//  RMThroughRomosEyesModule.m
//  RMVision
//

#import "RMThroughRomosEyesModule.h"
#import "RMVisionDebugBroker.h"
#import "GPUImageBrightColorNotchFilter.h"
#import "GPUImage.h"
#import "GPUImageFilter+RMAdditions.h"

#import "GPUImageMaskToPixelPositionFilter.h"

@interface RMThroughRomosEyesModule ()

@property (nonatomic) GPUImageRawDataInput *rawDataInput;

@property (nonatomic) GPUImageBrightColorNotchFilter *notchFilter;
@property (nonatomic) GPUImageGrayscaleFilter *grayscaleFilter;
@property (nonatomic) GPUImageAlphaBlendFilter *alphaBlend;
@property (nonatomic) GPUImageBoxBlurFilter *boxBlurFilter;
@property (nonatomic) GPUImageSaturationFilter *saturationFilter;

@property (nonatomic) GPUImageMaskToPixelPositionFilter *maskPositionFilter;
@property (nonatomic) GPUImageAverageColor *averageColor;

@property (nonatomic) GPUImageView *imageViewOutput;

@property (nonatomic) float saturationThreshold;
@property (nonatomic) float brightnessThreshold;

@property (nonatomic, readwrite) NSString *name;
@property (nonatomic) float scaleFactor;

@end

@implementation RMThroughRomosEyesModule

// Remap the paused property to the GPUImageFilter's property named "enabled"
@synthesize paused = enabled;

// Synthesize the properties from RMVisionModuleProtocol
@synthesize vision = _vision;
@synthesize name = _name;
@synthesize frameNumber = _frameNumber;

#pragma mark - Initialization and teardown
//------------------------------------------------------------------------------
-(id)initWithVision:(RMVision *)core
{
    return [self initModule:NSStringFromClass([self class]) withVision:core];
}

//------------------------------------------------------------------------------
- (id)initModule:(NSString *)moduleName withVision:(RMVision *)core
{
    self = [super init];
    if (self) {
        _vision = core;
        _name = moduleName;
        
        // Set up filters
        _grayscaleFilter = [[GPUImageGrayscaleFilter alloc] init];
        _notchFilter = [[GPUImageBrightColorNotchFilter alloc] init];
        _alphaBlend = [[GPUImageAlphaBlendFilter alloc] init];
        _saturationFilter = [[GPUImageSaturationFilter alloc] init];
        _boxBlurFilter = [[GPUImageBoxBlurFilter alloc] init];

        [self addFilter:_grayscaleFilter];
        [self addFilter:_notchFilter];
        [self addFilter:_alphaBlend];
        [self addFilter:_saturationFilter];
        [self addFilter:_boxBlurFilter];
        
        // Set parameters using the setter methods
        self.saturationThreshold = 0.55;
        self.brightnessThreshold = 0.65;
        self.saturationFilter.saturation = 2.0;
        
        if (self.vision.isSlow) {
            _scaleFactor = 1.0/2.0;
        }
        else {
            _scaleFactor = 1.0;
        }
        
        self.blurSize = 1.0; // Setting using the setter method
       
        // Set processing size
        CGSize processingSize = CGSizeMake(self.vision.width*_scaleFactor, self.vision.height*_scaleFactor);

        [_notchFilter forceProcessingAtSize:CGSizeMake(processingSize.width, processingSize.height)];
        [_grayscaleFilter forceProcessingAtSize:CGSizeMake(processingSize.width, processingSize.height)];
        [_alphaBlend forceProcessingAtSize:CGSizeMake(processingSize.width, processingSize.height)];
        [_saturationFilter forceProcessingAtSize:CGSizeMake(processingSize.width, processingSize.height)];
        [_boxBlurFilter forceProcessingAtSize:CGSizeMake(processingSize.width, processingSize.height)];
        
        // Input filters
        // Multiple filters can act as input filters
        self.initialFilters = [NSArray arrayWithObjects:_notchFilter, _grayscaleFilter, nil];
        
        // Pipeline
        [_notchFilter addTarget:_alphaBlend];
        [_grayscaleFilter addTarget:_alphaBlend];
        
        [_alphaBlend addTarget:_saturationFilter];
        [_saturationFilter addTarget:_boxBlurFilter];
        [_boxBlurFilter addTarget:self.imageViewOutput];  // Using self.imageViewOutput since we are doing lazy creation

        
        // Flip the output view for the front camera
        if (self.vision.camera == RMCamera_Front) {
            self.imageViewOutput.transform = CGAffineTransformMakeScale(-1,1);
        }
            
        // Output filter
        // There can only be one
        self.terminalFilter = _boxBlurFilter;
    }
    return self;
}

//------------------------------------------------------------------------------
- (void)shutdown
{
    for (GPUImageOutput *filter in filters) {
        if ([filter respondsToSelector:@selector(removeAllTargets)]) {
            [filter removeAllTargets];
        }
    }
}

//------------------------------------------------------------------------------
- (void)processFrame:(const cv::Mat)mat
           videoRect:(CGRect)rect
    videoOrientation:(AVCaptureVideoOrientation)videoOrientation
{
}

//------------------------------------------------------------------------------
- (void)blobDetected:(RMBlob *)blob
{
    if ([self.vision.delegate respondsToSelector:@selector(didDetectBlob:)]) {
        [self.vision.delegate didDetectBlob:blob];
    }
}

#pragma mark - Accessors

- (void)setOutputView:(UIView *)outputView
{
    _outputView = outputView;
    
    if (outputView) {
        self.imageViewOutput.frame = outputView.bounds;
        [outputView insertSubview:self.imageViewOutput atIndex:0];
    }
}

- (GPUImageView *)imageViewOutput
{
    if (!_imageViewOutput) {
        _imageViewOutput = [[GPUImageView alloc] initWithFrame:CGRectZero];
        _imageViewOutput.backgroundColor = [UIColor clearColor];
        _imageViewOutput.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _imageViewOutput.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
    }
    return _imageViewOutput;
}

-(void)setSaturationThreshold:(float)saturationThreshold
{
    _saturationThreshold = saturationThreshold;
    self.notchFilter.saturationThreshold = saturationThreshold;
}

-(void)setBrightnessThreshold:(float)brightnessThreshold
{
    _brightnessThreshold = brightnessThreshold;
    self.notchFilter.brightnessThreshold = brightnessThreshold;
}

-(void)setBlurSize:(float)blurSize
{
    _blurSize = blurSize;
    self.boxBlurFilter.blurSize = blurSize * self.scaleFactor;
}

@end
