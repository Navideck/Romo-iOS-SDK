//
//  RMLoudSoundDetector.m
//  Romo
//

#import "RMLoudSoundDetector.h"
#import "RMRealtimeAudio.h"
#import <UIKit/UIKit.h>
#import <Romo/RMDispatchTimer.h>
#import <Romo/RMCharacter.h>
#import "RMSoundEffect.h"

#ifdef SOUND_DEBUG
#define LOG(...) DDLogWarn(__VA_ARGS__)
#else
#define LOG(...)
#endif //SOUND_DEBUG

/** A loud sound must have a higher peak than this value */
static const float minimumPeakPowerForLoudSound = 92;

/** A loud sound must be this much higher than the rolling average power */
static const float multiplierAboveAveragePower = 1.17;

/** A loud sound must be this much higher than the previous average power */
static const float multiplierAbovePreviousPower = 1.15;

/** Higher leads to a faster leak */
static const float rollingAveragePowerLeak = 0.036;

@interface RMLoudSoundDetector () <RMRealtimeAudioDelegate>

@property (nonatomic) BOOL loudSound;

@property (nonatomic) float previousPeakPower;
@property (nonatomic) float rollingAveragePower;

@property (nonatomic) int soundEffectCount;

@end

@implementation RMLoudSoundDetector

- (id)init
{
    self = [super init];
    if (self) {
        [RMRealtimeAudio sharedInstance].input = YES;
        [RMRealtimeAudio sharedInstance].delegate = self;
        
        // Initialize these way higher than possible so loud sound is under-sensitive for the first few recordings
        _previousPeakPower = 120.0;
        _rollingAveragePower = 120.0;
        
        // We want to know when the character is making sounds so we can ignore input during those times
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAudioDidBeginNotification:)
                                                     name:RMCharacterDidBeginAudioNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAudioDidFinishNotification:)
                                                     name:RMCharacterDidFinishAudioNotification
                                                   object:nil];
        
        // Also ignore sounds when we're making a sound effect
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAudioDidBeginNotification:)
                                                     name:RMSoundEffectDidBeginNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAudioDidFinishNotification:)
                                                     name:RMSoundEffectDidFinishNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [RMRealtimeAudio sharedInstance].input = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Private Methods

- (void)gotDecibelLevel:(float)decibelLevel
{
    if (self.soundEffectCount > 0) {
        // We're playing sounds through our speaker, so ignore sounds
        return;
    }
    
    // Let's work on [0,120] instead of [-120, 0]
    decibelLevel += 120;
    
    // Check the current peak power for the following three criteria...
    BOOL absolutelyLoudEnough = decibelLevel > minimumPeakPowerForLoudSound;
    BOOL louderThanAverage = decibelLevel > self.rollingAveragePower * multiplierAboveAveragePower;
    BOOL louderThanPreviousSample = decibelLevel > self.previousPeakPower * multiplierAbovePreviousPower;
    
    if (absolutelyLoudEnough && louderThanAverage && louderThanPreviousSample) {
        // ...and if all pass, we just detected a loud sound
        self.loudSound = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            LOG(@"!!! BAM !!!");
            [self.delegate loudSoundDetectorDetectedLoudSound:self];
        });
    } else if (self.loudSound) {
        self.loudSound = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate loudSoundDetectorDetectedEndOfLoudSound:self];
        });
    }
    
    // Update our previous value and the rolling average
    self.previousPeakPower = decibelLevel;
    self.rollingAveragePower = ((1.0 - rollingAveragePowerLeak) * self.rollingAveragePower) + (rollingAveragePowerLeak * decibelLevel);
}

#pragma mark - Notifications

- (void)handleAudioDidBeginNotification:(NSNotification *)notification
{
    self.soundEffectCount++;
}

- (void)handleAudioDidFinishNotification:(NSNotification *)notification
{
    self.soundEffectCount = MAX(0, self.soundEffectCount - 1);
}

@end
