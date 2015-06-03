//
//  RMRomoMemory.h
//  Romo
//
//  Created on 8/23/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RMRomoMemory : NSObject

+ (RMRomoMemory *)sharedInstance;

- (BOOL)saveMemory;
- (void)printMemory;

- (BOOL)setKnowledge:(NSString *)knowledge forKey:(NSString *)key;
- (BOOL)removeKnowledgeWithKey:(NSString *)key;
- (NSString *)knowledgeForKey:(NSString *)key;

@end
