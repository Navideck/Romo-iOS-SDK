//
//  RMSandboxMission.m
//  Romo
//
//  Created on 9/13/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMSandboxMission.h"
#import "RMAction.h"
#import "RMEvent.h"
#import "RMMission_Protected.h"
#import "RMUnlockable.h"

static NSString *theLabsavedSolutionName = @"TheLab";

@interface RMSandboxMission ()

// All RMMission properties defined in RMMission_Protected.h are available to RMSandboxMission.

@end

@implementation RMSandboxMission

- (instancetype)initWithChapter:(RMChapter)chapter index:(NSInteger)index
{
    self = [super init];
    if (self) {
        self.chapter = chapter;
        
        self.title = NSLocalizedString(@"Lab-Mission-Title", @"The Lab");
        self.briefing = NSLocalizedString(@"Lab-Mission-Subtitle", @"A place to play with everything you've unlocked.");
        
        // Unlock all actions and events from the start
        // If the user hasn't made it to the end
        [[RMProgressManager sharedInstance] unlockAllEventsandActions];
        
        self.availableEvents = [RMProgressManager sharedInstance].unlockedEvents;
        self.availableActions = [RMProgressManager sharedInstance].unlockedActions;
        self.lockedActions = [RMProgressManager sharedInstance].lockedActions;
        
        // Set all the available actions' availableCount so they can be used
        [self.availableActions enumerateObjectsUsingBlock:^(RMAction *action, NSUInteger idx, BOOL *stop) {
            action.availableCount = -1;
        }];
        
        self.maximumActionCount = -1;
        self.allowsAddingEvents = (self.availableEvents.count > 1);
        self.allowsEditingParameters = YES;
        self.allowsAddingActions = YES;
        self.allowsDeletingActions = YES;
        self.skipBriefing = YES;
        self.skipDebriefing = YES;
        self.disableFlipDetection = YES;
        self.allowsRepeat = [[NSUserDefaults standardUserDefaults] boolForKey:RMRepeatUnlockedKey];
        self.allowsEditingRepeat = self.allowsRepeat;
        
        self.events = [NSMutableArray array];
        self.inputScripts = [NSMutableArray arrayWithCapacity:self.availableEvents.count];
        
        RMEvent *onStartEvent = [[RMEvent alloc] initWithType:RMEventMissionStart];
        [self.events addObject:onStartEvent];
        
        // Set the initial onStart script to contain the first available action
        NSMutableArray *emptyOnStartScript = [NSMutableArray array];
        if (self.availableActions.count > 0) {
            [emptyOnStartScript addObject:self.availableActions[0]];
        }
        [self.inputScripts addObject:emptyOnStartScript];
        
        [self loadSolutionFromDisk:theLabsavedSolutionName];
    }
    return self;
}

- (void)dealloc
{
    [self saveSolutionToDisk:theLabsavedSolutionName];
    
    // Clear out any photos captured in The Lab
    [[RMProgressManager sharedInstance].capturedPhotos removeAllObjects];
}

- (void)prepareToRun
{
    [self saveSolutionToDisk:theLabsavedSolutionName];
    [super prepareToRun];
}

@end
