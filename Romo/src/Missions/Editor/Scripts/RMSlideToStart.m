//
//  RMSlideToStart.m
//  Romo
//
#import "RMSlideToStart.h"

#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import <Romo/RMMath.h>
#import "RMSoundEffect.h"
#import "RMRealtimeAudio.h"
#import "RMRomoThemeSong.h"

#define kMixerDefaultGain 0.85

static const CGFloat labelOffsetX = 12.0;
static const CGFloat RomoIconOffsetX = -8.0;
static const CGFloat RomoIconOffsetY = -4.0;
//static const CGFloat dragDistance = 22.0;

typedef enum {
    // Random synth type, changes the frequency based on slider position
    RMSlideToStartSynthMode_FrequencySlider     = 0,
    // Plays the Romo theme song (notes change on slider direction changes)
    RMSlideToStartSynthMode_PlayRomoThemesong   = 1,
    // Changes the synth type and frequency on every move event
    RMSlideToStartSynthMode_CrazySlider         = 2,
    // The number of available synth modes
    RMSlideToStartSynthMode_Count
} RMSlideToStartSynthMode;

typedef enum {
    RMSynthSliderState_Untriggered,
    RMSynthSliderState_Righting,
    RMSynthSliderState_Lefting
} RMSynthSliderState;

@interface RMSlideToStart () <UIScrollViewDelegate>

@property (nonatomic, strong) UIView *labelsView;
@property (nonatomic, strong) UILabel *solidLabel;
@property (nonatomic, strong) UILabel *maskedLabel;
@property (nonatomic, strong) UIImageView *RomoIcon;
@property (nonatomic, strong) CAGradientLayer *shineLayer;
@property (nonatomic, strong) CAGradientLayer *featherLayer;
@property (nonatomic, strong) UIImageView *backgroundView;

// Sound / synth properties
@property (nonatomic) BOOL soundsEnabled;
@property (nonatomic, strong) RMSynthesizer *synth;
@property (nonatomic) RMSlideToStartSynthMode synthMode;

// For detecting direction changes
@property (atomic) RMSynthSliderState sliderState;
@property (nonatomic) double lastDragTime;
@property (nonatomic) double lastDragPosition;
@property (nonatomic) double lastDragVelocity;

@property (nonatomic) double velocityBuffer;

// For frequency sliding bounds
@property (nonatomic) float loFrequency;
@property (nonatomic) float hiFrequency;

// For playing songs
@property (nonatomic) int songIndex;
@property (nonatomic) int songPosition;

@end

@implementation RMSlideToStart

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.delegate = self;
        self.bounces = YES;
        self.contentSize = CGSizeMake(self.width * 2, self.height);
        self.contentOffset = CGPointMake(self.width, 0);
        self.pagingEnabled = YES;
        self.showsHorizontalScrollIndicator = NO;
        self.clipsToBounds = YES;
        self.layer.cornerRadius = 8.0;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationWillEnterForegroundNotification:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationDidEnterBackgroundNotification:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        
        [self addSubview:self.backgroundView];
        [self.labelsView addSubview:self.solidLabel];
        [self.labelsView addSubview:self.maskedLabel];
        [self addSubview:self.labelsView];
        [self addSubview:self.RomoIcon];
        [self scrollViewDidScroll:self];
        
        // If sounds are enabled, grab the synth and activate RMRealtimeAudio output
        self.soundsEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:soundEffectsEnabledKey];
        if (self.soundsEnabled) {
            self.synth = [RMRealtimeAudio sharedInstance].synth;
            [RMRealtimeAudio sharedInstance].output = YES;
            
            // Generate a random synth mode for this instance
            self.synthMode = arc4random_uniform(RMSlideToStartSynthMode_Count);
            self.sliderState = RMSynthSliderState_Untriggered;
        }
    }
    return self;
}

