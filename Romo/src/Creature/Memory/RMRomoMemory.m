//
//  RMRomoMemory.m
//  Romo
//
//  Created on 8/23/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMRomoMemory.h"
#import "RMAppDelegate.h"
#import "RMRobotController.h"

NSString *const kRMRomoMemoryStoreFileName = @"RomoMemoryStore";

NSString *const RMMemoryKey_RomoName = @"romoName";

@class RMRobotController;

@interface RMRomoMemory ()

@property (nonatomic, strong) NSMutableDictionary *memory;
@property (nonatomic, strong) NSString *filePath;
@property (nonatomic) BOOL updatedMemory;

@end

@implementation RMRomoMemory

//------------------------------------------------------------------------------
+ (RMRomoMemory *)sharedInstance
{
    static id sharedInstance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

//------------------------------------------------------------------------------
- (id)init
{
    self = [super init];
    if (self) {
        // Store the path
        NSString* libPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                                 NSUserDomainMask,
                                                                 YES) objectAtIndex:0];
        _filePath = [libPath stringByAppendingPathComponent:kRMRomoMemoryStoreFileName];
        
        // Try to load from disk
        _memory = (NSMutableDictionary*)[NSDictionary dictionaryWithContentsOfFile:_filePath];
        
#ifndef ROMO_CONTROL_APP
        // Add ourselves as an observer for name changes
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRomoDidChangeNameNotification:)
                                                     name:RMRomoDidChangeNameNotification
                                                   object:nil];
#endif
        
        // If doesn't exist, create a new one
        if (!_memory) {
            _memory = [[NSMutableDictionary alloc] init];
#ifdef ROMO_MEMORY_DEBUG
            DDLogVerbose(@"Created %@", kRMRomoMemoryStoreFileName);
#endif
        } else {
#ifdef ROMO_MEMORY_DEBUG
            DDLogVerbose(@"Loaded %@", kRMRomoMemoryStoreFileName);
            [self printMemory];
#endif
        }
    }
    return self;
}

//------------------------------------------------------------------------------
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

//------------------------------------------------------------------------------
- (BOOL)saveMemory
{
    if (!self.updatedMemory) {
        return YES;
    } else {
#ifdef ROMO_MEMORY_DEBUG
        DDLogVerbose(@"Saving Memory to Disk");
#endif
        self.updatedMemory = NO;
        return [self.memory writeToFile:self.filePath atomically:YES];
    }
}

//------------------------------------------------------------------------------
- (void)printMemory
{
#ifdef ROMO_MEMORY_DEBUG
    for(NSString *key in _memory) {
        NSString *value = [_memory objectForKey:key];
        DDLogVerbose(@"\t{%@} -> {%@}", key, value);
    }
    DDLogVerbose(@"\n----------------------\n\n");
#endif
}

//------------------------------------------------------------------------------
- (BOOL)setKnowledge:(NSString *)knowledge forKey:(NSString *)key
{
    if (!self.updatedMemory) {
        self.updatedMemory = YES;
    }
    [self.memory setObject:knowledge forKey:key];
    
    // Go through special keys
    if ([key isEqualToString:RMMemoryKey_RomoName]) {
        ((RMAppDelegate *)[UIApplication sharedApplication].delegate).robotController.Romo.name = knowledge;
    }
    
    [self saveMemory];
    return YES;
}

//------------------------------------------------------------------------------
- (BOOL)removeKnowledgeWithKey:(NSString *)key
{
    if (!self.updatedMemory) {
        self.updatedMemory = YES;
    }
    if (self.memory[key]) {
        [self.memory removeObjectForKey:key];
        return YES;
    } else {
        return NO;
    }
}

//------------------------------------------------------------------------------
- (NSString *)knowledgeForKey:(NSString *)key
{
    id thing = self.memory[key];
    if ([thing isKindOfClass:[NSString class]]) {
        return (NSString *)thing;
    } else {
        return nil;
    }
}

//------------------------------------------------------------------------------
- (void)handleRomoDidChangeNameNotification:(NSNotification *)notification
{
    NSString *newName = notification.userInfo[@"name"];
    [self.memory setObject:newName
                    forKey:RMMemoryKey_RomoName];
}

@end
