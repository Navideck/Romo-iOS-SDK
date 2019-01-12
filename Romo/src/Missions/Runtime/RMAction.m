//
//  RMAction.m
//  Romo
//

#import "RMAction.h"
#import "RMParameter.h"
#import "RMActionRuntime.h"
#import "RMDoodle.h"

@interface RMAction ()

@property (nonatomic, readwrite, strong) NSString *title;
@property (nonatomic, readwrite, strong) NSString *shortTitle;
@property (nonatomic, readwrite, strong) NSString *library;
@property (nonatomic, readwrite, strong) NSString *selector;
@property (nonatomic, readwrite, strong) NSString *fullSelector;
@property (nonatomic, readwrite, strong) NSDictionary *dictionary;
@property (nonatomic, readwrite, getter=isScripted) BOOL scripted;
@property (nonatomic, readwrite, strong) NSString *scriptPath;
@property (nonatomic, readwrite, strong) NSArray *scriptActions;
@property (nonatomic, readwrite, getter=isLocked) BOOL locked;
@property (nonatomic, readwrite, getter=isDeletable) BOOL deletable;

@end

@implementation RMAction

+ (RMAction *)actionWithSelector:(NSString *)selector parameterValues:(NSArray *)parameterValues locked:(BOOL)locked deletable:(BOOL)deletable
{
    __block RMAction *action = nil;
    
    NSArray *allActions = [RMActionRuntime allActions];
    [allActions enumerateObjectsUsingBlock:^(RMAction *otherAction, NSUInteger idx, BOOL *stop) {
        if ([selector isEqualToString:otherAction.fullSelector]) {
            action = [otherAction copy];
            action.locked = locked;
            action.deletable = deletable;
            [action.parameters enumerateObjectsUsingBlock:^(RMParameter *parameter, NSUInteger index, BOOL *stop) {
                if (parameterValues && index < parameterValues.count) {
                    parameter.value = parameterValues[index];
                }
            }];
        }
    }];
    
    return action;
}

- (RMAction *)initWithDictionary:(NSDictionary *)actionDictionary
{
    self = [super init];
    if (self) {
        if ([actionDictionary[@"isScripted"] boolValue]) {
            NSString *title = actionDictionary[@"title"];
            NSString *shortTitle = actionDictionary[@"shortTitle"];
            int availableCount = [actionDictionary[@"available count"] intValue];
            return [self initWithScriptTitle:title shortTitle:shortTitle availableCount:availableCount];
        }
        
        _dictionary = [NSDictionary dictionaryWithDictionary:actionDictionary];
        _library = actionDictionary[@"library"];
        _title = actionDictionary[@"title"];
        _shortTitle = actionDictionary[@"shortTitle"];
        _fullSelector = actionDictionary[@"selector"];
        _availableCount = [actionDictionary[@"available count"] intValue];
        _locked = [actionDictionary[@"locked"] boolValue];
        _deletable = actionDictionary[@"deletable"] ? [actionDictionary[@"deletable"] boolValue] : YES;
        
        if (!_title || !_shortTitle) {
            NSArray *allActions = [RMActionRuntime allActions];
            [allActions enumerateObjectsUsingBlock:^(RMAction *otherAction, NSUInteger idx, BOOL *stop) {
                if ([otherAction.fullSelector isEqualToString:self->_fullSelector]) {
                    self->_title = otherAction.title;
                    self->      _shortTitle = otherAction.shortTitle;
                }
            }];
        }
        
        if ([self.fullSelector rangeOfString:@":"].length == 0) {
            _selector = self.fullSelector;
        } else {
            NSArray *components = [self.fullSelector componentsSeparatedByString:@" "];
            NSMutableArray *nameComponents = [NSMutableArray arrayWithCapacity:components.count];
            NSMutableArray *parameters = [NSMutableArray arrayWithCapacity:components.count];
            NSArray *parameterValues = actionDictionary[@"parameterValues"];

            int i = 0;
            for (NSString *component in components) {
                NSArray *subcomponents = [component componentsSeparatedByString:@":"];
                if (subcomponents.count == 2) {
                    NSString *nameComponent = subcomponents[0];
                    [nameComponents addObject:nameComponent];
                    
                    RMParameter *parameter = [[RMParameter alloc] initFromString:subcomponents.lastObject];
                    if (parameterValues.count > i) {
                        if (parameter.type != RMParameterDoodle) {
                            parameter.value = parameterValues[i];
                        } else {
                            parameter.value = [[RMDoodle alloc] initWithSerialization:parameterValues[i]];
                        }
                    }
                    [parameters addObject:parameter];
                }
                i++;
            }
            _selector = [[[nameComponents valueForKey:@"description"] componentsJoinedByString:@":"] stringByAppendingFormat:@":"];
            _parameters = [NSArray arrayWithArray:parameters];
        }
        _scripted = NO;
    }
    return self;
}

