//
//  RMVoice.h
//  Romo
//

#import <UIKit/UIKit.h>
#ifndef ROMO_CONTROL_APP
#import <Romo/RMCharacter.h>
#endif

// Defines how each line's size should be
// S = Small = 0, L = Large = 1
typedef enum {
    //                0xSLS = 010
    RMVoiceStyleSLS = 0x010, // First Line: Small, Second: Large, Third: Small
    RMVoiceStyleLSL = 0x101,
    RMVoiceStyleSSS = 0x000,
    RMVoiceStyleLLS = 0x011,
    RMVoiceStyleSLL = 0x110,
    RMVoiceStyleSSL = 0x001,
} RMVoiceStyle;

@protocol RMVoiceDelegate;

@interface RMVoice : UIImageView

@property (nonatomic, weak) id<RMVoiceDelegate> delegate;
@property (nonatomic, readonly) NSString* speech;
@property (nonatomic, strong) UIView *view;
@property (nonatomic, readonly, getter=isVisible) BOOL visible;
@property (nonatomic, readonly) float duration;
@property (nonatomic) BOOL muteMumbleSound;

#ifndef ROMO_CONTROL_APP
@property (nonatomic, weak) RMCharacter *character;
#endif

+ (RMVoice *)voice;
- (void)say:(NSString *)speech;
- (void)say:(NSString *)speech withStyle:(RMVoiceStyle)style autoDismiss:(BOOL)autoDismiss;

/**
 Expects an array of string options
 Currently only supports two options, with the first being dimmed, second being emphasized
 */
- (void)ask:(NSString *)speech withAnswers:(NSArray *)answers;
- (void)dismiss;

/**
 Immediately removes the voice and doesn't notify the delegate
 Useful for when the delegate is changing and we don't want the current text's dismissal to interfere with the new delegate's control
 */
- (void)dismissImmediately;

/**
 Notification when a user has selected an option presented to them
 */
extern NSString *const RMVoiceUserDidSelectionOptionNotification;

@end

@protocol RMVoiceDelegate <NSObject>

@optional
- (void)userDidSelectOptionAtIndex:(int)optionIndex forVoice:(RMVoice *)voice;
- (void)speechDismissedForVoice:(RMVoice *)voice;

@end
