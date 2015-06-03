//
//  RMCharacter.m
//  RMCharacter
//

#import "RMCharacter.h"
#import "RMCharacterFace.h"
#import "RMCharacterVoice.h"
#import "RMCharacterPNS.h"
#import "RMMath.h"

#define NUM_EMOTIONS    10
#define NUM_EXPRESSIONS 32
#define NUM_MUMBLES      8
#define ROTATION_LIMIT  15

NSString *const RMCharacterDidBeginExpressingNotification = @"RMCharacterDidBeginExpressingNotification";
NSString *const RMCharacterDidFinishExpressingNotification = @"RMCharacterDidFinishExpressingNotification";

NSString *const RMCharacterDidBeginAudioNotification = @"RMCharacterDidBeginAudioNotification";
NSString *const RMCharacterDidFinishAudioNotification = @"RMCharacterDidFinishAudioNotification";

@interface RMCharacter () <RMCharacterFaceDelegate, RMCharacterPNSDelegate>

@property (nonatomic, strong) RMCharacterFace* face;
@property (nonatomic, strong) RMCharacterVoice* voice;
@property (nonatomic, strong) RMCharacterPNS* pns;

@property (nonatomic, readwrite) RMPoint3D gaze;

- (void)checkForResourcesBundle;

@end

@implementation RMCharacter

+ (RMCharacter *)characterWithType:(RMCharacterType)characterType
{
    return [[RMCharacter alloc] initWithCharacterType:characterType];
}

+ (RMCharacter *)Romo
{
    return [RMCharacter characterWithType:RMCharacterRomo];
}

- (RMCharacter *)initWithCharacterType:(RMCharacterType)characterType
{
    self = [super init];
    if (self) {
        _characterType = characterType;
        self.face = [RMCharacterFace faceWithCharacterType:characterType];
        self.face.delegate = self;

        self.pns = [[RMCharacterPNS alloc] init];
        self.pns.delegate = self;
        
        [self checkForResourcesBundle];
        
        _leftEyeOpen = _rightEyeOpen = YES;
        
        self.emotion = RMCharacterEmotionHappy;

        self.voice = [RMCharacterVoice sharedInstance];
    }
    return self;
}

- (void)dealloc
{
    if (self.face.expression) {
        // If we're deallocating while expressing, make sure to match the didBeginExpressing call
        [self.delegate characterDidFinishExpressing:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:RMCharacterDidFinishExpressingNotification object:nil];
    }
}

- (void)checkForResourcesBundle
{
    NSString* mainBundlePath = [[NSBundle mainBundle] resourcePath];
    NSString* frameworkBundlePath = [mainBundlePath stringByAppendingPathComponent:@"RMCharacter.bundle"];
    NSBundle* characterBundle = [NSBundle bundleWithPath:frameworkBundlePath];

    if (!characterBundle) {
        NSLog(@"RMCharacter Error: RMCharacter.bundle not found. Make sure you've added RMCharacter.bundle to the Xcode project. To do this, select your project, then \"Build Phases\", then add RMCharacter.bundle to the \"Copy Bundle Resources\" phase.");
        exit(EXIT_FAILURE);
    }
}

- (void)setEmotion:(RMCharacterEmotion)emotion
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (emotion > 0 && emotion <= self.numberOfEmotions) {
            self.face.emotion = emotion;
        }
    });
}

- (RMCharacterEmotion)emotion
{
    return self.face.emotion;
}

- (void)setExpression:(RMCharacterExpression)expression
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (expression <= self.numberOfExpressions) {
            self.face.expression = expression;
        }
    });
}

- (RMCharacterExpression)expression
{
    return self.face.expression;
}

- (void)setExpression:(RMCharacterExpression)expression withEmotion:(RMCharacterEmotion)emotion
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (emotion > 0 && expression <= self.numberOfExpressions && emotion <= self.numberOfEmotions) {
            [self.face setExpression:expression withEmotion:emotion];
        }
    });
}

- (void)mumble
{
    dispatch_async(dispatch_get_main_queue(), ^{
        int randomMumble = 101 + arc4random() % NUM_MUMBLES;
        self.face.expression = randomMumble;
    });
}

- (void)lookAtPoint:(RMPoint3D)point animated:(BOOL)animated
{
    self.gaze = point;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.face lookAtPoint:point animated:animated];
    });
}

- (void)lookAtDefault
{
    self.gaze = RMPoint3DMake(0.0, 0.0, 0.9);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.face lookAtDefault];
    });
}

- (void)setLeftEyeOpen:(BOOL)leftEyeOpen
{
    //TODO: I fucked up and swapped left & right eyes (left in user's perspective is Romo's RIGHT eye)
    // I put in this simple swap for now
    if (_rightEyeOpen != leftEyeOpen) {
        _rightEyeOpen = leftEyeOpen;
        [self setLeftEyeOpen:_rightEyeOpen rightEyeOpen:_leftEyeOpen];
    }
}

