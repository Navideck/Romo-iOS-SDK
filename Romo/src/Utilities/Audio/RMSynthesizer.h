//
//  RMSynthesizer.h
//  Romo
//	
//  Created on 10/16/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#import <Romo/RMDispatchTimer.h>

#import "RMRealtimeAudio.h"
#import "RMMusicConstants.h"

/**
 Different types of waveforms
 */
typedef enum {
    RMSynthWaveform_Sine        = 0,
    RMSynthWaveform_Square  	= 1,
    RMSynthWaveform_Sawtooth    = 2,
    RMSynthWaveform_Triangle    = 3
} RMSynthWaveform;

@class RMRealtimeAudio;

//==============================================================================
@interface RMSynthesizer : NSObject 

// Initialization
- (id)initWithAudio:(RMRealtimeAudio *)realtimeAudio;

// Synth sound properties
@property (atomic) RMSynthWaveform synthType;
@property (nonatomic) double frequency;
@property (nonatomic) float amplitude;

// Whether we're playing or not
@property (nonatomic) BOOL playing;

@property (nonatomic) BOOL lfoEnabled;
@property (atomic) float lfoRate;
@property (nonatomic, strong) RMDispatchTimer *lfoTimer;
@property (nonatomic) float lfoTheta;

// Starting / stopping the synth
- (void)play;
- (void)stop;

// Actual synthesis
- (void)synthesizeSamples:(SInt16 *)samples
               withLength:(UInt32)numFrames;
// Effects
@property (nonatomic) BOOL effectsEnabled;
@property (nonatomic) float effectPosition;

// Pitch helpers
- (void)playNote:(RMMusicPitch)pitch
        inOctave:(RMMusicOctave)octave;

+ (float)noteToFrequency:(RMMusicPitch)pitch
                inOctave:(RMMusicOctave)octave;

+ (NSString *)stringForNote:(RMMusicPitch)pitch
                   inOctave:(RMMusicOctave)octave;

+ (RMMusicPitch)pitchForString:(NSString *)string;

// MIDI playback
- (void)playMidiNote:(int)notenum;
- (void)stopMidiNote:(int)notenum;

@end
