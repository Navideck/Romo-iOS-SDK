//
//  RMMissionRobotController.m
//  Romo
//

#import "RMMissionRobotController.h"
//#import <Analytics/Analytics.h>
#import "UIView+Additions.h"
#import "UIColor+RMColor.h"
#import "UIFont+RMFont.h"
#import "UIButton+RMButtons.h"
#import "UIImage+Tint.h"
#import "UIButton+SoundEffects.h"
#import "RMSoundEffect.h"
#import "RMGradientLabel.h"
#import "RMAppDelegate.h"
#import <Romo/RMMath.h>
#import "RMProgressManager.h"
#import "RMMission.h"
#import "RMMissionEditorVC.h"
#import "RMSandboxMission.h"
#import "RMCompilingVC.h"
#import "RMRuntimeRobotController.h"
#import "RMDebriefingVC.h"
#import "RMSpaceScene.h"
#import "RMChapterPlanet.h"
#import "RMMissionToken.h"
#import "RMDockingRequiredVC.h"
#import "RMAction.h"
#import "RMMissionsPageControl.h"
#import <Romo/RMDispatchTimer.h>
#import "RMFavoriteColorRobotController.h"
#import "RMUnlockable.h"
#import "RMSpriteView.h"
#import "RMAlertView.h"
#import <Romo/UIDevice+Romo.h>
//#import "RMTelepresencePresence.h"

/** Positions */
static const CGFloat subtitleCenterY = 16.0;
static const CGFloat titleCenterY = 42.0;

static const CGFloat planetCenterYTall = 280;
static const CGFloat planetCenterYShort = 248;

static const CGFloat descriptionTopTall = 376;
static const CGFloat descriptionTopShort = 348;

static const CGFloat descriptionHeight = 48;
static const CGFloat descriptionSideOffset = 16.0;
static const CGFloat descriptionTitleTopOffset = 0.0;
static const CGFloat descriptionInfoTopOffset = 24.0;
static const CGFloat descriptionStarCountTopOffset = 48.0;

static const CGFloat missionsPageControlBottomOffset = 36;

/** Sizes */
static const CGFloat titleFontSize = 24.0;
static const CGFloat minimumTitleFontSize = 12.0;
static const CGFloat subtitleFontSize = 14.0;

/** The amount of parallax on the space scene when scrolling */
static const CGFloat spaceParallaxFactor = 0.5;

/** The amount of parallax on planet information when scrolling */
static const CGFloat informationParallaxFactor = 0.35;

static NSString *chapterInformationFileName = @"ChapterInformation";
static NSString *chapterInformationTitleKey = @"title";
static NSString *chapterInformationDescriptionKey = @"description";

#define planetUnlockSound       @"Missions-Planet-Unlock"
#define chaptersAppearSound     @"Missions-State-Chapters"
#define missionsAppearSound     @"Missions-State-Missions"
#define editorAppearSound       @"Missions-State-Editor"
#define compilingAppearSound    @"Missions-State-Compiling"
#define debriefingAppearSound   @"Missions-State-Debriefing"

typedef enum {
    /** All chapters shown */
    RMMissionStateChapters = 1,
    
    /** All missions for the selected chapter */
    RMMissionStateMissions = 2,
    
    /** Mission overview with briefing & events */
    RMMissionStateEditor = 3,
    
    /** Compilation before running */
    RMMissionStateCompiling = 4,
    
    /** Shows the validity status of this mission */
    RMMissionStateDebriefing = 5,
} RMMissionState;

@interface RMMissionRobotController () <UIScrollViewDelegate, RMMissionEditorVCDelegate, RMCompilingVCDelegate, RMDockingRequiredVCDelegate, RMRuntimeRobotControllerDelegate, RMDebriefingVCDelegate, RMMissionsPageControlDelegate, RMActivityRobotControllerDelegate>

@property (nonatomic, strong) RMProgressManager *progressManager;
@property (nonatomic, strong) RMMission *mission;
@property (nonatomic) RMChapter chapter;
@property (nonatomic) NSInteger index;
@property (nonatomic) RMMissionState state;
/** The state we're transitioning from */
@property (nonatomic) RMMissionState previousState;

/** General UI */
@property (nonatomic, strong) RMSpaceScene *spaceScene;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, strong) RMGradientLabel *subtitleLabel;
@property (nonatomic, strong) UIView *navigationBar;
@property (nonatomic, getter=isUnlocking) BOOL unlocking;

/** Chapters */
@property (nonatomic, strong) NSMutableDictionary *chapterPlanets;
@property (nonatomic, strong) NSMutableDictionary *chapterDescriptions;
@property (nonatomic, strong) NSDictionary *chapterInformation;
@property (nonatomic, strong) UIScrollView *chaptersScrollView;
@property (nonatomic, strong) RMMissionsPageControl *missionsPageControl;
@property (nonatomic, strong) RMDispatchTimer *chaptersScrollViewOffsetTimer;
@property (nonatomic) CGPoint targetOffset;

/** Missions */
@property (nonatomic, strong) NSArray *missions;
@property (nonatomic, strong) UIImageView *ring;
@property (nonatomic, strong) RMChapterPlanet *planet;

/** Briefing */
@property (nonatomic, strong) RMMissionEditorVC *editorVC;

/** Compiling */
@property (nonatomic, strong) RMCompilingVC *compilingVC;
@property (nonatomic, strong) RMDockingRequiredVC *dockingRequiredVC;

/** Debriefing */
@property (nonatomic, strong) RMDebriefingVC *debriefingVC;
@property (nonatomic) double missionStartTime;

@end

@implementation RMMissionRobotController

- (id)initWithMission:(RMMission *)mission
{
    self = [self init];
    if (self && mission) {
        self.chapter = mission.chapter;
        self.index = mission.index;
        self.mission = mission;
        self.state = RMMissionStateEditor;
    }
    return self;
}

