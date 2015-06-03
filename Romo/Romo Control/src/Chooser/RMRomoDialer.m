//
//  RMRomoDialer.m
//  Romo
//

#import "RMRomoDialer.h"
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"

#import "RMMusicConstants.h"
#import "RMSynthesizer.h"
#import "RMSoundEffect.h"

static const CGFloat kPadding = 20; // px

static const CGFloat digitSize = 64.0; // px
static const CGFloat digitSizeiPad = 64.0; // px
static const CGFloat digitFontSize = 40.0; // px
static const CGFloat digitFontSizeiPad = 40.0; // px

static const CGFloat clearInputButtonSize = 28.0;

@interface RMRomoDialer ()

@property (nonatomic, strong) UILabel *inputNumberLabel;
@property (nonatomic, strong) UIButton *clearInputButton;

@property (nonatomic, strong) NSArray *digits;

@property (nonatomic, strong, readwrite) NSString *inputNumber;
@property (nonatomic, strong, readwrite) UIButton *callButton;

@property (nonatomic, strong) RMSynthesizer *synth;
@property (nonatomic) float frequencyToPlay;

@end

@implementation RMRomoDialer

+ (CGFloat)preferredHeight
{
    return kPadding * 6 + digitSize * 3 + 74 + 52;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _inputNumber = @"";
        _synth = [RMRealtimeAudio sharedInstance].synth;
        _synth.synthType = RMSynthWaveform_Triangle;
        [RMRealtimeAudio sharedInstance].output = YES;
        
        [self addSubview:self.inputNumberLabel];

        for (UIButton *digit in self.digits) {
            [self addSubview:digit];
        }

        [self addSubview:self.callButton];
    }
    return self;
}

- (void)dealloc
{
    [RMRealtimeAudio sharedInstance].output = NO;
}

- (void)layoutSubviews
{
    self.inputNumberLabel.frame = CGRectMake(0, kPadding, self.width, 52);
    self.clearInputButton.center = CGPointMake(self.width - clearInputButtonSize / 2.0 - kPadding, self.inputNumberLabel.centerY);
    
    [self.digits enumerateObjectsUsingBlock:^(UIButton *digit, NSUInteger index, BOOL *stop) {
        NSInteger i = (NSInteger)index;
        
        digit.centerX = (self.width / 2.0) + ((i % 3) - 1) * (digitSize + kPadding);
        digit.centerY = (self.inputNumberLabel.bottom + 20) + (i / 3) * (digitSize + kPadding) + (digitSize / 2.0);
    }];

    self.callButton.frame = CGRectMake(0, [[self.digits lastObject] centerY] + (digitSize / 2.0) + kPadding, 288, 74);
    self.callButton.centerX = self.width / 2.0;
}

#pragma mark - Public Properties

- (UIButton *)callButton
{
    if (!_callButton) {
        _callButton = [[UIButton alloc] initWithFrame:CGRectZero];
        _callButton.layer.cornerRadius = 8.0;
        _callButton.clipsToBounds = YES;
        [_callButton setBackgroundImage:[UIImage imageNamed:@"romoControlCallButton.png"] forState:UIControlStateNormal];
        [_callButton setTitle:NSLocalizedString(@"Call Remote Romo", @"Call Remote Romo") forState:UIControlStateNormal];
        [_callButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_callButton setTitleShadowColor:[UIColor colorWithHue:0.383 saturation:1.0 brightness:0.80 alpha:1.0] forState:UIControlStateNormal];
        _callButton.titleLabel.font = [UIFont largeFont];
        _callButton.titleLabel.layer.shadowOffset = CGSizeMake(0, 2.0);
        _callButton.titleLabel.layer.shadowOpacity = 0.35;
        _callButton.titleLabel.layer.shadowRadius = 1.5;
        _callButton.titleLabel.layer.masksToBounds = NO;
        _callButton.titleLabel.clipsToBounds = NO;
    }
    return _callButton;
}

#pragma mark - Private Properties

- (void)setInputNumber:(NSString *)inputNumber
{
    _inputNumber = inputNumber ? inputNumber : @"";
    self.inputNumberLabel.text = inputNumber;

    if (inputNumber.length > 0) {
        [self addSubview:self.clearInputButton];
    } else {
        [self.clearInputButton removeFromSuperview];
    }
}

