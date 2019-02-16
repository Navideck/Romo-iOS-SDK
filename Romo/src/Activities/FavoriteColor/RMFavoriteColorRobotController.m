//
//  RMFavoriteColorRobotController.m
//  Romo
//

#import "RMFavoriteColorRobotController.h"
#import <Romo/RMVision.h>
#import "UIView+Additions.h"
#import "UIColor+RMColor.h"
#import "UIFont+RMFont.h"
#import "RMAppDelegate.h"
#import "RMRomoMemory.h"
#import "RMMissionRuntime.h"
#import "RMInteractionScriptRuntime.h"
#import "RMColorTrainingHelpRobotController.h"
#import "RMProgressManager.h"
#import "RMUnlockable.h"
#import "RMBehaviorArbiter.h"
#import "RMSoundEffect.h"

NSString *const favoriteColorKnowledgeKey = @"romoFavoriteColorHue";

static NSString *introductionFirstTimeFileName = @"Favorite-Color-Introduction-First-Run";
static NSString *introductionFileName = @"Favorite-Color-Introduction";

/**
 For a new Romo without a favorite color, the user must show n colors
 before Romo memorizes a specific hue as his favorite
 To ensure this is fun, the user must show their Romo this many "unique" hues
 */
static const int minimumHueCountBeforeChoosing = 4;

/** The time interval that Romo becomes bored on if he sees no interesting colors */
static const float minimumBoredTime = 12.0;
static const float maximumBoredTime = 32.0;

float const favoriteHueWidth = 0.18;

/**
 The first time, Romo must see n unique hues before choosing a favorite color
 This defines how far a hue has to be from another to be considered unique
 */
static const float uniqueColorHueWidth = 0.03;

/** A flag for indicating no favorite hue has been chosen yet */
static const float undefinedFavoriteHue = -1.0;

@interface RMFavoriteColorRobotController () <RMBehaviorArbiterDelegate>

/**
 The first time played, your Romo permanently chooses a favorite color based on the hue of the nth hue he sees
 From then on, he likes any hue within a certain distance of that hue
 */
@property (nonatomic) float favoriteHue;

@property (nonatomic, getter=isFirstTimePlayed) BOOL firstTimePlayed;
@property (nonatomic) BOOL shouldShowExtendedIntroduction;
@property (nonatomic) BOOL shouldShowHelp;
@property (nonatomic) BOOL shouldShowIntroduction;

@property (nonatomic, strong) RMBehaviorArbiter *behaviorArbiter;

@property (nonatomic, strong) NSMutableArray *hueRanges;
@property (nonatomic, strong) NSTimer *confirmationTimer;
@property (nonatomic, getter=isThinking) BOOL thinking;

@property (nonatomic, strong) NSTimer *boredTimer;
@property (nonatomic, strong) NSMutableSet *boredPrompts;
@property (nonatomic, strong) NSMutableSet *wrongColorPrompts;
@property (nonatomic, strong) NSMutableSet *correctColorPrompts;
@property (nonatomic, strong) NSMutableSet *conclusionPrompts;

@end

@implementation RMFavoriteColorRobotController

+ (double)activityProgress
{
    NSString *favoriteHueString = [[RMRomoMemory sharedInstance] knowledgeForKey:favoriteColorKnowledgeKey];
    if (favoriteHueString.length && favoriteHueString.floatValue >= 0.0) {
        return 1.0;
    } else {
        return 0.0;
    }
}

- (id)init
{
    self = [super init];
    if (self) {
        NSString *favoriteHueString = [[RMRomoMemory sharedInstance] knowledgeForKey:favoriteColorKnowledgeKey];
        if (favoriteHueString.length && favoriteHueString.floatValue >= 0.0) {
            // If we've played before, initialize our favorite color
            _favoriteHue = favoriteHueString.floatValue;
        } else {
            _favoriteHue = undefinedFavoriteHue;
        }
        
        _firstTimePlayed = (self.favoriteHue == undefinedFavoriteHue);
        
        _shouldShowExtendedIntroduction = self.firstTimePlayed;
        _shouldShowHelp = self.firstTimePlayed;
        _shouldShowIntroduction = YES;
    }
    return self;
}