- (id)init
{
    self = [super init];
    if (self) {
        _progressManager = [RMProgressManager sharedInstance];
        self.chapter = self.progressManager.newestChapter == RMChapterTheEnd ? RMChapterThree : self.progressManager.newestChapter;
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    if (self.state == RMMissionStateChapters && _chapterPlanets) {
        // Collect all off-screen elements
        NSMutableArray *trash = [NSMutableArray arrayWithCapacity:self.chapterPlanets.count - 1];
        [self.chapterPlanets enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, RMChapterPlanet *planet, BOOL *stop) {
            if (!planet.superview) {
                [trash addObject:key];
            }
        }];
        
        // And throw them out to save memory
        // (they will automatically be recreated when needed)
        [trash enumerateObjectsUsingBlock:^(NSNumber *key, NSUInteger idx, BOOL *stop) {
            [self.chapterPlanets removeObjectForKey:key];
            [self.chapterDescriptions removeObjectForKey:key];
        }];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.navigationBar addSubview:self.backButton];
    [self.navigationBar addSubview:self.titleLabel];
    [self.view addSubview:self.spaceScene];
    [self.view addSubview:self.navigationBar];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (!self.state || self.state == RMMissionStateEditor) {
        [RMSoundEffect playBackgroundEffectWithName:spaceLoopSound repeats:YES gain:1.0];
        [RMSoundEffect playForegroundEffectWithName:missionsAppearSound repeats:NO gain:1.0];
    }
    
    [self.Romo.robot tiltToAngle:self.Romo.robot.maximumHeadTiltAngle completion:nil];

    if (!self.state) {
        self.state = RMMissionStateChapters;
        
        RMChapterStatus chapterTwoStatus = [self.progressManager statusForChapter:RMChapterTwo];
        if (chapterTwoStatus == RMChapterStatusSeenCutscene) {
            [self unlockNewestChapter:RMChapterTwo];
        } else {
            RMChapterStatus chapterThreeStatus = [self.progressManager statusForChapter:RMChapterThree];
            if (chapterThreeStatus != RMChapterStatusLocked && chapterThreeStatus != RMChapterStatusSeenUnlock) {
                [self unlockNewestChapter:RMChapterThree];
            }
        }
    } else if (self.state == RMMissionStateChapters) {
        [self scrollViewDidScroll:self.chaptersScrollView];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [RMSoundEffect stopBackgroundEffect];
    
    [self.chapterDescriptions enumerateKeysAndObjectsUsingBlock:^(id key, UIView *descriptionView, BOOL *stop) {
        [descriptionView removeFromSuperview];
    }];
    [self.chapterDescriptions removeAllObjects];
}

- (RMRomoFunctionalities)initiallyActiveFunctionalities
{
    // We don't need anything external running
    return RMRomoFunctionalityNone;
}

- (RMRomoInterruptions)initiallyAllowedInterruptions
{
    // never interrupt
    return RMRomoInterruptionNone;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView == self.chaptersScrollView) {
        CGFloat ratio = scrollView.contentOffset.x / scrollView.width;
        
        if ([UIDevice currentDevice].isFastDevice) {
            // Only use parallax if the device is fast
            self.spaceScene.cameraLocation = RMPoint3DMake(ratio * spaceParallaxFactor, 0, 0);
        }

        self.spaceScene.origin = scrollView.contentOffset;

        NSInteger chapterCount = self.progressManager.chapters.count;
        if ([self.progressManager.chapters containsObject:@(RMChapterTheEnd)]) {
            chapterCount--;
        }

        CGFloat clampedRatio = CLAMP(0, ratio, chapterCount - 1);
        self.missionsPageControl.currentPage = (int)(round(clampedRatio));
        
        int indexOfVisibleChapter = (int)clampedRatio;
        RMChapterPlanet *planet = [self planetForChapterAtIndex:indexOfVisibleChapter];
        planet.centerX = (scrollView.width / 2.0) + indexOfVisibleChapter * scrollView.width;
        if (!planet.superview) {
            [scrollView addSubview:planet];
        }
        
        UIView *description = [self descriptionForChapterAtIndex:indexOfVisibleChapter];
        description.centerX = planet.centerX + informationParallaxFactor * scrollView.width * (indexOfVisibleChapter - ratio);
        description.alpha = CLAMP(0.0, 1.0 - 2.0 * (ratio - indexOfVisibleChapter), 1.0);
        if (!description.superview) {
            [scrollView addSubview:description];
        }
        
        RMChapterPlanet *nextPlanet = nil;
        UIView *nextDescription = nil;
        BOOL showsNextChapter = ratio - indexOfVisibleChapter > 0.0;
        if (showsNextChapter && indexOfVisibleChapter + 1 < chapterCount) {
            nextPlanet = [self planetForChapterAtIndex:indexOfVisibleChapter + 1];
            nextDescription = [self descriptionForChapterAtIndex:indexOfVisibleChapter + 1];
            nextPlanet.centerX = (scrollView.width / 2.0) + (indexOfVisibleChapter + 1) * scrollView.width;
            if (!nextPlanet.superview) {
                [scrollView addSubview:nextPlanet];
            }
            
            nextDescription.centerX = nextPlanet.centerX + informationParallaxFactor * scrollView.width * (indexOfVisibleChapter + 1 - ratio);
            nextDescription.alpha = CLAMP(0.0, 2.0 * (ratio - indexOfVisibleChapter - 0.5), 1.0);
            if (!nextDescription.superview) {
                [scrollView addSubview:nextDescription];
            }
        }
        
        [self.chapterPlanets enumerateKeysAndObjectsUsingBlock:^(id key, RMChapterPlanet *otherPlanet, BOOL *stop) {
            if (otherPlanet != planet && otherPlanet != nextPlanet && otherPlanet.superview) {
                [otherPlanet removeFromSuperview];
            }
        }];
        
        [self.chapterDescriptions enumerateKeysAndObjectsUsingBlock:^(id key, UIView *otherDescription, BOOL *stop) {
            if (otherDescription != description && otherDescription != nextDescription && otherDescription.superview) {
                if (self.state == RMMissionStateChapters) {
                    // Play random swish sound
                    int randomSwishNum = arc4random_uniform(kNumSwishSounds) + 1;
                    [RMSoundEffect playForegroundEffectWithName:[NSString stringWithFormat:@"Swish-%d", randomSwishNum]
                                                        repeats:NO
                                                           gain:1.0];
                }
                [otherDescription removeFromSuperview];
            }
        }];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (scrollView == self.chaptersScrollView) {
        if (_chaptersScrollViewOffsetTimer) {
            [self.chaptersScrollViewOffsetTimer stopRunning];
            self.chaptersScrollViewOffsetTimer = nil;
        }
    }
}

#pragma mark - RMMissionEditorVCDelegate

- (void)handleMissionEditorDidStart:(RMMissionEditorVC *)missionEditorVC
{
    self.state = RMMissionStateCompiling;
}

#pragma mark - RMCompilingVCDelegate

- (void)compilingVCDidFailToCompile:(RMCompilingVC *)compilingVC
{
    if (self.state == RMMissionStateCompiling) {
        self.state = RMMissionStateEditor;
    }
}

- (void)compilingVCDidFinishCompiling:(RMCompilingVC *)compilingVC
{
    if (self.state == RMMissionStateCompiling) {
        if (self.Romo.robot) {
            [self runMission];
        } else {
            [self presentViewController:self.dockingRequiredVC animated:YES completion:nil];
        }
    }
}

#pragma mark - RMDockingRequiredVCDelegate

- (void)dockingRequiredVCDidDismiss:(RMDockingRequiredVC *)dockingRequiredVC
{
    [self dismissViewControllerAnimated:YES completion:^{
        self.dockingRequiredVC = nil;
    }];
    self.state = RMMissionStateEditor;
}

- (void)dockingRequiredVCDidDock:(RMDockingRequiredVC *)dockingRequiredVC
{
    [self dismissViewControllerAnimated:YES completion:^{
        self.dockingRequiredVC = nil;
        [self runMission];
    }];
}

#pragma mark - RMRuntimeRobotControllerDelegate

- (void)runtimeFinishedRunningAllScripts:(RMRuntimeRobotController *)runtime
{
    if (self.mission.chapter != RMChapterTheLab && self.mission.duration <= 0) {
        runtime.delegate = nil;
        self.mission.running = NO;
        
        double delayInSeconds = 0.75;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            self.state = RMMissionStateDebriefing;
        });
    }
}