- (void)startAnimating
{
    CABasicAnimation *textAnimation = [CABasicAnimation animationWithKeyPath:@"locations"];
    [textAnimation setFromValue: @[ @-1.5, @-1.0, @-0.5 ]];
    [textAnimation setToValue: @[ @1.5, @2.0, @2.5 ]];
    [textAnimation setFillMode:kCAFillModeRemoved];
    [textAnimation setRepeatCount:HUGE_VALF];
    [textAnimation setDuration:2.0f];
    [textAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
    [self.shineLayer addAnimation:textAnimation forKey:@"gradient animation"];
}

- (void)didMoveToSuperview
{
    [super didMoveToSuperview];
    
    if (self.superview) {
        [self startAnimating];
    } else {
        [self stopAnimating];
    }
}

- (void)stopAnimating
{
    [self.shineLayer removeAllAnimations];
}

- (void)dealloc
{
    [RMRealtimeAudio sharedInstance].output = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat xOffset = scrollView.contentOffset.x;
    
    // Update the synth with a pre-determined range
    if (self.soundsEnabled) {
        [self updateSynthWithPosition:CLAMP(0, xOffset, 400)];
    }
    
    self.backgroundView.left = xOffset;
    self.backgroundView.top = -6;
    
    self.labelsView.centerX = xOffset + (self.width / 2.0) + labelOffsetX;
    self.labelsView.alpha = CLAMP(0.0, 2.0 * (xOffset - self.width / 2.0) / self.width, 1.0);
    
    self.RomoIcon.right = (-xOffset + self.width) + self.labelsView.left + RomoIconOffsetX;
    self.featherLayer.frame = CGRectMake(-xOffset + self.width - 10, 0, self.width, self.height);
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (self.soundsEnabled) {
        self.sliderState = RMSynthSliderState_Untriggered;
        self.velocityBuffer = 0;
        [self stopSynth];
    }
    if (!decelerate) {
        [self scrollViewDidEndDecelerating:scrollView];
    }
}

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (self.soundsEnabled) {
        [self startSynth];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (scrollView.contentOffset.x == 0) {
        [self.slideDelegate slideToStart:self];
    }
}

#pragma mark - Private Properties

- (UIImageView *)backgroundView
{
    if (!_backgroundView) {
        _backgroundView = [[UIImageView alloc] initWithFrame:self.bounds];
        _backgroundView.image = [UIImage imageNamed:@"missionsTopBarBackground.png"];
        _backgroundView.transform = CGAffineTransformMakeScale(1.0, -1.0);
    }
    return _backgroundView;
}

- (UIView *)labelsView
{
    if (!_labelsView) {
        _labelsView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.solidLabel.width, self.solidLabel.height)];
        _labelsView.centerY = self.height / 2.0;
        _labelsView.layer.mask = self.featherLayer;
    }
    return _labelsView;
}

- (UILabel *)solidLabel
{
    if (!_solidLabel) {
        _solidLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _solidLabel.backgroundColor = [UIColor clearColor];
        _solidLabel.text = NSLocalizedString(@"Slide-To-Start-Title",@"slide to start");
        if ([[[NSLocale preferredLanguages] objectAtIndex:0] isEqualToString:@"ja"]) {
           _solidLabel.font = [UIFont mediumFont];
        } else {
            _solidLabel.font = [UIFont largeFont];
        }
        _solidLabel.textColor = [UIColor colorWithHue:0.575 saturation:1.0 brightness:1.0 alpha:1.0];
        _solidLabel.size = [_solidLabel.text sizeWithFont:_solidLabel.font];
    }
    return _solidLabel;
}

- (UILabel *)maskedLabel
{
    if (!_maskedLabel) {
        _maskedLabel = [[UILabel alloc] initWithFrame:self.solidLabel.frame];
        _maskedLabel.backgroundColor = [UIColor clearColor];
        _maskedLabel.text = NSLocalizedString(@"Slide-To-Start-Title",@"slide to start");
        if ([[[NSLocale preferredLanguages] objectAtIndex:0] isEqualToString:@"ja"]) {
            _maskedLabel.font = [UIFont mediumFont];
        } else {
            _maskedLabel.font = [UIFont largeFont];
        }
        _maskedLabel.textColor = [UIColor colorWithHue:0.42 saturation:0.2 brightness:1.0 alpha:1.0];
        _maskedLabel.layer.mask = self.shineLayer;
    }
    return _maskedLabel;
}

