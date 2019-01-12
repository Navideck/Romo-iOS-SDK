//
//  RMMission.m
//  Romo
//

#import "RMMission.h"
#import "RMMissionRule.h"
#import "RMMissionRuleConstraint.h"
#import "RMMissionRuleValue.h"
#import "RMMissionProperty.h"
#import "RMEvent.h"
#import "RMUnlockable.h"
#import "RMAction.h"
#import "RMActionRuntime.h"
#import "RMProgressManager.h"
#import "RMMission_Protected.h"

NSString *const savedSolutionKey = @"Mission-%d-%ld-Solution";

@interface RMMission () <RMActionRuntimeDelegate>

// Only add Private properties here. Protected properties should be added to RMMission_Protected.h
// so that subclasses such as RMSandboxMission can access them.

@end

@implementation RMMission

- (id)initWithChapter:(RMChapter)chapter index:(NSInteger)index
{
    self = [super init];
    if (self) {
        BOOL validIndex = [[RMProgressManager sharedInstance] missionCountForChapter:chapter] >= index;
        if (!validIndex) {
            return nil;
        }

        _chapter = chapter;
        _index = index;

        _progressManager = [RMProgressManager sharedInstance];
        _status = [self.progressManager statusForMissionInChapter:chapter index:index];

        NSString *missionPath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"Mission-%d-%ld", chapter, (long)index] ofType:@"plist"];

        NSDictionary *mission = [NSDictionary dictionaryWithContentsOfFile:missionPath];

        NSString *localKeyPrefix = [NSString stringWithFormat:@"Mission-%i-%li", chapter, (long)index];

        self.title = [[NSBundle mainBundle] localizedStringForKey:[NSString stringWithFormat:@"%@-title", localKeyPrefix]
                                                            value:mission[@"title"]
                                                            table:@"Missions"];
        self.briefing = [[NSBundle mainBundle] localizedStringForKey:[NSString stringWithFormat:@"%@-briefing", localKeyPrefix]
                                                               value:mission[@"briefing"]
                                                               table:@"Missions"];
        self.failureDebriefing = [[NSBundle mainBundle] localizedStringForKey:[NSString stringWithFormat:@"%@-failure debriefing", localKeyPrefix]
                                                                        value:mission[@"failure debriefing"]
                                                                        table:@"Missions"];
        self.successDebriefing = [[NSBundle mainBundle] localizedStringForKey:[NSString stringWithFormat:@"%@-success debriefing", localKeyPrefix]
                                                                        value:mission[@"success debriefing"]
                                                                        table:@"Missions"];
        self.congratsDebriefing = [[NSBundle mainBundle] localizedStringForKey:[NSString stringWithFormat:@"%@-congrats debriefing", localKeyPrefix]
                                                                         value:mission[@"congrats debriefing"]
                                                                         table:@"Missions"];
        self.promptToPlay = [[NSBundle mainBundle] localizedStringForKey:[[NSString stringWithFormat:@"%@-prompt", localKeyPrefix] stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"]
                                                                   value:[mission[@"prompt"] stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"]
                                                                   table:@"Missions"];

        self.glowActionViews = [mission[@"glow action views"] boolValue];
        self.skipCollapseScripts = [mission[@"skip collapse scripts"] boolValue];
        self.disableFlipDetection = [mission[@"disable flip detection"] boolValue];
        self.allowsRepeat = [mission[@"allows repeat"] boolValue];
        self.allowsEditingRepeat = mission[@"editing repeat"] ? [mission[@"editing repeat"] boolValue] : YES;
        self.lightInitiallyOff = [mission[@"light initially off"] boolValue];

        self.duration = mission[@"duration"] ? [mission[@"duration"] intValue] : -1;

        self.visionModules = [NSMutableSet setWithCapacity:1];

        self.skipBriefing = NO;
        self.skipDebriefing = NO;

        NSNumber *maxActionCountNumber = mission[@"max action count"];
        self.maximumActionCount = (maxActionCountNumber == nil) ? -1 : maxActionCountNumber.integerValue;

        NSNumber *allowsAddingEventsValue = mission[@"adding events"];
        self.allowsAddingEvents = allowsAddingEventsValue.boolValue;

        NSNumber *allowsEditingParametersValue = mission[@"editing parameters"];
        self.allowsEditingParameters = allowsEditingParametersValue.boolValue;

        NSNumber *allowsAddingActions = mission[@"adding actions"];
        self.allowsAddingActions = (allowsAddingActions == nil) || (allowsAddingActions.boolValue == YES);

        NSNumber *allowsDeletingActions = mission[@"deleting actions"];
        self.allowsDeletingActions = (allowsDeletingActions == nil) || (allowsDeletingActions.boolValue == YES);

        NSArray *initialSolution = mission[@"initial solution"];
        _events = [NSMutableArray arrayWithCapacity:initialSolution.count];
        _inputScripts = [NSMutableArray arrayWithCapacity:initialSolution.count];

        for (NSDictionary *eventDictionary in initialSolution) {
            NSString *eventName = eventDictionary[@"event"];
            RMEvent *event = [[RMEvent alloc] initWithName:eventName];
            event.parameter.value = eventDictionary[@"eventParameter"];
            event.repeats = [eventDictionary[@"repeats"] boolValue];
            [self.events addObject:event];

            NSArray *scriptArray = eventDictionary[@"script"];
            NSMutableArray *script = [NSMutableArray arrayWithCapacity:scriptArray.count];
            for (NSDictionary *actionDictionary in scriptArray) {
                BOOL deletable = actionDictionary[@"deletable"] ? [actionDictionary[@"deletable"] boolValue] : YES;
                RMAction *action = [RMAction actionWithSelector:actionDictionary[@"selector"]
                                                parameterValues:actionDictionary[@"parameterValues"]
                                                         locked:[actionDictionary[@"locked"] boolValue]
                                                      deletable:deletable];
                [script addObject:action];
            }
            [self.inputScripts addObject:script];
        }

        NSArray *availableEventsNames = mission[@"events"];
        NSMutableArray *availableEvents = [NSMutableArray arrayWithCapacity:availableEventsNames.count];
        for (NSString *eventName in availableEventsNames) {
            RMEvent *event = [[RMEvent alloc] initWithName:eventName];
            [availableEvents addObject:event];
        }
        self.availableEvents = [NSArray arrayWithArray:availableEvents];

        NSArray *availableActionsDictionaries = mission[@"actions"];
        if (availableActionsDictionaries.count) {
            NSMutableArray *availableActions = [NSMutableArray arrayWithCapacity:availableActionsDictionaries.count];
            for (NSDictionary *actionDictionary in availableActionsDictionaries) {
                RMAction *action = [[RMAction alloc] initWithDictionary:actionDictionary];
                [availableActions addObject:action];
            }
            self.availableActions = [NSArray arrayWithArray:availableActions];
        }

        for (NSArray *script in self.inputScripts) {
            for (RMAction *action in script) {
                [self decrementAvailableCountForAction:action];
            }
        }

        self.allowsViewingEvents = self.allowsAddingEvents || (self.events.count > 1) || (self.availableEvents.count > 1);

        NSArray *unlockableDictionaries = mission[@"unlockables"];
        NSMutableArray *unlockables = [NSMutableArray arrayWithCapacity:unlockableDictionaries.count];
        for (NSDictionary *unlockableDictionary in unlockableDictionaries) {
            [unlockables addObject:[[RMUnlockable alloc] initWithDictionary:unlockableDictionary]];
        }
        self.unlockables = [NSArray arrayWithArray:unlockables];

        self.threeStarSolution = [self solutionFromArray:mission[@"three star solution"]];
        self.twoStarSolution = [self solutionFromArray:mission[@"two star solution"]];
        self.oneStarSolution = [self solutionFromArray:mission[@"one star solution"]];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:RMEventDidOccurNotification object:nil];
}