- (RMAction *)initWithScriptTitle:(NSString *)title shortTitle:(NSString *)shortTitle availableCount:(int)availableCount
{
    self = [super init];
    if (self) {
        _title = title;
        _shortTitle = shortTitle;
        _availableCount = availableCount;
        _library = @"UserDefined";
        _deletable = YES;
        
        NSString *scriptPath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"User-Action-%@",shortTitle] ofType:@"plist"];
        NSArray *script = [NSArray arrayWithContentsOfFile:scriptPath];
        
        NSMutableArray *scriptActions = [NSMutableArray arrayWithCapacity:script.count];
        for (NSDictionary *dictionary in script) {
            [scriptActions addObject:[[RMAction alloc] initWithDictionary:dictionary]];
        }
        self.scriptActions = [NSArray arrayWithArray:scriptActions];
                
        _scripted = YES;
    }
    return self;
}

- (id)copy
{
    RMAction *copiedAction = [[RMAction alloc] init];
    copiedAction.title = self.title ? [NSString stringWithString:self.title] : nil;
    copiedAction.shortTitle = self.shortTitle ? [NSString stringWithString:self.shortTitle] : nil;
    copiedAction.library = self.library ? [NSString stringWithString:self.library] : nil;
    copiedAction.selector = self.selector ? [NSString stringWithString:self.selector] : nil;
    copiedAction.fullSelector = self.fullSelector ? [NSString stringWithString:self.fullSelector] : nil;
    copiedAction.availableCount = self.availableCount;
    copiedAction.dictionary = self.dictionary.count ? [NSDictionary dictionaryWithDictionary:self.dictionary] : nil;
    copiedAction.scripted = self.isScripted;
    copiedAction.scriptPath = self.scriptPath ? [NSString stringWithString:self.scriptPath] : nil;
    copiedAction.scriptActions = self.scriptActions.count ? [NSArray arrayWithArray:self.scriptActions] : nil;
    copiedAction.locked = self.isLocked;
    copiedAction.deletable = self.isDeletable;
    
    NSMutableArray *copiedParameters = [NSMutableArray arrayWithCapacity:self.parameters.count];
    for (RMParameter *parameter in self.parameters) {
        RMParameter *copiedParameter = [[RMParameter alloc] initWithType:parameter.type];
        if ([copiedParameters respondsToSelector:@selector(copy)]) {
            copiedParameter.value = [parameter.value copy];
        } else {
            copiedParameter.value = parameter.value;
        }
        [copiedParameters addObject:copiedParameter];
    }
    copiedAction.parameters = [NSArray arrayWithArray:copiedParameters];

    return copiedAction;
}

#pragma mark - Public Methods

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ \"%@\": %@",super.description, self.title.length ? self.title : self.selector,self.parameters];
}

- (NSDictionary *)dictionarySerialization
{
    NSMutableDictionary *actionDictionary = [NSMutableDictionary dictionary];
 
    if (self.isScripted) {
        actionDictionary[@"isScripted"] = @YES;
        actionDictionary[@"title"] = self.title;
        actionDictionary[@"shortTitle"] = self.shortTitle;
    } else {
        actionDictionary[@"selector"] = self.fullSelector;
        actionDictionary[@"library"] = self.library;

        if (self.parameters.count) {
            NSMutableArray *parameterArray = [NSMutableArray arrayWithCapacity:self.parameters.count];
            for (RMParameter *parameter in self.parameters) {
                if (parameter.value) {
                    if (parameter.type != RMParameterDoodle) {
                        [parameterArray addObject:parameter.value];
                    } else {
                        [parameterArray addObject:[(RMDoodle *)parameter.value serialization]];
                    }
                }
            }
            actionDictionary[@"parameterValues"] = parameterArray;
        }
    }
    
    actionDictionary[@"locked"] = @(self.isLocked);
    actionDictionary[@"deletable"] = @(self.isDeletable);
    return actionDictionary;
}