- (CAGradientLayer *)shineLayer
{
    if (!_shineLayer) {
        _shineLayer = [CAGradientLayer layer];
        _shineLayer.frame = self.maskedLabel.bounds;
        _shineLayer.colors = @[(id)[UIColor clearColor].CGColor,
                               (id)[UIColor blackColor].CGColor,
                               (id)[UIColor clearColor].CGColor
                               ];
        _shineLayer.locations = @[ @-1.5, @-1.0, @-0.5 ];
        _shineLayer.startPoint = CGPointZero;
        _shineLayer.endPoint = CGPointMake(1.0, 0.0);
    }
    return _shineLayer;
}

- (CAGradientLayer *)featherLayer
{
    if (!_featherLayer) {
        _featherLayer = [CAGradientLayer layer];
        _featherLayer.frame = self.bounds;
        _featherLayer.colors = @[(id)[UIColor clearColor].CGColor,
                                 (id)[UIColor blackColor].CGColor,
                                 ];
        _featherLayer.locations = @[ @0.0, @0.04 ];
        _featherLayer.startPoint = CGPointZero;
        _featherLayer.endPoint = CGPointMake(1.0, 0.0);
        _featherLayer.duration = 0.0;
    }
    return _featherLayer;
}

- (UIImageView *)RomoIcon
{
    if (!_RomoIcon) {
        _RomoIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"missionStartButton.png"]];
        _RomoIcon.centerY = self.height / 2.0 + RomoIconOffsetY;
    }
    return _RomoIcon;
}

#pragma mark - Private Methods

- (void)handleApplicationWillEnterForegroundNotification:(NSNotification *)notification
{
    if (self.superview) {
        [self startAnimating];
    }
}

- (void)handleApplicationDidEnterBackgroundNotification:(NSNotification *)notification
{
    [self stopAnimating];
}

#pragma mark - RMSynthesizer helpers
//------------------------------------------------------------------------------
- (void)setSynthMode:(RMSlideToStartSynthMode)synthMode
{
    _synthMode = synthMode;
    switch (_synthMode) {
        case RMSlideToStartSynthMode_FrequencySlider:
            break;
        case RMSlideToStartSynthMode_PlayRomoThemesong:
            self.synth.synthType = arc4random_uniform(2) ? RMSynthWaveform_Square : RMSynthWaveform_Sawtooth;
            self.songIndex = arc4random_uniform(2);
            self.songPosition = 0;
            break;
        case RMSlideToStartSynthMode_CrazySlider:
            
            break;
        default:
            break;
    }
}

// Starts playing a note on the synth given the current synth mode
//------------------------------------------------------------------------------
- (void)startSynth
{
    switch (self.synthMode) {
        case RMSlideToStartSynthMode_FrequencySlider:
            self.synth.synthType = arc4random_uniform(4);
            self.loFrequency = [RMMath randFloatWithLowerBound:[RMSynthesizer noteToFrequency:A inOctave:RMMusicOctave_2]
                                                 andUpperBound:[RMSynthesizer noteToFrequency:A inOctave:RMMusicOctave_3]];
            
            self.hiFrequency = [RMMath randFloatWithLowerBound:[RMSynthesizer noteToFrequency:A inOctave:RMMusicOctave_4]
                                                 andUpperBound:[RMSynthesizer noteToFrequency:C inOctave:RMMusicOctave_5]];

            break;
        case RMSlideToStartSynthMode_PlayRomoThemesong:
            [self playNextNote];
            break;
        case RMSlideToStartSynthMode_CrazySlider:
            
            break;
        default:
            break;
    }
    [self.synth play];
}