- (void)loadSolutionFromDisk:(NSString *)name
{
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *fileName = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", name]];
    NSArray *events = [NSArray arrayWithContentsOfFile:fileName];

    if (events.count) {
        [self.events removeAllObjects];
        [self.inputScripts removeAllObjects];

        for (NSDictionary *eventDictionary in events) {
            NSString *eventName = eventDictionary[@"event"];
            RMEvent *event = [[RMEvent alloc] initWithName:eventName];
            event.parameter.value = eventDictionary[@"eventParameter"];
            event.repeats = [eventDictionary[@"repeats"] boolValue];
            [self.events addObject:event];

            NSArray *serializedActions = eventDictionary[@"script"];
            NSMutableArray *script = [NSMutableArray arrayWithCapacity:serializedActions.count];
            for (NSDictionary *serializedAction in serializedActions) {
                RMAction *action = [[RMAction alloc] initWithDictionary:serializedAction];
                [script addObject:action];
            }
            [self.inputScripts addObject:script];
        }
    }
}

- (NSSet *)visionModules
{
    NSMutableSet *set = [NSMutableSet set];

    [self.events enumerateObjectsUsingBlock:^(RMEvent *event, NSUInteger idx, BOOL *stop) {
        [set unionSet:event.requiredVisionModules];
    }];

    return [set copy];
}