- (void)runtimeDidTimeout:(RMRuntimeRobotController *)runtime
{
    if (self.mission.duration > 0) {
        runtime.delegate = nil;
        self.mission.running = NO;
        
        double delayInSeconds = 0.75;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            self.state = RMMissionStateDebriefing;
        });
    }
}

- (void)runtimeDisconnectedFromRobot:(RMRuntimeRobotController *)runtime
{
    runtime.delegate = nil;
    self.mission.running = NO;

    self.mission.reasonForFailing = RMMissionFailureReasonUndocked;
    if (self.mission.skipDebriefing) {
        self.state = RMMissionStateEditor;
    } else {
        self.state = RMMissionStateDebriefing;
    }
}

- (void)runtime:(RMRuntimeRobotController *)runtime robotDidFlipToOrientation:(RMRobotOrientation)orientation
{
    runtime.delegate = nil;
    self.mission.running = NO;

    self.mission.reasonForFailing = RMMissionFailureReasonFlipped;
    if (self.mission.skipDebriefing) {
        self.state = RMMissionStateEditor;
    } else {
        self.state = RMMissionStateDebriefing;
    }
}

- (void)runtimeDidEnterBackground:(RMRuntimeRobotController *)runtime
{
    self.mission.running = NO;
    self.state = RMMissionStateEditor;
    [(RMAppDelegate *)[UIApplication sharedApplication].delegate popRobotController];
}

#pragma mark - RMDebriefingVCDelegate

- (void)debriefingVCDidSelectReplay:(RMDebriefingVC *)debriefingVC
{
    [self debriefingVCDidSelectTryAgain:debriefingVC];
}

- (void)debriefingVCDidSelectTryAgain:(RMDebriefingVC *)debriefingVC
{
    self.state = RMMissionStateEditor;
}

- (void)debriefingVCDidSelectContinue:(RMDebriefingVC *)debriefingVC
{
    [self dismiss];
}

#ifdef FAST_MISSIONS
- (void)replay
{
    [self handleMissionEditorDidStart:nil];
}
#endif

#pragma mark - RMMissionsPageControlDelegate

- (void)pageControl:(RMMissionsPageControl *)pageControl didSelectPage:(int)page
{
    if (self.state == RMMissionStateChapters) {
        CGFloat xOffset = page * self.chaptersScrollView.width;
        [self setChaptersScrollViewOffset:CGPointMake(xOffset, 0)];
    }
}

#pragma mark - RMActivityRobotControllerDelegate

- (void)activityDidFinish:(RMActivityRobotController *)activity
{
    if ([activity isKindOfClass:[RMRuntimeRobotController class]]) {
        self.mission.running = NO;
        self.state = RMMissionStateEditor;
        [(RMAppDelegate *)[UIApplication sharedApplication].delegate popRobotController];
    } else {
        // Pop back to self and display the unlocking of the new chapter
        _state = 0;
        [(RMAppDelegate *)[UIApplication sharedApplication].delegate popRobotController];
    }
}

#pragma mark - Private Properties

