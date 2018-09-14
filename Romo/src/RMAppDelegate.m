//
//  RMAppDelegate.m
//  Romo
//

#import "RMAppDelegate.h"
#import <AudioToolbox/AudioToolbox.h>
#import <MediaPlayer/MediaPlayer.h>
#import "UIView+Additions.h"
#import "RMRobotController.h"
#import <CocoaLumberjack/DDASLLogger.h>
#import <CocoaLumberjack/DDTTYLogger.h>
#import <CocoaLumberjack/DDFileLogger.h>
#import <RMShared/RMWebSocketLogger.h>
#import <RMShared/RMLogFormatter.h>
#import <RMShared/UIApplication+Environment.h>
#import "RMProgressRobotController.h"
#import "RMCreatureRobotController.h"
#import "RMRomo.h"
#import "RMInfoRobotController.h"
#import "RMAnalytics.h"
//#import "RMPushNotificationsManager.h"
#import "RMRomoMemory.h"
#import "RMiPadVC.h"
#import "RMSoundEffect.h"
#import <MediaPlayer/MediaPlayer.h>
#import "RMRealtimeAudio.h"
//#import "RMTelepresencePresence.h"

#ifdef UNLOCK_EVERYTHING
#import "RMProgressManager.h"
#endif

#ifdef SIMULATOR
#import <RMVision/RMVision.h>
#endif
@interface RMAppDelegate ()

@property (nonatomic, strong) RMRomo *Romo;

@property (nonatomic, strong) NSMutableArray *robotControllers;
@property (nonatomic, readwrite, strong) RMRobotController *defaultController;

@property (nonatomic, getter=isTransitioningRobotControllers) BOOL transitioningRobotControllers;
@property (nonatomic, strong) RMRobotController *queuedRobotController;

@property (nonatomic, strong) DDFileLogger *fileLogger;
@property (nonatomic, strong) RMAnalytics *analytics;

@end

void uncaughtExceptionHandler(NSException *exception) {
    NSLog(@"CRASH: %@", exception);
    NSLog(@"Stack Trace: %@", [exception callStackSymbols]);
}

@implementation RMAppDelegate

DDLOG_ENABLE_DYNAMIC_LEVELS

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
#ifdef DEBUG
    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
#endif
    
    [self loadEnvironmentVariables];
    [self loadLumberjackLogger];
    DDLogVerbose(@"Application Boot");
    [self loadAnalyticsAndReporting];
    [self loadPreferences];
    
    self.Romo = [[RMRomo alloc] init];
    [[RMRealtimeAudio sharedInstance] startup];
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    if (!iPad) {
        self.window.rootViewController = [[UIViewController alloc] init];
        [self.window makeKeyAndVisible];

        self.robotControllers = [NSMutableArray arrayWithCapacity:2];
        self.defaultController = [[RMProgressRobotController alloc] init];
        self.robotController = self.defaultController;

        // trick to prevent iOS from showing the volume alert bezel
        MPVolumeView *volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(0, 0, -1000, -1000)];
        volumeView.clipsToBounds = YES;
        [self.window.rootViewController.view addSubview:volumeView];
    } else {
        self.window.rootViewController = [[RMiPadVC alloc] init];
        [self.window makeKeyAndVisible];
    }
    
#ifdef SOUND_DEBUG
    [MPMusicPlayerController applicationMusicPlayer].volume = 1.0;
#endif
    
#ifdef SIMULATOR
    // add in a button to fake a facedetect, seeing as there are no cameras
    UIButton *fakeFace = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    fakeFace.accessibilityLabel = @"fake face";
    fakeFace.bounds = CGRectMake(0, 0, 1, 1);
    [fakeFace addTarget:self action:@selector(fakeFace) forControlEvents:UIControlEventTouchUpInside];
    [self.window addSubview:fakeFace];
#endif
    
#ifdef UNLOCK_EVERYTHING
    // Check to see if we have already unlocked everything
    // If we have, then don't do it again until the app is reinstalled
    // Saving the user from having to go through the end interaction script
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"all unlocked"]) {
        [[RMProgressManager sharedInstance] fastForwardThroughChapter:RMChapterTheEnd index:0];
        [[NSUserDefaults standardUserDefaults] setObject:@(1) forKey:@"all unlocked"];
    }
#endif
    
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [[RMRomoMemory sharedInstance] saveMemory];
}

#pragma mark - Public Properties