/** Saves a serialized version to the Documents directory */
- (void)saveSolutionToDisk:(NSString *)name
{
    NSMutableArray *serialization = [NSMutableArray arrayWithCapacity:self.events.count];

    for (int i = 0; i < self.events.count; i++) {
        NSMutableDictionary *eventDictionary = [NSMutableDictionary dictionary];

        RMEvent *event = self.events[i];
        eventDictionary[@"event"] = [RMEvent nameForEventType:event.type];
        if (event.parameter.value) {
            eventDictionary[@"eventParameter"] = event.parameter.value;
            eventDictionary[@"repeats"] = @(event.repeats);
        }

        NSArray *script = self.inputScripts[i];
        NSMutableArray *scriptArray = [NSMutableArray arrayWithCapacity:script.count];
        for (RMAction *action in script) {
            [scriptArray addObject:[action dictionarySerialization]];
        }

        eventDictionary[@"script"] = scriptArray;
        serialization[i] = eventDictionary;
    }

    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *fileName = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist",name]];
    [serialization writeToFile:fileName atomically:YES];
}

- (void)updateAvailableActionsToMatchAction:(RMAction *)action
{
    [self.availableActions enumerateObjectsUsingBlock:^(RMAction *availableAction, NSUInteger idx, BOOL *stop) {
        if ([availableAction.selector isEqualToString:action.selector]) {
            for (int i = 0; i < availableAction.parameters.count; i++) {
                RMParameter *parameterToDuplicate = action.parameters[i];
                RMParameter *parameterToBeOverwritten = availableAction.parameters[i];
                parameterToBeOverwritten.value = [parameterToDuplicate.value copy];
            }
        }
    }];
}

- (void)setRunning:(BOOL)running
{
    if (running != _running) {
        _running = running;
        if (running) {
            self.completedScripts = [NSMutableDictionary dictionaryWithCapacity:self.events.count];

            for (int i = 0; i < self.events.count; i++) {
                self.completedScripts[@(i)] = @NO;
            }

            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(eventDidOccur:) name:RMEventDidOccurNotification object:nil];
        } else {
            [self.actionRuntime stopAllActions];
            self.actionRuntime = nil;
            self.currentScript = nil;
            self.currentMethodIndex = -1;
            self.indexOfCurrentScript = -1;
            self.completedMethodCount = 0;

            [[NSNotificationCenter defaultCenter] removeObserver:self name:RMEventDidOccurNotification object:nil];
        }
    }
}

- (void)runScriptForEvent:(RMEvent *)event
{
    if (event) {
        [self.actionRuntime stopAllActions];
        self.running = YES;

        self.currentEvent = event;

        self.indexOfCurrentScript = [self.events indexOfObject:event];
        self.currentScript = [RMMission flattenedScript:self.inputScripts[self.indexOfCurrentScript]];
        [self.outputScripts replaceObjectAtIndex:self.indexOfCurrentScript withObject:self.currentScript];
        self.currentMethodIndex = 0;
        self.completedMethodCount = 0;

        int triggerCount = [self.eventTriggerCounts[self.indexOfCurrentScript] intValue];
        triggerCount++;
        self.eventTriggerCounts[self.indexOfCurrentScript] = @(triggerCount);

        if (event.type == RMEventMissionStart) {
            // Since the "Mission start" event can never trigger again, make sure we flag that it's done once we start it
            // Otherwise, we risk being stuck in the mission runtime forever
            self.completedScripts[@(self.indexOfCurrentScript)] = @YES;
        }

        [self runNextMethod];

        // If the script is empty, it's already finished
        if (self.currentScript.count == 0) {
            [self scriptAtIndexDidFinishRunning:self.indexOfCurrentScript];
        }
    }
}

- (void)scriptAtIndexWillFinishRunning:(NSInteger)index
{
    self.completedScripts[@(index)] = @YES;
}

- (void)scriptAtIndexDidFinishRunning:(NSInteger)index
{
    if (self.currentEvent.repeats) {
        [self runScriptForEvent:self.currentEvent];
    } else {
        [self.delegate mission:self scriptForEventDidFinish:self.currentEvent];
    }

    __block BOOL finishedAllScripts = YES;
    [self.completedScripts enumerateKeysAndObjectsUsingBlock:^(NSNumber *index, NSNumber *completionValue, BOOL *stop) {
        if (completionValue.boolValue == NO) {
            finishedAllScripts = NO;
            *stop = YES;
        }
    }];

    if (finishedAllScripts) {
        [self.delegate missionFinishedRunningAllScripts:self];
    }
}

