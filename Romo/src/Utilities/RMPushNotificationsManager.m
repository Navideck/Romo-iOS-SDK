//
//  RMPushNotificationsManager.m
//  Romo
//
//  Created on 8/21/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMPushNotificationsManager.h"
#import "Analytics/Analytics.h"
#import "RMAppDelegate.h"
#import "RMRobotController.h"

@interface RMPushNotificationsManager()

@end

@implementation RMPushNotificationsManager

+ (RMPushNotificationsManager *)sharedInstance
{
    static RMPushNotificationsManager *sharedInstance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[RMPushNotificationsManager alloc] init];
    });
    
    return sharedInstance;
}

- (void)setDeviceToken:(NSData *)deviceToken
{
    // Update Mixpanel (our push notification server)
    [[Analytics sharedAnalytics] registerPushDeviceToken:deviceToken];
}

#pragma mark - Push notification handler

- (void)handlePush:(NSDictionary *)userInfo
{
    NSString *notificationStyle = [userInfo objectForKey:@"style"];
    NSString *message = [[userInfo objectForKey:@"aps"] objectForKey:@"alert"];
    
    RMAppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
    
    if ([notificationStyle isEqualToString:@"Alertview"]) {
        // Alertview
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@""
                                                            message:message
                                                           delegate:nil
                                                  cancelButtonTitle:@"Okay"
                                                  otherButtonTitles: nil];
        [alertView show];
    }  else {
        // Use the voice capabilities of Romo by default
        [appDelegate.robotController.Romo.voice say:message withStyle:RMVoiceStyleSSS autoDismiss:NO];
    }
}



@end
