//
//  RMExpressActionView
//  Romo
//

#import "RMFaceActionView.h"
#import <QuartzCore/QuartzCore.h>
#import <Romo/RMCharacter.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "RMProgressManager.h"
#import <Romo/RMMath.h>

#define faceOptionTagUnlocked 1
#define faceOptionTagLocked   -1

static const CGFloat selectedFaceOptionTop = -8.0;
static const CGFloat unselectedFaceOptionTop = 8.0;

@interface RMFaceActionView () <RMCharacterDelegate>

@property (nonatomic, strong) UIImageView *iPhone;
@property (nonatomic, strong) UIImageView *screen;
@property (nonatomic, strong) UIView *characterContainer;
@property (nonatomic, strong) RMCharacter *character;

@property (nonatomic) RMCharacterExpression expression;
@property (nonatomic) RMCharacterEmotion emotion;

@property (nonatomic, strong) NSMutableArray *options;
@property (nonatomic, strong) UIScrollView *optionsView;

@end

@implementation RMFaceActionView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.title = @"";

        _iPhone = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"iphoneFull.png"]];
        self.iPhone.center = CGPointMake(self.contentView.width / 2, self.contentView.height / 2 + 20);
        self.iPhone.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView insertSubview:self.iPhone atIndex:0];

        _screen = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"romoExpression10.png"]];
        self.screen.origin = CGPointMake(15, 44);
        self.screen.alpha = 1.0;
        self.screen.clipsToBounds = YES;
        self.screen.layer.borderWidth = 2;
        self.screen.layer.borderColor = [UIColor colorWithWhite:0.08 alpha:1.0].CGColor;
        [self.iPhone addSubview:self.screen];
    }
    return self;
}

- (void)setParameters:(NSArray *)parameters
{
    super.parameters = parameters;

    for (RMParameter *parameter in parameters) {
        if (parameter.type == RMParameterExpression) {
            self.expression = [parameter.value intValue];
        } else if (parameter.type == RMParameterEmotion) {
            self.emotion = [parameter.value intValue];
        }
    }
}

- (void)willLayoutForEditing:(BOOL)editing
{
    [super willLayoutForEditing:editing];

    if (editing) {
        self.character = [RMCharacter Romo];
        self.character.delegate = self;

        self.characterContainer = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        CGFloat s = MAX(self.screen.width / self.characterContainer.width, self.screen.height / self.characterContainer.height);
        [self.character addToSuperview:self.characterContainer];
        self.characterContainer.transform = CGAffineTransformMakeScale(s, s);
        self.characterContainer.centerY = self.screen.height / 2;
        self.characterContainer.left = 0;
        [self.screen addSubview:self.characterContainer];

        self.characterContainer.alpha = 0.0;

        self.optionsView.bottom = self.contentView.bottom + 200;
        self.optionsView.alpha = 0.0;
        [self.contentView addSubview:self.optionsView];
    }
}

- (void)setEditing:(BOOL)editing
{
    super.editing = editing;

    if (editing) {
        self.iPhone.center = CGPointMake(self.contentView.width / 2, self.contentView.height / 2);
        self.characterContainer.alpha = 1.0;

        self.optionsView.frame = CGRectMake(0, self.contentView.bottom - self.optionsView.height, self.contentView.width, self.optionsView.height);
        self.optionsView.alpha = 1.0;
    } else {
        self.iPhone.center = CGPointMake(self.contentView.width / 2, self.contentView.height / 2 + 32);
        self.characterContainer.alpha = 0.0;

        self.optionsView.frame = CGRectMake(0, self.contentView.bottom - self.optionsView.height + 200, self.contentView.width, self.optionsView.height);
        self.optionsView.alpha = 0.0;
    }
}

- (void)didLayoutForEditing:(BOOL)editing
{
    [super didLayoutForEditing:editing];

    if (editing) {
        if (self.showingEmotion) {
            self.character.emotion = self.emotion;
        } else {
            self.character.expression = self.expression;
        }
        [self displaySelectedFaceNumber:self.showingEmotion ? self.emotion : self.expression];
    } else {
        [self.character removeFromSuperview];
        [self.characterContainer removeFromSuperview];
        self.character = nil;
        self.characterContainer = nil;

        [self.optionsView removeFromSuperview];
        self.optionsView = nil;

        self.options = nil;
    }
}

