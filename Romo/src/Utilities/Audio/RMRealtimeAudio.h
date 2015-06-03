//
//  RMRealtimeAudio.h
//      The Realtime Audio pipeline handles capturing from the iOS microphone
//      and generating synthesized sounds. This singleton class should be
//      started on app launch using the -startup method and shut down on
//      app background using the -shutdown method.
//
//      By default the realtime audio pipeline initializes with both input and
//      output set to NO. To enable mic capture or synthesized playback, simply
//      set these corresponding boolean values to YES. To stop them, set the
//      values to NO.
//
//      To ensure the best performance, only enable the input or output
//      channels when they are being used. There is very little overhead
//      to running this system when both input and output are NO, and it
//      does not need to be shutdown until the app closes.
//
//  Romo
//
//  Created on 10/27/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
//==============================================================================
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#import "RMSynthesizer.h"

/**
 State for fading in / out
 */
typedef enum {
    RMFadeState_Idle,
    RMFadeState_FadeIn,
    RMFadeState_FadeOut,
    RMFadeState_Sustain
} RMFadeState;

/**
 If you want to receive information about the mic level (or get access to the 
 raw samples), your class should subscribe to the RMRealtimeAudioDelegate.
 */
@protocol RMRealtimeAudioDelegate <NSObject>

@optional
/** Triggered when the mic line level goes above the silence threshold  */
- (void)lineLevelActivated;

/** Triggered when the mic line level decreases below the silence threshold */
- (void)lineLevelDeactivated;

/** Triggered every time the decibel level is calculated */
- (void)gotDecibelLevel:(float)decibelLevel;

/** If you want to process the data yourself... */
- (void)didReceiveSampleBufferFromMic:(SInt16 *)samples
                           withLength:(int)length;

@end

@class RMSynthesizer;

//==============================================================================
@interface RMRealtimeAudio : NSObject

// Shared instance
+ (RMRealtimeAudio *)sharedInstance;

// A way to startup and shutdown realtime audio
- (void)startup;
- (void)shutdown;

// Determine whether realtime audio is enabled or not
@property (nonatomic, readonly, getter=isEnabled) BOOL enabled;

// Enabling of input / output
@property (atomic) BOOL input;
@property (atomic) BOOL output;

@property (nonatomic, weak) id <RMRealtimeAudioDelegate> delegate;

// A synthesizer object - your interface for generating sounds
@property (nonatomic, strong) RMSynthesizer *synth;

// The sample rate of the audio session
@property (nonatomic) double sampleRate;

// The fade state of the mixer
@property (nonatomic) RMFadeState state;

// Whether or not we've been interrupted
@property (atomic, readonly, getter=isInterrupted) BOOL interrupted;

// Effects
@property (nonatomic) BOOL effectsEnabled;
@property (nonatomic) float effectPosition;

// Mixer
- (void)setMixerOutputGain:(AudioUnitParameterValue)newGain;
- (float)getMixerOutputGain;

// MIDI interface for RMSynthesizer
- (void)executeMidiCommand:(UInt32)command
                  withNote:(UInt32)note
              withVelocity:(UInt32)velocity;

@end
