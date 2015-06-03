//
//  RMParameter.h
//  Romo
//

#import <Foundation/Foundation.h>

typedef enum {
    // Action Parameters
    RMParameterDuration = 1, // float number of seconds, "(duration)"
    RMParameterDistance, // float number of cm, "(distance)"
    RMParameterExpression, // int for expression type, "(expression)"
    RMParameterEmotion, // int for emotion type, "(expression)"
    RMParameterSpeed, // int percentage, e.g. 50% speed, "(speed)"
    RMParameterLightBrightness, // int percentage, e.g. 75% brightness, "(lightBrightness)"
    RMParameterAngle, // int angle in degrees, e.g. 90 degrees, "(angle)"
    RMParameterText, // ASCII text, like "Hello"
    RMParameterSong, // mpmediaitem unique id, "(song)"
    RMParameterTurnDirection, // BOOL for clockwise, "(direction)"
    RMParameterLookPoint, // NSString representation of a CGPoint, @"x, y", "(pointValue)"
    RMParameterRadius, // float number of cm, "(radius)"
    RMParameterDoodle, // a representation of a doodle using an RMDoodle, "(doodle)"
    RMParameterColor, // a UIColor*, "(color)"
    
    // Event Parameters
    RMParameterRomoPoke, // "(romoPoke)"
    RMParameterRomoTickle, // "(romoTickle)"
    RMParameterTime, // time of day, e.g. 8:30, "(time)"

    RMParameterCount
} RMParameterType;

/** A model for representing method's parameters */
@interface RMParameter : NSObject

/** The parameter value type, e.g. duration or percentage */
@property (nonatomic, readonly) RMParameterType type;

/** Name of the parameter, e.g. "tiltAngle" */
@property (nonatomic, readonly) NSString *name;

/** Returns different type of object depending on parameter type */
@property (nonatomic, strong) id value;

@property (nonatomic, readonly) NSString *units;

/** Returns expected values if the options are a finite list */
@property (nonatomic, readonly) NSArray *valueOptions;

/** Creates a parameter from a parameter type */
- (RMParameter *)initWithType:(RMParameterType)type;

/** Creates a parameter from a properly-formatted string */
- (RMParameter *)initFromString:(NSString *)string;

/**
 Given an array of valid values for this parameter
 Returns a new parameter option or nil if all were included in values
 */
- (id)appropriateValueExcludingValues:(NSArray *)values;

@end