- (void)setRightEyeOpen:(BOOL)rightEyeOpen
{
    //TODO: I fucked up and swapped left & right eyes (left in user's perspective is Romo's RIGHT eye)
    // I put in this simple swap for now
    if (_leftEyeOpen != rightEyeOpen) {
        _leftEyeOpen = rightEyeOpen;
        [self setLeftEyeOpen:_rightEyeOpen rightEyeOpen:_leftEyeOpen];
    }
}

- (void)setLeftEyeOpen:(BOOL)leftEyeOpen rightEyeOpen:(BOOL)rightEyeOpen
{
    //TODO: I fucked up and swapped left & right eyes (left in user's perspective is Romo's RIGHT eye)
    // I put in this simple swap for now
    _rightEyeOpen = leftEyeOpen;
    _leftEyeOpen = rightEyeOpen;
    [self.face setLeftEyeOpen:rightEyeOpen rightEyeOpen:leftEyeOpen];
}

- (void)setPupilDilation:(CGFloat)pupilDilation
{
    _pupilDilation = pupilDilation;
    self.face.pupilDilation = pupilDilation;
}

- (void)setFaceRotation:(CGFloat)faceRotation
{
    _faceRotation =  CLAMP(-ROTATION_LIMIT, faceRotation, ROTATION_LIMIT);
    self.face.rotation = _faceRotation;
}

- (void)setFillColor:(UIColor *)fillColor percentage:(float)percentage
{
    [self.face setFillColor:fillColor percentage:percentage];
}

- (unsigned int)numberOfEmotions
{
    return NUM_EMOTIONS;
}

- (unsigned int)numberOfExpressions
{
    return NUM_EXPRESSIONS;
}

+ (unsigned int)numberOfEmotions
{
    return NUM_EMOTIONS;
}

+ (unsigned int)numberOfExpressions
{
    return NUM_EXPRESSIONS;
}

+ (RMCharacterExpression)mapReadableNameToExpression:(NSString *)name
{
    // Check we have a string
    if (!name) {
        return RMCharacterExpressionNone;
    } else {
        // Convert string to lowercase and strip!
        name = [name lowercaseString];
        name = [name stringByReplacingOccurrencesOfString:@" " withString:@""];
        name = [name stringByReplacingOccurrencesOfString:@"_" withString:@""];
        name = [name stringByReplacingOccurrencesOfString:@"-" withString:@""];
    }
    
    // Do the mapping
    if ([name isEqualToString:@"angry"]) {
        return RMCharacterExpressionAngry;
    } else if ([name isEqualToString:@"bewildered"]) {
        return RMCharacterExpressionBewildered;
    } else if ([name isEqualToString:@"bored"]) {
        return RMCharacterExpressionBored;
    } else if ([name isEqualToString:@"chuckle"]) {
        return RMCharacterExpressionChuckle;
    } else if ([name isEqualToString:@"curious"]) {
        return RMCharacterExpressionCurious;
    } else if ([name isEqualToString:@"dizzy"]) {
        return RMCharacterExpressionDizzy;
    } else if ([name isEqualToString:@"embarrassed"]) {
        return RMCharacterExpressionEmbarrassed;
    } else if ([name isEqualToString:@"excited"]) {
        return RMCharacterExpressionExcited;
    } else if ([name isEqualToString:@"exhausted"]) {
        return RMCharacterExpressionExhausted;
    } else if ([name isEqualToString:@"fart"]) {
        return RMCharacterExpressionFart;
    } else if ([name isEqualToString:@"happy"]) {
        return RMCharacterExpressionHappy;
    } else if ([name isEqualToString:@"hiccup"]) {
        return RMCharacterExpressionHiccup;
    } else if ([name isEqualToString:@"holdingbreath"]) {
        return RMCharacterExpressionHoldingBreath;
    } else if ([name isEqualToString:@"laugh"]) {
        return RMCharacterExpressionLaugh;
    } else if ([name isEqualToString:@"letdown"]) {
        return RMCharacterExpressionLetDown;
    } else if ([name isEqualToString:@"lookingaround"]) {
        return RMCharacterExpressionLookingAround;
    } else if ([name isEqualToString:@"love"]) {
        return RMCharacterExpressionLove;
    } else if ([name isEqualToString:@"ponder"]) {
        return RMCharacterExpressionPonder;
    } else if ([name isEqualToString:@"proud"]) {
        return RMCharacterExpressionProud;
    } else if ([name isEqualToString:@"sad"]) {
        return RMCharacterExpressionSad;
    } else if ([name isEqualToString:@"scared"]) {
        return RMCharacterExpressionScared;
    } else if ([name isEqualToString:@"sleepy"]) {
        return RMCharacterExpressionSleepy;
    } else if ([name isEqualToString:@"smack"]) {
        return RMCharacterExpressionSmack;
    } else if ([name isEqualToString:@"sneeze"]) {
        return RMCharacterExpressionSneeze;
    } else if ([name isEqualToString:@"sniff"]) {
        return RMCharacterExpressionSniff;
    } else if ([name isEqualToString:@"startled"]) {
        return RMCharacterExpressionStartled;
    } else if ([name isEqualToString:@"struggling"]) {
        return RMCharacterExpressionStruggling;
    } else if ([name isEqualToString:@"talking"]) {
        return RMCharacterExpressionTalking;
    } else if ([name isEqualToString:@"want"]) {
        return RMCharacterExpressionWant;
    } else if ([name isEqualToString:@"wee"]) {
        return RMCharacterExpressionWee;
    } else if ([name isEqualToString:@"yawn"]) {
        return RMCharacterExpressionYawn;
    } else if ([name isEqualToString:@"yippee"]) {
        return RMCharacterExpressionYippee;
    } else {
        return RMCharacterExpressionNone;
    }
}

