//
//  RMAnalytics.m
//  Romo
//
//  Created on 8/19/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMAnalytics.h"
#import <Romo/RMCore.h>
//#import <Analytics/Analytics.h>
#import <Romo/UIDevice+UDID.h>
#import "RMAppDelegate.h"
#import "RMProgressManager.h"
#import "RMRomoMemory.h"

#ifndef ROMO_CONTROL_APP
#import "RMRobotController.h"
#endif

@interface RMAnalytics()

@property (nonatomic, strong) NSString *uniqueDeviceId;
@property (nonatomic, strong) NSDate *appActiveStartTime;
@property (nonatomic, strong) NSDate *robotControllerActiveStartTime;
@property (nonatomic, strong) NSDate *wifiDriveRobotControllerSessionStartTime;
@property (nonatomic, strong) NSDate *telepresenceRobotControllerSessionStartTime;
@property (nonatomic, strong) NSDate *robotDockedStartTime;

@property (nonatomic) BOOL isFirstTime;

- (void)setupAnalytics;
- (void)setupObservers;

@end

@implementation RMAnalytics

#pragma mark -- Init --

+ (RMAnalytics *)sharedInstance
{
    static RMAnalytics *sharedInstance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[RMAnalytics alloc] init];
    });
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self setupAnalytics];
        [self setupObservers];
    }
    return self;
}

- (void)setupAnalytics
{

#define APP_STORE_RELEASE
#ifdef APP_STORE_RELEASE

//#ifdef ROMO_CONTROL_APP
//    // The Romo Control App
//    [Analytics initializeWithSecret:@"ednxl8q121"];
//#else
//    // The ROMO App
//    [Analytics initializeWithSecret:@"pbokuwcgig"]; // 3.0+ key
//#endif

#else
    
#ifdef ANALYTICS_DEVELOPMENT
    [Analytics initializeWithSecret:@"ia6er0p2mz"]; // Use for development
    [[Analytics sharedAnalytics] reset]; 
    [[Analytics sharedAnalytics] debug:YES]; // set to YES to get the noisy logs
#else
    [Analytics initializeWithSecret:@"e0qhkj682d"]; // Use for testing
#endif
    
#endif
    
    [self track:@"App: Start"];
    
    // UIApplicationWillEnterForegroundNotification does not get called on the first launch of the app,
    // so to make sure we have a date, set it here
    self.appActiveStartTime = [NSDate date];
    
    // Determine whether this if a first time for this user
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"romo-3 date installed"]) {
        self.isFirstTime = YES;
        [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"romo-3 date installed"];
        NSString *firstStartDate = [self formattedStringForDate:[NSDate date]];
        [self track:@"App: First Start" properties:@{@"Date": firstStartDate}];
    }
    
    // Generate a unique hash to identify the current user
    self.uniqueDeviceId = [UIDevice currentDevice].UDID;
    
    // Only identify the user if the user is using a dockable device
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
        // Associate this play session to a unique id to identify this user
        // Update the user info with date first started,
        // everytime the app starts so that we don't lose this info for older users who have updated
//        [[Analytics sharedAnalytics] identify:self.uniqueDeviceId
//                                       traits:@{@"First Start Date": [[NSUserDefaults standardUserDefaults] objectForKey:@"romo-3 date installed"] }];
    }
}

- (void)setupObservers
{
    // App level notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAppNotifications:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAppNotifications:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    // Handle alert view responses notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAlertviewResponseNotification:)
                                                 name:@"RMRateAppResponseNotification"
                                               object:nil];
#ifndef ROMO_CONTROL_APP
    // Robot controller level notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRobotControllerNotifications:)
                                                 name:RMRobotControllerDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRobotControllerNotifications:)
                                                 name:RMRobotControllerDidResignActiveNotification
                                               object:nil];
    // Robot level notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRobotNotifications:)
                                                 name:RMCoreRobotDidConnectNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRobotNotifications:)
                                                 name:RMCoreRobotDidDisconnectNotification
                                               object:nil];
    // Wi-Fi Drive Robot Controller notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleWiFiDriveRobotControllerNotifications:)
                                                 name:@"RMWiFiDriveRobotControllerSessionDidStart"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleWiFiDriveRobotControllerNotifications:)
                                                 name:@"RMWiFiDriveRobotControllerSessionDidEnd"
                                               object:nil];
    
    // Telepresence Robot Controller notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleTelepresenceRobotControllerNotifications:)
                                                 name:@"RMTelepresenceRobotControllerSessionDidStart"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleTelepresenceRobotControllerNotifications:)
                                                 name:@"RMTelepresenceRobotControllerSessionDidEnd"
                                               object:nil];
    
    // RMVoice notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRMVoiceNotifications:)
                                                 name:@"RMVoiceUserDidSelectionOptionNotification"
                                               object:nil];
