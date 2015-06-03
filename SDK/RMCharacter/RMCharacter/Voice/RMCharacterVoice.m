//
//  RMCharacterVoice.m
//  RMCharacter
//

#import "RMCharacterVoice.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

#define kNumFarts   19
#define kNumMumbles 21
#define kNumBlinks  5

@interface RMCharacterVoice () <AVAudioPlayerDelegate> {
    RMCharacterExpression _audioExpression;
}

@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, strong) NSBundle *characterBundle;
@property (atomic, getter=isInitialized) BOOL initialized;
@property (nonatomic) BOOL playingAuxiliarySound;

@property (nonatomic) BOOL postedAudioBeganNotification;

- (RMCharacterVoice *)initWithCharacterType:(RMCharacterType)characterType;

@end

@implementation RMCharacterVoice

+ (RMCharacterVoice *)sharedInstance
{
    static RMCharacterVoice *sharedInstance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[RMCharacterVoice alloc] initWithCharacterType:RMCharacterRomo];
    });
    
    return sharedInstance;
}

- (RMCharacterVoice *)initWithCharacterType:(RMCharacterType)characterType
{
    self = [super init];
    if (self) {
        _characterType = characterType;
        
        NSString* frameworkBundlePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"RMCharacter.bundle"];
        _characterBundle = [NSBundle bundleWithPath:frameworkBundlePath];
        
        self.initialized = YES;
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    [self audioDidFinish];
    [self.audioPlayer stop];
    self.audioPlayer = nil;
}

- (void)dealloc
{
    [self audioDidFinish];
}

#pragma mark - Public Properties

- (void)setFading:(BOOL)fading
{
    if (fading != _fading) {
        _fading = fading;
        [self _fadeOut];
    }
}

- (void)setExpression:(RMCharacterExpression)expression
{
    _expression = expression;
    if (self.isInitialized) {
        [NSThread detachNewThreadSelector:@selector(_setExpression) toTarget:self withObject:nil];
    }
}

#pragma mark - Public Methods

- (void)mumbleWithUtterance:(NSString *)utterance
{
    if (self.isInitialized) {
        NSString *fileToUtter = nil;
        // Interrogatives
        if (0 && [utterance rangeOfString:@"?"].location != NSNotFound) {
            int numInterrogatives = 3;
            fileToUtter = [NSString stringWithFormat:@"int_mumble%d", (arc4random() % numInterrogatives) + 1];
            // Exclamatories
        } else if (0 && [utterance rangeOfString:@"!"].location != NSNotFound) {
            int numExclamatories = 3;
            fileToUtter = [NSString stringWithFormat:@"exc_mumble%d", (arc4random() % numExclamatories) + 1];
            // Declaratives / Imperatives
        } else {
            fileToUtter = [NSString stringWithFormat:@"mumble%d", (arc4random() % kNumMumbles) + 1];
        }
        [self _playAuxiliarySoundWithFileName:fileToUtter];
    }
}

- (void)makeBlinkSound
{
    NSString *blinkFile = [NSString stringWithFormat:@"Creature-Blink-%d", (arc4random_uniform(kNumBlinks) + 1)];
    [self _playAuxiliarySoundWithFileName:blinkFile];
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    [self audioDidFinish];
}

#pragma mark - Private Methods

- (void)audioDidFinish
{
    if (self.postedAudioBeganNotification) {
        // If we have an unmatched notification, post that audio stopped
        self.postedAudioBeganNotification = NO;
        self.audioPlayer.delegate = nil;
        [self.audioPlayer stop];

        [[NSNotificationCenter defaultCenter] postNotificationName:RMCharacterDidFinishAudioNotification object:nil];
    }
    self.audioPlayer = nil;
    self.playingAuxiliarySound = NO;
}

- (void)_setExpression
{
    
    NSString *path;
    
    // Special case for farting
    if (_expression == RMCharacterExpressionFart) {
        int randomSound = arc4random_uniform(kNumFarts);
        path = [self.characterBundle pathForResource:[NSString stringWithFormat:@"%d-%02d",_expression, randomSound] ofType:@"caf"];
    } else {
        path = [self.characterBundle pathForResource:[NSString stringWithFormat:@"%d",_expression] ofType:@"caf"];
    }
    path = [path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    [self audioDidFinish];
    self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL URLWithString:path] error:nil];
    
    if (self.audioPlayer.duration) {
        [self.audioPlayer prepareToPlay];
        self.audioPlayer.delegate = self;
        _audioExpression = _expression;
    } else {
        self.audioPlayer = nil;
    }
    
    [self.audioPlayer play];
    self.postedAudioBeganNotification = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:RMCharacterDidBeginAudioNotification object:nil];
}

- (void)_playAuxiliarySoundWithFileName:(NSString *)filename
{
    // If we're playing a sound...
    if (self.audioPlayer) {
        // ...and it's an auxiliary one, then stop it
        if (self.playingAuxiliarySound) {
            [self audioDidFinish];
        }
        // Otherwise return - character sounds are more important
        else {
            return;
        }
    }
    
    NSString *path = [self.characterBundle pathForResource:filename ofType:@"caf"];
    path = [path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL URLWithString:path] error:nil];
    
    self.playingAuxiliarySound = YES;
    if (self.audioPlayer.duration) {
        [self.audioPlayer prepareToPlay];
        self.audioPlayer.delegate = self;
        _audioExpression = RMCharacterExpressionNone;
        
        [self.audioPlayer play];
        self.postedAudioBeganNotification = YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:RMCharacterDidBeginAudioNotification object:nil];
    } else {
        self.audioPlayer = nil;
    }
}

-(void)_fadeOut
{
    if (self.audioPlayer.volume > 0.05 && self.fading) {
        self.audioPlayer.volume -= 0.15;
        [self performSelector:@selector(_fadeOut) withObject:nil afterDelay:0.05];
    } else {
        [self audioDidFinish];
    }
}

@end