- (void)setState:(RMMissionState)state
{
    self.previousState = _state;
    _state = state;
    
    [self.navigationBar addSubview:self.backButton];
    
    switch (state) {
            // Scroll view of planets arranged horizontally
        case RMMissionStateChapters: {
            [self.backButton setImage:[UIImage imageNamed:@"backButtonImageCreature.png"]];
            self.title = NSLocalizedString(@"Mission-Chapters-View-Title", @"Choose a Planet");
            self.subtitle = nil;
            
            [self addChapters];
            self.chaptersScrollView.scrollEnabled = YES;
            self.spaceScene.origin = self.chaptersScrollView.contentOffset;
            [self scrollViewDidScroll:self.chaptersScrollView];
            
            if (self.previousState == RMMissionStateEditor) {
                [self scrollViewDidScroll:self.chaptersScrollView];
                self.chaptersScrollView.transform = CGAffineTransformMakeScale(0.5, 0.5);
                self.chaptersScrollView.alpha = 0.0;
                [self.view insertSubview:self.spaceScene belowSubview:self.chaptersScrollView];
                self.spaceScene.origin = CGPointZero;
            } else {
                [self.chaptersScrollView insertSubview:self.spaceScene atIndex:0];
            }
            
            [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
            [UIView animateWithDuration:0.35
                             animations:^{
                                 self.missionsPageControl.center = CGPointMake(self.view.width / 2, self.view.height - missionsPageControlBottomOffset);
                                 self.missionsPageControl.alpha = 1.0;
                                 
                                 for (NSValue *key in self->_chapterDescriptions) {
                                     UIView *description = self.chapterDescriptions[key];
                                     description.top = y(descriptionTopTall, descriptionTopShort);
                                 }
                                 
                                 if (self.previousState == RMMissionStateEditor) {
                                     self.editorVC.view.top = self.view.height;
                                     self.chaptersScrollView.transform = CGAffineTransformIdentity;
                                     self.chaptersScrollView.alpha = 1.0;
                                 } else {
                                     [self scrollViewDidScroll:self.chaptersScrollView];
                                 }
                                 
                                 if (self->_missions.count) {
                                     [self expandMissionsByRatio:0.0];
                                 }
                             } completion:^(BOOL finished) {
                                 self.spaceScene.origin = self.chaptersScrollView.contentOffset;
                                 [self.chaptersScrollView insertSubview:self.spaceScene atIndex:0];
                                 [self removeMissions];
                                 [self removeEditing];
                                 [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                             }];
            
            break;
        }
            
            // Individual planet centered, with mission tokens surrounding it
        case RMMissionStateMissions: {
            [self.backButton setImage:[UIImage imageNamed:@"backButtonImagePlanets.png"]];
            // Localized version of the chapter name is stored in the plist
            self.title = self.chapterInformation[[NSString stringWithFormat:@"%d", self.chapter]][chapterInformationTitleKey];
            self.subtitle = [self chapterNumber];
            
            [self scrollViewDidScroll:self.chaptersScrollView];
            self.chaptersScrollView.scrollEnabled = NO;
            
            [self addChapters];
            [self addMissions];
            
            if (self.previousState == RMMissionStateEditor) {
                [self scrollViewDidScroll:self.chaptersScrollView];
                [self expandMissionsByRatio:1.0];
                self.chaptersScrollView.transform = CGAffineTransformMakeScale(0.5, 0.5);
                self.chaptersScrollView.alpha = 0.0;
                [self.view insertSubview:self.spaceScene belowSubview:self.chaptersScrollView];
                self.spaceScene.origin = CGPointZero;
            }
            
            [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
            [UIView animateWithDuration:0.35
                             animations:^{
                                 if (self->_missionsPageControl.superview) {
                                     self.missionsPageControl.top = self.view.height;
                                     self.missionsPageControl.alpha = 0.0;
                                 }
                                 
                                 for (NSValue *key in self->_chapterDescriptions) {
                                     UIView *description = self.chapterDescriptions[key];
                                     description.top = y(descriptionTopTall, descriptionTopShort) + 16.0;
                                     description.alpha = 0.0;
                                 }
                                 
                                 if (self.previousState == RMMissionStateEditor) {
                                     self.editorVC.view.top = self.view.height;
                                     self.chaptersScrollView.transform = CGAffineTransformIdentity;
                                     self.chaptersScrollView.alpha = 1.0;
                                 } else {
                                     [self expandMissionsByRatio:1.0];
                                 }
                             } completion:^(BOOL finished) {
                                 self.spaceScene.origin = self.chaptersScrollView.contentOffset;
                                 [self.chaptersScrollView insertSubview:self.spaceScene atIndex:0];
                                 [self removeEditing];
                                 [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                             }];
            
            break;
        }
            
            // Rattlesnake mission editor
        case RMMissionStateEditor: {
            [self.backButton setImage:[UIImage imageNamed:[NSString stringWithFormat:@"backButtonImagePlanet%d.png", self.chapter]]];
            [self setTitleToMissionNumber];
            [self setSubtitleToMissionStatus];
            
            [self addEditing];
            
            if (self.previousState == RMMissionStateChapters || self.previousState == RMMissionStateMissions) {
                [self.view insertSubview:self.spaceScene belowSubview:self.chaptersScrollView];
                self.spaceScene.origin = CGPointZero;
                self.editorVC.view.top = self.view.height;
            } else if (self.previousState == RMMissionStateDebriefing) {
                self.editorVC.view.top = self.view.height;
            } else {
                self.editorVC.view.bottom = 0.0;
                self.editorVC.view.alpha = 0.0;
            }
            
            [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
            [UIView animateWithDuration:0.35
                             animations:^{
                                 if (self.previousState == RMMissionStateChapters || self.previousState == RMMissionStateMissions) {
                                     if (self->_missionsPageControl.superview) {
                                         self.missionsPageControl.top = self.view.height;
                                         self.missionsPageControl.alpha = 0.0;
                                     }
                                     
                                     if (self->_chaptersScrollView.superview) {
                                         self.chaptersScrollView.transform = CGAffineTransformMakeScale(0.5, 0.5);
                                         self.chaptersScrollView.alpha = 0.0;
                                     }
                                 } else if (self.previousState == RMMissionStateDebriefing) {
                                     self.debriefingVC.view.bottom = 0.0;
                                     self.debriefingVC.view.alpha = 0.0;
                                 } else if (self.previousState == RMMissionStateCompiling) {
                                     self.compilingVC.view.top = self.view.height;
                                     self.compilingVC.view.alpha = 0.0;
                                 }
                                 
                                 self.editorVC.view.top = 0.0;
                                 self.editorVC.view.alpha = 1.0;
                                 
                             } completion:^(BOOL finished) {
                                 [self removeChapters];
                                 [self removeMissions];
                                 [self removeCompiling];
                                 [self removeDebriefing];
                                 [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                             }];
            
            break;
        }
            
            // Shows a progress bar of compilation
        case RMMissionStateCompiling: {
            [self setTitleToMissionName];
            [self setSubtitleToMissionNumber];
            
            self.mission.reasonForFailing = RMMissionFailureReasonNone;
            
            [self addCompiling];
            [RMSoundEffect playForegroundEffectWithName:compilingAppearSound repeats:NO gain:1.0];
            
            [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
            [UIView animateWithDuration:0.35
                             animations:^{
                                 self.editorVC.view.top = -self.view.height;
                                 self.editorVC.view.alpha = 0.0;
                                 self.compilingVC.view.top = 0;
                             } completion:^(BOOL finished) {
                                 [self removeEditing];
                                 [self.compilingVC compile];
                                 [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                             }];
            
            break;
        }
            
            // After the mission is done running, shows whether or not they beat it
        case RMMissionStateDebriefing: {
            [self setTitleToMissionName];
            [self setSubtitleToMissionNumber];
            [self.backButton removeFromSuperview];
            
            [(RMAppDelegate *)[UIApplication sharedApplication].delegate popRobotController];
            [self removeEditing];
            [self removeCompiling];
            [self addDebriefing];
            
            if (self.previousState == RMMissionStateCompiling) {
                double missionPlayTime = currentTime() - self.missionStartTime;
                [self.progressManager incrementPlayTime:missionPlayTime forMissionInChapter:self.chapter index:self.index];
                self.debriefingVC.playDuration = missionPlayTime;
                [RMSoundEffect playForegroundEffectWithName:debriefingAppearSound repeats:NO gain:1.0];
                
                [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionCurveEaseOut
                                 animations:^{
                                     self.debriefingVC.view.top = 0;
                                 } completion:nil];
            }
            [self.Romo.robot tiltToAngle:self.Romo.robot.maximumHeadTiltAngle completion:nil];
            
            break;
        }
    }
}

- (void)setTitle:(NSString *)title
{
    super.title = title;
    
    CGFloat actualFontSize;
    self.titleLabel.text = title;
    self.titleLabel.size = [title sizeWithFont:[UIFont fontWithSize:titleFontSize]
                                   minFontSize:minimumTitleFontSize
                                actualFontSize:&actualFontSize
                                      forWidth:self.view.width - 160
                                 lineBreakMode:NSLineBreakByClipping];
    self.titleLabel.font = [UIFont fontWithSize:actualFontSize];
    
    [self layoutTopBar];
}

- (void)setSubtitle:(NSString *)subtitle
{
    _subtitle = subtitle;
    
    self.subtitleLabel.text = subtitle;
    
    [self layoutTopBar];
}

- (void)setMission:(RMMission *)mission
{
    _mission = mission;
    _chapter = mission.chapter;
    _index = mission.index;
    
    self.title = mission.title;
}

- (void)setIndex:(NSInteger)index
{
    _index = index;
    
    if (self.chapter == RMChapterTheLab) {
        self.mission = [[RMSandboxMission alloc] initWithChapter:self.chapter index:index];
    } else {
        self.mission = [[RMMission alloc] initWithChapter:self.chapter index:index];
    }
    
    self.progressManager.currentChapter = self.chapter;
    self.missionStartTime = currentTime();
}

- (RMSpaceScene *)spaceScene
{
    if (!_spaceScene) {
        _spaceScene = [[RMSpaceScene alloc] initWithFrame:self.view.bounds];
    }
    return _spaceScene;
}

- (UIButton *)backButton
{
    if (!_backButton) {
        _backButton = [UIButton backButtonWithImage:[UIImage imageNamed:@"backButtonImageCreature.png"]];
        [_backButton addTarget:self action:@selector(handleBackButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _backButton;
}

- (UILabel *)titleLabel
{
    if (!_titleLabel) {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.backgroundColor = [UIColor clearColor];
    }
    return _titleLabel;
}

- (RMGradientLabel *)subtitleLabel
{
    if (!_subtitleLabel) {
        _subtitleLabel = [[RMGradientLabel alloc] initWithFrame:CGRectMake(0, 0, self.view.width - 140, 16)];
        _subtitleLabel.gradientColor = [UIColor greenColor];
        _subtitleLabel.backgroundColor = [UIColor clearColor];
        _subtitleLabel.font = [UIFont fontWithSize:subtitleFontSize];
        _subtitleLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _subtitleLabel;
}

- (UIView *)navigationBar
{
    if (!_navigationBar) {
        _navigationBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.width, 64)];
        _navigationBar.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"missionsTopBarBackground.png"]];
    }
    return _navigationBar;
}

- (NSMutableDictionary *)chapterPlanets
{
    if (!_chapterPlanets) {
        _chapterPlanets = [NSMutableDictionary dictionaryWithCapacity:4];
    }
    return _chapterPlanets;
}

- (NSMutableDictionary *)chapterDescriptions
{
    if (!_chapterDescriptions) {
        _chapterDescriptions = [NSMutableDictionary dictionaryWithCapacity:4];
    }
    return _chapterDescriptions;
}

- (UIScrollView *)chaptersScrollView
{
    if (!_chaptersScrollView) {
        NSMutableArray *chapters = [NSMutableArray arrayWithArray:self.progressManager.chapters];
        if ([chapters containsObject:@(RMChapterTheEnd)]) {
            [chapters removeObject:@(RMChapterTheEnd)];
        }
        
        NSInteger numberOfChapters = chapters.count;

        _chaptersScrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
        _chaptersScrollView.delegate = self;
        _chaptersScrollView.contentSize = CGSizeMake(_chaptersScrollView.width * numberOfChapters, _chaptersScrollView.height);
        _chaptersScrollView.bounces = YES;
        _chaptersScrollView.alwaysBounceHorizontal = YES;
        _chaptersScrollView.alwaysBounceVertical = NO;
        _chaptersScrollView.showsHorizontalScrollIndicator = NO;
        _chaptersScrollView.showsVerticalScrollIndicator = NO;
        _chaptersScrollView.delaysContentTouches = NO;
        _chaptersScrollView.pagingEnabled = YES;
        
        if (self.chapter) {
            NSInteger index = [chapters indexOfObject:@(self.chapter)];
            _chaptersScrollView.contentOffset = CGPointMake(index * _chaptersScrollView.width, 0);
        }
    }
    return _chaptersScrollView;
}

- (RMMissionsPageControl *)missionsPageControl
{
    if (!_missionsPageControl) {
        // We're not going to show this anymore
        _missionsPageControl = [[RMMissionsPageControl alloc] init];
        _missionsPageControl.delegate = self;
    }
    return _missionsPageControl;
}

- (NSArray *)missions
{
    if (!_missions) {
        int missionCount = [self.progressManager missionCountForChapter:self.chapter];
        int highestUnlockedMission = 1;
        for (int i = 1; i <= missionCount; i++) {
            RMMissionStatus status = [self.progressManager statusForMissionInChapter:self.chapter index:i];
            if (status != RMMissionStatusLocked) {
                highestUnlockedMission = i;
            }
        }
        
        // If we have less than 6 unlocked missions, only show the first six
        // to keep it less cluttered
        if (highestUnlockedMission < 6) {
            missionCount = 6;
        }
        
        NSMutableArray *missions = [NSMutableArray arrayWithCapacity:missionCount];
        for (int i = 1; i <= missionCount; i++) {
            RMMissionToken *token = [[RMMissionToken alloc] initWithChapter:self.chapter index:i status:[self.progressManager statusForMissionInChapter:self.chapter index:i]];
            [token addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleMissionTap:)]];
            [missions addObject:token];
        }
        _missions = [NSArray arrayWithArray:missions];
    }
    return _missions;
}

- (UIImageView *)ring
{
    if (!_ring) {
        _ring = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"planetRing.png"]];
    }
    return _ring;
}

- (RMMissionEditorVC *)editorVC
{
    if (!_editorVC) {
        _editorVC = [[RMMissionEditorVC alloc] init];
        _editorVC.mission = self.mission;
        _editorVC.delegate = self;
    }
    return _editorVC;
}

- (RMCompilingVC *)compilingVC
{
    if (!_compilingVC) {
        _compilingVC = [[RMCompilingVC alloc] init];
        _compilingVC.delegate = self;
        _compilingVC.mission = self.mission;
    }
    return _compilingVC;
}

- (RMDockingRequiredVC *)dockingRequiredVC
{
    if (!_dockingRequiredVC) {
        _dockingRequiredVC = [[RMDockingRequiredVC alloc] init];
        _dockingRequiredVC.delegate = self;
        _dockingRequiredVC.showsPurchaseButton = NO;
        _dockingRequiredVC.showsDismissButton = YES;
    }
    return _dockingRequiredVC;
}

- (RMDebriefingVC *)debriefingVC
{
    if (!_debriefingVC) {
        _debriefingVC = [[RMDebriefingVC alloc] initWithMission:self.mission];
        _debriefingVC.delegate = self;
    }
    return _debriefingVC;
}

#pragma mark - Chapters

- (void)addChapters
{
    if (!self.chaptersScrollView.superview) {
        [self.chaptersScrollView addSubview:self.spaceScene];
        [self.view insertSubview:self.chaptersScrollView atIndex:0];
    }
    
    if (!self.missionsPageControl.superview) {
        self.missionsPageControl.center = CGPointMake(self.view.width / 2, self.view.height + self.missionsPageControl.height / 2.0);
        self.missionsPageControl.alpha = 0.0;
        [self.view addSubview:self.missionsPageControl];
    }
}

- (void)removeChapters
{
    if (_chapterPlanets) {
        for (NSNumber *key in self.chapterPlanets) {
            RMChapterPlanet *chapterPlanet = self.chapterPlanets[key];
            [chapterPlanet removeFromSuperview];
        }
        self.chapterPlanets = nil;
    }
    
    if (_chapterDescriptions) {
        for (NSNumber *key in self.chapterDescriptions) {
            UIView *chapterDescription = self.chapterDescriptions[key];
            [chapterDescription removeFromSuperview];
        }
        self.chapterDescriptions = nil;
    }
    
    if (_chaptersScrollView.superview) {
        self.spaceScene.top = 0;
        [self.view insertSubview:self.spaceScene atIndex:0];
        [self.chaptersScrollView removeFromSuperview];
        self.chaptersScrollView = nil;
    }
    
    if (_missionsPageControl.superview) {
        [_missionsPageControl removeFromSuperview];
        _missionsPageControl = nil;
    }
}

- (RMChapterPlanet *)planetForChapterAtIndex:(NSInteger)index
{
    RMChapterPlanet *planet = self.chapterPlanets[@(index)];
    if (!planet) {
        RMChapter chapter = [self.progressManager.chapters[index] intValue];
        planet = [[RMChapterPlanet alloc] initWithChapter:chapter status:[self.progressManager statusForChapter:chapter]];
        planet.centerY = y(planetCenterYTall, planetCenterYShort);
        [planet addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handlePlanetTap:)]];
#ifdef DEBUG
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handlePlanetDoubleTap:)];
        doubleTap.numberOfTapsRequired = 2;
        [planet addGestureRecognizer:doubleTap];
#endif
        self.chapterPlanets[@(index)] = planet;
    }
    return planet;
}

