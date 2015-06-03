//
//  RMEvent.m
//  Romo
//

#import "RMEvent.h"
#import "RMParameter.h"

@interface RMEvent ()

@property (nonatomic, readwrite, strong) RMParameter *parameter;

@end

@implementation RMEvent

- (id)copy
{
    RMEvent *copy = [[RMEvent alloc] initWithType:self.type];
    copy.parameter.value = [self.parameter.value copy];
    copy.repeats = self.repeats;
    return copy;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self copy];
}

- (RMEvent *)initWithName:(NSString *)name
{
    NSArray *components = [name componentsSeparatedByString:@":"];
    RMEvent *event = [self initWithType:[RMEvent eventTypeForName:components[0]]];
    if (components.count == 2) {
        event.parameter = [[RMParameter alloc] initFromString:components[1]];
    }
    return event;
}

- (RMEvent *)initWithType:(RMEventType)type
{
    self = [super init];
    if (self) {
        self.type = type;
        RMParameterType parameterType = [self parameterTypeForEventType:type];
        if (parameterType > 0 && parameterType < RMParameterCount) {
            self.parameter = [[RMParameter alloc] initWithType:parameterType];
        }
    }
    return self;
}

+ (RMEventType)eventTypeForName:(NSString *)name
{
    if ([name isEqualToString:@"RMEventMissionStart"] || [name isEqualToString:@"RMEventProgramStart"]) {
        return RMEventMissionStart;
    } else if ([name isEqualToString:@"RMEventPickedUp"]) {
        return RMEventPickedUp;
    } else if ([name isEqualToString:@"RMEventPutDown"]) {
        return RMEventPutDown;
    } else if ([name isEqualToString:@"RMEventTickle"]) {
        return RMEventTickle;
    } else if ([name isEqualToString:@"RMEventPoke"]) {
        return RMEventPoke;
    } else if ([name isEqualToString:@"RMEventPokeAnywhere"]) {
        return RMEventPokeAnywhere;
    } else if ([name isEqualToString:@"RMEventTime"]) {
        return RMEventTime;
    } else if ([name isEqualToString:@"RMEventHearsLoudSound"]) {
        return RMEventHearsLoudSound;
    } else if ([name isEqualToString:@"RMEventFaceAppear"]) {
        return RMEventFaceAppear;
    } else if ([name isEqualToString:@"RMEventFaceDisappear"]) {
        return RMEventFaceDisappear;
    } else if ([name isEqualToString:@"RMEventShake"]) {
        return RMEventShake;
    } else if ([name isEqualToString:@"RMEventDock"]) {
        return RMEventDock;
    } else if ([name isEqualToString:@"RMEventUndock"]) {
        return RMEventUndock;
    } else if ([name isEqualToString:@"RMEventHearsLoudSound"]) {
        return RMEventHearsLoudSound;
    } else if ([name isEqualToString:@"RMEventSeesMotion"]) {
        return RMEventSeesMotion;
    } else if ([name isEqualToString:@"RMEventStasis"]) {
        return RMEventStasis;
    } else if ([name isEqualToString:@"RMEventLightsOff"]) {
        return RMEventLightsOff;
    } else if ([name isEqualToString:@"RMEventLightsOn"]) {
        return RMEventLightsOn;
    } else if ([name isEqualToString:@"RMEventFavoriteColor"]) {
        return RMEventFavoriteColor;
    } else {
        return 0;
    }
}

