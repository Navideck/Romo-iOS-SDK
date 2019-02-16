//
//  RMSynthesizer.m
//  Romo
//
//  Created on 10/16/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
#import "RMSynthesizer.h"
#import <Romo/RMMath.h>
#import <Romo/UIDevice+Romo.h>
#import "UIDevice+Temporary.h"

#ifdef SOUND_DEBUG
#define LOG(...) DDLogWarn(__VA_ARGS__)
#else
#define LOG(...)
#endif //SOUND_DEBUG

#define kAmplitudeDefault       0.5
#define kAmplitudeIpodTouch4G   0.92
#define kAmplitudeIphone4       0.5
#define kAmplitudeIphone4S      0.425
#define kAmplitudeIpodTouch5G   0.80
#define kAmplitudeIphone5       0.325
#define kAmplitudeIphone5C      0.50
#define kAmplitudeIphone5S      0.45

#define kTwelfthRootOfTwo       1.059463094359293
#define kReferenceFrequency     440.0
#define kReferenceNote          A
#define kReferenceOctave        RMMusicOctave_4

#define kLFOUpdateFrequency     60

#define kMIDIMessage_NoteOn     0x9
#define kMIDIMessage_NoteOff    0x8

//==============================================================================
@interface RMSynthesizer ()

@property (nonatomic, weak) RMRealtimeAudio *realtimeAudio;

@property (nonatomic) RMMusicPitch  currentPitch;
@property (nonatomic) RMMusicOctave currentOctave;

@property (atomic) BOOL interrupted;

@end

//==============================================================================
@implementation RMSynthesizer

#pragma mark - Initialization / Teardown
//------------------------------------------------------------------------------
- (id)initWithAudio:(RMRealtimeAudio *)realtimeAudio
{
    self = [super init];
    if (self) {
        LOG(@"Initializing");
        // Save a weak reference to the realtime audio session
        _realtimeAudio = realtimeAudio;
        
        // Set the default synth type and parameters
        _synthType = RMSynthWaveform_Sawtooth;
        _amplitude = [self _amplitudeForDevice];
        _frequency = kReferenceFrequency;
        
        // Set default effects parameters
        _lfoRate = 2.0f;
    }
    return self;
}

//------------------------------------------------------------------------------
- (void)play
{
    if (self.realtimeAudio.output && !self.realtimeAudio.interrupted) {
        if (self.realtimeAudio.state == RMFadeState_Idle ||
            self.realtimeAudio.state == RMFadeState_FadeOut) {
            self.realtimeAudio.state = RMFadeState_FadeIn;
        }
    } else {
        LOG(@"ERROR: Playing RMSynthesizer with output disabled");
    }
}

//------------------------------------------------------------------------------
- (void)stop
{
    if (self.realtimeAudio.output && !self.realtimeAudio.interrupted) {
        if (self.realtimeAudio.state == RMFadeState_FadeIn) {
            self.realtimeAudio.state = RMFadeState_Idle;
        } else {
            self.realtimeAudio.state = RMFadeState_FadeOut;
        }
    } else {
        LOG(@"ERROR: Stopping RMSynthesizer with output disabled");
    }
}

#pragma mark - Waveform Synthesis
// Helper C variables
double  theta           = 0;
int     squareIndex     = 0;
int     sawIndex        = 0;
int     triangleIndex   = 0;

// Synthesizes samples in a given buffer based on the current waveform type
//------------------------------------------------------------------------------
- (void)synthesizeSamples:(SInt16 *)samples
               withLength:(UInt32)numFrames
{
    // Ensure amplitude is on the correct scale
    float amplitude = CLAMP(0.0, self.amplitude, 1.0) * SHRT_MAX;
    
    switch (self.synthType) {
        case RMSynthWaveform_Square:
            generateSquare(samples, numFrames, self.realtimeAudio.sampleRate, self.frequency, amplitude);
            break;
        case RMSynthWaveform_Triangle:
            generateTriangle(samples, numFrames, self.realtimeAudio.sampleRate, self.frequency, amplitude);
            break;
        case RMSynthWaveform_Sawtooth:
            generateSawtooth(samples, numFrames, self.realtimeAudio.sampleRate, self.frequency, amplitude);
            break;
        case RMSynthWaveform_Sine:
        default:
            generateSine(samples, numFrames, self.realtimeAudio.sampleRate, self.frequency, amplitude);
            break;
    }
}