- (UIView *)descriptionForChapterAtIndex:(int)index
{
    if (self.isUnlocking) {
        return nil;
    }
    
    UIView *descriptionView = self.chapterDescriptions[@(index)];
    if (!descriptionView) {
        descriptionView = [[UIView alloc] initWithFrame:CGRectMake(descriptionSideOffset, y(descriptionTopTall, descriptionTopShort), self.view.width - 2.0 * descriptionSideOffset, descriptionHeight)];
        
        RMChapter chapter = [self.progressManager.chapters[index] intValue];
        NSDictionary *chapterInformation = self.chapterInformation[[NSString stringWithFormat:@"%d", chapter]];
        
        UILabel *planetNameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        planetNameLabel.backgroundColor = [UIColor clearColor];
        planetNameLabel.textColor = [UIColor whiteColor];
        planetNameLabel.font = [UIFont fontWithSize:titleFontSize];
        planetNameLabel.text = chapterInformation[chapterInformationTitleKey];
        planetNameLabel.size = [planetNameLabel.text sizeWithFont:planetNameLabel.font];
        planetNameLabel.center = CGPointMake(descriptionView.width / 2.0, descriptionTitleTopOffset);
        [descriptionView addSubview:planetNameLabel];
        
        UILabel *planetInfoLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        planetInfoLabel.backgroundColor = [UIColor clearColor];
        planetInfoLabel.textColor = [UIColor blueTextColor];
        planetInfoLabel.font = [UIFont fontWithSize:subtitleFontSize];
        planetInfoLabel.text = chapterInformation[chapterInformationDescriptionKey];
        planetInfoLabel.size = [planetInfoLabel.text sizeWithFont:planetInfoLabel.font];
        planetInfoLabel.center = CGPointMake(descriptionView.width / 2.0, descriptionInfoTopOffset);
        [descriptionView addSubview:planetInfoLabel];
        
        RMChapterStatus chapterStatus = [self.progressManager statusForChapter:chapter];
        int missionCount = [self.progressManager missionCountForChapter:chapter];
        if (chapterStatus != RMChapterStatusLocked && missionCount > 0) {
            UIImageView *star = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"missionTokenStar.png"]];
            star.centerY = descriptionStarCountTopOffset;
            [descriptionView addSubview:star];
            
            RMGradientLabel *starCountLabel = [[RMGradientLabel alloc] initWithFrame:CGRectZero];
            starCountLabel.backgroundColor = [UIColor clearColor];
            starCountLabel.gradientColor = [UIColor greenColor];
            starCountLabel.font = [UIFont fontWithSize:subtitleFontSize];
            starCountLabel.text = [NSString stringWithFormat:@"%d", [self.progressManager starCountForChapter:chapter]];
            starCountLabel.size = [starCountLabel.text sizeWithFont:starCountLabel.font];
            starCountLabel.centerY = descriptionStarCountTopOffset;
            [descriptionView addSubview:starCountLabel];
            
            CGFloat width = star.width + starCountLabel.width;
            star.left = (descriptionView.width - width) / 2.0;
            starCountLabel.left = star.right;
        } else if (chapterStatus != RMChapterStatusLocked && chapterIsComet(chapter)) {
            double activityProgress = 0.0;
            switch (chapter) {
                case RMCometFavoriteColor:
                    activityProgress = [RMFavoriteColorRobotController activityProgress];
                    break;
                    
                default:
                    break;
            }
            
            UIImageView *activityProgressBarBackground = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"activityProgressBarBackground.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 5.5, 0, 5.5)]];
            activityProgressBarBackground.width = 144.0;
            activityProgressBarBackground.center = CGPointMake(descriptionView.width / 2.0, descriptionStarCountTopOffset);
            [descriptionView addSubview:activityProgressBarBackground];
            
            UIImageView *activityProgressBar = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"activityProgressBar.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 15, 0, 15)]];
            activityProgressBar.frame = CGRectMake(activityProgressBarBackground.left - 9.0, activityProgressBarBackground.top - 9.0,
                                                   18.0 + activityProgress * activityProgressBarBackground.width, activityProgressBar.height);
            [descriptionView addSubview:activityProgressBar];
            
            RMGradientLabel *activityProgressLabel = [[RMGradientLabel alloc] initWithFrame:CGRectZero];
            activityProgressLabel.backgroundColor = [UIColor clearColor];
            activityProgressLabel.gradientColor = [UIColor greenColor];
            activityProgressLabel.font = [UIFont fontWithSize:subtitleFontSize];
            activityProgressLabel.text = [NSString stringWithFormat:@"%.0f%%", floor(activityProgress * 100.0)];
            activityProgressLabel.size = [activityProgressLabel.text sizeWithFont:activityProgressLabel.font];
            activityProgressLabel.center = CGPointMake(descriptionView.width / 2.0, descriptionStarCountTopOffset + 24.0);
            [descriptionView addSubview:activityProgressLabel];
        }


        self.chapterDescriptions[@(index)] = descriptionView;
    }
    return descriptionView;
}