+ (NSString *)nameForEventType:(RMEventType)type
{
    switch (type) {
        case RMEventMissionStart: return @"RMEventMissionStart"; break;
        case RMEventPickedUp: return @"RMEventPickedUp"; break;
        case RMEventPutDown: return @"RMEventPutDown"; break;
        case RMEventTickle: return @"RMEventTickle"; break;
        case RMEventPoke: return @"RMEventPoke"; break;
        case RMEventPokeAnywhere: return @"RMEventPokeAnywhere"; break;
        case RMEventTime: return @"RMEventTime"; break;
        case RMEventHearsLoudSound: return @"RMEventHearsLoudSound"; break;
        case RMEventFaceAppear: return @"RMEventFaceAppear"; break;
        case RMEventFaceDisappear: return @"RMEventFaceDisappear"; break;
        case RMEventShake: return @"RMEventShake"; break;
        case RMEventDock: return @"RMEventDock"; break;
        case RMEventUndock: return @"RMEventUndock"; break;
        case RMEventFavoriteColor: return @"RMEventFavoriteColor"; break;
        case RMEventLightsOff: return @"RMEventLightsOff"; break;
        case RMEventLightsOn: return @"RMEventLightsOn"; break;
        case RMEventSeesMotion: return @"RMEventSeesMotion"; break;
        case RMEventStasis: return @"RMEventStasis"; break;
        default: return nil;
    }
}

- (NSSet *)requiredVisionModules
{
    switch (self.type) {
        case RMEventFaceAppear:
        case RMEventFaceDisappear:
            return [NSSet setWithObjects:RMVisionModule_FaceDetection, nil];
            break;
            
        case RMEventSeesMotion:
            return [NSSet setWithObjects:@"RMVisionModule_MotionDetection", nil];
            break;
            
        case RMEventLightsOn:
        case RMEventLightsOff:
            return [NSSet setWithObjects:@"RMVisionModule_BrightnessMetering", nil];
            break;
            
        case RMEventFavoriteColor:
            return [NSSet setWithObjects:@"RMVisionModule_HueDetection", nil];
            break;
            
        case RMEventStasis:
            return [NSSet setWithObjects:@"RMVisionModule_StasisDetection", nil];
            break;
            
        default: return nil;
    }
}

- (NSString *)readableName
{
    NSString *parameterUnits = self.parameter.units;
    NSString *parameterTitle = [NSString stringWithFormat:@"%@%@",(self.parameter.value ? self.parameter.value : @"•••"), (parameterUnits.length ? parameterUnits : @"")];
    
    NSString *readableName = [RMEvent readableNameForEventType:self.type];
    
    NSRange parameterRange = [readableName rangeOfString:@"$"];
    if (self.parameter.type == RMParameterRomoPoke
        || self.parameter.type == RMParameterRomoTickle) {
        parameterTitle = [[NSBundle mainBundle] localizedStringForKey:parameterTitle value:parameterTitle table:@"Extras"];
    }
    
    if (parameterRange.length) {
        readableName = [readableName stringByReplacingOccurrencesOfString:@"$" withString:parameterTitle];
    }
    
    return readableName;
}

- (NSString *)shortName
{
    NSString *parameterUnits = self.parameter.units;
    NSString *parameterTitle = [NSString stringWithFormat:@"%@%@",(self.parameter.value ? self.parameter.value : @"•••"), (parameterUnits.length ? parameterUnits : @"")];
    
    NSString *readableName =  [RMEvent shortNameForEventType:self.type];

    NSRange parameterRange = [readableName rangeOfString:@"$"];
    if (parameterRange.length) {
        readableName = [readableName stringByReplacingOccurrencesOfString:@"$" withString:parameterTitle];
    }
    
    return readableName;
}

