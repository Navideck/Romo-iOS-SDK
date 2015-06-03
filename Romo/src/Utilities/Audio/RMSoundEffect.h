//
//  RMSoundEffect.h
//  Romo
//

#import <Foundation/Foundation.h>

#define generalButtonSound          @"General-Button-Continue"
#define backButtonSound             @"Missions-Editor-Back"
#define unlockButtonSound           @"Missions-Debriefing-Unlocked"
#define deleteSwipeButtonSound      @"Missions-Editor-Swipe-Delete"
#define deleteUnswipeButtonSound    @"Missions-Editor-Unswipe-Delete"
#define deleteButtonSound           @"Missions-Editor-Delete"
#define characterDismissSound       @"Info-Button"
#define creatureNoSound             @"Creature-No"
#define creaturePowerUpSound        @"Creature-Power-Up"
#define creaturePowerDownSound      @"Creature-Power-Down"
#define spaceLoopSound              @"Spaceloop"
#define romoJingle                  @"RomoJingle"
#define threeTwoOneCountdownSound   @"Creature-3-2-1"
#define kNumSwishSounds             6
#define kNumPokeSounds              8

@interface RMSoundEffect : NSObject

@property (nonatomic, readonly) NSString *name;

/** When true, loops the track */
@property (nonatomic) BOOL repeats;

/** The gain of the audio source */
@property (nonatomic) CGFloat gain;

/** The duration, in seconds */
@property (nonatomic, readonly) float duration;

/**
 Interface for playing a foreground or background effect. Only one of each may be playing at
 any given time.
 */
+ (void)playForegroundEffectWithName:(NSString *)name repeats:(BOOL)repeats gain:(CGFloat)gain;
+ (void)playBackgroundEffectWithName:(NSString *)name repeats:(BOOL)repeats gain:(CGFloat)gain;

/** Stop either the foreground or background effect. This is useful for stopping looping effects */
+ (void)stopForegroundEffect;
+ (void)stopBackgroundEffect;

/**
 Creates a sound effect with a file of this name.
 
 Note that when the RMSoundEffect is dealloc'ed the sound will abruptly stop. You need to hold
 onto the RMSoundEffect that is returned for the duration of the sound.
 */
+ (instancetype)effectWithName:(NSString *)name;

/**
 Creates a sound effect with a file of this name.
 
 Note that when the RMSoundEffect is dealloc'ed the sound will abruptly stop. You need to hold
 onto the RMSoundEffect that is returned for the duration of the sound.
 */
- (instancetype)initWithName:(NSString *)name;

/** Plays the sound effect from the beginning */
- (void)play;

/** Pauses the sound effect */
- (void)pause;

/** Call to initialize OpenAL */
+ (void)startup;

/** Match all startup calls with shutdown */
+ (void)shutdown;

@end

/**
 Key in NSUserDefaults for accessing sound effects preference
 Defaults to YES
 */
extern NSString *const soundEffectsEnabledKey;

extern NSString *const RMSoundEffectDidBeginNotification;
extern NSString *const RMSoundEffectDidFinishNotification;
