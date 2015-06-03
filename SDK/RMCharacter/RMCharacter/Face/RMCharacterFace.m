
//
//  RMCharacterFace.m
//  RMCharacter
//

#import "RMCharacterFace.h"
#import "RMCharacterAnimation.h"
#import "RMCharacterProtectedView.h"
#import "RMCharacterFaceEmotion.h"
#import "RMMath.h"
#import "RMCharacterColorFill.h"

#define romoBackgroundBlue ([UIColor colorWithHue:0.5361 saturation:1.0 brightness:0.93 alpha:1.0])

typedef void (^AnimationCompletion)(BOOL);

int _audioBreakpoints[33] = {
    -1,	// Neutral
    4,  // Angry
    2,  // Bored
    6,  // Curious
    2,  // Dizzy
    2,  // Embarrassed
    5,  // Excited
    6,  // Exhausted
    21, // Happy
    5,  // Holding Breath
    3,  // Laugh
    3,  // Looking Around
    2,  // Love
    3,  // Ponder
    12, // Sad
    5,  // Scared
    2,  // Sleepy
    7,  // Sneeze
    4,  // Talking
    5,  // Yawn
    0,  // Startled
    0,  // Chuckle
    0,  // Proud
    0,  // Let down
    0,  // Want
    0,  // Hiccup
    0,  // Fart
    0,  // Bewildered
    0,  // Yippee
    0,  // Sniff
    0,  // Smack
    0,  // Wee
    0,  // Struggling
};

@interface RMCharacterFace () <RMCharacterAnimationDelegate> {
    UIView *_hiddenView;
    UIView *_faceView;
    RMCharacterExpression _queuedExpression;
    RMCharacterEmotion _queuedEmotion;
}

@property (nonatomic) BOOL emoting;
@property (nonatomic) BOOL expressing;

@property (nonatomic, strong) RMCharacterAnimation *animation;
@property (nonatomic, strong) RMCharacterFaceEmotion *faceEmotion;
@property (nonatomic)         RMCharacterExpression complexion;

@property (nonatomic, strong) RMCharacterColorFill *colorFill;

- (RMCharacterFace *)initWithCharacterType:(RMCharacterType)characterType;
- (void)animationDidFinish;

@end

@implementation RMCharacterFace

+ (RMCharacterFace *)faceWithCharacterType:(RMCharacterType)characterType
{
    return [[RMCharacterFace alloc] initWithCharacterType:characterType];
}

- (RMCharacterFace *)initWithCharacterType:(RMCharacterType)characterType
{
    self = [super init];
    if (self) {
        _characterType = characterType;
    }
    return self;
}

- (void)loadView
{
    CGRect frame = [UIScreen mainScreen].bounds;
    frame.size.width = MIN(320, frame.size.width);
    _hiddenView = [[UIView alloc] initWithFrame:frame];
    _faceView = [[UIView alloc] initWithFrame:frame];
    
    self.view = (UIView *)[[RMCharacterProtectedView alloc] initWithFrame:frame backgroundColor:romoBackgroundBlue subview:_hiddenView];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.animation = [[RMCharacterAnimation alloc] initWithFrame:_hiddenView.bounds];
    self.animation.delegate = self;
    self.animation.backgroundColor = [UIColor clearColor];
    [_faceView addSubview:self.animation];
    
    self.faceEmotion = [[RMCharacterFaceEmotion alloc] initWithFrame:_hiddenView.bounds];
    
    _emotion = RMCharacterEmotionHappy;
    self.faceEmotion.emotion = RMCharacterEmotionHappy;
    self.animation.image = [RMCharacterImage imageNamed:[NSString stringWithFormat:@"Romo_Emotion_%d.png",RMCharacterEmotionHappy]];
    [_faceView addSubview:self.faceEmotion];
    [_hiddenView addSubview:_faceView];
    [self.animation removeFromSuperview];
}

- (void)setEmotion:(RMCharacterEmotion)emotion
{
    if (!self.emoting && !self.expressing && (emotion != _emotion) && self.view.superview) {
        // If we aren't mid-animation and the character is visible
        
        RMCharacterEmotion __block finalEmotion = emotion;
        
        self.emoting = YES;
        self.animation.image = [RMCharacterImage imageNamed:[NSString stringWithFormat:@"Romo_Emotion_%d.png",emotion]];
        [_faceView addSubview:self.animation];
        [self.faceEmotion removeFromSuperview];
        
        // Outro from the existing emotion
        __weak RMCharacterFace *weakSelf = self;
        [self.animation animateWithAction:RMAnimatedActionOutro
                               forEmotion:_emotion
                               completion:^(BOOL finished) {
                                   // If the desired emotion changed, we can just go to that one
                                   if (_queuedEmotion) {
                                       finalEmotion = _queuedEmotion;
                                       _queuedEmotion = 0;
                                   }
                                   // Animated into into new emotion
                                   [weakSelf.delegate expressionFaceAnimationDidStart];
                                   [weakSelf transitionToEmotion:emotion];
                               }];
    } else if (self.emoting || self.expressing) {
        // If we're currently animating, queue this as the final desired emotion
        _queuedEmotion = emotion;
    }
}