- (NSString *)parameterlessName
{
    switch (self.type) {
        case RMEventMissionStart: return NSLocalizedString(@"Event-ParameterlessName-MissionStart", @"Mission start"); break;
        case RMEventPickedUp: return NSLocalizedString(@"Event-ParameterlessName-PickedUp", @"Picked up"); break;
        case RMEventPutDown: return NSLocalizedString(@"Event-ParameterlessName-PutDown", @"Put down"); break;
        case RMEventTickle: return NSLocalizedString(@"Event-ParameterlessName-Tickle", @"Tickle"); break;
        case RMEventPoke: return NSLocalizedString(@"Event-ParameterlessName-Poke", @"Poke"); break;
        case RMEventPokeAnywhere: return NSLocalizedString(@"Event-ParameterlessName-PokeAnywhere", @"Poke"); break;
        case RMEventTime: return NSLocalizedString(@"Event-ParameterlessName-Time", @"Time"); break;
        case RMEventHearsLoudSound: return NSLocalizedString(@"Event-ParameterlessName-HearsLoudSound", @"Loud sound"); break;
        case RMEventFaceAppear: return NSLocalizedString(@"Event-ParameterlessName-FaceAppear", @"See a Face"); break;
        case RMEventFaceDisappear: return NSLocalizedString(@"Event-ParameterlessName-FaceDisappear", @"No Face"); break;
        case RMEventShake: return NSLocalizedString(@"Event-ParameterlessName-Shake", @"Shake"); break;
        case RMEventDock: return NSLocalizedString(@"Event-ParameterlessName-Dock", @"Dock"); break;
        case RMEventUndock: return NSLocalizedString(@"Event-ParameterlessName-Undock", @"Undock"); break;
        case RMEventFavoriteColor: return NSLocalizedString(@"Event-ParameterlessName-FavoriteColor", @"Favorite color"); break;
        case RMEventLightsOff: return NSLocalizedString(@"Event-ParameterlessName-LightsOff", @"Lights off"); break;
        case RMEventLightsOn: return NSLocalizedString(@"Event-ParameterlessName-LightsOn", @"Lights on"); break;
        case RMEventSeesMotion: return NSLocalizedString(@"Event-ParameterlessName-SeesMotion", @"Movement"); break;
        case RMEventStasis: return NSLocalizedString(@"Event-ParameterlessName-Stasis", @"Stuck"); break;
        default: return nil;
    }
}

+ (NSString *)readableNameForEventType:(RMEventType)type
{
    switch (type) {
        case RMEventMissionStart: return NSLocalizedString(@"Event-ReadableName-MissionStart", @"After you slide to start"); break;
        case RMEventPickedUp: return NSLocalizedString(@"Event-ReadableName-PickedUp", @"When I'm picked up"); break;
        case RMEventPutDown: return NSLocalizedString(@"Event-ReadableName-PutDown", @"When I'm put down"); break;
        case RMEventTickle: return NSLocalizedString(@"Event-ReadableName-Tickle", @"When you tickle my $"); break;
        case RMEventPoke: return NSLocalizedString(@"Event-ReadableName-Poke", @"When you poke my $"); break;
        case RMEventPokeAnywhere: return NSLocalizedString(@"Event-ReadableName-PokeAnywhere", @"When you poke me"); break;
        case RMEventTime: return NSLocalizedString(@"Event-ReadableName-Time", @"When it's $"); break;
        case RMEventHearsLoudSound: return NSLocalizedString(@"Event-ReadableName-HearsLoudSound", @"When I hear a loud sound"); break;
        case RMEventFaceAppear: return NSLocalizedString(@"Event-ReadableName-FaceAppear", @"When I see a face"); break;
        case RMEventFaceDisappear: return NSLocalizedString(@"Event-ReadableName-FaceDisappear", @"When I don't see a face"); break;
        case RMEventShake: return NSLocalizedString(@"Event-ReadableName-Shake", @"When you shake me"); break;
        case RMEventDock: return NSLocalizedString(@"Event-ReadableName-Dock", @"When you dock me"); break;
        case RMEventUndock: return NSLocalizedString(@"Event-ReadableName-Undock", @"When you undock me"); break;
        case RMEventFavoriteColor: return NSLocalizedString(@"Event-ReadableName-FavoriteColor", @"When I see my favorite color"); break;
        case RMEventLightsOff: return NSLocalizedString(@"Event-ReadableName-LightsOff", @"When the lights turn off"); break;
        case RMEventLightsOn: return NSLocalizedString(@"Event-ReadableName-LightsOn", @"When the lights turn on"); break;
        case RMEventSeesMotion: return NSLocalizedString(@"Event-ReadableName-SeesMotion", @"When I see movement"); break;
        case RMEventStasis: return NSLocalizedString(@"Event-ReadableName-Stasis", @"When I get stuck"); break;
        default: return nil;
    }
}

