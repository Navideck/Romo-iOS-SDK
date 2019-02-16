//==============================================================================
//                             _
//                            | | (_)
//   _ __ ___  _ __ ___   ___ | |_ ___   _____
//  | '__/ _ \| '_ ` _ \ / _ \| __| \ \ / / _ \
//  | | | (_) | | | | | | (_) | |_| |\ V /  __/
//  |_|  \___/|_| |_| |_|\___/ \__|_| \_/ \___|
//
//==============================================================================
//
//  RMCharacter.h
//  RMCharacter
//
//==============================================================================
/** @file RMCharacter.h
 @brief Public header for creating and interfacing with an RMCharacter.
 
 Contains the RMCharacter interface, a few helpful types for interfacing with
 RMCharacter, and RMCharacterDelegate for receiving events from an instantiated
 character.
 */
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

/** Macro for creating RMPoint3D structs */
#define RMPoint3DMake(x,y,z) ((RMPoint3D){(x),(y),(z)})

/**
 Simple data type to represent what type of chara
 
 Each character has it's own emotions, expressions, personality, and voice.
 */
typedef enum {
    /// Romo, the curious blue robot
    RMCharacterRomo,
} RMCharacterType;

/**
 Emotions are persistent emotional states
 
 When you set the RMCharacterEmotion of an RMCharacter, it will
 stay in that emotional state until it receives another request to change
 its RMCharacterEmotion.
 */
typedef enum {
    /// The character is in a bewildered state
    RMCharacterEmotionBewildered         = 9,
    /// The character is in a curious state
    RMCharacterEmotionCurious            = 1,
    /// The character is in a delighted state
    RMCharacterEmotionDelighted          = 10,
    /// The character is in an excited state
    RMCharacterEmotionExcited            = 2,
    /// The character is in a happy state
    RMCharacterEmotionHappy              = 3,
    /// The character is in an indifferent state
    RMCharacterEmotionIndifferent        = 8,
    /// The character is in a sad state
    RMCharacterEmotionSad                = 4,
    /// The character is in a scared state
    RMCharacterEmotionScared             = 5,
    /// The character is in a sleepy state
    RMCharacterEmotionSleepy             = 6,
    /// The character is sleeping
    RMCharacterEmotionSleeping           = 7
} RMCharacterEmotion;

/**
 Expressions are briefly animated actions
 
 Each RMCharacterExpression represents a type of animation that the
 robot will briefly express
 */
typedef enum {
    /// The character is not expressing anything
    RMCharacterExpressionNone            = 0,
    /// The character becomes angry
    RMCharacterExpressionAngry           = 1,
    /// The character gets bewildered
    RMCharacterExpressionBewildered      = 27,
    /// The character gets bored
    RMCharacterExpressionBored           = 2,
    /// The character lets out a big laugh
    RMCharacterExpressionChuckle         = 21,
    /// The character expresses curiosity
    RMCharacterExpressionCurious         = 3,
    /// The character gets dizzy
    RMCharacterExpressionDizzy           = 4,
    /// The character becomes embarassed
    RMCharacterExpressionEmbarrassed     = 5,
    /// The character gets really excited
    RMCharacterExpressionExcited         = 6,
    /// The character becomes exhausted
    RMCharacterExpressionExhausted       = 7,
    /// The character becomes exhausted
    RMCharacterExpressionFart            = 26,
    /// The character gets happy
    RMCharacterExpressionHappy           = 8,
    /// The character hiccups
    RMCharacterExpressionHiccup          = 25,
    /// The character holds his breath
    RMCharacterExpressionHoldingBreath   = 9,
    /// The character laughs
    RMCharacterExpressionLaugh           = 10,
    /// The character gets disappointed & sad
    RMCharacterExpressionLetDown         = 23,
    /// The character looks around
    RMCharacterExpressionLookingAround   = 11,
    /// The character falls in love
    RMCharacterExpressionLove            = 12,
    /// The character thinks about something
    RMCharacterExpressionPonder          = 13,
    /// The character lets out a warm smile
    RMCharacterExpressionProud           = 22,
    /// The character gets sad
    RMCharacterExpressionSad             = 14,
    /// The character gets scared
    RMCharacterExpressionScared          = 15,
    /// The character becomes sleepy
    RMCharacterExpressionSleepy          = 16,
    /// The character smacks into the screen
    RMCharacterExpressionSmack           = 30,
    /// The character sneezes
    RMCharacterExpressionSneeze          = 17,
    /// The character sniffs something
    RMCharacterExpressionSniff           = 29,
    /// The character gets scared
    RMCharacterExpressionStartled        = 20,
    /// The character struggles to move
    RMCharacterExpressionStruggling      = 32,
    /// The character starts babbling
    RMCharacterExpressionTalking         = 18,
    /// The character makes an "oooh" face
    RMCharacterExpressionWant            = 24,
    /// The character makes an "Wee" face
    RMCharacterExpressionWee             = 31,
    /// The character yawns
    RMCharacterExpressionYawn            = 19,
    /// The character makes a "Yippee!"
    RMCharacterExpressionYippee          = 28
} RMCharacterExpression;