#endif

}

#pragma mark -- Notification Handlers --
// Log events for App Level notifications
//------------------------------------------------------------------------------
- (void)handleAppNotifications:(NSNotification *)notification
{
    if (notification.name == UIApplicationWillEnterForegroundNotification) {
        self.appActiveStartTime = [NSDate date];
        
    } else if (notification.name == UIApplicationDidEnterBackgroundNotification) {
        // Calculate the time elapsed since app active
        NSTimeInterval elapsedAppPlaytime = [[NSDate date] timeIntervalSinceDate:self.appActiveStartTime];
        [self track:@"App: End" properties:@{@"duration": @(elapsedAppPlaytime), @"FirstTime": @(self.isFirstTime)}];
        
#ifndef ROMO_CONTROL_APP
        
        [self logMissionsProgress];

//        // Log the odometer, user name, and Romo name, and total docked time
//        NSString *romoName = [[RMRomoMemory sharedInstance] knowledgeForKey:@"romoName"];
//        NSString *userName = [[RMRomoMemory sharedInstance] knowledgeForKey:@"userName"];
//
//        // Retrieve the total docked time
//        NSNumber *totalDockedPlaytime = [[NSUserDefaults standardUserDefaults] objectForKey:@"romo-3 total-docked-playtime"];
//        NSNumber *dockedCount = [[NSUserDefaults standardUserDefaults] objectForKey:@"romo-3 total-docked-count"];
//
//        // Retrieve the total wifi drive time
//        NSNumber *totalWiFiDriveSessions = [[NSUserDefaults standardUserDefaults] objectForKey:@"romo-3 total-wifi-drive-count"];
//        NSNumber *totalWiFiDriveTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"romo-3 total-wifi-drive-playtime"];
//
//        // Retrieve the total telepresence time
//        NSNumber *totalTelepresenceSessions = [[NSUserDefaults standardUserDefaults] objectForKey:@"romo-3 total-telepresence-count"];
//        NSNumber *totalTelepresenceTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"romo-3 total-telepresence-playtime"];
//
//        RMAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];

//        [[Analytics sharedAnalytics] identify:self.uniqueDeviceId
//                                       traits:@{@"Odometer": @(appDelegate.robotController.Romo.vitals.odometer),
//                                                @"RomoName": romoName ? romoName : @"nil",
//                                                @"name": userName ? userName : @"nil",
//                                                @"Docked Time": totalDockedPlaytime ? totalDockedPlaytime : @(0),
//                                                @"Docked Count": dockedCount ? dockedCount : @(0),
//                                                @"Wi-Fi Drive Playtime": totalWiFiDriveTime ? totalWiFiDriveTime : @(0),
//                                                @"Wi-Fi Drive Sessions": totalWiFiDriveSessions ? totalWiFiDriveSessions : @(0),
//                                                @"Telepresence Playtime": totalTelepresenceTime ? totalTelepresenceTime : @(0),
//                                                @"Telepresence Sessions": totalTelepresenceSessions ? totalTelepresenceSessions : @(0) }];
#endif
    }
}

#ifndef ROMO_CONTROL_APP

// Log events for Robot Controller Level notifications
//------------------------------------------------------------------------------
- (void)handleRobotControllerNotifications:(NSNotification *)notification
{
    RMRobotController *robotController = notification.object;
    
    if (notification.name == RMRobotControllerDidBecomeActiveNotification) {
        self.robotControllerActiveStartTime = [NSDate date];
        
        // Mute the did become active
        // [self track:[NSString stringWithFormat:@"%@: active",robotController.class]
        // properties:@{ @"docked" : @(robotController.Romo.robot != nil) }];
        
    } else if (notification.name == RMRobotControllerDidResignActiveNotification) {
        // Calculate the time elapsed since controller was active
        NSTimeInterval elapsedRobotControllerActiveTime = [[NSDate date] timeIntervalSinceDate:self.robotControllerActiveStartTime];
        
        NSString *robotControllerClassName = NSStringFromClass(robotController.class);
        
        if (![robotControllerClassName isEqualToString:@"RMJuvenileCreatureRobotController"] &&
            ![robotControllerClassName isEqualToString:@"RMMatureCreatureRobotController"] &&
            ![robotControllerClassName isEqualToString:@"RMCharacterUnlockedRobotController"] &&
            ![robotControllerClassName isEqualToString:@"RMProgressRobotController"] &&
            ![robotControllerClassName isEqualToString:@"RMRuntimeRobotController"]) {
            
            [self track:[NSString stringWithFormat:@"%@: resigned active",robotController.class]
             properties:@{ @"duration" : @(elapsedRobotControllerActiveTime), @"docked" : @(robotController.Romo.robot != nil) }];
        }
    }
}