+ (NSString *)nameForEmotion:(RMCharacterEmotion)emotion
{
    switch (emotion) {
        case RMCharacterEmotionBewildered: return NSLocalizedString(@"Action-Emotion-Bewildered-Title", @"Become bewildered");
        case RMCharacterEmotionCurious: return NSLocalizedString(@"Action-Emotion-Curious-Title", @"Become curious");
        case RMCharacterEmotionDelighted: return NSLocalizedString(@"Action-Emotion-Delighted-Title", @"Become delighted");
        case RMCharacterEmotionExcited: return NSLocalizedString(@"Action-Emotion-Excited-Title", @"Become excited");
        case RMCharacterEmotionHappy: return NSLocalizedString(@"Action-Emotion-Happy-Title", @"Become happy");
        case RMCharacterEmotionIndifferent: return NSLocalizedString(@"Action-Emotion-Indifferent-Title", @"Become indifferent");
        case RMCharacterEmotionSad: return NSLocalizedString(@"Action-Emotion-Sad-Title", @"Become sad");
        case RMCharacterEmotionScared: return NSLocalizedString(@"Action-Emotion-Scared-Title", @"Become scared");
        case RMCharacterEmotionSleeping: return NSLocalizedString(@"Action-Emotion-Sleep-Title", @"Go to sleep");
        case RMCharacterEmotionSleepy: return NSLocalizedString(@"Action-Emotion-Sleepy-Title", @"Become sleepy");
    }
}

+ (NSString *)nameForExpression:(RMCharacterExpression)expression
{
    switch (expression) {
        case RMCharacterExpressionAngry: return NSLocalizedString(@"Action-Expression-Angry-Title", @"Act angry");
        case RMCharacterExpressionBewildered: return NSLocalizedString(@"Action-Expression-Bewildered-Title", @"Act bewildered");
        case RMCharacterExpressionBored: return NSLocalizedString(@"Action-Expression-Bored-Title", @"Act bored");
        case RMCharacterExpressionCurious: return NSLocalizedString(@"Action-Expression-Curious-Title", @"Act curious");
        case RMCharacterExpressionDizzy: return NSLocalizedString(@"Action-Expression-Dizzy-Title", @"Act dizzy");
        case RMCharacterExpressionEmbarrassed: return NSLocalizedString(@"Action-Expression-Embarrassed-Title", @"Act embarrassed");
        case RMCharacterExpressionExcited: return NSLocalizedString(@"Action-Expression-Excited-Title", @"Act excited");
        case RMCharacterExpressionExhausted: return NSLocalizedString(@"Action-Expression-Exhausted-Title", @"Act exhausted");
        case RMCharacterExpressionFart: return NSLocalizedString(@"Action-Expression-Backfire-Title", @"Backfire");
        case RMCharacterExpressionHappy: return NSLocalizedString(@"Action-Expression-Happy-Title", @"Act happy");
        case RMCharacterExpressionHiccup: return NSLocalizedString(@"Action-Expression-Hiccup-Title", @"Hiccup");
        case RMCharacterExpressionHoldingBreath: return NSLocalizedString(@"Action-Expression-HoldBreath-Title", @"Hold his breath");
        case RMCharacterExpressionLaugh: return NSLocalizedString(@"Action-Expression-Laugh-Title", @"Laugh");
        case RMCharacterExpressionLookingAround: return NSLocalizedString(@"Action-Expression-LookAround-Title", @"Look around");
        case RMCharacterExpressionLove: return NSLocalizedString(@"Action-Expression-Love-Title", @"Fall in love");
        case RMCharacterExpressionNone: return NSLocalizedString(@"Action-Expression-None-Title", @"Make a face");
        case RMCharacterExpressionPonder: return NSLocalizedString(@"Action-Expression-Ponder-Title", @"Ponder");
        case RMCharacterExpressionSad: return NSLocalizedString(@"Action-Expression-Sad-Title", @"Act sad");
        case RMCharacterExpressionScared: return NSLocalizedString(@"Action-Expression-Scared-Title", @"Act scared");
        case RMCharacterExpressionSleepy: return NSLocalizedString(@"Action-Expression-Sleepy-Title", @"Act sleepy");
        case RMCharacterExpressionSneeze: return NSLocalizedString(@"Action-Expression-Sneeze-Title", @"Sneeze");
        case RMCharacterExpressionTalking: return NSLocalizedString(@"Action-Expression-Mumbling-Title", @"Start mumbling");
        case RMCharacterExpressionYawn: return NSLocalizedString(@"Action-Expression-Yawn-Title", @"Yawn");
        case RMCharacterExpressionLetDown: return NSLocalizedString(@"Action-Expression-LetDown-Title", @"Act let down");
        case RMCharacterExpressionChuckle: return NSLocalizedString(@"Action-Expression-Chuckle-Title", @"Chuckle");
        case RMCharacterExpressionProud: return NSLocalizedString(@"Action-Expression-Proud-Title", @"Act proud");
        case RMCharacterExpressionStartled: return NSLocalizedString(@"Action-Expression-Startled-Title", @"Act startled");
        case RMCharacterExpressionWant: return NSLocalizedString(@"Action-Expression-Want-Title", @"I want it");
        case RMCharacterExpressionWee: return NSLocalizedString(@"Action-Expression-Wee-Title", @"Wee!");
        case RMCharacterExpressionYippee: return NSLocalizedString(@"Action-Expression-Yippee-Title", @"Yippee!");
        case RMCharacterExpressionSniff: return NSLocalizedString(@"Action-Expression-Sniff-Title", @"Sniff");
        case RMCharacterExpressionSmack: return NSLocalizedString(@"Action-Expression-Smack-Title", @"Smack into the Screen");
        case RMCharacterExpressionStruggling: return NSLocalizedString(@"Action-Expression-Struggle-Title", @"Struggle to Move");
    }
}