/**
 @struct RMPoint3D
 @brief A helper data type for reasoning about 3-Dimensional cartesian space
 within the RMCharacter framework
 @var RMPoint3D::x
 The X-axis component of the point
 @var RMPoint3D::y
 The Y-axis component of the point
 @var RMPoint3D::z
 The Z-axis component of the point
 */
typedef struct {
    CGFloat x;
    CGFloat y;
    CGFloat z;
} RMPoint3D;

@protocol RMCharacterDelegate;

/**
 @brief RMCharacter is the public interface for creating characters and
 interfacing with them.
 
 An RMCharacter object represents a socially-embodied creature that will
 respond to events from a programmer while still maintaining an "illusion of
 life". RMCharacter is meant to abstract away many problems that arise when
 designing software for social robots, such as animation and gaze. After
 instantiating an RMCharacter object with a specific type (and setting its
 delegate), it can be added to a superview where the character will be
 displayed. The RMCharacter object is now ready to accept expressions,
 animations, and gaze / eye commands.
 */
@interface RMCharacter : NSObject

/**
 The delegate to which RMCharacter will send all events
 */
@property (nonatomic, weak) id<RMCharacterDelegate> delegate;

/**
 The type of character contained within this instance
 */
@property (nonatomic, readonly) RMCharacterType characterType;

/**
 The total number of available RMCharacterEmotions
 */
@property (nonatomic, readonly) unsigned int numberOfEmotions;

/**
 The total number of available RMCharacterExpressions
 */
@property (nonatomic, readonly) unsigned int numberOfExpressions;

/**
 Creates an RMCharacter object given a specified character type
 
 @param characterType The specific type of character to initialize
 @returns An instantiated RMCharacter object with the given type
 */
+ (RMCharacter *)characterWithType:(RMCharacterType)characterType;

/**
 Helper method for creating a Romo RMCharacter object
 
 @returns An instantiated RMCharacter object with type RMCharacterRomo
 */
+ (RMCharacter *)Romo;

/**
 Adds a view displaying the character to a given superview. The view containing
 the character will automatically scale to fit the device's screen.
 
 @param superview The parent view in which to contain the character's view.
 */
- (void)addToSuperview:(UIView *)superview;

/**
 Removes the character's view from its superview.
 */
- (void)removeFromSuperview;

/// @name Animation (Expressions and Emotions)

/**
 The current persistent emotional state of the character
 
 Setting the emotion transitions and remains in the emotion until explicitly
 changed to another emotion.
 
 Getting the emotion indicates which emotional state the character is currently
 in.
 */
@property (nonatomic) RMCharacterEmotion emotion;

/**
 The current expression (if any) that the character is expressing
 
 Setting the expression commands the robot to briefly express one of the
 RMCharacterExpression values. After this expression is finished, the character
 will transition back to the current emotion.
 
 Getting the expression returns the current
 expression (or RMCharacterExpressionNone when not expressing).
 */
@property (nonatomic) RMCharacterExpression expression;

/**
 Sets the character's expression and transitions to a specified emotion after
 the expression is finished.
 
 @param expression The expression to perform.
 @param emotion The emotion to transition to after performing the expression.
 */
- (void)setExpression:(RMCharacterExpression)expression
          withEmotion:(RMCharacterEmotion)emotion;

/** @name Eye / Gaze System */

/**
 A float in the range [0.5, 1.25] for adjusting the dilation of Romo's pupils.
 
 The value will be internally clamped between 0.5 and 1.25.
 */
@property (nonatomic) CGFloat pupilDilation;