- (void)controllerDidBecomeActive
{
    [super controllerDidBecomeActive];
    
    [[RMProgressManager sharedInstance] setStatus:RMChapterStatusSeenUnlock forChapter:RMCometFavoriteColor];
    
    if (self.shouldShowExtendedIntroduction) {
        // If this is the first time we play and the first time this controller is active, show an extended intro
        [self startExtendedIntroduction];
    } else if (self.shouldShowHelp) {
        // When we become active after that intro, show help
        [self userAskedForHelp];
    } else if (self.shouldShowIntroduction) {
        // Next time around, show the introduction
        [self startIntroduction];
    } else {
        // Finally, start playing the game
        [self startLookingForColors];
    }
}

- (void)controllerWillResignActive
{
    [super controllerWillResignActive];
    
    if (_behaviorArbiter) {
        self.behaviorArbiter = nil;
    }
    
    [self.confirmationTimer invalidate];
    [self.boredTimer invalidate];
}

- (RMChapter)chapter
{
    return RMCometFavoriteColor;
}

- (NSString *)title
{
    return NSLocalizedString(@"Favorite-Color-Title", @"Favorite Color");
}

- (void)userAskedForHelp
{
    self.shouldShowHelp = NO;
    
    RMColorTrainingHelpRobotController *helpRobotController = [[RMColorTrainingHelpRobotController alloc] init];
    RMAppDelegate *appDelegate = (RMAppDelegate *)[UIApplication sharedApplication].delegate;
    [appDelegate pushRobotController:helpRobotController];
}

- (NSSet *)initiallyActiveVisionModules
{
    return nil;
}

- (RMRomoFunctionalities)initiallyActiveFunctionalities
{
    return RMRomoFunctionalityBroadcasting | RMRomoFunctionalityCharacter;
}

- (RMRomoInterruptions)initiallyAllowedInterruptions
{
    return RMRomoInterruptionRomotion | RMRomoInterruptionWakefulness;
}

#pragma mark - State

- (void)startExtendedIntroduction
{
    self.shouldShowExtendedIntroduction = NO;
    
    // Show an extended backstory then help if this is the first time
    NSString *firstTimeIntroductionPath = [[NSBundle mainBundle] pathForResource:introductionFirstTimeFileName ofType:@"json"];
    RMInteractionScriptRuntime *runtime = [[RMInteractionScriptRuntime alloc] initWithJSONPath:firstTimeIntroductionPath];
    runtime.completion = ^(BOOL finished){
        [(RMAppDelegate *)[UIApplication sharedApplication].delegate popRobotController];
    };
    [(RMAppDelegate *)[UIApplication sharedApplication].delegate pushRobotController:runtime];
}

/**
 If this is the first time they've played with favorite color, introduce the backstory & motivation
 */
- (void)startIntroduction
{
    self.shouldShowIntroduction = NO;
    self.Romo.character.emotion = RMCharacterEmotionHappy;
    
    // Every time, we show an introduction for how to show Romo colors
    NSString *introductionPath = [[NSBundle mainBundle] pathForResource:introductionFileName ofType:@"json"];
    RMInteractionScriptRuntime *runtime = [[RMInteractionScriptRuntime alloc] initWithJSONPath:introductionPath];
    runtime.completion = ^(BOOL finished){
        [(RMAppDelegate *)[UIApplication sharedApplication].delegate popRobotController];
    };
    [(RMAppDelegate *)[UIApplication sharedApplication].delegate pushRobotController:runtime];
}

