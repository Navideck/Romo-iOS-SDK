//
//  RMAnalytics.h
//  Romo
//
//  Created on 8/19/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RMAnalytics : NSObject

/**
 Singleton for manual tracking if necessary
 */
+ (RMAnalytics *)sharedInstance;

/**
 Tracks a specific event manually, for events not handled by observing notifications
 */
- (void)track:(NSString *)event;
- (void)track:(NSString *)event properties:(NSDictionary *)properties;


@end