// Log events for Wifi Drive Robot Controller Level notifications
//------------------------------------------------------------------------------
- (void)handleWiFiDriveRobotControllerNotifications:(NSNotification *)notification
{
    if ([notification.name isEqualToString:@"RMWiFiDriveRobotControllerSessionDidStart"]) {
        self.wifiDriveRobotControllerSessionStartTime = [NSDate date];
//        [self track:@"WiFiDriveRobot: Drive Session Start"];
        
        [self incrementStoredValueBy:1 forKey:@"romo-3 total-wifi-drive-count"];
        
    } else if([notification.name isEqualToString:@"RMWiFiDriveRobotControllerSessionDidEnd"]) {
        // Calculate the time elapsed since start event
        NSTimeInterval elapsedWifiDriveSessionTime = [[NSDate date] timeIntervalSinceDate:self.wifiDriveRobotControllerSessionStartTime];
        [self track:@"WiFiDriveRobot: Drive Session End" properties:@{@"duration":@(elapsedWifiDriveSessionTime)}];
        
        [self incrementStoredValueBy:(int)floor(elapsedWifiDriveSessionTime) forKey:@"romo-3 total-wifi-drive-playtime"];
    }
}

// Log events for Telepresence Drive Robot Controller Level notifications
//------------------------------------------------------------------------------
- (void)handleTelepresenceRobotControllerNotifications:(NSNotification *)notification
{
    if ([notification.name isEqualToString:@"RMTelepresenceRobotControllerSessionDidStart"]) {
        self.telepresenceRobotControllerSessionStartTime = [NSDate date];
//        [self track:@"Telepresence Robot: Session Start"];
        
        [self incrementStoredValueBy:1 forKey:@"romo-3 total-telepresence-count"];
        
    } else if([notification.name isEqualToString:@"RMTelepresenceRobotControllerSessionDidEnd"]) {
        // Calculate the time elapsed since start event
        NSTimeInterval elapsedSessionTime = [[NSDate date] timeIntervalSinceDate:self.telepresenceRobotControllerSessionStartTime];
        [self track:@"Telepresence Robot: Session End" properties:@{@"duration":@(elapsedSessionTime)}];
        
        [self incrementStoredValueBy:(int)floor(elapsedSessionTime) forKey:@"romo-3 total-telepresence-playtime"];
    }
}

// Log events for RMVoice notifications
//------------------------------------------------------------------------------
- (void)handleRMVoiceNotifications:(NSNotification *)notification
{
    if ([notification.name isEqualToString:@"RMVoiceUserDidSelectionOptionNotification"]) {
//        [[Analytics sharedAnalytics] track:@"Voice: Option Selected" properties:notification.userInfo];
    }
}

// Log events for Robot Level notifications
//------------------------------------------------------------------------------
- (void)handleRobotNotifications:(NSNotification *)notification
{
    RMCoreRobot *robot = notification.object;
    RMCoreRobotIdentification *rid = robot.identification;
    
    if (notification.name == RMCoreRobotDidConnectNotification) {
        self.robotDockedStartTime = [NSDate date];
        [self track:@"Robot: docked"
         properties:@{@"RobotName": rid.name ? rid.name : @"-",
                      @"RobotModel": rid.modelNumber ? rid.modelNumber : @"-",
                      @"RobotFirmwareVersion": rid.firmwareVersion ? rid.firmwareVersion : @"-",
                      @"RobotHWVersion": rid.hardwareVersion ? rid.hardwareVersion : @"-",
                      @"RobotSerial": rid.serialNumber ? rid.serialNumber : @"-",
                      @"RobotBatteryLevel": @(robot.vitals.batteryLevel) }];
        
        // Determine whether this if a first time docked
        if (![[NSUserDefaults standardUserDefaults] objectForKey:@"romo-3 date first-docked"]) {
            [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"romo-3 date first-docked"];
            
            NSString *firstDockedDate = [self formattedStringForDate:[NSDate date]];
            [self track:@"Robot: First Docked" properties:@{@"Date": firstDockedDate}];
        }
        
        // Increase the number of docked instances by 1
        [self incrementStoredValueBy:1 forKey:@"romo-3 total-docked-count"];

    } else if (notification.name == RMCoreRobotDidDisconnectNotification) {
        // Calculate the time elapsed since docked event
        NSTimeInterval elapsedRobotDockedTime = [[NSDate date] timeIntervalSinceDate:self.robotDockedStartTime];
        [self track:@"Robot: undocked"
         properties:@{@"RobotSerial": rid.serialNumber.length ? rid.serialNumber : @"-",
                      @"duration" : @(elapsedRobotDockedTime) }];
        
        // Add the docked time to the running total docked time
        [self incrementStoredValueBy:(int)floor(elapsedRobotDockedTime) forKey:@"romo-3 total-docked-playtime"];
    }
}