- (NSDictionary *)chapterInformation
{
    if (!_chapterInformation) {
        NSString *chapterInformationFile = [[NSBundle mainBundle] pathForResource:chapterInformationFileName ofType:@"plist"];
        _chapterInformation = [NSDictionary dictionaryWithContentsOfFile:chapterInformationFile];
    }
    return _chapterInformation;
}

- (void)setChaptersScrollViewOffset:(CGPoint)offset
{
    self.targetOffset = offset;
    [self.chaptersScrollViewOffsetTimer startRunning];
}

- (RMDispatchTimer *)chaptersScrollViewOffsetTimer
{
    if (!_chaptersScrollViewOffsetTimer) {
        __weak RMMissionRobotController *weakSelf = self;
        _chaptersScrollViewOffsetTimer = [[RMDispatchTimer alloc] initWithName:@"Missions ScrollView"
                                                                     frequency:30.0];
        
        _chaptersScrollViewOffsetTimer.eventHandler = ^{
            CGFloat error = weakSelf.targetOffset.x - weakSelf.chaptersScrollView.contentOffset.x;
            if (error) {
                CGFloat tweenedX = (int)MIN(200, error / 5.0) + ((error > 0) ? 1 : -1);
                dispatch_async(dispatch_get_main_queue(), ^{
                    weakSelf.chaptersScrollView.contentOffset = CGPointMake(weakSelf.chaptersScrollView.contentOffset.x + tweenedX, 0);
                });
            } else {
                [weakSelf.chaptersScrollViewOffsetTimer stopRunning];
                weakSelf.chaptersScrollViewOffsetTimer = nil;
            }
        };
    }
    return _chaptersScrollViewOffsetTimer;
}