- (void)setFillColor:(UIColor *)fillColor percentage:(float)percentage
{
    if (percentage <= 0 || !fillColor || [fillColor isEqual:[UIColor clearColor]]) {
        if (_colorFill) {
            [self.colorFill removeFromSuperview];
            self.colorFill = nil;
        }
    } else {
        self.colorFill.fillColor = fillColor;
        self.colorFill.fillAmount = percentage / 100.0;
    }
}

- (RMCharacterColorFill *)colorFill
{
    if (!_colorFill) {
        _colorFill = [[RMCharacterColorFill alloc] initWithFrame:_hiddenView.bounds];
        
        // Ensure we add the color fill above any complexion views
        __block int highestIndex = -1;
        [_hiddenView.subviews enumerateObjectsUsingBlock:^(UIView* subview, NSUInteger index, BOOL *stop) {
            if (subview.tag == 111) {
                highestIndex = index;
            }
        }];
        [_hiddenView insertSubview:_colorFill atIndex:highestIndex + 1];
    }
    return _colorFill;
}

- (void)setExpression:(RMCharacterExpression)expression
{
    [self setExpression:expression withEmotion:_emotion];
}

- (void)setExpression:(RMCharacterExpression)expression withEmotion:(RMCharacterEmotion)emotion
{
    __weak RMCharacterFace *weakSelf = self;
    
    if (expression == RMCharacterExpressionNone) {
        // If we aren't given an expression, simply change emotions
        self.emotion = emotion;
        
    } else if (!self.emoting && !self.expressing && self.view.superview) {
        [_faceView addSubview:self.animation];
        [self.faceEmotion removeFromSuperview];
        
        RMCharacterEmotion startEmotion = self.emotion;
        RMCharacterEmotion __block finalEmotion = emotion;
        
        // Handles the expression anim and outro anim (if needed)
        // Then transitions into the newest queued emotion
        AnimationCompletion expressionToEmotion = ^(BOOL finished) {
            weakSelf.complexion = expression;
            weakSelf.animation.breakpointFrame = expression < (RMCharacterExpression)100 ? _audioBreakpoints[expression] : 0;
            [weakSelf.animation animateWithAction:RMAnimatedActionExpression
                                    forExpression:expression
                                       completion:^(BOOL finished) {
                                           if (_queuedEmotion) {
                                               finalEmotion = _queuedEmotion;
                                               _queuedEmotion = 0;
                                           }
                                           weakSelf.animation.breakpointFrame = -1;
                                           weakSelf.complexion = RMCharacterExpressionNone;
                                           
                                           // Check if we need to animate out then back in to the emotion, or not
                                           BOOL needsOutroToEmotion = ![weakSelf expression:expression endsWithEmotion:finalEmotion];
                                           if (needsOutroToEmotion) {
                                               [weakSelf.animation animateWithAction:RMAnimatedActionOutro
                                                                       forExpression:expression
                                                                          completion:^(BOOL finished) {
                                                                              [weakSelf transitionToEmotion:finalEmotion];
                                                                          }];
                                           } else {
                                               [weakSelf immediateTransitionToEmotion:finalEmotion];
                                           }
                                       }];
        };
        
        self.expressing = YES;
        _expression = expression;
        [self.faceEmotion lookAtDefaultAnimated:YES];
        self.animation.breakpointFrame = -1;
        
        BOOL needsTransitionToExpression = ![self expression:expression startsWithEmotion:startEmotion];
        if (needsTransitionToExpression) {
            [self.animation animateWithAction:RMAnimatedActionOutro
                                   forEmotion:startEmotion
                                   completion:^(BOOL finished) {
                                       _emotion = finalEmotion;
                                       [weakSelf.delegate expressionFaceAnimationDidStart];
                                       [weakSelf.animation animateWithAction:RMAnimatedActionIntro
                                                               forExpression:expression
                                                                  completion:expressionToEmotion];
                                   }];
        } else {
            _emotion = finalEmotion;
            [self.delegate expressionFaceAnimationDidStart];
            expressionToEmotion(YES);
        }
    } else if (self.emoting && self.expressing && self.view.superview) {
        _queuedEmotion = emotion;
    } else if (self.emoting && self.view.superview) {
        _queuedExpression = expression;
        _queuedEmotion = emotion;
    }
}