- (void)startLookingForColors
{
    [self becomeInterested];
    
    self.Romo.character.emotion = RMCharacterEmotionCurious;
    
    self.behaviorArbiter.Romo = self.Romo;
    self.behaviorArbiter.wavePrompt = NSLocalizedString(@"FavColor-Wave-Something", @"Wave something\ncolorful!");
    self.behaviorArbiter.prioritizedBehaviors = @[
                                                  @(RMActivityBehaviorTooBright),
                                                  @(RMActivityBehaviorTooDark),
                                                  @(RMActivityBehaviorMotionTriggeredColorTrainingFinished),
                                                  @(RMActivityBehaviorMotionTriggeredColorTrainingUpdated),
                                                  ];
    self.behaviorArbiter.objectTracker.shouldCluster = NO;
    [self.behaviorArbiter startBrightnessMetering];
    [self.behaviorArbiter startMotionTriggeredColorTrainingWithCompletion:nil];
}

#pragma mark - RMBehaviorArbiterDelegate

- (void)behaviorArbiter:(RMBehaviorArbiter *)behaviorArbiter didFinishExecutingBehavior:(RMActivityBehavior)behavior
{
    switch (behavior) {
        case RMActivityBehaviorMotionTriggeredColorTrainingUpdated:
            if (!self.isThinking && behaviorArbiter.objectTracker.trainingProgress > 0.2) {
                [self becomeInterested];
            }
            break;
            
        case RMActivityBehaviorMotionTriggeredColorTrainingFinished:
            if (!self.isThinking) {
                [self becomeInterested];

                // Grab the hue component and react based on that value
                CGFloat hueOfTriggeredColor;
                [behaviorArbiter.objectTracker.trainedColor getHue:&hueOfTriggeredColor saturation:nil brightness:nil alpha:nil];
                [self finishedTrainingOnHue:hueOfTriggeredColor];
            }
            break;
            
        default:
            break;
    }
}

- (UIViewController *)viewController
{
    return self;
}

#pragma mark - Color Confirmation

- (BOOL)hasSpannedEnoughWithHue:(float)hue
{
    int width = (int)(uniqueColorHueWidth * 100.0);
    int start = ((int)(hue * 100.0) - width) % 100;
    if (start < 0) {
        start += 100;
    }
    
    NSRange hueRange = NSMakeRange(start, 2 * width);
    
    BOOL intersectsAnyRanges = NO;
    for (NSValue *otherHueRangeValue in self.hueRanges) {
        NSRange otherHueRange = otherHueRangeValue.rangeValue;
        NSRange intersectingHueRange = NSIntersectionRange(hueRange, otherHueRange);
        intersectsAnyRanges |= intersectingHueRange.length > 0;
    }
    
    if (!intersectsAnyRanges) {
        [self.hueRanges addObject:[NSValue valueWithRange:hueRange]];
    }
    
    return (self.hueRanges.count >= minimumHueCountBeforeChoosing);
}