- (BOOL)mergeWithAction:(RMAction *)action
{
    BOOL collapsed = NO;
    // Make sure we're both the same action
    if ([self.fullSelector isEqualToString:action.fullSelector] && [self.library isEqualToString:action.library]) {
        if ([self.selector isEqualToString:@"waitForDuration:"]) {
            // Add durations
            RMParameter *duration = [self parameterForType:RMParameterDuration];
            RMParameter *otherDuration = [action parameterForType:RMParameterDuration];
            duration.value = @([duration.value doubleValue] + [otherDuration.value doubleValue]);
            collapsed = YES;
            
        } else if ([self.selector isEqualToString:@"turnOnLights:"]) {
            // Same brightness
            RMParameter *brightness = [self parameterForType:RMParameterLightBrightness];
            RMParameter *otherBrightness = [action parameterForType:RMParameterLightBrightness];
            collapsed = ABS([brightness.value floatValue] - [otherBrightness.value floatValue]) < 0.02;
            
        } else if ([self.selector isEqualToString:@"tiltToAngle:"]) {
            // Same angle
            RMParameter *angle = [self parameterForType:RMParameterAngle];
            RMParameter *otherAngle = [action parameterForType:RMParameterAngle];
            collapsed = ABS([angle.value floatValue] - [otherAngle.value floatValue]) < 0.02;

        } else if ([self.selector isEqualToString:@"emote:"]) {
            // Same emotion
            RMParameter *emotion = [self parameterForType:RMParameterEmotion];
            RMParameter *otherEmotion = [action parameterForType:RMParameterEmotion];
            collapsed = [emotion.value intValue] == [otherEmotion.value intValue];
            
        } else if ([self.selector isEqualToString:@"driveForwardWithSpeed:distance:"] ||
                   [self.selector isEqualToString:@"driveBackwardWithSpeed:distance:"]) {
            // Same speed adds distances
            RMParameter *speed = [self parameterForType:RMParameterSpeed];
            RMParameter *otherSpeed = [action parameterForType:RMParameterSpeed];

            RMParameter *distance = [self parameterForType:RMParameterDistance];
            RMParameter *otherDistance = [action parameterForType:RMParameterDistance];
            
            if (ABS([speed.value floatValue] - [otherSpeed.value floatValue]) < 0.05) {
                distance.value = @([distance.value floatValue] + [otherDistance.value floatValue]);
                collapsed = YES;
            }

        } else if ([self.selector isEqualToString:@"turnByAngle:radius:clockwise:"]) {
            // Same radius & direction adds angles
            RMParameter *angle = [self parameterForType:RMParameterAngle];
            RMParameter *otherAngle = [action parameterForType:RMParameterAngle];
            
            RMParameter *radius = [self parameterForType:RMParameterRadius];
            RMParameter *otherRadius = [action parameterForType:RMParameterRadius];
            
            RMParameter *direction = [self parameterForType:RMParameterTurnDirection];
            RMParameter *otherDirection = [action parameterForType:RMParameterTurnDirection];

            if ([direction.value boolValue] == [otherDirection.value boolValue] &&
                ABS([radius.value floatValue] - [otherRadius.value floatValue]) < 0.1) {
                angle.value = @([angle.value floatValue] + [otherAngle.value floatValue]);
                collapsed = YES;
            }
            
        } else if ([self.selector isEqualToString:@"shuffleMusic"] ||
                   [self.selector isEqualToString:@"turnOffLights"] ||
                   [self.selector isEqualToString:@"blinkLights"]) {
            // No need to do any
            collapsed = YES;
        }
    }
    return collapsed;
}

- (RMParameter *)parameterForType:(RMParameterType)type
{
    for (RMParameter *parameter in self.parameters) {
        if (parameter.type == type) {
            return parameter;
        }
    }
    return nil;
}

@end