+ (RMCharacterEmotion)mapReadableNameToEmotion:(NSString *)name
{
    // Check we have a string
    if (!name) {
        return RMCharacterEmotionHappy;
    } else {
        // Convert string to lowercase and strip!
        name = [name lowercaseString];
        name = [name stringByReplacingOccurrencesOfString:@" " withString:@""];
        name = [name stringByReplacingOccurrencesOfString:@"_" withString:@""];
        name = [name stringByReplacingOccurrencesOfString:@"-" withString:@""];
    }
    
    // Do the mapping
    if ([name isEqualToString:@"bewildered"]) {
        return RMCharacterEmotionBewildered;
    } else if ([name isEqualToString:@"curious"]) {
        return RMCharacterEmotionCurious;
    } else if ([name isEqualToString:@"delighted"]) {
        // WARNING: Delighted is not in there
        return RMCharacterEmotionDelighted;
    } else if ([name isEqualToString:@"excited"]) {
        return RMCharacterEmotionExcited;
    } else if ([name isEqualToString:@"happy"]) {
        return RMCharacterEmotionHappy;
    } else if ([name isEqualToString:@"indifferent"]) {
        return RMCharacterEmotionIndifferent;
    } else if ([name isEqualToString:@"sad"]) {
        return RMCharacterEmotionSad;
    } else if ([name isEqualToString:@"scared"]) {
        return RMCharacterEmotionScared;
    } else if ([name isEqualToString:@"sleepy"]) {
        return RMCharacterEmotionSleepy;
    } else if ([name isEqualToString:@"sleeping"]) {
        return RMCharacterEmotionSleeping;
    } else {
        return RMCharacterEmotionHappy;
    }
}

- (void)addToSuperview:(UIView *)superview
{
    [superview addSubview:self.face.view];
    self.voice.fading = NO;
    [self.pns reset];
}

- (void)removeFromSuperview
{
    [self.face.view removeFromSuperview];
    self.voice.fading = YES;
    [self.pns stop];
    [RMCharacterImage emptyCache];
}

- (void)say:(NSString *)utterance
{
    [self.voice mumbleWithUtterance:utterance];
}

#pragma mark RMCharacterFaceDelegate

- (void)expressionFaceAnimationDidStart
{
    [self.delegate characterDidBeginExpressing:self];
    [[NSNotificationCenter defaultCenter] postNotificationName:RMCharacterDidBeginExpressingNotification object:self];
}

- (void)expressionFaceAnimationDidFinish
{
    [self.delegate characterDidFinishExpressing:self];
    [[NSNotificationCenter defaultCenter] postNotificationName:RMCharacterDidFinishExpressingNotification object:self];
}

- (void)expressionFaceAnimationDidHitBreakpoint
{
    self.voice.expression = self.face.expression;
}

- (void)didReceiveMemoryWarning
{
    [self.voice didReceiveMemoryWarning];
}

#pragma mark RMCharacterPNSDelegate

- (void)didRecievePNSSignalWithType:(RMCharacterPNSSignalType)PNSSignalType
{
    switch (PNSSignalType) {
        case RMCharacterPNSSignalBlink:
            [self.face blink];
            break;
            
        case RMCharacterPNSSignalDoubleBlink:
            [self.face doubleBlink];
            break;
            
        case RMCharacterPNSSignalLook:
            break;
            
        case RMCharacterPNSSignalBreathe:
            break;
            
        default:
            break;
    }
}

@end