- (void)finishedTrainingOnHue:(float)hue
{
    // Stop looking for other colors
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    self.thinking = YES;
    
    if (self.favoriteHue == undefinedFavoriteHue && [self hasSpannedEnoughWithHue:hue]) {
        // If we haven't chosen a favorite hue yet but we've seen enough range, choose this as our favorite
        self.firstTimePlayed = NO;
        self.favoriteHue = hue;
        [[RMRomoMemory sharedInstance] setKnowledge:[NSString stringWithFormat:@"%f", hue] forKey:favoriteColorKnowledgeKey];
    }
    
    BOOL seeingFavoriteColor = self.favoriteHue != undefinedFavoriteHue && [self hue:hue matchesFavoriteHue:self.favoriteHue];
    
    if (seeingFavoriteColor) {
        // Let the user know they figured out their Romo's favorite color...
        enableRomotions(YES, self.Romo);
        [self.Romo.character setExpression:RMCharacterExpressionWant withEmotion:RMCharacterEmotionExcited];
        
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self sayRandomPromptFromPrompts:self.correctColorPrompts];
            
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self sayRandomPromptFromPrompts:self.conclusionPrompts];
                
                // Unlock Chapter 2 if not already done
                RMUnlockable *chapterTwoUnlockable = [[RMUnlockable alloc] initWithType:RMUnlockableChapter value:@(RMChapterTwo)];
                [[RMProgressManager sharedInstance] achieveUnlockable:chapterTwoUnlockable];
                
                // And Mission 2-1
                RMUnlockable *missionOneUnlockable = [[RMUnlockable alloc] initWithType:RMUnlockableMission value:@"2-1"];
                [[RMProgressManager sharedInstance] achieveUnlockable:missionOneUnlockable];
                
                // Let our delegate know we're done
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                    [self.delegate activityDidFinish:self];
                });
            });
        });
    } else {
        // ...Otherwise, tell them to keep guessing
        self.Romo.character.emotion = RMCharacterEmotionIndifferent;
        [self.Romo.romotions sayNo];
        [RMSoundEffect playForegroundEffectWithName:creatureNoSound repeats:NO gain:1.0];
        
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self sayRandomPromptFromPrompts:self.wrongColorPrompts];
            [self becomeInterested];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
                [self becomeInterested];
                self.thinking = NO;
                self.Romo.character.emotion = RMCharacterEmotionCurious;
                [self.behaviorArbiter startMotionTriggeredColorTrainingWithCompletion:nil];
                [[UIApplication sharedApplication] endIgnoringInteractionEvents];
            });
        });
    }
}

/**
 Returns whether the provided hue is similar enough to the favorite hue to be considered the same color
 */
- (BOOL)hue:(float)hue matchesFavoriteHue:(float)favoriteHue
{
    return ABS(hue - favoriteHue) < [self widthForHue:favoriteHue];
}

/**
 For a specific hue, returns how close other hues must be to be considered the same color
 e.g. blue has a much wider band of the color wheel (around 30%) than yellow (around 10%)
 */
- (float)widthForHue:(float)hue
{
    return favoriteHueWidth;
}

#pragma mark - Boredom

- (void)becomeBored
{
    [self.boredTimer invalidate];
    
    [self sayRandomPromptFromPrompts:self.boredPrompts];
    NSArray *randomExpressions = @[ @(RMCharacterExpressionCurious), @(RMCharacterExpressionLookingAround), @(RMCharacterExpressionTalking), @(RMCharacterExpressionBewildered)];
    RMCharacterExpression randomExpression = [randomExpressions[arc4random() % randomExpressions.count] intValue];
    self.Romo.character.expression = randomExpression;
    [self becomeInterested];
}

- (void)becomeInterested
{
    [self.boredTimer invalidate];
    
    CGFloat rangeOfTime = maximumBoredTime - minimumBoredTime;
    CGFloat interval = minimumBoredTime + (arc4random() % (int)rangeOfTime);
    self.boredTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                       target:self
                                                     selector:@selector(becomeBored)
                                                     userInfo:nil
                                                      repeats:NO];
}

#pragma mark - Prompts

- (void)sayRandomPromptFromPrompts:(NSMutableSet *)prompts
{
    [self.Romo.voice dismiss];
    
    int seed = arc4random() % prompts.count;
    NSString *prompt = prompts.allObjects[seed];
    [prompts removeObject:prompt];
    [self.Romo.voice say:prompt withStyle:RMVoiceStyleLLS autoDismiss:YES];
}