- (void)setRobotController:(RMRobotController *)robotController
{
    if (robotController && robotController != _robotController && !self.isTransitioningRobotControllers) {
        self.transitioningRobotControllers = YES;
        
        BOOL currentControllerShowsRomo = isFunctionalityActive(RMRomoFunctionalityCharacter, self.Romo.activeFunctionalities);
        BOOL newControllerShowsRomo = isFunctionalityActive(RMRomoFunctionalityCharacter, robotController.initiallyActiveFunctionalities);

        BOOL isVisionCurrentlyActive = isFunctionalityActive(RMRomoFunctionalityVision, self.Romo.activeFunctionalities);
        BOOL newControllerUsesVision = isFunctionalityActive(RMRomoFunctionalityVision, robotController.initiallyActiveFunctionalities);

        NSSet *currentVisionModules = nil;
        if (isVisionCurrentlyActive) {
            NSMutableSet *currentModuleNames = [NSMutableSet setWithCapacity:self.Romo.vision.activeModules.count];
            [self.Romo.vision.activeModules enumerateObjectsUsingBlock:^(id<RMVisionModuleProtocol> module, BOOL *stop) {
                [currentModuleNames addObject:module.name];
            }];
            currentVisionModules = [currentModuleNames copy];
        }
        
        if (currentControllerShowsRomo) {
            [self.Romo.voice dismissImmediately];
        }
        
        __block void (^beforeAnimation)() = nil;
        UIViewAnimationOptions animationOptions = 0;
        __block void (^animation)() = nil;
        __block void (^completion)(BOOL finished) = ^(BOOL finished){
            [_robotController.view removeFromSuperview];
            [_robotController removeFromParentViewController];
            _robotController.view.top = 0.0;
            
            RMRobotController *oldRobotController = _robotController;
            _robotController = robotController;
            
            self.Romo.delegate = robotController;
            self.Romo.activeFunctionalities = robotController.initiallyActiveFunctionalities;
            self.Romo.allowedInterruptions = robotController.initiallyAllowedInterruptions;
            self.Romo.romotions.intensity = 0.0;
            
            // Switch to desired vision modules by removing only what needs to be removed
            if (newControllerUsesVision) {
                NSSet *desiredVisionModules = robotController.initiallyActiveVisionModules;
                
                // Remove all active modules that we don't want
                NSMutableSet *removedVisionModules = [NSMutableSet setWithSet:currentVisionModules];
                [removedVisionModules minusSet:desiredVisionModules];
                [removedVisionModules enumerateObjectsUsingBlock:^(NSString *moduleKey, BOOL *stop) {
                    [self.Romo.vision deactivateModuleWithName:moduleKey];
                }];
                
                // Then add in new modules
                NSMutableSet *addedVisionModules = [NSMutableSet setWithSet:desiredVisionModules];
                [addedVisionModules minusSet:currentVisionModules];
                [addedVisionModules enumerateObjectsUsingBlock:^(NSString *moduleKey, BOOL *stop) {
                    [self.Romo.vision activateModuleWithName:moduleKey];
                }];
            }
            
            [oldRobotController controllerDidResignActive];
            [robotController controllerDidBecomeActive];
            
            self.transitioningRobotControllers = NO;
            [self checkForQueuedRobotController];
        };
        
        if (_robotController) {
            if (currentControllerShowsRomo && !newControllerShowsRomo) {
                // dismiss Romo
                beforeAnimation = ^{
                    [self.window.rootViewController.view insertSubview:robotController.view belowSubview:_robotController.view];
                };
                animationOptions = UIViewAnimationOptionCurveEaseIn;
                animation = ^{
                    _robotController.view.top = self.window.rootViewController.view.height;
                };
            } else if (!currentControllerShowsRomo && newControllerShowsRomo) {
                // present Romo
                beforeAnimation = ^{
                    self.Romo.delegate = robotController;
                    self.Romo.activeFunctionalities = robotController.initiallyActiveFunctionalities;
                    robotController.view.top = self.window.rootViewController.view.height;
                    [self.window.rootViewController.view insertSubview:robotController.view aboveSubview:_robotController.view];
                };
                animationOptions = UIViewAnimationOptionCurveEaseOut;
                animation = ^{
                    robotController.view.top = 0;
                };
            }
        }
        
        [_robotController controllerWillResignActive];
        [robotController controllerWillBecomeActive];
        
        _robotController.Romo = nil;
        robotController.Romo = self.Romo;
        
        [self.window.rootViewController addChildViewController:robotController];
        [self.window.rootViewController.view addSubview:robotController.view];
        
        if (beforeAnimation) {
            beforeAnimation();
        }
        if (animation) {
            [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
            [UIView animateWithDuration:0.25 delay:0.0 options:animationOptions animations:animation
                             completion:^(BOOL finished) {
                                 if (completion) {
                                     completion(finished);
                                 }
                                 [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                             }];
        } else if (completion) {
            completion(YES);
        }
        
    } else if (self.isTransitioningRobotControllers) {
        self.queuedRobotController = robotController;
    }
}

- (void)checkForQueuedRobotController
{
    if (self.queuedRobotController) {
        RMRobotController *queuedRobotController = self.queuedRobotController;
        self.queuedRobotController = nil;
        self.robotController = queuedRobotController;
    }
}

- (void)pushRobotController:(RMRobotController *)robotController
{
    [self.robotControllers addObject:self.robotController];
    [self setRobotController:robotController];
}

- (void)popRobotController
{
    if (self.robotControllers.count > 0) {
        RMRobotController *previousRobotController = self.robotControllers.lastObject;
        [self.robotControllers removeLastObject];
        [self setRobotController:previousRobotController];
    }
}

#ifdef SIMULATOR
- (void)fakeFace
{
    // Simulator doesn't have a camera, so we can call this method to pretend we
    // saw a face.
    // XXX if there's a way for to trigger -didDetectFace from an arbitrary
    //     location, or if it can be done as a notification, that would be better
    RMCreatureRobotController <RMVisionDelegate> *rc;
    rc = (RMCreatureRobotController <RMVisionDelegate> *)self.robotController;
    if ([rc respondsToSelector:@selector(didDetectFace:)]) {
        [rc didDetectFace:nil];
    }
}
#endif

#pragma mark - Initialization

- (void)loadEnvironmentVariables
{
    [UIApplication setEnvironmentVariableDefaultValue:@"romotive-telepresence.herokuapp.com"
                                               forKey:@"ROMO_TELEPRESENCE_SERVER"];
    [UIApplication setEnvironmentVariableDefaultValue:@"wss"
                                               forKey:@"ROMO_TELEPRESENCE_WS_PROTOCOL"];
    [UIApplication setEnvironmentVariableDefaultValue:nil
                                               forKey:@"ROMO_LOG_SERVER"];
    [UIApplication setEnvironmentVariableDefaultValue:@"NO"
                                               forKey:@"XcodeColors"];
}

- (void)loadPreferences
{
    // Load sound effects preference
    NSNumber *soundEffectPreference = [[NSUserDefaults standardUserDefaults] objectForKey:soundEffectsEnabledKey];
    if (!soundEffectPreference) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:soundEffectsEnabledKey];
    }
}