#pragma mark - RMCharacterDelegate

- (void)characterDidBeginExpressing:(RMCharacter *)character
{
}

- (void)characterDidFinishExpressing:(RMCharacter *)character
{
    double delayInSeconds = 1.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (self.showingEmotion) {
            if (self.character.emotion != self.emotion) {
                self.character.emotion = self.emotion;
            }
        } else {
            self.character.expression = self.expression;
        }
    });
}

#pragma mark - Private Methods

- (void)handleFaceOptionTap:(UITapGestureRecognizer *)tap
{
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL isUnlocked = SIGN(tap.view.tag) == faceOptionTagUnlocked;
        int faceNumber = (int)ABS(tap.view.tag);

        if (isUnlocked) {
            if (self.showingEmotion) {
                self.emotion = faceNumber;
            } else {
                self.expression = faceNumber;
            }
        }
    });
}

+ (NSSet *)allowedEmotions
{
    return [NSSet setWithArray:@[
                                 @(RMCharacterEmotionHappy),
                                 @(RMCharacterEmotionExcited),
                                 @(RMCharacterEmotionSad),
                                 @(RMCharacterEmotionScared),
                                 @(RMCharacterEmotionSleepy),
                                 @(RMCharacterEmotionBewildered),
                                 @(RMCharacterEmotionIndifferent),
                                 ]];
}

+ (NSSet *)allowedExpressions
{
    return [NSSet setWithArray:@[
                                 @(RMCharacterExpressionAngry),
                                 @(RMCharacterExpressionChuckle),
                                 @(RMCharacterExpressionCurious),
                                 @(RMCharacterExpressionDizzy),
                                 @(RMCharacterExpressionExcited),
                                 @(RMCharacterExpressionExhausted),
                                 @(RMCharacterExpressionHoldingBreath),
                                 @(RMCharacterExpressionLaugh),
                                 @(RMCharacterExpressionLetDown),
                                 @(RMCharacterExpressionLove),
                                 @(RMCharacterExpressionSad),
                                 @(RMCharacterExpressionScared),
                                 @(RMCharacterExpressionSneeze),
                                 @(RMCharacterExpressionWee),
                                 @(RMCharacterExpressionYawn),
                                 @(RMCharacterExpressionYippee),
                                 ]];
}