- (NSMutableSet *)wrongColorPrompts
{
    if (!_wrongColorPrompts || _wrongColorPrompts.count == 0) {
        NSArray *wrongColorPrompts = @[
                                       NSLocalizedString(@"FavColor-WrongColorPrompt1", @"Nope!\nKeep guessing!"),
                                       NSLocalizedString(@"FavColor-WrongColorPrompt2", @"Hmmm...\nnot quite"),
                                       NSLocalizedString(@"FavColor-WrongColorPrompt3", @"Yuck!"),
                                       NSLocalizedString(@"FavColor-WrongColorPrompt4", @"No no no no\nno no!"),
                                       NSLocalizedString(@"FavColor-WrongColorPrompt5", @"Eww!"),
                                       NSLocalizedString(@"FavColor-WrongColorPrompt6", @"Hmm, I don't\nthink so!"),
                                       NSLocalizedString(@"FavColor-WrongColorPrompt7", @"Nope!"),
                                       NSLocalizedString(@"FavColor-WrongColorPrompt8", @"Closer..."),
                                       NSLocalizedString(@"FavColor-WrongColorPrompt9", @"No, my favorite color\nis way nicer"),
                                       NSLocalizedString(@"FavColor-WrongColorPrompt10", @"No, but is that\nyour favorite?"),
                                       NSLocalizedString(@"FavColor-WrongColorPrompt11", @"Hmm...\nnot that one"),
                                       NSLocalizedString(@"FavColor-WrongColorPrompt12", @"Umm...\nnope!"),
                                       NSLocalizedString(@"FavColor-WrongColorPrompt13", @"Guess again!"),
                                       NSLocalizedString(@"FavColor-WrongColorPrompt14", @"No, show me\nsomething else!"),
                                       NSLocalizedString(@"FavColor-WrongColorPrompt15", @"Not that one.\nI thought you\nknew me!"),
                                       NSLocalizedString(@"FavColor-WrongColorPrompt16", @"Not that color!"),
                                       NSLocalizedString(@"FavColor-WrongColorPrompt17", @"No!"),
                                       NSLocalizedString(@"FavColor-WrongColorPrompt18", @"No! No! No!"),
                                       NSLocalizedString(@"FavColor-WrongColorPrompt19", @"No!\nNo!\nNo!"),
                                       NSLocalizedString(@"FavColor-WrongColorPrompt20", @"No!\nThat color is gross!"),
                                       NSLocalizedString(@"FavColor-WrongColorPrompt21", @"THAT color is\nDISGUSTING!")
                                       ];
        _wrongColorPrompts = [NSMutableSet setWithArray:wrongColorPrompts];
    }
    return _wrongColorPrompts;
}

- (NSMutableSet *)correctColorPrompts
{
    if (!_correctColorPrompts || _correctColorPrompts.count == 0) {
        NSArray *correctColorPrompts = @[
                                         NSLocalizedString(@"FavColor-CorrectColorPrompt1", @"You got it!"),
                                         NSLocalizedString(@"FavColor-CorrectColorPrompt2", @"Ding ding ding!"),
                                         NSLocalizedString(@"FavColor-CorrectColorPrompt3", @"Correctamundo!"),
                                         NSLocalizedString(@"FavColor-CorrectColorPrompt4", @"Perfecto!"),
                                         NSLocalizedString(@"FavColor-CorrectColorPrompt5", @"There we go!"),
                                         NSLocalizedString(@"FavColor-CorrectColorPrompt6", @"Gimme gimme!"),
                                         NSLocalizedString(@"FavColor-CorrectColorPrompt7", @"Gimme!\nGimme!"),
                                         NSLocalizedString(@"FavColor-CorrectColorPrompt8", @"Mmm, my favorite!"),
                                         NSLocalizedString(@"FavColor-CorrectColorPrompt9", @"Oooooh!\nGimme!"),
                                         NSLocalizedString(@"FavColor-CorrectColorPrompt10", @"Yeah! Yeah!\nYeah, yeah, yeah!"),
                                         NSLocalizedString(@"FavColor-CorrectColorPrompt11", @"Holy robot!"),
                                         NSLocalizedString(@"FavColor-CorrectColorPrompt12", @"Nuts and bolts!"),
                                         NSLocalizedString(@"FavColor-CorrectColorPrompt13", @"Holy firmware!"),
                                         NSLocalizedString(@"FavColor-CorrectColorPrompt14", @"Huzzah!"),
                                         NSLocalizedString(@"FavColor-CorrectColorPrompt15", @"We have\na winner!"),
                                         NSLocalizedString(@"FavColor-CorrectColorPrompt16", @"YEAAAHHH!!!")
                                         ];
        _correctColorPrompts = [NSMutableSet setWithArray:correctColorPrompts];
    }
    return _correctColorPrompts;
}

