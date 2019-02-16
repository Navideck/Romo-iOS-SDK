//
//  RMEvent.h
//  Romo
//

#import <Foundation/Foundation.h>
#import <Romo/RMVision.h>

#define RMEventDidOccurNotification @"RMEventDidOccurNotification"

@class RMParameter;

typedef enum {
    RMEventMissionStart = 1,
    RMEventPickedUp = 2,
    RMEventPutDown = 3,
    RMEventTickle = 4,
    RMEventPoke = 5,
    RMEventPokeAnywhere = 6,
    RMEventTime = 7,
    RMEventFaceAppear = 8,
    RMEventFaceDisappear = 9,
    RMEventShake = 10,
    RMEventDock = 11,
    RMEventUndock = 12,
    RMEventHearsLoudSound = 13,
    RMEventSeesMotion = 14,
    RMEventStasis = 15,
    RMEventLightsOff = 16,
    RMEventLightsOn = 17,
    RMEventFavoriteColor = 18,
    
    RMEventCount,
} RMEventType;

/** Events that occur in Romo's environment */
@interface RMEvent : NSObject <NSCopying>

/** The event type */
@property (nonatomic) RMEventType type;

/** Parameter for this Event */
@property (nonatomic, strong, readonly) RMParameter *parameter;

/** 
 Returns a lengthier name that is user-readable
 Fills in each parameter with the appropriate value
 e.g. "When you poke my left eye"
 */
@property (nonatomic, strong, readonly) NSString *readableName;

/**
 Returns a shorter name with parameters
 e.g. "Poke my left eye"
 */
@property (nonatomic, strong, readonly) NSString *shortName;

/**
 Returns a very short name without parameters
 e.g. "Poke me"
 */
@property (nonatomic, strong, readonly) NSString *parameterlessName;

/**
 A set of RMVisionModule keys for modules needed by this event
 e.g. RMEventFaceAppear -> FaceDetectionKey
 */
@property (nonatomic, strong, readonly) NSSet *requiredVisionModules;

@property (nonatomic) BOOL repeats;

/** 
 Creates an Event with the appropriate type and parameters
 e.g. "RMEventPickedUp" creates an event of type RMEventPickedUp with nil parameters
 e.g. "RMEventPoke:(romoChin)" creates a RMEventPoke event with RMParameterRomoChin
 */
- (RMEvent *)initWithName:(NSString *)name;

/** Creates an Event with the appropriate parameters */
- (RMEvent *)initWithType:(RMEventType)type;

/** 
 Returns the RMEventType that the name corresponds to
 e.g. @"RMEventTypeEyePoke" => RMEventTypeEyePoke
 */
+ (RMEventType)eventTypeForName:(NSString *)name;

/** 
 Returns the name for the RMEventType
 e.g. RMEventTypeEyePoke => @"RMEventTypeEyePoke"
 */
+ (NSString *)nameForEventType:(RMEventType)type;

/**
 Returns a lengthier name that is user-readable
 Places a "$" for each parameter
 e.g. "When you poke Romo's $"
 */
+ (NSString *)readableNameForEventType:(RMEventType)type;

/**
 Given all possible paramters, this is the maximum number of this type of event that is unique
 e.g. "Mission Start" -> 1
 e.g. "Poke" -> 5 (forehead, left eye, right eye, nose, chin)
 */
+ (int)maximumCountForEventType:(RMEventType)type;

@end