+ (NSArray *)flattenedScript:(NSArray *)script
{
    NSMutableArray *flattenedScript = [NSMutableArray arrayWithCapacity:script.count];

    for (RMAction *action in script) {
        if (!action.isScripted) {
            [flattenedScript addObject:[action copy]];
        } else {
            NSArray *flattenedActions = [self flattenedScript:action.scriptActions];
            for (RMAction *flattenedAction in flattenedActions) {
                [flattenedScript addObject:[flattenedAction copy]];
            }
        }
    }

    return [NSArray arrayWithArray:flattenedScript];
}

+ (NSArray *)mergedScript:(NSArray *)script
{
    NSMutableArray *mergedScript = [NSMutableArray arrayWithCapacity:script.count];
    for (RMAction *action in script) {
        [mergedScript addObject:[action copy]];
    }

    if (script.count) {
        for (int i = 0; i < mergedScript.count - 1; i++) {
            RMAction *firstAction = mergedScript[i];
            RMAction *secondAction = mergedScript[i + 1];

            BOOL mergedAction = [firstAction mergeWithAction:secondAction];
            if (mergedAction) {
                [mergedScript removeObjectAtIndex:i + 1];
                i--;
            }
        }
    }

    return mergedScript;
}

/**
 Compares with the three star solution first, then tries two and one star solutions if needed
 Note: not all Missions have a one or two star solution,
 so if a mission passes for three stars, it could still fail the one-star test
 */
- (int)starCount
{
    if (self.reasonForFailing) {
        return 0;
    }

    RMMissionFailureReason threeStarFailureReason = [self validityForSolution:self.threeStarSolution];
    if (threeStarFailureReason == RMMissionFailureReasonNone) {
        self.reasonForFailing = RMMissionFailureReasonNone;
        self.reasonForImperfectSolution = RMMissionFailureReasonNone;
        return 3;
    } else if (self.twoStarSolution.count) {
        RMMissionFailureReason twoStarFailureReason = [self validityForSolution:self.twoStarSolution];
        if (twoStarFailureReason == RMMissionFailureReasonNone) {
            self.reasonForFailing = RMMissionFailureReasonNone;
            self.reasonForImperfectSolution = threeStarFailureReason;
            return 2;
        } else if (self.oneStarSolution.count) {
            RMMissionFailureReason oneStarFailureReason = [self validityForSolution:self.oneStarSolution];
            if (oneStarFailureReason == RMMissionFailureReasonNone) {
                self.reasonForFailing = RMMissionFailureReasonNone;
                self.reasonForImperfectSolution = twoStarFailureReason;
                return 1;
            } else {
                self.reasonForFailing = oneStarFailureReason;
                self.reasonForImperfectSolution = twoStarFailureReason;
                return 0;
            }
        } else {
            self.reasonForFailing = twoStarFailureReason;
            self.reasonForImperfectSolution = threeStarFailureReason;
            return 0;
        }
    } else {
        self.reasonForFailing = threeStarFailureReason;
        self.reasonForImperfectSolution = RMMissionFailureReasonNone;
        return 0;
    }
}

- (void)setStatus:(RMMissionStatus)status
{
    BOOL didSetStatus = [self.progressManager setStatus:status forMissionInChapter:self.chapter index:self.index];
    if (didSetStatus) {
        _status = status;
        [self saveSolutionToDisk:[NSString stringWithFormat:savedSolutionKey, self.chapter, (long)self.index]];
    }
}

- (void)incrementAvailableCountForAction:(RMAction *)action
{
    for (RMAction *availableAction in self.availableActions) {
        if ([availableAction.fullSelector isEqualToString:action.fullSelector] ||
            (availableAction.isScripted && action.isScripted && [availableAction.title isEqualToString:action.title])) {
            // Find the right action
            if (availableAction.availableCount >= 0) {
                // Only increment it if we don't allow infinite usage
                availableAction.availableCount++;
            }
            break;
        }
    }
}

- (void)decrementAvailableCountForAction:(RMAction *)action
{
    for (RMAction *availableAction in self.availableActions) {
        if ([availableAction.fullSelector isEqualToString:action.fullSelector] ||
            (availableAction.isScripted && action.isScripted && [availableAction.title isEqualToString:action.title])) {
            availableAction.availableCount--;
            break;
        }
    }
}