- (UILabel *)inputNumberLabel
{
    if (!_inputNumberLabel) {
        _inputNumberLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _inputNumberLabel.backgroundColor = [UIColor clearColor];
        _inputNumberLabel.textColor = [UIColor whiteColor];
        _inputNumberLabel.font = [UIFont fontWithSize:48.0];
        _inputNumberLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _inputNumberLabel;
}

- (UIButton *)clearInputButton
{
    if (!_clearInputButton) {
        _clearInputButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, clearInputButtonSize, clearInputButtonSize)];
        _clearInputButton.layer.cornerRadius = clearInputButtonSize / 2.0;
        _clearInputButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.65];
        _clearInputButton.titleLabel.font = [UIFont systemFontOfSize:24.0];
        [_clearInputButton setTitle:@"x" forState:UIControlStateNormal];
        [_clearInputButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [_clearInputButton addTarget:self action:@selector(handleClearInputButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _clearInputButton;
}

- (NSArray *)digits
{
    if (!_digits) {
        NSMutableArray *digits = [NSMutableArray arrayWithCapacity:9];
        for (int i = 0; i < 9; i++) {
            UIButton *digit = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, iPad ? digitSizeiPad : digitSize, iPad ? digitSizeiPad : digitSize)];
            digit.layer.cornerRadius = (iPad ? digitSizeiPad : digitSize) / 2.0;
            digit.backgroundColor = [UIColor colorWithHue:0.54 saturation:0.65 brightness:1.0 alpha:0.90];
            digit.titleLabel.font = [UIFont fontWithSize:iPad ? digitFontSizeiPad : digitFontSize];
            [digit setTitle:[NSString stringWithFormat:@"%d", i + 1] forState:UIControlStateNormal];
            [digit setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            [digit addTarget:self action:@selector(handleDigitTouchDown:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
            [digit addTarget:self action:@selector(handleDigitTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchDragExit | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
            [digits addObject:digit];
        }
        _digits = [NSArray arrayWithArray:digits];
    }
    return _digits;
}

#pragma mark - Private Methods
- (void)handleDigitTouchDown:(UIButton *)sender
{
    int digit = 1 + [self.digits indexOfObject:sender];
    self.frequencyToPlay = [self _mapDigitToFrequency:digit];
    if (self.inputNumber.length < 7) {
        self.inputNumber = [self.inputNumber stringByAppendingString:[NSString stringWithFormat:@"%@%d", self.inputNumber.length == 3 ? @"-" : @"", digit]];
        self.synth.frequency = self.frequencyToPlay;
        [self.synth play];
    } else {
        [RMSoundEffect playForegroundEffectWithName:@"Missions-Editor-Action-Edit-Disabled" repeats:NO gain:1.0];
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self.synth selector:@selector(stop) object:nil];

    sender.transform = CGAffineTransformMakeScale(1.2, 1.2);
}

- (void)handleDigitTouchUp:(UIButton *)sender
{
    [self.synth performSelector:@selector(stop) withObject:nil afterDelay:0.1];
    [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         sender.transform = CGAffineTransformIdentity;
                     } completion:nil];
}

- (void)handleClearInputButtonTouch:(id)sender
{
    [RMSoundEffect playForegroundEffectWithName:@"Missions-Editor-Unswipe-Delete" repeats:NO gain:1.0];
    self.inputNumber = nil;
}

- (float)_mapDigitToFrequency:(int)digit
{
    if (digit == 1) { return [RMSynthesizer noteToFrequency:C inOctave:RMMusicOctave_4]; }
    else if (digit == 2) { return [RMSynthesizer noteToFrequency:D inOctave:RMMusicOctave_4]; }
    else if (digit == 3) { return [RMSynthesizer noteToFrequency:E inOctave:RMMusicOctave_4]; }
    else if (digit == 4) { return [RMSynthesizer noteToFrequency:F inOctave:RMMusicOctave_4]; }
    else if (digit == 5) { return [RMSynthesizer noteToFrequency:G inOctave:RMMusicOctave_4]; }
    else if (digit == 6) { return [RMSynthesizer noteToFrequency:Ab inOctave:RMMusicOctave_4]; }
    else if (digit == 7) { return [RMSynthesizer noteToFrequency:A inOctave:RMMusicOctave_5]; }
    else if (digit == 8) { return [RMSynthesizer noteToFrequency:B inOctave:RMMusicOctave_5]; }
    else if (digit == 9) { return [RMSynthesizer noteToFrequency:C inOctave:RMMusicOctave_5]; }
    else { return -1; }
}

@end