// Some expressions began in an emotion and don't need an animated transition
- (BOOL)expression:(RMCharacterExpression)expression startsWithEmotion:(RMCharacterEmotion)emotion
{
    switch (expression) {
        case RMCharacterExpressionCurious:
        case RMCharacterExpressionLookingAround:
        case RMCharacterExpressionPonder:
            return (emotion == RMCharacterEmotionCurious);
            
        case RMCharacterExpressionSad:
            return (emotion == RMCharacterEmotionSad);
            
        case RMCharacterExpressionScared:
            return (emotion == RMCharacterEmotionScared);
            
        case RMCharacterExpressionSleepy:
            return (emotion == RMCharacterEmotionSleepy);
            
        case RMCharacterExpressionFart:
        case RMCharacterExpressionWee:
        case RMCharacterExpressionStruggling:
            return (emotion == RMCharacterEmotionHappy);
            
        case RMCharacterExpressionBewildered:
            return (emotion == RMCharacterEmotionBewildered);
            
        default:
            break;
    }
    
    if ((int)expression >= 100) {
        return (emotion == RMCharacterEmotionHappy);
    }
    
    return NO;
}

// Some expressions end in an emotion and don't need an animated transition
- (BOOL)expression:(RMCharacterExpression)expression endsWithEmotion:(RMCharacterEmotion)emotion
{
    switch (expression) {
        case RMCharacterExpressionCurious:
        case RMCharacterExpressionLookingAround:
        case RMCharacterExpressionPonder:
            return (emotion == RMCharacterEmotionCurious);
            
        case RMCharacterExpressionExcited:
        case RMCharacterExpressionLaugh:
        case RMCharacterExpressionChuckle:
        case RMCharacterExpressionProud:
            return (emotion == RMCharacterEmotionExcited);
            
        case RMCharacterExpressionHappy:
            return (emotion == RMCharacterEmotionHappy);
            
        case RMCharacterExpressionSad:
            return (emotion == RMCharacterEmotionSad);
            
        case RMCharacterExpressionScared:
            return (emotion == RMCharacterEmotionScared);
            
        case RMCharacterExpressionSleepy:
        case RMCharacterExpressionYawn:
            return (emotion == RMCharacterEmotionSleepy);
            
        case RMCharacterExpressionHiccup:
            return (emotion == RMCharacterEmotionIndifferent);
            
        case RMCharacterExpressionBewildered:
            return (emotion == RMCharacterEmotionBewildered);
            
        case RMCharacterExpressionYippee:
            return (emotion == RMCharacterEmotionDelighted);
            
        default:
            break;
    }
    
    if ((int)expression >= 100) {
        return (emotion == RMCharacterEmotionHappy);
    }
    
    return NO;
}

// Transitions into the modular emotion using the emotion's intro
- (void)transitionToEmotion:(RMCharacterEmotion)emotion
{
    _emotion = emotion;
    
    // Intro into final emotion
    __weak RMCharacterFace *weakSelf = self;
    [self.animation animateWithAction:RMAnimatedActionIntro
                           forEmotion:_emotion
                           completion:^(BOOL finished) {
                               [weakSelf immediateTransitionToEmotion:_emotion];
                           }];
}

// Immediately displays the modular emotion
- (void)immediateTransitionToEmotion:(RMCharacterEmotion)emotion
{
    _emotion = emotion;
    self.faceEmotion.emotion = emotion;
    [_faceView addSubview:self.faceEmotion];
    [self.animation removeFromSuperview];
    
    // This will notify delegate and call any queued emotions
    [self animationDidFinish];
}

