//
//  RMProgressRobotController.m
//  Romo
//

#import "RMProgressRobotController.h"

#import "RMProgressManager.h"
#import "RMAppDelegate.h"
#import "RMCutscene.h"
#import "RMMission.h"
#import "RMUnlockable.h"
#import "RMDockingRequiredVC.h"
#import "RMInteractionScriptRuntime.h"
#import "RMChapterPlanet.h"

#import "RMCreatureRobotController.h"
#import "RMJuvenileCreatureRobotController.h"
#import "RMMatureCreatureRobotController.h"

#import "UIView+Additions.h"

@interface RMProgressRobotController () <RMDockingRequiredVCDelegate>

/** Chapter progression, missions, & cutscenes */
@property (nonatomic, strong) RMProgressManager *progressManager;
@property (nonatomic, strong) RMCutscene *cutscene;

@end

@implementation RMProgressRobotController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.progressManager = [RMProgressManager sharedInstance];
}

- (void)controllerDidBecomeActive
{
    [super controllerDidBecomeActive];
    
    [self transitionToNextTask];
}

- (RMRomoFunctionalities)initiallyActiveFunctionalities
{
    return RMRomoFunctionalityCharacter;
}

- (RMRomoInterruptions)initiallyAllowedInterruptions
{
    return RMRomoInterruptionNone;
}

#pragma mark - Chapter Transitioning

/**
 General task-flow for a chapter:
 1 - Chapter cutscene (-presentCutsceneForChapter:)
 2 - Chapter introduction (-presentIntroductionForChapter:)
 3 - Chapter mission(s) (Wait for user interaction)
 */
- (void)transitionToNextTask
{
    // The user is playing with the newest chapter here
    RMChapter chapter = self.progressManager.newestChapter;
    self.progressManager.currentChapter = chapter;
    
    RMChapterStatus chapterStatus = [self.progressManager statusForChapter:chapter];
    switch (chapterStatus) {
        case RMChapterStatusNew:
            if ([self.progressManager chapterHasCutscene:chapter]) {
                [self presentCutsceneForChapter:chapter];
            } else {
                [self.progressManager setStatus:RMChapterStatusSeenCutscene forChapter:chapter];
                [self transitionToNextTask];
            }
            break;
            
        case RMChapterStatusSeenCutscene:
        case RMChapterStatusSeenUnlock:
            [self.progressManager setStatus:RMMissionStatusNew forMissionInChapter:chapter index:1];
            [self presentCreatureControllerForChapter:chapter];
            break;
            
        default:
            break;
    }
}

/**
 Fades through black into the cutscene movie
 */
- (void)presentCutsceneForChapter:(RMChapter)chapter
{
    UIView *blackShade = nil;
    
    __weak RMProgressRobotController *weakSelf = self;
    void (^completion)(BOOL finished) = ^(BOOL finished){
        [blackShade removeFromSuperview];
        [self.Romo.character removeFromSuperview];
        
        self.cutscene.robot = self.Romo.robot;
        [self.cutscene playCutscene:chapter inView:self.view
                         completion:^(BOOL finished) {
                             weakSelf.cutscene = nil;
                             
                             [weakSelf.Romo.character addToSuperview:weakSelf.characterView];
                             [weakSelf.progressManager setStatus:RMChapterStatusSeenCutscene forChapter:chapter];
                             if (chapter == RMChapterOne || chapter == RMChapterThree) {
                                 // These chapters are a bit backward: we see the unlock first, then the cutscene
                                 // So when we're done with the cutscene, then indicate that we've also seen the unlock
                                 [weakSelf.progressManager setStatus:RMChapterStatusSeenUnlock forChapter:chapter];
                             }
                             [weakSelf transitionToNextTask];
                         }];
    };
    
    if (chapter == RMChapterOne) {
        blackShade = [[UIView alloc] initWithFrame:self.view.bounds];
        blackShade.backgroundColor = [UIColor blackColor];
        blackShade.alpha = 0.0;
        [self.view addSubview:blackShade];
        [UIView animateWithDuration:1.25 delay:1.25 options:0
                         animations:^{
                             blackShade.alpha = 1.0;
                         } completion:completion];
    } else {
        completion(YES);
    }
}

/**
 Transitions to the Creature Robot controller, which waits for user input
 */
- (void)presentCreatureControllerForChapter:(RMChapter)chapter
{
    RMCreatureRobotController *creatureController;
    switch (chapter) {
        case RMChapterOne:
            creatureController = [[RMJuvenileCreatureRobotController alloc] init];
            break;
        case RMChapterTwo:
            creatureController = [[RMMatureCreatureRobotController alloc] init];
            break;
        default:
            creatureController = [[RMMatureCreatureRobotController alloc] init];
            break;
    }
    ((RMAppDelegate *)[UIApplication sharedApplication].delegate).robotController = creatureController;
}

/**
 Called when a robot is needed but not connected.
 Shows an option to purchase a Romo if we've never docked before.
 */
- (void)presentDockingRequiredVCForChapter:(RMChapter)chapter
{
    RMDockingRequiredVC *dockingRequiredVC = [[RMDockingRequiredVC alloc] init];
    dockingRequiredVC.delegate = self;
    dockingRequiredVC.showsPurchaseButton = (chapter == 1);
    dockingRequiredVC.showsDismissButton = NO;
    [self presentViewController:dockingRequiredVC animated:YES completion:nil];
}

#pragma mark - RMDockingRequiredVCDelegate

- (void)dockingRequiredVCDidDismiss:(RMDockingRequiredVC *)dockingRequiredVC
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dockingRequiredVCDidDock:(RMDockingRequiredVC *)dockingRequiredVC
{
    [self dismissViewControllerAnimated:YES completion:nil];
    [self transitionToNextTask];
}

#pragma mark - RMCoreDelegate

- (void)robotDidConnect:(RMCoreRobot *)robot
{
    _cutscene.robot = (RMCoreRobotRomo3 *)robot;
}

- (void)robotDidDisconnect:(RMCoreRobot *)robot
{
    _cutscene.robot = nil;
}

#pragma mark - Private Properties

- (RMCutscene *)cutscene
{
    if (!_cutscene) {
        _cutscene = [[RMCutscene alloc] init];
    }
    return _cutscene;
}

@end
