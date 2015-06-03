//
//  RMCharacterFaceEmotion.m
//  RMCharacter
//

#import "RMCharacterFaceEmotion.h"
#import "RMCharacterImage.h"
#import "RMCharacterEye.h"
#import "RMCharacterVoice.h"

#define romoBackgroundBlue ([UIColor colorWithHue:0.5361 saturation:1.0 brightness:0.93 alpha:1.0])

@interface RMCharacterFaceEmotion () {
    UIImageView *_mouthView;
    CGFloat _h;
    BOOL _doubleBlink;
}

@property (nonatomic, strong) RMCharacterEye *leftEye;
@property (nonatomic, strong) RMCharacterEye *rightEye;

- (void)openEyesWithCompletion:(void (^)(BOOL))completion;
- (float)blinkDurationForEmotion:(RMCharacterEmotion)emotion;

@end

@implementation RMCharacterFaceEmotion

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.leftEye = [RMCharacterEye leftEye];
        [self addSubview:self.leftEye];
        
        self.rightEye = [RMCharacterEye rightEye];
        [self addSubview:self.rightEye];
        
        _mouthView = [[UIImageView alloc] init];
        [self addSubview:_mouthView];
        
        _h = (self.frame.size.height - 480)/2;
    }
    return self;
}

- (void)setEmotion:(RMCharacterEmotion)emotion
{    
    self.leftEye.emotion = emotion;
    [self.leftEye lookAtDefault];
    self.leftEye.close = 0.0;
    
    self.rightEye.emotion = emotion;
    [self.rightEye lookAtDefault];
    self.rightEye.close = 0.0;
    
    _mouthView.transform = CGAffineTransformIdentity;

    if (_emotion == RMCharacterEmotionSleeping) {
        [self.layer removeAllAnimations];
        self.frame= (CGRect){self.frame.origin.x, 0, self.frame.size};
    }
        
    _emotion = emotion;
    switch (_emotion) {
        case RMCharacterEmotionBewildered:
            _mouthView.image = [RMCharacterImage imageNamed:[NSString stringWithFormat:@"Romo_Emotion_Mouth_%d.png",_emotion]];
            _mouthView.frame = (CGRect){206.5, 218.5 + _h, _mouthView.image.size};
            break;

        case RMCharacterEmotionCurious:
            _mouthView.image = [RMCharacterImage imageNamed:[NSString stringWithFormat:@"Romo_Emotion_Mouth_%d.png",_emotion]];
            _mouthView.frame = (CGRect){156.5, 285.0 + _h, _mouthView.image.size};
            break;
            
        case RMCharacterEmotionExcited:
            _mouthView.image = [RMCharacterImage imageNamed:[NSString stringWithFormat:@"Romo_Emotion_Mouth_%d.png",_emotion]];
            _mouthView.frame = (CGRect){40.0, 266.0 + _h, _mouthView.image.size};
            break;
            
        case RMCharacterEmotionHappy:
            _mouthView.image = [RMCharacterImage imageNamed:[NSString stringWithFormat:@"Romo_Emotion_Mouth_%d.png",_emotion]];
            _mouthView.frame = (CGRect){43.5, 252.5 + _h, _mouthView.image.size};
            break;

        case RMCharacterEmotionIndifferent:
            _mouthView.image = [RMCharacterImage imageNamed:[NSString stringWithFormat:@"Romo_Emotion_Mouth_%d.png",_emotion]];
            _mouthView.frame = (CGRect){38.5, 261.0 + _h, _mouthView.image.size};
            break;
            
        case RMCharacterEmotionSad:
            _mouthView.image = [RMCharacterImage imageNamed:[NSString stringWithFormat:@"Romo_Emotion_Mouth_%d.png",_emotion]];
            _mouthView.frame = (CGRect){114, 269.0 + _h, _mouthView.image.size};
            break;
            
        case RMCharacterEmotionScared:
            _mouthView.image = [RMCharacterImage imageNamed:[NSString stringWithFormat:@"Romo_Emotion_Mouth_%d.png",_emotion]];
            _mouthView.frame = (CGRect){104.5, 264.0 + _h, _mouthView.image.size};
            break;

        case RMCharacterEmotionSleepy:
            _mouthView.image = [RMCharacterImage imageNamed:[NSString stringWithFormat:@"Romo_Emotion_Mouth_%d.png",RMCharacterEmotionHappy]];
            _mouthView.frame = (CGRect){43.5, 231.0 + _h, _mouthView.image.size};
            _mouthView.transform = CGAffineTransformMakeRotation(1.1 * M_PI/180.0);
            break;
            
        case RMCharacterEmotionSleeping: {
            _mouthView.image = [RMCharacterImage imageNamed:[NSString stringWithFormat:@"Romo_Emotion_Mouth_%d.png",_emotion]];
            _mouthView.frame = (CGRect){96.0, 268.0 + _h, _mouthView.image.size};
            [UIView animateWithDuration:3.0
                                  delay:0.0
                                options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat
                             animations:^{
                                 self.frame = (CGRect){self.frame.origin.x, -28, self.frame.size};
                                 self.leftEye.frame = (CGRect){self.leftEye.frame.origin.x, self.leftEye.frame.origin.y + 8, self.leftEye.frame.size};
                                 self.rightEye.frame = (CGRect){self.rightEye.frame.origin.x, self.rightEye.frame.origin.y + 8, self.rightEye.frame.size};
                                 self.leftEye.transform = CGAffineTransformScale(self.leftEye.transform, 1.0, 0.88);
                                 self.rightEye.transform = CGAffineTransformScale(self.leftEye.transform, 1.0, 0.85);
                             } completion:^(BOOL finished) {
                                 self.leftEye.transform = CGAffineTransformIdentity;
                                 self.rightEye.transform = CGAffineTransformIdentity;
                             }];
            break;}
            
        default:
            break;
    }
}