// Animates the newest chapter exploding into view
- (void)unlockNewestChapter:(RMChapter)newestChapter
{
    if (self.state == RMMissionStateChapters) {
        self.unlocking = YES;
        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
        [self.navigationBar removeFromSuperview];
        [self.missionsPageControl removeFromSuperview];
        self.missionsPageControl = nil;
        
        [self.chapterDescriptions enumerateKeysAndObjectsUsingBlock:^(id key, UIView *descriptionView, BOOL *stop) {
            [descriptionView removeFromSuperview];
        }];
        
        NSInteger indexOfNewestChapter = [self.progressManager.unlockedChapters indexOfObject:@(newestChapter)];
        NSInteger indexOfPreviousChapter = indexOfNewestChapter - 1;
        
        self.chaptersScrollView.contentOffset = CGPointMake(self.chaptersScrollView.width * indexOfPreviousChapter, 0);
        
        // Replace the newest planet with a locked version
        RMChapterPlanet *newestPlanetLocked = [[RMChapterPlanet alloc] initWithChapter:newestChapter status:RMChapterStatusLocked];
        newestPlanetLocked.centerY = y(planetCenterYTall, planetCenterYShort);
        self.chapterPlanets[@(indexOfNewestChapter)] = newestPlanetLocked;
        
        // Slide to the newest one, then animate it in
        double delayInSeconds = 1.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self.chaptersScrollView setContentOffset:CGPointMake(self.chaptersScrollView.width * indexOfNewestChapter, 0) animated:YES];
            
            double delayInSeconds = 1.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                // Show the explosion animation
                RMSpriteView *unlockingExplosion = [[RMSpriteView alloc] initWithFrame:CGRectMake(0, 0, self.view.width / 4.0, self.view.height / 4.0)
                                                                            spriteName:@"planetUnlockSprites"
                                                                           repeatCount:0
                                                                          autoreverses:NO
                                                                       framesPerSecond:30.0];
                unlockingExplosion.transform = CGAffineTransformMakeScale(4.0, 4.0);
                unlockingExplosion.center = self.view.boundsCenter;
                [self.view addSubview:unlockingExplosion];
                [unlockingExplosion startAnimating];
                [RMSoundEffect playForegroundEffectWithName:planetUnlockSound repeats:NO gain:1.0];
                
                double delayInSeconds = 1.0;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    [self.chapterPlanets removeObjectForKey:@(indexOfNewestChapter)];
                    [self planetForChapterAtIndex:indexOfNewestChapter];
                    
                    self.unlocking = NO;
                    [newestPlanetLocked removeFromSuperview];
                    [self scrollViewDidScroll:self.chaptersScrollView];
                    
                    self.navigationBar.bottom = 0;
                    [self.view addSubview:self.navigationBar];
                    
                    self.missionsPageControl.top = self.view.height;
                    self.missionsPageControl.centerX = self.view.width / 2.0;
                    [self.view addSubview:self.missionsPageControl];
                    
                    [UIView animateWithDuration:0.65 delay:1.0 options:0
                                     animations:^{
                                         self.navigationBar.top = 0;
                                         self.missionsPageControl.bottom = self.view.height - missionsPageControlBottomOffset;
                                     } completion:^(BOOL finished) {
                                         [unlockingExplosion removeFromSuperview];
                                         
                                         if (newestChapter != RMChapterThree) {
                                             // Update the progress to indicate that we've shown the animation
                                             // Chapter Three is an exception where we show the unlock before the cutscene
                                             [self.progressManager setStatus:RMChapterStatusSeenUnlock forChapter:newestChapter];
                                         }

                                         if (newestChapter == RMChapterTwo || newestChapter == RMChapterThree) {
                                             // If we're just unlocking Chapter 2 or Chapter 3, make sure we go back to the Creature
                                             // to show a cutscene or interaction script
                                             double delayInSeconds = 1.5;
                                             dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                                             dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                                                 [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                                                 [self dismiss];
                                             });
                                         } else {
                                             [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                                         }
                                     }];
                });
            });
        });
    }
}

#pragma mark - Missions

- (void)addMissions
{
    if (!_missions.count) {
        for (NSNumber *key in self.chapterPlanets) {
            RMChapterPlanet *planet = self.chapterPlanets[key];
            if (planet.chapter == self.chapter) {
                self.planet = planet;
            }
        }
        [self.chaptersScrollView insertSubview:self.ring belowSubview:self.planet];
        
        for (RMMissionToken *mission in self.missions) {
            [self.chaptersScrollView insertSubview:mission aboveSubview:self.ring];
            if (self.missions.count <= 6 && [UIDevice currentDevice].isFastDevice) {
                [mission startAnimating];
            }
        }
        [self expandMissionsByRatio:0.0];
    }
}

- (void)removeMissions
{
    if (_missions) {
        for (RMMissionToken *mission in self.missions) {
            [mission removeFromSuperview];
        }
        self.missions = nil;
    }
    
    if (_ring) {
        [self.ring removeFromSuperview];
        self.ring = nil;
    }
}

/**
 1.0 = expanded,
 0.0 = collapsed
 */
- (void)expandMissionsByRatio:(float)ratio
{
    // If we have a bunch of orbs, shrink them a bit and spread them further
    BOOL condensed = (self.missions.count > 6);
    float initialTheta = condensed ? 145.0 : 130.0;
    float finalTheta = condensed ? 35.0 : 50.0;
    
    float radius = 148 * ratio;
    
    CGFloat maxSize = condensed ? 0.75 : 1.0;
    CGFloat scale = 0.25 + 0.75 * ratio;
    
    self.ring.center = self.planet.center;
    self.ring.transform = CGAffineTransformMakeScale(scale, scale);
    self.ring.alpha = ratio;
    
    scale = maxSize * scale;
    
    for (int i = 0; i < self.missions.count; i++) {
        CGFloat theta = 0;
        CGFloat thetaGap = 0;
        if (i < self.missions.count / 2) {
            thetaGap = (initialTheta - finalTheta) / (self.missions.count / 2 - 1);
            theta = initialTheta - (i * thetaGap);
        } else {
            thetaGap = (initialTheta - finalTheta) / (ceilf(self.missions.count / 2.0) - 1);
            theta = -initialTheta + ((i - self.missions.count / 2) * thetaGap);
        }
        
        RMMissionToken *orb = self.missions[i];
        orb.center = CGPointMake(self.planet.centerX + radius * cosf(DEG2RAD(theta)), self.planet.centerY - radius * sinf(DEG2RAD(theta)));
        orb.alpha = 0.5 + 0.5 * ratio;
        orb.transform = CGAffineTransformMakeScale(scale, scale);
    }
    
}

#pragma mark - Editing

- (void)addEditing
{
    self.editorVC.view.frame = self.view.bounds;
    [self addChildViewController:self.editorVC];
    [self.view insertSubview:self.editorVC.view belowSubview:self.navigationBar];
}

- (void)removeEditing
{
    if (_editorVC) {
        [self.editorVC.view removeFromSuperview];
        [self.editorVC removeFromParentViewController];
        self.editorVC = nil;
    }
}

#pragma mark - Compiling

- (void)addCompiling
{
    self.compilingVC.view.top = self.view.height;
    [self addChildViewController:self.compilingVC];
    [self.view insertSubview:self.compilingVC.view belowSubview:self.navigationBar];
}

- (void)removeCompiling
{
    if (_compilingVC) {
        [self.compilingVC.view removeFromSuperview];
        [self.compilingVC removeFromParentViewController];
        self.compilingVC = nil;
    }
}