// Animates the color of Romo's face
- (void)setComplexion:(RMCharacterExpression)complexion
{
    _complexion = complexion;
    
    if (complexion == RMCharacterExpressionNone) {
        for (UIView* view in _hiddenView.subviews) {
            if (view.tag == 111) {
                [UIView animateWithDuration:2.0
                                 animations:^{
                                     view.alpha = 0.0;
                                 } completion:^(BOOL finished) {
                                     [view removeFromSuperview];
                                 }];
            }
        }
        return;
    }
    
    UIColor *complexionColor = nil;
    switch (complexion) {
        case RMCharacterExpressionAngry:
            complexionColor = [UIColor colorWithHue:0.0 saturation:0.65 brightness:0.9 alpha:1.0];
            break;
            
        case RMCharacterExpressionDizzy:
            complexionColor = [UIColor colorWithHue:0.22 saturation:0.7 brightness:0.7 alpha:1.0];
            break;
            
        case RMCharacterExpressionScared:
            complexionColor = [UIColor colorWithHue:0.5361 saturation:0.45 brightness:0.85 alpha:1.0];
            break;
            
        case RMCharacterExpressionExhausted:
            complexionColor = [UIColor colorWithHue:0.51 saturation:0.65 brightness:0.9 alpha:1.0];
            break;
            
        case RMCharacterExpressionHoldingBreath:
            complexionColor = [UIColor colorWithHue:0.72 saturation:0.65 brightness:0.95 alpha:1.0];
            break;
            
        case RMCharacterExpressionLove:
            complexionColor = [UIColor colorWithHue:0.95 saturation:0.5 brightness:1.0 alpha:1.0];
            break;
            
        default:
            break;
    }
    
    if (complexionColor) {
        UIView* complexionView = [[UIView alloc] initWithFrame:_hiddenView.bounds];
        complexionView.backgroundColor = complexionColor;
        complexionView.tag = 111;
        complexionView.alpha = 0.0;
        [_hiddenView insertSubview:complexionView atIndex:0];
        [UIView animateWithDuration:2.0
                         animations:^{
                             complexionView.alpha = 1.0;
                         }];
    }
}

- (void)lookAtPoint:(RMPoint3D)point animated:(BOOL)animated
{
    if (!self.expressing && !self.emoting) {
        [self.faceEmotion lookAtPoint:point animated:animated];
    }
}

- (void)lookAtDefault
{
    if (!self.expressing && !self.emoting) {
        [self.faceEmotion lookAtDefaultAnimated:YES];
    }
}

- (void)blink
{
    if (!self.expressing && !self.emoting) {
        [self.faceEmotion blink];
    }
}

- (void)doubleBlink
{
    if (!self.expressing && !self.emoting) {
        [self.faceEmotion doubleBlink];
    }
}

- (void)setLeftEyeOpen:(BOOL)leftEyeOpen rightEyeOpen:(BOOL)rightEyeOpen
{
    if (!self.expressing && !self.emoting) {
        if (leftEyeOpen == rightEyeOpen) {
            if (leftEyeOpen == YES) {
                [self.faceEmotion openEyes];
            } else {
                [self.faceEmotion closeEyes];
            }
        } else {
            if (leftEyeOpen) {
                [self.faceEmotion openLeftEye];
            } else {
                [self.faceEmotion closeLeftEye];
            }
            if (rightEyeOpen) {
                [self.faceEmotion openRightEye];
            } else {
                [self.faceEmotion closeRightEye];
            }
        }
    }
}

- (void)setPupilDilation:(CGFloat)pupilDilation
{
    _pupilDilation = pupilDilation;
    self.faceEmotion.pupilDilation = pupilDilation;
}

- (void)setRotation:(CGFloat)rotation
{
    BOOL shouldAnimate = NO;
    if (ABS(_rotation - rotation) > 3) {
        shouldAnimate = YES;
    }
    _rotation = rotation;
    CGAffineTransform transform = CGAffineTransformMakeRotation(DEG2RAD(_rotation));
    
    if (shouldAnimate) {
        [UIView animateWithDuration:0.25
                         animations:^(void) {
                             _faceView.transform = transform;
                         }];
    } else {
        _faceView.transform = transform;
    }
}

#pragma mark RMAnimatedImageViewDelegate

- (void)animationDidStart
{
}

- (void)animationDidFinish
{
    self.emoting = NO;
    self.expressing = NO;
    _expression = RMCharacterExpressionNone;
    
    if (_queuedEmotion && _queuedExpression) {
        [self setExpression:_queuedExpression withEmotion:_queuedEmotion];
        _queuedExpression = 0;
        _queuedEmotion = 0;
    } else if (_queuedExpression) {
        self.expression = _queuedExpression;
        _queuedExpression = 0;
    } else if (_queuedEmotion) {
        self.emotion = _queuedEmotion;
        _queuedEmotion = 0;
    } else {
        [self.delegate expressionFaceAnimationDidFinish];
    }
}

- (void)animationReachedBreakpointAtFrame:(int)frame
{
    [self.delegate expressionFaceAnimationDidHitBreakpoint];
}

- (void)didReceiveMemoryWarning
{
    [self.animation didReceiveMemoryWarning];
    [self.delegate didReceiveMemoryWarning];
}

@end