- (NSMutableArray *)options
{
    if (!_options) {
        NSArray *unlocked = nil;
        NSMutableArray *locked = [NSMutableArray arrayWithCapacity:20];
        
        if (self.showingEmotion) {
            unlocked = [RMFaceActionView allowedEmotions].allObjects;
        } else {
            NSSet *allowedOptions = [RMFaceActionView allowedExpressions];
            NSMutableSet *unlockedOptions = [NSMutableSet setWithArray:[RMProgressManager sharedInstance].unlockedExpressions];
            [unlockedOptions intersectSet:allowedOptions];
            unlocked = [unlockedOptions allObjects];

            for (RMCharacterEmotion lockedExpression = 1; lockedExpression <= self.character.numberOfExpressions; lockedExpression++) {
                if (![unlocked containsObject:@(lockedExpression)] && [allowedOptions containsObject:@(lockedExpression)]) {
                    [locked addObject:@(lockedExpression)];
                }
            }
        }

        NSInteger count = unlocked.count + locked.count;
        _options = [NSMutableArray arrayWithCapacity:count];

        for (int i = 0; i < count; i++) {
            BOOL isUnlocked = i < unlocked.count;
            NSNumber *faceNumber = isUnlocked ? unlocked[i] : locked[i - unlocked.count];
            UIImage *faceImage = [UIImage smartImageNamed:[NSString stringWithFormat:@"romo%@%d",self.showingEmotion ? @"Emotion" : @"Expression", faceNumber.intValue]];

            UIImageView *phone = [[UIImageView alloc] initWithFrame:CGRectMake(16 + 64 * i, unselectedFaceOptionTop, 55, 100)];
            phone.image = [UIImage imageNamed:@"iphoneFull@1x.png"];
            phone.tag = (isUnlocked ? faceOptionTagUnlocked : faceOptionTagLocked) * faceNumber.intValue;
            [phone addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleFaceOptionTap:)]];
            phone.userInteractionEnabled = YES;
            phone.contentMode = UIViewContentModeScaleAspectFit;
            [_options addObject:phone];

            UIImageView *face = [[UIImageView alloc] initWithImage:faceImage];
            face.frame = CGRectMake(5, 16, 46, 69);
            face.alpha = isUnlocked ? 1.0 : 0.5;
            face.backgroundColor = [UIColor whiteColor];
            [phone addSubview:face];

            if (!isUnlocked) {
                UIImageView *lockIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"lockIcon.png"]];
                lockIcon.center = CGPointMake(face.width / 2.0, face.height / 2.0 - 12);
                [face addSubview:lockIcon];
            }
        }
    }
    return _options;
}

- (UIScrollView *)optionsView
{
    if (!_optionsView) {
        _optionsView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, self.contentView.width, 70)];
        _optionsView.indicatorStyle = UIScrollViewIndicatorStyleBlack;
        _optionsView.scrollIndicatorInsets = UIEdgeInsetsMake(0, 26, 0, 26);
        _optionsView.clipsToBounds = NO;

        for (UIButton *button in self.options) {
            button.top = 4;
            [_optionsView addSubview:button];
        }
        _optionsView.contentSize = CGSizeMake(32 + 64 * self.options.count, _optionsView.height);
    }
    return _optionsView;
}

- (void)setExpression:(RMCharacterExpression)expression
{
    if (expression != _expression) {
        _expression = expression;

        self.title = [RMFaceActionView nameForExpression:expression];
        self.screen.image = [UIImage smartImageNamed:[NSString stringWithFormat:@"romoExpression%d.png",expression]];

        if (self.isEditing) {
            [self.character removeFromSuperview];
            [self.characterContainer removeFromSuperview];

            self.character = [RMCharacter Romo];
            self.character.delegate = self;

            self.characterContainer = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
            CGFloat s = MAX(self.screen.width / self.characterContainer.width, self.screen.height / self.characterContainer.height);
            [self.character addToSuperview:self.characterContainer];
            self.characterContainer.transform = CGAffineTransformMakeScale(s, s);
            self.characterContainer.centerY = self.screen.height / 2;
            self.characterContainer.left = 0;
            [self.screen addSubview:self.characterContainer];

            if (self.showingEmotion) {
                self.character.emotion = self.emotion;
            } else {
                self.character.expression = self.expression;
            }
        }

        for (RMParameter *parameter in self.parameters) {
            if (parameter.type == RMParameterExpression) {
                parameter.value = @(expression);
            }
        }
        [self displaySelectedFaceNumber:expression];
    }
}

- (void)setEmotion:(RMCharacterEmotion)emotion
{
    if (emotion != _emotion) {
        _emotion = emotion;

        self.title = [RMFaceActionView nameForEmotion:emotion];
        self.screen.image = [UIImage smartImageNamed:[NSString stringWithFormat:@"romoEmotion%d.png",emotion]];

        if (self.showingEmotion) {
            self.character.emotion = self.emotion;
        }

        for (RMParameter *parameter in self.parameters) {
            if (parameter.type == RMParameterEmotion) {
                parameter.value = @(emotion);
            }
        }
        [self displaySelectedFaceNumber:emotion];
    }
}

- (void)displaySelectedFaceNumber:(int)faceNumber
{
    if (_options) {
        [UIView animateWithDuration:0.35
                         animations:^{
                             for (UIImageView *faceOption in self.options) {
                                 if (ABS(faceOption.tag) == faceNumber) {
                                     faceOption.top = selectedFaceOptionTop;
                                 } else {
                                     faceOption.top = unselectedFaceOptionTop;
                                 }
                             }
                         }];
    }
}

@end
