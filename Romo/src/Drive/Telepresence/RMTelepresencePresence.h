//
//  RMTelepresence2Presence.h
//  Romo
//
//  Created on 11/5/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^RMTelepresence2PresenceFetchNumberCompletion)(NSError *error);

@interface RMTelepresencePresence : NSObject

@property (nonatomic, strong, readonly) NSString *number;

+ (instancetype)sharedInstance;

- (void)fetchNumber:(RMTelepresence2PresenceFetchNumberCompletion)completion;
- (void)connect;
- (void)disconnect;

@end