- (void)prepareToRun
{
    // Trim out all events that have no scripts
    NSMutableArray *events = [NSMutableArray arrayWithCapacity:self.events.count];
    NSMutableArray *scripts = [NSMutableArray arrayWithCapacity:self.events.count];
    [self.events enumerateObjectsUsingBlock:^(NSArray *event, NSUInteger i, BOOL *stop) {
        NSArray *correspondingScript = self.inputScripts[i];
        if (correspondingScript.count > 0) {
            [events addObject:event];
            [scripts addObject:correspondingScript];
        }
    }];

    self.events = events;
    self.inputScripts = scripts;

    self.outputScripts = [NSMutableArray arrayWithCapacity:self.inputScripts.count];
    self.eventTriggerCounts = [NSMutableArray arrayWithCapacity:self.inputScripts.count];
    for (int i = 0; i < self.inputScripts.count; i++) {
        [self.outputScripts addObject:[NSNull null]];
        [self.eventTriggerCounts addObject:@0];
    }
    
}

- (RMActionRuntime *)actionRuntime
{
    if (!_actionRuntime) {
        _actionRuntime = [[RMActionRuntime alloc] init];
        _actionRuntime.delegate = self;
    }
    return _actionRuntime;
}

#pragma mark - RMactionRuntimeDelegate

- (void)actionRuntimeBecameReadyToRunNextAction:(RMActionRuntime *)actionRuntime
{
    [self runNextMethod];
}

- (void)actionRuntime:(RMActionRuntime *)actionRuntime finishedRunningAction:(RMAction *)method
{
    if (method) {
        self.completedMethodCount++;
        
        if (self.completedMethodCount == self.currentScript.count - 1) {
            // If we just finished the 2nd to last method, mark this event as done
            [self scriptAtIndexWillFinishRunning:self.indexOfCurrentScript];
        } else if (self.completedMethodCount == self.currentScript.count) {
            // If we just finisehd the last method, check to see if we're completely done running
            [self scriptAtIndexWillFinishRunning:self.indexOfCurrentScript];
            [self scriptAtIndexDidFinishRunning:self.indexOfCurrentScript];
        }
    }
}

#pragma mark - Private Methods

- (void)runNextMethod
{
    if (self.actionRuntime.readyToRun && self.running) {
        if (self.currentScript.count > self.currentMethodIndex) {
            // If we have more actions to run, run the next one
            RMAction *action = self.currentScript[self.currentMethodIndex];
            
            if (self.currentMethodIndex == 0 && self.currentScript.count == 1) {
                // If we just finished the 2nd to last method, mark this event as done
                [self scriptAtIndexWillFinishRunning:self.indexOfCurrentScript];
            }

            self.currentMethodIndex++;
            
            [self.actionRuntime runAction:action];
        } else {
            if (self.completion) {
                self.completion(YES);
            }
        }
    }
}

- (void)eventDidOccur:(NSNotification *)eventNotification
{
    NSDictionary *eventInfo = eventNotification.userInfo;

    RMEventType eventType = ((NSNumber *)(eventInfo[@"type"])).intValue;
    id eventParameter = eventInfo[@"parameter"];

    for (RMEvent *event in self.events) {
        if (event.type == eventType) {
            if ([event.parameter.value isEqual:eventParameter] || !eventParameter) {
                [self.delegate mission:self eventDidOccur:event];
                [self runScriptForEvent:event];
                break;
            }
        }
    }
}

/**
 Builds a solution model from a serialized array
 */