//------------------------------------------------------------------------------
void generateSine(SInt16 *sampleBuffer, int numFrames, float sampleRate, float freq, float amp)
{
    float deltaTheta = 2 * M_PI * (freq/sampleRate);
    for (int i = 0; i < numFrames; i++) {
        sampleBuffer[i] = (SInt16) (amp * sin(theta));
        theta += deltaTheta;
        if (theta > 2*M_PI) {
            theta = theta - 2*M_PI;
        }
    }
}

//------------------------------------------------------------------------------
void generateSquare(SInt16 *sampleBuffer, int numFrames, float sampleRate, float frequency, float amp)
{
    float samplesPerCycle = sampleRate / frequency;
    for (int i = 0; i < numFrames; i++) {
        if (fmodf(squareIndex, samplesPerCycle)/samplesPerCycle > 0.5) {
            sampleBuffer[i] = amp;
        } else {
            sampleBuffer[i] = -1 * amp;
        }
        
        squareIndex++;
        if (squareIndex >= samplesPerCycle) {
            squareIndex -= samplesPerCycle;
        }
    }
}

//------------------------------------------------------------------------------
void generateSawtooth(SInt16 *sampleBuffer, int numFrames, float sampleRate, float frequency, float amp)
{
    float samplesPerCycle = sampleRate / frequency;
    for (int i = 0; i < numFrames; i++) {
        sampleBuffer[i] = (SInt16) amp * (2*(fmodf(sawIndex, samplesPerCycle)/samplesPerCycle)-1);

        sawIndex++;
        if (sawIndex >= samplesPerCycle) {
            sawIndex -= samplesPerCycle;
        }
    }
}

//------------------------------------------------------------------------------
void generateTriangle(SInt16 *sampleBuffer, int numFrames, float sampleRate, float frequency, float amp)
{
    float samplesPerCycle = sampleRate / frequency;
    for (int i = 0; i < numFrames; i++) {
        if (fmodf(triangleIndex, samplesPerCycle)/samplesPerCycle>0.5) {
            sampleBuffer[i] = (SInt16) amp * ((2-2*((fmodf(triangleIndex, samplesPerCycle)/samplesPerCycle-0.5)/0.5))-1);
        } else {
            sampleBuffer[i] = (SInt16) amp * ((2*((fmodf(triangleIndex, samplesPerCycle)/samplesPerCycle)/0.5))-1);
        }
        triangleIndex++;
    }
}

#pragma mark - Effects / LFO
//------------------------------------------------------------------------------
- (void)setEffectsEnabled:(BOOL)effectsEnabled
{
    if (!self.realtimeAudio.interrupted) {
        [self.realtimeAudio setEffectsEnabled:effectsEnabled];
    }
}

//------------------------------------------------------------------------------
- (void)setEffectPosition:(float)effectPosition
{
    if (!self.realtimeAudio.interrupted) {
        [self.realtimeAudio setEffectPosition:effectPosition];
    }
}

//------------------------------------------------------------------------------
- (void)setLfoEnabled:(BOOL)lfoEnabled
{
    if (_lfoEnabled != lfoEnabled) {
        _lfoEnabled = lfoEnabled;
        
        if (_lfoEnabled) {
            [self.lfoTimer startRunning];
        } else {
            [self.lfoTimer stopRunning];
        }
    }
}

//------------------------------------------------------------------------------
- (void)updateLFO
{
    float deltaTheta = 2 * M_PI * (self.lfoRate/kLFOUpdateFrequency);
    self.lfoTheta += deltaTheta;
    if (self.lfoTheta > 2*M_PI) {
        self.lfoTheta = self.lfoTheta - 2*M_PI;
    }
    
    float signal = (sin(self.lfoTheta) + 1) / 2.0;
    [self.realtimeAudio setEffectPosition:signal];
}

//------------------------------------------------------------------------------
- (RMDispatchTimer *)lfoTimer
{
    if (!_lfoTimer) {
        _lfoTimer = [[RMDispatchTimer alloc] initWithName:@"com.romotive.audio.lfo"
                                                frequency:kLFOUpdateFrequency];
        __weak RMSynthesizer *weakSelf = self;
        
        _lfoTimer.eventHandler = ^{
            [weakSelf updateLFO];
        };
    }
    return _lfoTimer;
}