- (void)lookAtDefaultAnimated:(BOOL)animated
{
    if (animated) {
        [UIView animateWithDuration:0.12 delay:0.0 options:UIViewAnimationOptionCurveLinear
                         animations:^{
                             [self.leftEye lookAtDefault];
                             [self.rightEye lookAtDefault];
                         } completion:nil];
    } else {
        [self.leftEye lookAtDefault];
        [self.rightEye lookAtDefault];
    }
}

- (void)lookAtPoint:(RMPoint3D)point animated:(BOOL)animated
{
    if (animated) {
        [UIView animateWithDuration:0.12 delay:0.0 options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState
         animations:^{
             [self.leftEye lookAtPoint:point];
             [self.rightEye lookAtPoint:point];
         } completion:nil];
    } else {
        [self.leftEye lookAtPoint:point];
        [self.rightEye lookAtPoint:point];
    }
}

- (void)blink
{    
    if ((self.leftEye.close < 0.89 || self.leftEye.close < 0.89) && self.emotion != RMCharacterEmotionSleeping) {
        [[RMCharacterVoice sharedInstance] makeBlinkSound];
        float duration = [self blinkDurationForEmotion:self.emotion];
        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             if (self.leftEye.close < 0.89) {
                                 self.leftEye.close = 0.9;
                             }
                             if (self.rightEye.close < 0.89) {
                                 self.rightEye.close = 0.9;
                             }
                             self.frame = (CGRect){self.frame.origin.x, 4, self.frame.size};
                             self.leftEye.pupil.frame = (CGRect){self.leftEye.pupil.frame.origin.x, self.leftEye.pupil.frame.origin.y + 8, self.leftEye.pupil.frame.size};
                             self.rightEye.pupil.frame = (CGRect){self.rightEye.pupil.frame.origin.x, self.rightEye.pupil.frame.origin.y + 8, self.rightEye.pupil.frame.size};
                         } completion:^(BOOL finished) {
                             if (self.leftEye.close > 0.89 || self.rightEye.close > 0.89) {
                                 if (self.leftEye.close > 0.89) {
                                     self.leftEye.close = 1.0;
                                 }
                                 if (self.rightEye.close > 0.89) {
                                     self.rightEye.close = 1.0;
                                 }
                                 double delayInSeconds = 0.05;
                                 dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                                 dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                                     if (self.leftEye.close > 0.89 || self.rightEye.close > 0.89) {
                                         if (_doubleBlink) {
                                             [self openEyesWithCompletion:^(BOOL finished) {
                                                 _doubleBlink = NO;
                                                 [self blink];
                                             }];
                                         } else {
                                             [self openEyes];
                                         }
                                     }
                                 });
                             }
                         }];
    }
}

- (void)doubleBlink
{
    _doubleBlink = YES;
    [self blink];
}