// Read from the stored progress values in NSUserDefaults
// Updates the analytics user properties to reflect their progress
// Log event to update user progress as a safety measure
//------------------------------------------------------------------------------
- (void)logMissionsProgress
{
    NSMutableDictionary *chaptersProgress = [[NSMutableDictionary alloc] initWithCapacity:50];
    NSArray *unlockedChapters = [RMProgressManager sharedInstance].unlockedChapters;
    
    for (NSNumber *chapterValue in unlockedChapters) {
        RMChapter chapter = chapterValue.intValue;
        
        NSNumber *chapterPlayTime = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:chapterPlaytimeKey,chapter]];
        if (chapterPlayTime) {
            [chaptersProgress setObject:@(floor(chapterPlayTime.intValue)) forKey:[NSString stringWithFormat:@"Chapter %i Playtime",chapter]];
        }
                
        // Tally the stars and completed missions for a chapter
        int totalStarCount = 0;
        
        if (chapter < 100) {
            // Only set the completed missions for activities with missions
            int successfulMissionCount = [[RMProgressManager sharedInstance] successfulMissionCountForChapter:chapter];
            [chaptersProgress setObject:@(successfulMissionCount) forKey:[NSString stringWithFormat:@"Chapter %i Completed Missions",chapter]];
            // Get the number of stars that a user has completed inside a chapter
            totalStarCount = [[RMProgressManager sharedInstance] starCountForChapter:chapter];
        } else {
            // If the chapter does not have starcount, use the percent complete
            totalStarCount = [[RMProgressManager sharedInstance] percentCompleteForChapter:chapter];
        }
        [chaptersProgress setObject:@(totalStarCount) forKey:[NSString stringWithFormat:@"Chapter %i Star Count",chapter]];
    }
    
//    // Update the user's traits
//    [[Analytics sharedAnalytics] identify:self.uniqueDeviceId traits:chaptersProgress];

    // Add identifiers to event for tying the play times back the user
    [chaptersProgress setObject:self.uniqueDeviceId forKey:@"userId"];
    
    // Logs event with user play times
//    [self track:@"Updated User Progress" properties:chaptersProgress];

}

#endif // END Check if this is not Romo Control App

// Log events for Rate this app alert notifications
//------------------------------------------------------------------------------
- (void)handleAlertviewResponseNotification:(NSNotification *)notification
{
    if ([notification.name isEqualToString:@"RMRateAppResponseNotification"]) {
//        [[Analytics sharedAnalytics] track:@"Rate App Response" properties:notification.userInfo];
    }
}


#pragma mark -- Private Methods --

// Formatted string for date
//------------------------------------------------------------------------------
- (NSString *)formattedStringForDate:(NSDate *)date
{
    NSDateFormatter *dateToUTCString = [[NSDateFormatter alloc] init];
    dateToUTCString.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS";
    dateToUTCString.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    dateToUTCString.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    NSString *formattedString = [dateToUTCString stringFromDate:date];
    
    return formattedString;
}

// Helper method to increment a stored integer value for a key
//------------------------------------------------------------------------------
- (void)incrementStoredValueBy:(int)increment forKey:(NSString *)key
{
    NSNumber *storedValue = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (!storedValue) {
        storedValue = @(0);
    }
    int newValue = [storedValue intValue] + increment;
    
    [[NSUserDefaults standardUserDefaults] setObject:@(newValue) forKey:key];
}

#pragma mark -- Public Methods --
// Allows outside objects to log manual events without worrying about the ...
// analtyics backend
//------------------------------------------------------------------------------
- (void)track:(NSString *)event
{
//    [[Analytics sharedAnalytics] track:event];
}

- (void)track:(NSString *)event properties:(NSDictionary *)properties
{
//    [[Analytics sharedAnalytics] track:event properties:properties];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


@end