// Updates the synth with the finger location given the current synth mode
//------------------------------------------------------------------------------
- (void)updateSynthWithPosition:(float)position
{
    BOOL changedDirection = [self detectDirectionChange:position];

    switch (self.synthMode) {
        case RMSlideToStartSynthMode_FrequencySlider: {
            self.synth.frequency = [RMMath map:position min:400 max:0 out_min:self.loFrequency out_max:self.hiFrequency];
        }
            break;
        case RMSlideToStartSynthMode_PlayRomoThemesong: {
            self.synth.effectPosition = [RMMath map:position min:400 max:0 out_min:0.0 out_max:0.75];
            Float32 newGain = [RMMath map:position min:400 max:0 out_min:0.85 out_max:0.05];
            [[RMRealtimeAudio sharedInstance] setMixerOutputGain:newGain];
            if (changedDirection) {
                self.songPosition++;
                [self playNextNote];
            }
        }
            break;
        case RMSlideToStartSynthMode_CrazySlider: {
            self.synth.synthType = arc4random_uniform(4);
            self.loFrequency = [RMMath randFloatWithLowerBound:[RMSynthesizer noteToFrequency:A inOctave:RMMusicOctave_2]
                                                 andUpperBound:[RMSynthesizer noteToFrequency:A inOctave:RMMusicOctave_3]];
            
            self.hiFrequency = [RMMath randFloatWithLowerBound:[RMSynthesizer noteToFrequency:A inOctave:RMMusicOctave_4]
                                                 andUpperBound:[RMSynthesizer noteToFrequency:A inOctave:RMMusicOctave_6]];
            
            self.synth.frequency = [RMMath map:position min:400 max:0 out_min:self.loFrequency out_max:self.hiFrequency];
        }
            break;
        default:
            break;
    }
}

// Stops playing a note on the synth given the current synth mode
//------------------------------------------------------------------------------
- (void)stopSynth
{
    [self.synth stop];
    [[RMRealtimeAudio sharedInstance] setMixerOutputGain:kMixerDefaultGain];
    switch (self.synthMode) {
        case RMSlideToStartSynthMode_FrequencySlider:
            
            break;
        case RMSlideToStartSynthMode_PlayRomoThemesong:
            self.songPosition++;
            break;
        case RMSlideToStartSynthMode_CrazySlider:
            
            break;
        default:
            break;
    }
}

// Detects changes in touch directions
//------------------------------------------------------------------------------
- (BOOL)detectDirectionChange:(float)position
{
    BOOL detectedChange = NO;
    
    double timeOfCapture = currentTime();
    float timeDiff = timeOfCapture - self.lastDragTime;
    float posDiff = position - self.lastDragPosition;
    float velocity = posDiff / timeDiff;
    
    self.velocityBuffer += velocity;
    if (!SAME_SIGN(velocity, self.lastDragVelocity)) {
        self.velocityBuffer = 0;
    }
    
    float kVelocityBufferOverflow = 600.0f;
    // Has the buffer filled?
    if (ABS(self.velocityBuffer) > kVelocityBufferOverflow) {
        switch (self.sliderState) {
            case RMSynthSliderState_Untriggered:
                if (self.velocityBuffer < 0) {
                    self.sliderState = RMSynthSliderState_Righting;
                } else if (self.velocityBuffer > 0) {
                    self.sliderState = RMSynthSliderState_Lefting;
                }
                break;
            case RMSynthSliderState_Lefting:
                if (self.velocityBuffer < 0) {
                    self.sliderState = RMSynthSliderState_Righting;
                    detectedChange = YES;
                }
                break;
            case RMSynthSliderState_Righting:
                if (self.velocityBuffer > 0) {
                    self.sliderState = RMSynthSliderState_Lefting;
                    detectedChange = YES;
                }
                break;
            default:
                break;
        }
    }
    
    self.lastDragPosition = position;
    self.lastDragVelocity = velocity;
    self.lastDragTime = timeOfCapture;
    
    return detectedChange;
}

// Helper method for setting the next note in the synth for a song
//------------------------------------------------------------------------------
- (void)playNextNote
{
    // Change song / loop if done
    int songLength = sizeof(themeSong) / sizeof(int);
    if (self.songIndex == 1) {
        songLength = sizeof(ringTone) / sizeof(int);
    }
    if (self.songPosition == songLength) {
        self.songPosition = 0;
        if (self.songIndex == 0) {
            self.songIndex = 1;
        } else {
            self.songIndex = 0;
        }
    }
    
    float nextNote = [RMSynthesizer noteToFrequency:themeSong[self.songPosition]
                                           inOctave:RMMusicOctave_2];
    if (self.songIndex == 1) {
        nextNote = [RMSynthesizer noteToFrequency:ringTone[self.songPosition]
                                         inOctave:RMMusicOctave_3];
    }
    self.synth.frequency = nextNote;
}

@end