#pragma mark - Helpers
//------------------------------------------------------------------------------
- (float)_amplitudeForDevice
{
    NSUInteger device = [UIDevice currentDevice].platformType;
    float desiredAmplitude = kAmplitudeDefault;
    
    if (device == UIDevice4GiPod) {
        desiredAmplitude = kAmplitudeIpodTouch4G;
    } else if (device == UIDevice4iPhone) {
        desiredAmplitude = kAmplitudeIphone4;
    } else if (device == UIDevice4SiPhone) {
        desiredAmplitude = kAmplitudeIphone4S;
    } else if (device == UIDevice5GiPod) {
        desiredAmplitude = kAmplitudeIpodTouch5G;
    } else if (device == UIDevice5iPhone) {
        desiredAmplitude = kAmplitudeIphone5;
    } else if (device == UIDevice5CiPhone) {
        desiredAmplitude = kAmplitudeIphone5C;
    } else if (device == UIDevice5SiPhone) {
        desiredAmplitude = kAmplitudeIphone5S;
    }
    
    LOG(@"Initializing Device %@ with amplitude %f", [UIDevice currentDevice].platformString, desiredAmplitude);
    return desiredAmplitude;
}

#pragma mark - Pitch Helpers
//------------------------------------------------------------------------------
- (void)playNote:(RMMusicPitch)pitch
        inOctave:(RMMusicOctave)octave
{
    self.currentPitch = pitch;
    self.currentOctave = octave;
    self.frequency = [RMSynthesizer noteToFrequency:pitch inOctave:octave];
    
    if (![self.realtimeAudio isEnabled]) {
        [self play];
    }
}

//------------------------------------------------------------------------------
+ (float)noteToFrequency:(RMMusicPitch)pitch
                inOctave:(RMMusicOctave)octave
{
    int numHalfSteps = ABS(pitch - kReferenceNote);
    int octaveOffset = 0;
    if (octave < kReferenceOctave) {
        numHalfSteps -= 12;
        if (octave < (kReferenceOctave - 1)) {
            octaveOffset = -12 * (ABS(kReferenceOctave - octave) - 1);
        }
    } else {
        octaveOffset = 12 * ABS(octave - kReferenceOctave);
    }
    numHalfSteps += octaveOffset;
    
    return kReferenceFrequency * powf(kTwelfthRootOfTwo, numHalfSteps);
}

//------------------------------------------------------------------------------
+ (NSString *)stringForNote:(RMMusicPitch)pitch
                   inOctave:(RMMusicOctave)octave
{
    NSString *note;
    switch (pitch) {
        case A :
            note = @"A";
            break;
        case Bb:
            note = @"Bb";
            break;
        case B :
            note = @"B";
            break;
        case C :
            note = @"C";
            break;
        case Cs:
            note = @"C#";
            break;
        case D :
            note = @"D";
            break;
        case Eb:
            note = @"Eb";
            break;
        case E :
            note = @"E";
            break;
        case F :
            note = @"F";
            break;
        case Fs:
            note = @"F#";
            break;
        case G :
            note = @"G";
            break;
        case Ab:
            note = @"Ab";
            break;
    }
    return [NSString stringWithFormat:@"%@_%d", note, octave];
}

//------------------------------------------------------------------------------
+ (RMMusicPitch)pitchForString:(NSString *)string
{
    if ([string isEqualToString:@"A"]) {
        return A;
    } else if ([string isEqualToString:@"Bb"]) {
        return Bb;
    } else if ([string isEqualToString:@"B"]) {
        return B;
    } else if ([string isEqualToString:@"C"]) {
        return C;
    } else if ([string isEqualToString:@"C#"]) {
        return Cs;
    } else if ([string isEqualToString:@"D"]) {
        return D;
    } else if ([string isEqualToString:@"Eb"]) {
        return Eb;
    } else if ([string isEqualToString:@"E"]) {
        return E;
    } else if ([string isEqualToString:@"F"]) {
        return F;
    } else if ([string isEqualToString:@"F#"]) {
        return Fs;
    } else if ([string isEqualToString:@"G"]) {
        return G;
    } else if ([string isEqualToString:@"Ab"]) {
        return Ab;
    } else {
        return -1;
    }
}

#pragma mark - Sampler Unit/MIDI Control -
//------------------------------------------------------------------------------
- (void)playMidiNote:(int)notenum
{
    UInt32 noteNum = notenum;
	UInt32 noteVelocity = 100;
	UInt32 noteCommand = kMIDIMessage_NoteOn << 4 | 0;
	
    [self.realtimeAudio executeMidiCommand:noteCommand
                                  withNote:noteNum
                              withVelocity:noteVelocity];
}

//------------------------------------------------------------------------------
- (void)stopMidiNote:(int)notenum
{
    UInt32 noteNum = notenum;
	UInt32 noteVelocity = 100;
	UInt32 noteCommand = kMIDIMessage_NoteOff << 4 | 0;
	
    [self.realtimeAudio executeMidiCommand:noteCommand
                                  withNote:noteNum
                              withVelocity:noteVelocity];
}

@end