- (NSDictionary *)solutionFromArray:(NSArray *)solutionArray
{
    if (solutionArray.count) {
        NSMutableArray *events = [NSMutableArray arrayWithCapacity:solutionArray.count];
        NSMutableArray *triggerCounts = [NSMutableArray arrayWithCapacity:solutionArray.count];
        NSMutableArray *rules = [NSMutableArray arrayWithCapacity:solutionArray.count];
        NSMutableArray *properties = [NSMutableArray arrayWithCapacity:solutionArray.count];
        
        for (NSDictionary *eventDictionary in solutionArray) {
            NSString *name = eventDictionary[@"event"];
            RMEvent *event = [[RMEvent alloc] initWithName:name];
            event.parameter.value = eventDictionary[@"eventParameter"];
            [events addObject:event];
            
            NSNumber *triggerCount = eventDictionary[@"trigger count"];
            if (triggerCount.intValue > 0) {
                [triggerCounts addObject:triggerCount];
            } else {
                [triggerCounts addObject:@(-1)];
            }
                
            NSArray *rulesDictionaries = eventDictionary[@"rules"];
            NSMutableArray *rulesforEvent = [NSMutableArray arrayWithCapacity:rulesDictionaries.count];
            for (NSDictionary *rulesDictionary in rulesDictionaries) {
                RMMissionRule *rule = [[RMMissionRule alloc] initWithDictionary:rulesDictionary];
                [rulesforEvent addObject:rule];
            }
            [rules addObject:rulesforEvent];
            
            NSArray *propertyDictionaries = eventDictionary[@"properties"];
            NSMutableSet *propertySet = [NSMutableSet setWithCapacity:propertyDictionaries.count];
            for (NSDictionary *propertyDictionary in propertyDictionaries) {
                RMMissionProperty *property = [[RMMissionProperty alloc] initWithDictionary:propertyDictionary];
                [propertySet addObject:property];
            }
            [properties addObject:propertySet];
        }
        return @{@"rules" : rules, @"properties" : properties, @"events" : events, @"trigger counts" : triggerCounts};
    }
    return nil;
}

/**
 Checks if self is valid for the solution model actually executed
 If invalid, compare to the reference input to see if we can deduce why
 */
- (RMMissionFailureReason)validityForSolution:(NSDictionary *)solution
{
    if (solution.count >= 3) {
        NSArray *triggerCounts = solution[@"trigger counts"];
        NSArray *rules = solution[@"rules"];
        NSArray *properties = solution[@"properties"];
        NSArray *events = solution[@"events"];
        
        //events[] is ordered by solution; self.events isn't same order
        
        // check that we have all and only the correct events
        for (int solutionIndex = 0; solutionIndex < events.count; solutionIndex++) {
            RMEvent *event = events[solutionIndex];
            if (![self.events containsObject:event]) {
                return RMMissionFailureReasonWrongInput;
            } else {
                NSInteger scriptIndex = [self.events indexOfObject:event];
                
                int triggerCount = [self.eventTriggerCounts[scriptIndex] intValue];
                int minimumTriggerCount = [triggerCounts[solutionIndex] intValue];
                if (minimumTriggerCount > 0 && triggerCount < minimumTriggerCount) {
                    return RMMissionFailureReasonTimedOut;
                }
                
                // check that our rules are matched
                NSArray *outputScript = self.outputScripts[scriptIndex];
                NSArray *inputScript = self.inputScripts[scriptIndex];
                NSArray *collapsedOutputScript = outputScript;
                NSArray *collapsedInputScript = inputScript;
                if (!self.skipCollapseScripts) {
                    outputScript = [RMMission flattenedScript:outputScript];
                    collapsedOutputScript = [RMMission mergedScript:outputScript];
                    
                    inputScript = [RMMission flattenedScript:inputScript];
                    collapsedInputScript = [RMMission mergedScript:inputScript];
                }
                NSArray *rulesForEvent = rules[solutionIndex];
                NSArray *propertiesForEvent = properties[solutionIndex];
                
                // we must have enough actions to match against rules
                if (rulesForEvent.count > collapsedOutputScript.count) {
                    return RMMissionFailureReasonWrongInput;
                }
                
                for (int j = 0; j < rulesForEvent.count; j++) {
                    RMMissionRule *rule = rulesForEvent[j];
                    RMAction *action = collapsedOutputScript[j];
                    rule.actions = collapsedOutputScript;
                    
                    if (![rule matchesAction:action]) {
                        // if the reference method matches, that means a runtime error failed the mission
                        if (collapsedInputScript.count > j) {
                            RMAction *referenceAction = collapsedInputScript[j];
                            if ([rule matchesAction:referenceAction]) {
                                NSString *title = referenceAction.title;
                                if ([title isEqualToString:@"Turn"]) {
                                    return RMMissionFailureReasonTurning;
                                } else if ([title isEqualToString:@"Tilt"]) {
                                    return RMMissionFailureReasonTilting;
                                }
                            }
                            return RMMissionFailureReasonWrongInput;
                        } else {
                            return RMMissionFailureReasonWrongInput;
                        }
                    }
                }
                
                for (RMMissionProperty *property in propertiesForEvent) {
                    if (![property matchesActions:outputScript]) {
                        return RMMissionFailureReasonWrongInput;
                    }
                }
            }
        }
        return RMMissionFailureReasonNone;
    }
    return RMMissionFailureReasonWrongInput;
}

@end
