//
//  RMRomo.h
//  Romo
//

#import <Foundation/Foundation.h>
#import <Romo/RMCharacter.h>
#import <Romo/RMCore.h>
#import <Romo/RMVision.h>
#import "RMEquilibrioception.h"
#import "RMLoudSoundDetector.h"
#import "RMRomotion.h"
#import "RMVitals.h"
#import "RMTouch.h"
#import "RMVoice.h"

@protocol RMRomoDelegate;

#define enableRomotions(enabled, Romo) (Romo.allowedInterruptions = (enabled ? enableInterruption(RMRomoInterruptionRomotion, Romo.allowedInterruptions) : disableInterruption(RMRomoInterruptionRomotion, Romo.allowedInterruptions)))

/**
 Functionality of perception and action
 */
typedef enum {
    RMRomoFunctionalityCharacter         = 1 << 0,
    RMRomoFunctionalityEquilibrioception = 1 << 1,
    RMRomoFunctionalityBroadcasting      = 1 << 2,
    RMRomoFunctionalityVision            = 1 << 3,
    RMRomoFunctionalityLoudSound         = 1 << 4,
    RMRomoFunctionalityAll               = 0xFFFFFFFF,
    RMRomoFunctionalityNone              = 0
} RMRomoFunctionalities;

/**
 Real-time interruptions triggered by various events
 */
typedef enum {
    /** Only true if RMRomoFeatureEquilibrioception is true */
    RMRomoInterruptionSelfRighting      = 1 << 0,
    /** Animates to show the unlocking of new expressions */
    RMRomoInterruptionCharacterUnlocks  = 1 << 1,
    /** Pushes to firmware updating controller */
    RMRomoInterruptionFirmwareUpdating  = 1 << 2,
    /** Changes character's emotion for wakefulness changes */
    RMRomoInterruptionWakefulness       = 1 << 3,
    /** Performs Romotions when expressing */
    RMRomoInterruptionRomotion          = 1 << 4,
    /** Becomes dizzy when spun */
    RMRomoInterruptionDizzy             = 1 << 5,
    /** Bitmask for all interruption types */
    RMRomoInterruptionAll               = 0xFFFFFFFF,
    RMRomoInterruptionNone              = 0
} RMRomoInterruptions;

/**
 Given a desired functionality and a bit mask of allowed functionalities
 Returns whether the desired functionality is allowed
 */
#define isFunctionalityActive(functionality, bitMask) ((BOOL)((functionality) & (bitMask)))

/**
 Given a desired interruption and a bit mask of allowed interruptions
 Returns whether the desired interruption is allowed
 */
#define allowsRomoInterruption(interruption, bitMask) ((BOOL)((interruption) & (bitMask)))

/**
 Enables the functionality on the bit mask
 Returns a new bit mask with the functionality included
 */
#define enableFunctionality(functionality, bitMask) ((RMRomoFunctionalities)((functionality) | (bitMask)))

/**
 Disables the functionality from the bit mask
 Returns a new bit mask without the functionality
 */
#define disableFunctionality(functionality, bitMask) ((RMRomoFunctionalities)(~(functionality) & (bitMask)))

/**
 Enables the interruption on the bit mask
 Returns a new bit mask with the interruption included
 */
#define enableInterruption(interruption, bitMask) ((RMRomoInterruptions)((interruption) | (bitMask)))

/**
 Disables the interruption from the bit mask
 Returns a new bit mask without the interruption
 */
#define disableInterruption(interruption, bitMask) ((RMRomoInterruptions)(~(interruption) & (bitMask)))

/**
 @brief Romo, the living creature
 
 RMRomo incorporates every system that Romo has, from the robot base to the character;
 from the perception of balance to vitals.
 */
@interface RMRomo : NSObject <RMCharacterDelegate, RMEquilibrioceptionDelegate, RMTouchDelegate, RMVitalsDelegate, RMLoudSoundDetectorDelegate>

@property (nonatomic, weak) id<RMRomoDelegate, RMTouchDelegate, RMVisionDelegate, RMCharacterDelegate, RMEquilibrioceptionDelegate, RMLoudSoundDetectorDelegate> delegate;
@property (nonatomic, readonly) RMCoreRobotRomo3 *robot;
@property (nonatomic, readonly) RMCharacter *character;

/**
 When set, toggles on or off the appropriate systems of Romo
 e.g. RMRomoFunctionalityWakefulness | RMRomoFunctionalityBroadcasting
 */
@property (nonatomic) RMRomoFunctionalities activeFunctionalities;

/**
 Before Romo will interrupt (with either a character action or robot action),
 this bitmask is checked
 e.g. RMRomoInterruptionSelfRighting | RMRomoInterruptionFirmwareUpdating
 */
@property (nonatomic) RMRomoInterruptions allowedInterruptions;

/**
 Sensory input and core systems
 */
@property (nonatomic) RMVision *vision;
@property (nonatomic, readonly) RMEquilibrioception *equilibrioception;
@property (nonatomic, readonly) RMLoudSoundDetector *loudSoundDetector;
@property (nonatomic, readonly) RMVoice *voice;
@property (nonatomic, readonly) RMRomotion *romotions;
@property (nonatomic, readonly) RMTouch *touch;
@property (nonatomic, readonly) RMVitals *vitals;

/**
 @returns whether or not the robot is in a state where he should be driven
 Should always be polled before sending motor commands to Romo
 */
@property (nonatomic, readonly) BOOL RomoCanDrive;

/**
 @returns whether or not the character can move his pupils
 */
@property (nonatomic, readonly) BOOL RomoCanLook;

/** The persistent name of this Romo */
@property (nonatomic, strong) NSString *name;

@end

/**
 @brief A protocol of optional methods to receive messages from RMRomo
 */
@protocol RMRomoDelegate <NSObject>

/**
 View for displaying elements including RMCharacter or RUIVoice
 If not implemented, the Romo character will not be displayed or usable
 */
- (UIView *)characterView;

@end

/**
 NSNotification posted from an RMRomo, when the Romo's name is changed.
 */
extern NSString *const RMRomoDidChangeNameNotification;
