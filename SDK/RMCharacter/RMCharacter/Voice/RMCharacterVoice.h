//
//  RMCharacterVoice.h
//  RMCharacter
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "RMCharacter.h"

@interface RMCharacterVoice : NSObject <AVAudioPlayerDelegate>

@property (nonatomic, readonly) RMCharacterType characterType;
@property (nonatomic)           RMCharacterEmotion emotion;
@property (nonatomic)           RMCharacterExpression expression;
@property (nonatomic) BOOL fading;

+ (RMCharacterVoice *)sharedInstance;

- (void)didReceiveMemoryWarning;
- (void)mumbleWithUtterance:(NSString *)utterance;
- (void)makeBlinkSound;

@end