#pragma mark - Debriefing

- (void)addDebriefing
{
    self.debriefingVC.view.bottom = 0;
    [self addChildViewController:self.debriefingVC];
    [self.view insertSubview:self.debriefingVC.view belowSubview:self.navigationBar];
}

- (void)removeDebriefing
{
    if (_debriefingVC) {
        [self.debriefingVC.view removeFromSuperview];
        [self.debriefingVC removeFromParentViewController];
        self.debriefingVC = nil;
    }
}

#pragma mark - RMRomoDelegate

- (UIView *)characterView
{
    return nil;
}

#pragma mark - Private Methods

- (void)layoutTopBar
{
    if (self.subtitle.length) {
        [self.navigationBar addSubview:self.subtitleLabel];
        self.subtitleLabel.center = CGPointMake(self.view.width / 2, subtitleCenterY);
        self.titleLabel.center = CGPointMake(self.view.width / 2, titleCenterY);
    } else {
        self.titleLabel.center = CGPointMake(self.view.width / 2, self.navigationBar.height / 2);
        [self.subtitleLabel removeFromSuperview];
    }
}

- (void)handlePlanetTap:(UITapGestureRecognizer *)tap
{
    RMChapterPlanet *planet = (RMChapterPlanet *)tap.view;
    if (self.state == RMMissionStateChapters) {
        RMChapterStatus status = [self.progressManager statusForChapter:planet.chapter];
        if (status != RMChapterStatusLocked) {
            self.planet = planet;
            self.chapter = planet.chapter;
            
            int missionCountForChapter = [self.progressManager missionCountForChapter:self.chapter];
            if (missionCountForChapter > 0) {
                [RMSoundEffect playForegroundEffectWithName:missionsAppearSound repeats:NO gain:1.0];
                self.state = RMMissionStateMissions;
            } else if (chapterIsComet(self.chapter)) {
                [self presentComet:self.chapter];
            } else {
                [RMSoundEffect playForegroundEffectWithName:editorAppearSound repeats:NO gain:1.0];
                self.index = 0;
                self.state = RMMissionStateEditor;
            }
        }
    } else if (self.state == RMMissionStateMissions && planet == self.planet) {
        self.state = RMMissionStateChapters;
    }
}

- (void)presentComet:(RMChapter)comet
{
    // Enter Challenge Mode if this is the last thing the user unlocked
    RMActivityRobotController *cometRobotController = nil;
    
    switch (comet) {
        case RMCometFavoriteColor: {
            cometRobotController = [[RMFavoriteColorRobotController alloc] init];
            break;
        }
            
        default:
            break;
    }
    
    if (cometRobotController) {
        cometRobotController.delegate = self;
        [(RMAppDelegate *)[UIApplication sharedApplication].delegate pushRobotController:cometRobotController];
    }
}



#ifdef DEBUG
- (void)handlePlanetDoubleTap:(UITapGestureRecognizer *)tap
{
    RMChapterPlanet *planet = (RMChapterPlanet *)tap.view;
    [self.progressManager fastForwardThroughChapter:planet.chapter index:1];
}
#endif

- (void)handleMissionTap:(UITapGestureRecognizer *)tap
{
    if (!self.spaceScene.isAnimating) {
        NSInteger missionIndex = [self.missions indexOfObject:tap.view] + 1;
        if ([self.progressManager statusForMissionInChapter:self.chapter index:missionIndex] != RMMissionStatusLocked) {
            self.index = missionIndex;
            self.state = RMMissionStateEditor;
            [RMSoundEffect playForegroundEffectWithName:editorAppearSound repeats:NO gain:1.0];
        }
    }
}

- (void)handleBackButtonTouch:(UIButton *)backButton
{
    if (!self.spaceScene.isAnimating) {
        [RMSoundEffect playForegroundEffectWithName:backButtonSound repeats:NO gain:1.0];
        switch (self.state) {
            case RMMissionStateCompiling:
                self.state = RMMissionStateEditor;
                break;
                
            case RMMissionStateEditor:
                _mission = nil;
                if (self.chapter == RMChapterTheLab) {
                    [self dismiss];
                } else {
                    self.state = RMMissionStateMissions;
                }
                
                break;
                
            case RMMissionStateMissions:
                self.state = RMMissionStateChapters;
                break;
                
            case RMMissionStateChapters:
                [self dismiss];
                break;
                
            default:
                break;
        }
    }
}

- (void)setTitleToMissionNumber
{
    if (self.chapter == RMChapterTheLab) {
        self.title = NSLocalizedString(@"Lab-Mission-Title", @"The Lab");
    } else {
        self.title = [NSString stringWithFormat:NSLocalizedString(@"Generic-Mission-Title", @"Mission %d-%d"), self.chapter, self.index];
    }
}

- (void)setTitleToMissionName
{
    self.title = self.mission.title;
}

- (void)setSubtitleToMissionNumber
{
    if (self.chapter == RMChapterTheLab) {
        self.subtitle = nil;
    } else {
        self.subtitle = [NSString stringWithFormat:NSLocalizedString(@"Generic-Mission-Title", @"Mission %d-%d"), self.chapter, self.index];
    }
}

- (void)setSubtitleToMissionStatus
{
    RMMissionStatus status = [self.progressManager statusForMissionInChapter:self.chapter index:self.index];
    switch (status) {
        case RMMissionStatusOneStar: self.subtitle = NSLocalizedString(@"Mission-Status-Subtitle-1", @" Best Score: ★☆☆"); break;
        case RMMissionStatusTwoStar: self.subtitle = NSLocalizedString(@"Mission-Status-Subtitle-2", @" Best Score: ★★☆"); break;
        case RMMissionStatusThreeStar: self.subtitle = NSLocalizedString(@"Mission-Status-Subtitle-3", @" Best Score: ★★★"); break;
        default: self.subtitle = [self chapterNumber]; break;
    }
}

- (NSString *)chapterNumber
{
    int chapterIndex = self.chapter % 100;
    NSString *chapterType = nil;
    switch (self.chapter / 100) {
        case 0: chapterType = NSLocalizedString(@"Mission-Chapter-Type-Planet-Title", @"Planet"); break;
        case 1: chapterType = NSLocalizedString(@"Mission-Chapter-Type-Comet-Title", @"Comet"); break;
        case 2: chapterType = NSLocalizedString(@"Mission-Chapter-Type-Bonus-Title", @"Bonus"); break;
        default: break;
    }
    return [NSString stringWithFormat:@"%@ %d", chapterType, chapterIndex];
}

- (void)runMission
{
    [self.mission prepareToRun];
    
    RMRuntimeRobotController *runningVC = [[RMRuntimeRobotController alloc] init];
    runningVC.delegate = self;
    runningVC.mission = self.mission;
    [((RMAppDelegate *)[UIApplication sharedApplication].delegate) pushRobotController:runningVC];
}

- (void)dismiss
{
    RMRobotController *defaultController = ((RMAppDelegate *)[UIApplication sharedApplication].delegate).defaultController;
    ((RMAppDelegate *)[UIApplication sharedApplication].delegate).robotController = defaultController;
}

@end