+ (NSString *)shortNameForEventType:(RMEventType)type
{
    switch (type) {
        case RMEventMissionStart: return NSLocalizedString(@"Event-ShortName-MissionStart", @"Mission start"); break;
        case RMEventPickedUp: return NSLocalizedString(@"Event-ShortName-PickedUp", @"Picked up"); break;
        case RMEventPutDown: return NSLocalizedString(@"Event-ShortName-PutDown", @"Put down"); break;
        case RMEventTickle: return NSLocalizedString(@"Event-ShortName-Tickle", @"Tickle my $"); break;
        case RMEventPoke: return NSLocalizedString(@"Event-ShortName-Poke", @"Poke my $"); break;
        case RMEventPokeAnywhere: return NSLocalizedString(@"Event-ShortName-PokeAnywhere", @"Poke me"); break;
        case RMEventTime: return NSLocalizedString(@"Event-ShortName-Time", @"At $"); break;
        case RMEventHearsLoudSound: return NSLocalizedString(@"Event-ShortName-HearsLoudSound", @"Loud sound"); break;
        case RMEventFaceAppear: return NSLocalizedString(@"Event-ShortName-FaceAppear", @"Face"); break;
        case RMEventFaceDisappear: return NSLocalizedString(@"Event-ShortName-FaceDisappear", @"No face"); break;
        case RMEventShake: return NSLocalizedString(@"Event-ShortName-Shake", @"Shake"); break;
        case RMEventDock: return NSLocalizedString(@"Event-ShortName-Dock", @"Dock me"); break;
        case RMEventUndock: return NSLocalizedString(@"Event-ShortName-Undock", @"Undock me"); break;
        case RMEventFavoriteColor: return NSLocalizedString(@"Event-ShortName-FavoriteColor", @"Favorite color"); break;
        case RMEventLightsOff: return NSLocalizedString(@"Event-ShortName-LightsOff", @"Lights off"); break;
        case RMEventLightsOn: return NSLocalizedString(@"Event-ShortName-LightsOn", @"Lights on"); break;
        case RMEventSeesMotion: return NSLocalizedString(@"Event-ShortName-SeesMotion", @"Movement"); break;
        case RMEventStasis: return NSLocalizedString(@"Event-ShortName-Stasis", @"Stuck"); break;
        default: return nil;
    }
}

+ (int)maximumCountForEventType:(RMEventType)type
{
    switch (type) {
        case RMEventMissionStart: return 1; break;
        case RMEventPickedUp: return 1; break;
        case RMEventPutDown: return 1; break;
        case RMEventTickle: return 3; break;
        case RMEventPoke: return 4; break;
        case RMEventPokeAnywhere: return 1; break;
        case RMEventTime: return 1440; break;
        case RMEventHearsLoudSound: return 1; break;
        case RMEventFaceAppear: return 1; break;
        case RMEventFaceDisappear: return 1; break;
        case RMEventShake: return 1; break;
        case RMEventDock: return 1; break;
        case RMEventUndock: return 1; break;
        default: return 1;
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<RMEvent: (%d) %@; Parameter = %@; repeats ? %@>",self.type,[RMEvent readableNameForEventType:self.type],self.parameter,self.repeats ? @"YES" : @"NO"];
}

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[RMEvent class]]) {
        RMEvent *otherEvent = (RMEvent *)object;
        BOOL sameType = self.type == otherEvent.type;
        BOOL sameParameterType = self.parameter.type == otherEvent.parameter.type;
        BOOL sameParameterValue = [self.parameter.value isEqual:otherEvent.parameter.value];
        BOOL nilParameterValues = (self.parameter.value == nil) && (otherEvent.parameter.value == nil);
        return sameType && sameParameterType && (sameParameterValue || nilParameterValues);
    }
    return NO;
}

#pragma mark - Private Methods

- (RMParameterType)parameterTypeForEventType:(RMEventType)type
{
    switch (type) {
        case RMEventTickle: return RMParameterRomoTickle; break;
        case RMEventPoke: return RMParameterRomoPoke; break;
        case RMEventTime: return RMParameterTime; break;
        default: return -1;
    }
}

@end