/**
 A float in the range [-15, 15] representing rotation of the character's face
 
 The value will be internally clamped between -15 and 15. Setting this to 15
 from 0 results in the character's face rotating clockwise from the
 character's perspective.
 */
@property (nonatomic) CGFloat faceRotation;

/**
 A boolean value representing the state of the character's left eye.
 
 Read this property to determine whether the character's left eye is open, and
 set it to directly change the state of the character's left eye.
 */
@property (nonatomic) BOOL leftEyeOpen;

/**
 A boolean value representing the state of the character's right eye.
 
 Read this property to determine whether the character's right eye is open, and
 set it to directly change the state of the character's right eye.
 */
@property (nonatomic) BOOL rightEyeOpen;

/**
 An RMPoint3D of where the character's looking.
 
 Calling lookAtPoint:animated: sets this value, but the character also changes
 gaze automatically.
 */
@property (nonatomic, readonly) RMPoint3D gaze;

/**
 Combined setter for changing the state of both eyes.
 
 Guarantees that the state of both eyes are changed at the same time.
 
 @param leftEyeOpen YES if the character should set its left eye to be open,
 NO for closed
 @param rightEyeOpen YES if the character should set its right eye to be open,
 NO for closed
 */
- (void)setLeftEyeOpen:(BOOL)leftEyeOpen
          rightEyeOpen:(BOOL)rightEyeOpen;

/**
 Tells the character to look at a specified point.
 
 @param point An RMPoint3D specifying where the character should look.
 When setting the gaze location:
 - x and y values are clamped to the interval [-1, 1]
 - z values are clamped to the interval [0, 1]
 - Negative x values look left, positive x values look right
 - Negative y values look up, positive y values look down
 - Smaller z values converge the eyes to look closer, while larger z values
 diverge eyes toward a parallel gaze
 
 @param animated YES if the character should animate the gaze change, NO for an
 immediate jump of the pupils.
 */
- (void)lookAtPoint:(RMPoint3D)point
           animated:(BOOL)animated;

/**
 Tells the character to look at its default location (straight ahead).
 */
- (void)lookAtDefault;

/**
 The character says a particular utterance
 */
- (void)say:(NSString *)utterance;

/**
 The character makes a short mumbling expression
 */
- (void)mumble;

/**
 The number of expressions that the character is capable of
 */
+ (unsigned int)numberOfExpressions;

/**
 The number of emotions that the character is capable of
 */
+ (unsigned int)numberOfEmotions;

/*
 A helper method to map human-readable strings to RMCharacterExpressions

 This method takes in any string that is appended to an RMCharacterExpression
 and returns the corresponding enum value. The string can be in any capitalization
 and can contain "-", "_", or " " as a separator in multi-word expressions
 (e.g. "looking-around").
 */
+ (RMCharacterExpression)mapReadableNameToExpression:(NSString *)name;

/*
 A helper method to map human-readable strings to RMCharacterExpressions
 
 This method takes in any string that is appended to an RMCharacterEmotion
 and returns the corresponding enum value. The string can be capitalized
 in any way.
 */
+ (RMCharacterEmotion)mapReadableNameToEmotion:(NSString *)name;

- (void)setFillColor:(UIColor *)fillColor percentage:(float)percentage;

@end

/**
 @brief A protocol for receiving messages from an RMCharacter object
 
 This protocol handles receiving all messages from an RMCharacter
 object. Currently indicates when an expression has begun and when it has
 finished.
 */
@protocol RMCharacterDelegate <NSObject>

/**
 Delegate method that is triggered when an expression or emotion begins.
 */
- (void)characterDidBeginExpressing:(RMCharacter *)character;

/**
 Delegate method that is triggered when an expression completes execution.
 */
- (void)characterDidFinishExpressing:(RMCharacter *)character;

@end

/**
 NSNotification posted from a character, when an expression or emotion begins.
 */
extern NSString *const RMCharacterDidBeginExpressingNotification;

/**
 NSNotification posted from a character, when an expression or emotion finishes.
 */
extern NSString *const RMCharacterDidFinishExpressingNotification;

/**
 NSNotification posted from a character, when audio begins, like expressions or blinks.
 */
extern NSString *const RMCharacterDidBeginAudioNotification;

/**
 NSNotification posted from a character, when audio finishes.
 */
extern NSString *const RMCharacterDidFinishAudioNotification;
