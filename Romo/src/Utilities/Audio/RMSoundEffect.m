//
//  RMSound.m
//  Romo
//

#import "RMSoundEffect.h"
#import <AudioToolbox/AudioToolbox.h>
#import <OpenAl/al.h>
#import <OpenAl/alc.h>

NSString *const soundEffectsEnabledKey = @"soundEffectsEnabled";

NSString *const RMSoundEffectDidBeginNotification = @"RMSoundEffectDidBeginNotification";
NSString *const RMSoundEffectDidFinishNotification = @"RMSoundEffectDidFinishNotification";

static const int samplingRate = 44100;

@interface RMSoundEffect ()

@property (nonatomic, strong, readwrite) NSString *name;

/** Were we able to load it from disk? */
@property (nonatomic, getter=isLoaded) BOOL loaded;
/** A BOOL to keep track of the play/pause state */
@property (nonatomic, getter=isPlaying) BOOL playing;
@property (nonatomic) ALuint buffer;
@property (nonatomic) ALuint outputSource;

/** Readwrite */
@property (nonatomic, readwrite) float duration;

@end

@implementation RMSoundEffect

#pragma mark - State

static ALCdevice *openALDevice;
static ALCcontext *openALContext;

static RMSoundEffect *_foregroundEffect = nil;
static RMSoundEffect *_backgroundEffect = nil;
static bool started = NO;

+ (void)startup
{
    if (!started) {
        started = YES;
        openALDevice = alcOpenDevice(NULL);
        openALContext = alcCreateContext(openALDevice, NULL);
        
        // make the context the current context and we're good to start using OpenAL
        alcMakeContextCurrent(openALContext);
    }
}

+ (void)shutdown
{
    if (started) {
        alcDestroyContext(openALContext);
        alcCloseDevice(openALDevice);
        started = NO;
    }
}

+ (void)playForegroundEffectWithName:(NSString *)name repeats:(BOOL)repeats gain:(CGFloat)gain
{
    if (started) {
        _foregroundEffect = [[RMSoundEffect alloc] initWithName:name];
        _foregroundEffect.repeats = repeats;
        _foregroundEffect.gain = gain;
        [_foregroundEffect play];
    }
}

+ (void)playBackgroundEffectWithName:(NSString *)name repeats:(BOOL)repeats gain:(CGFloat)gain
{
    if (started) {
        _backgroundEffect = [[RMSoundEffect alloc] initWithName:name];
        _backgroundEffect.repeats = repeats;
        _backgroundEffect.gain = gain;
        [_backgroundEffect play];
    }
}

+ (void)stopForegroundEffect
{
    _foregroundEffect = nil;
}

+ (void)stopBackgroundEffect
{
    _backgroundEffect = nil;
}

#pragma mark - Initialization & Lifecycle

+ (id)effectWithName:(NSString *)name
{
    return [[self alloc] initWithName:name];
}

- (id)initWithName:(NSString *)name
{
    self = [super init];
    if (self) {
        BOOL soundEffectsAreEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:soundEffectsEnabledKey];
        if (!soundEffectsAreEnabled) {
            return nil;
        }
        
        alGenSources(1, &_outputSource);
        
        alSourcef(_outputSource, AL_PITCH, 1.0f);
        alSourcef(_outputSource, AL_GAIN, 1.0f);
        
        _name = name;
        _gain = 1.0f;
        [self loadSoundWithFileName:name extension:@"caf"];
    }
    return self;
}

- (void)dealloc
{
    if (self.isPlaying) {
        [self pause];
    }
    
    alDeleteSources(1, &_outputSource);
    alDeleteBuffers(1, &_buffer);
}

#pragma mark - Public Methods

- (void)setGain:(CGFloat)gain
{
    _gain = gain;
    if (self.isPlaying) {
        alSourcef(_outputSource, AL_GAIN, _gain);
    }
}

- (void)play
{
    BOOL soundEffectsAreEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:soundEffectsEnabledKey];
    if (self.isLoaded && soundEffectsAreEnabled && !self.isPlaying && started) {
        alSourcei(_outputSource, AL_BUFFER, self.buffer);
        
        [[NSNotificationCenter defaultCenter] postNotificationName:RMSoundEffectDidBeginNotification object:nil];

        if (self.repeats) {
            alSourcei(_outputSource, AL_LOOPING, AL_TRUE);
        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
                [self pause];
            });
        }
        
        alSourcef(_outputSource, AL_GAIN, self.gain);
        alSourcePlay(_outputSource);
        
        self.playing = YES;
    }
}

- (void)pause
{
    if (self.isPlaying) {
        self.playing = NO;
        alSourcePause(_outputSource);
        [[NSNotificationCenter defaultCenter] postNotificationName:RMSoundEffectDidFinishNotification object:nil];
    }
}

#pragma mark - Private Methods

- (void)loadSoundWithFileName:(NSString *)fileName extension:(NSString *)extension
{
    NSString* filePath = [[NSBundle mainBundle] pathForResource:fileName ofType:extension];
    if (filePath.length) {
        NSURL* fileUrl = [NSURL fileURLWithPath:filePath];
        AudioFileID afid;
        AudioFileOpenURL((__bridge CFURLRef)fileUrl, kAudioFileReadPermission, 0, &afid);
        
        // determine the size of the audio file then read the audio data from the file and put it into the output buffer
        UInt64 fileSizeInBytes = 0;
        UInt32 propSize = sizeof(fileSizeInBytes);
        AudioFileGetProperty(afid, kAudioFilePropertyAudioDataByteCount, &propSize, &fileSizeInBytes);
        UInt32 bytesRead = (UInt32)fileSizeInBytes;
        void* audioData = malloc(bytesRead);
        AudioFileReadBytes(afid, false, 0, &bytesRead, audioData);
        AudioFileClose(afid);
        
        ALuint outputBuffer;
        alGenBuffers(1, &outputBuffer);
        alBufferData(outputBuffer, AL_FORMAT_MONO16, audioData, bytesRead, samplingRate);
        
        // Manually compute our duration based on the size of the file
        static const long sampleRate = 44100;
        static const int bitsPerSample = 2;
        self.duration = (float)bytesRead / (float)(sampleRate * bitsPerSample);

        self.buffer = outputBuffer;
        self.loaded = YES;
        free(audioData);
    } else {
        self.loaded = NO;
    }
}

@end