- (void)loadAnalyticsAndReporting
{    
    self.analytics = [RMAnalytics sharedInstance];
    
}

#pragma mark - Logger

- (void)loadLumberjackLogger
{
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    [[DDASLLogger sharedInstance] setLogFormatter:[[RMLogFormatter alloc] init]];
    
#ifdef DEBUG
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [[DDTTYLogger sharedInstance] setLogFormatter:[[RMLogFormatter alloc] initWithColors:YES]];
    
    if ([UIApplication environmentVariableWithKey:@"ROMO_LOG_SERVER"]) {
        [DDLog addLogger:[RMWebSocketLogger sharedInstance]];
    }
#endif
    
    self.fileLogger = [[DDFileLogger alloc] init];
    self.fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
    self.fileLogger.logFileManager.maximumNumberOfLogFiles = 2;
    self.fileLogger.maximumFileSize = 1024 * 128; // 128kb
    [DDLog addLogger:self.fileLogger];
}

#pragma mark - Telepresence

- (void)fetchTelepresenceNumberAndConnect
{
    
}

#pragma mark - Application States

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
    return [self application:application openURL:url sourceApplication:nil annotation:nil];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    if ([[url scheme] isEqualToString:@"romo"]) {
        return YES;
    }
    return NO;
}

//#pragma mark - Application Push Notifications
//
//- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
//{
//    [[RMPushNotificationsManager sharedInstance] setDeviceToken:deviceToken];
//}
//
//- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
//{
//    [[RMPushNotificationsManager sharedInstance] handlePush:userInfo];
//}


@end