- (void)closeLeftEye
{
    if (self.leftEye.close < 0.89 && self.emotion != RMCharacterEmotionSleeping) {
        float duration = [self blinkDurationForEmotion:self.emotion];
        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             self.leftEye.close = 0.9;
                             self.leftEye.pupil.frame = (CGRect){self.leftEye.pupil.frame.origin.x, self.leftEye.pupil.frame.origin.y + 8, self.leftEye.pupil.frame.size};
                         } completion:^(BOOL finished) {
                             if (self.leftEye.close > 0.89) {
                                 self.leftEye.close = 1.0;
                             }
                         }];
    }
}

- (void)closeRightEye
{
    if (self.rightEye.close < 0.89 && self.emotion != RMCharacterEmotionSleeping) {
        float duration = [self blinkDurationForEmotion:self.emotion];
        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             self.rightEye.close = 0.9;
                             self.rightEye.pupil.frame = (CGRect){self.rightEye.pupil.frame.origin.x, self.rightEye.pupil.frame.origin.y + 8, self.rightEye.pupil.frame.size};
                         } completion:^(BOOL finished) {
                             if (self.rightEye.close > 0.89) {
                                 self.rightEye.close = 1.0;
                             }
                         }];
    }
}

- (void)closeEyes
{
    if ((self.leftEye.close < 0.89 || self.leftEye.close < 0.89) && self.emotion != RMCharacterEmotionSleeping) {
        float duration = [self blinkDurationForEmotion:self.emotion];
        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             if (self.leftEye.close < 0.89) {
                                 self.leftEye.close = 0.9;
                                 self.leftEye.pupil.frame = (CGRect){self.leftEye.pupil.frame.origin.x, self.leftEye.pupil.frame.origin.y + 8, self.leftEye.pupil.frame.size};
                             }
                             if (self.rightEye.close < 0.89) {
                                 self.rightEye.close = 0.9;
                                 self.rightEye.pupil.frame = (CGRect){self.rightEye.pupil.frame.origin.x, self.rightEye.pupil.frame.origin.y + 8, self.rightEye.pupil.frame.size};
                             }
                         } completion:^(BOOL finished) {
                             if (self.leftEye.close > 0.89 || self.rightEye.close > 0.89) {
                                 if (self.leftEye.close > 0.89) {
                                     self.leftEye.close = 1.0;
                                 }
                                 if (self.rightEye.close > 0.89) {
                                     self.rightEye.close = 1.0;
                                 }
                             }
                         }];
    }
}

- (void)openLeftEye
{
    if (self.leftEye.close != 0.0 && self.emotion != RMCharacterEmotionSleeping) {
        float duration = [self blinkDurationForEmotion:self.emotion];
        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             self.leftEye.close = 0.0;
                         } completion:nil];
    }
}

- (void)openRightEye
{
    if (self.rightEye.close != 0.0 && self.emotion != RMCharacterEmotionSleeping) {
        float duration = [self blinkDurationForEmotion:self.emotion];
        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             self.rightEye.close = 0.0;
                         } completion:nil];
    }
}

- (void)openEyes
{
    [self openEyesWithCompletion:nil];
}

- (void)openEyesWithCompletion:(void (^)(BOOL))completion
{
    if (self.emotion != RMCharacterEmotionSleeping) {
        float duration = [self blinkDurationForEmotion:self.emotion];
        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             if (self.leftEye.close > 0.89) {
                                 self.leftEye.close = 0.0;
                                 self.leftEye.pupil.frame = (CGRect){self.leftEye.pupil.frame.origin.x, self.leftEye.pupil.frame.origin.y - 8, self.leftEye.pupil.frame.size};
                             }
                             if (self.rightEye.close > 0.89) {
                                 self.rightEye.close = 0.0;
                                 self.rightEye.pupil.frame = (CGRect){self.rightEye.pupil.frame.origin.x, self.rightEye.pupil.frame.origin.y - 8, self.rightEye.pupil.frame.size};
                             }

                             if (!_doubleBlink) {
                                 self.frame = (CGRect){self.frame.origin.x, 0, self.frame.size};
                             }
                         } completion:completion];
    }
}

- (float)blinkDurationForEmotion:(RMCharacterEmotion)emotion
{
    switch (emotion) {
        case RMCharacterEmotionSleepy:
            return 0.22;
            break;
            
        default:
            return 0.15;
            break;
    }
}

- (void)setPupilDilation:(CGFloat)pupilDilation
{
    _pupilDilation = pupilDilation;
    self.leftEye.pupil.dilation = pupilDilation;
    self.rightEye.pupil.dilation = pupilDilation;
}

@end
