//
//  UIButton+SoundEffects.h
//  Romo
//

#import <UIKit/UIKit.h>

@class RMSoundEffect;

@interface UIButton (SoundEffects)

/** Maps UIControlEvents to RMSoundEffects */
@property (nonatomic, strong) NSMutableDictionary *soundEffects;

/** When the specified events occur, the provided sound effect is played */
- (void)setSoundEffect:(RMSoundEffect *)soundEffect forControlEvents:(UIControlEvents)events;

@end
