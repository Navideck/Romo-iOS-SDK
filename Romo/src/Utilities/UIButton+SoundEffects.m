//
//  UIButton+SoundEffects.m
//  Romo
//

#import "UIButton+SoundEffects.h"
#import <objc/runtime.h>
#import "RMSoundEffect.h"

static char const *SoundEffectsKey;

@implementation UIButton (SoundEffects)

@dynamic soundEffects;

- (void)setSoundEffect:(RMSoundEffect *)soundEffect forControlEvents:(UIControlEvents)events
{
    if (soundEffect) {
        if (!self.soundEffects) {
            self.soundEffects = [NSMutableDictionary dictionary];
        }
        
        self.soundEffects[@(events)] = soundEffect;
        [self addTarget:self action:@selector(handleAction:forEvents:) forControlEvents:events];
    }
}
    
- (void)handleAction:(UIButton *)button forEvents:(UIControlEvents)events
{
    RMSoundEffect *soundEffect = self.soundEffects[@(events)];
    [soundEffect play];
}

- (NSMutableDictionary *)soundEffects
{
    return objc_getAssociatedObject(self, SoundEffectsKey);
}

- (void)setSoundEffects:(NSMutableDictionary *)soundEffects
{
    objc_setAssociatedObject(self, SoundEffectsKey, soundEffects, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end