- (NSMutableSet *)conclusionPrompts
{
    if (!_conclusionPrompts || _conclusionPrompts.count == 0) {
        NSArray *conclusionPrompts = @[
                                       NSLocalizedString(@"FavColor-ConclusionPrompt1", @"Looks like you guessed\nmy favorite frequency!"),
                                       NSLocalizedString(@"FavColor-ConclusionPrompt2", @"Now you know\nmy favorite color!"),
                                       NSLocalizedString(@"FavColor-ConclusionPrompt3", @"That sure is\nmy favorite color!"),
                                       NSLocalizedString(@"FavColor-ConclusionPrompt4", @"I just love\nthat color!"),
                                       NSLocalizedString(@"FavColor-ConclusionPrompt5", @"I love\nthat color!")
                                       ];
        _conclusionPrompts = [NSMutableSet setWithArray:conclusionPrompts];
    }
    return _conclusionPrompts;
}

- (NSMutableSet *)boredPrompts
{
    if (!_boredPrompts || _boredPrompts.count == 0) {
        NSArray *boredPrompts = @[
                                  NSLocalizedString(@"FavColor-BoredPrompt1", @"Show me something\nBRIGHT!"),
                                  NSLocalizedString(@"FavColor-BoredPrompt2", @"Hmm...\nShow me a warm color!"),
                                  NSLocalizedString(@"FavColor-BoredPrompt3", @"Do you have any\ncolorful toys?"),
                                  NSLocalizedString(@"FavColor-BoredPrompt4", @"Remember, I like\nbrighter colors!"),
                                  NSLocalizedString(@"FavColor-BoredPrompt5", @"Lemme see some\nCOLOR!"),
                                  NSLocalizedString(@"FavColor-BoredPrompt6", @"Did you try all\ncolors of the rainbow?"),
                                  NSLocalizedString(@"FavColor-BoredPrompt7", @"Hint...\nIt's a bright color!"),
                                  NSLocalizedString(@"FavColor-BoredPrompt8", @"Hint...\nThis color is vibrant"),
                                  NSLocalizedString(@"FavColor-BoredPrompt9", @"Here's a hint...\nIt's not black!"),
                                  NSLocalizedString(@"FavColor-BoredPrompt10", @"Keep\nguessing!"),
                                  NSLocalizedString(@"FavColor-BoredPrompt11", @"Guess another\ncolor"),
                                  NSLocalizedString(@"FavColor-BoredPrompt12", @"Wave a color\nin front of me!"),
                                  NSLocalizedString(@"FavColor-BoredPrompt13", @"Wave something\nin front of me!")
                                  ];
        _boredPrompts = [NSMutableSet setWithArray:boredPrompts];
    }
    return _boredPrompts;
}

- (NSMutableArray *)hueRanges
{
    if (!_hueRanges) {
        _hueRanges = [NSMutableArray arrayWithCapacity:5];
    }
    return _hueRanges;
}

#pragma mark - Private Properties

- (RMBehaviorArbiter *)behaviorArbiter
{
    if (!_behaviorArbiter) {
        _behaviorArbiter = [[RMBehaviorArbiter alloc] init];
        _behaviorArbiter.delegate = self;
        _behaviorArbiter.Romo = self.Romo;
    }
    return _behaviorArbiter;
}

@end
