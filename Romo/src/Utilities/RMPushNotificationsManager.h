//
//  RMPushNotificationsManager.h
//  Romo
//
//  Created on 8/21/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface RMPushNotificationsManager : NSObject

+ (RMPushNotificationsManager *)sharedInstance;

/**
 Saves the device token from Apple to the push notificiation server
 */
- (void)setDeviceToken:(NSData *)deviceToken;

/**
 Handles a remote push notification while app is active
 */
- (void)handlePush:(NSDictionary *)userInfo;

@end
