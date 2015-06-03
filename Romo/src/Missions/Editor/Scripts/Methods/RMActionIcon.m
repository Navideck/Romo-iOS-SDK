//
//  RMActionIcon.m
//  Romo
//

#import "RMActionIcon.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "RMAction.h"
#import "RMDriveActionIcon.h"
#import "RMTurnActionIcon.h"
#import "RMVideoActionIcon.h"
#import "RMPictureActionIcon.h"
#import "RMSongActionIcon.h"
#import "RMSayActionIcon.h"
#import "RMWaitActionIcon.h"
#import "RMFaceActionIcon.h"
#import "RMTiltActionIcon.h"
#import "RMLightBlinkActionIcon.h"
#import "RMLightOffActionIcon.h"
#import "RMLightOnActionIcon.h"
#import "RMShuffleActionIcon.h"
#import "RMLookActionIcon.h"
#import "RMSquareActionIcon.h"
#import "RMNoActionIcon.h"
#import "RMFartActionIcon.h"
#import "RMDoodleActionIcon.h"
#import "RMAlarmActionIcon.h"
#import "RMExploreActionIcon.h"
#import "RMFaceColorActionIcon.h"

@interface RMActionIcon ()

@property (nonatomic, strong) UILabel *availableLabel;
@property (nonatomic, strong) UIImageView *availableBubble;

@end

@implementation RMActionIcon

- (RMActionIcon *)initWithAction:(RMAction *)action
{
    CGRect frame = CGRectMake(0, 0, 102, 124);
    
    NSString *actionTitle = [[NSBundle mainBundle] localizedStringForKey:[NSString stringWithFormat:@"Action-title-%@", action.title]
                                                                   value:action.title
                                                                   table:@"MissionActions"];
    
    NSString *actionShortTitle = [[NSBundle mainBundle] localizedStringForKey:[NSString stringWithFormat:@"Action-shortTitle-%@", action.shortTitle]
                                                                        value:action.shortTitle
                                                                        table:@"MissionActions"];
    NSString *title = [action.title lowercaseString];
    
    if ([title isEqualToString:@"drive forward"]) {
        RMDriveActionIcon *icon = [[RMDriveActionIcon alloc] initWithFrame:frame];
        icon.title = actionShortTitle;
        icon.forward = YES;
        return icon;
    } else if ([title isEqualToString:@"drive backward"]) {
        RMDriveActionIcon *icon = [[RMDriveActionIcon alloc] initWithFrame:frame];
        icon.forward = NO;
        icon.title = actionShortTitle;
        return icon;
    } else if ([title isEqualToString:@"turn"]) {
        RMTurnActionIcon *icon = [[RMTurnActionIcon alloc] initWithFrame:frame];
        icon.title = actionShortTitle;
        return icon;
    } else if ([title isEqualToString:@"take a photo"]) {
        RMPictureActionIcon *icon = [[RMPictureActionIcon alloc] initWithFrame:frame];
        icon.title = actionShortTitle;
        return icon;
    } else if ([title isEqualToString:@"record a video"]) {
        RMVideoActionIcon *icon = [[RMVideoActionIcon alloc] initWithFrame:frame];
        icon.title = actionShortTitle;
        return icon;
    } else if ([title isEqualToString:@"play $"]) {
        RMSongActionIcon *icon = [[RMSongActionIcon alloc] initWithFrame:frame];
        icon.title = actionShortTitle;
        return icon;
    } else if ([title isEqualToString:@"say"]) {
        RMSayActionIcon *icon = [[RMSayActionIcon alloc] initWithFrame:frame];
        icon.title = actionShortTitle;
        return icon;
    } else if ([title isEqualToString:@"pause"]) {
        RMWaitActionIcon *icon = [[RMWaitActionIcon alloc] initWithFrame:frame];
        icon.title = actionShortTitle;
        return icon;
    } else if ([title isEqualToString:@"act $"]) {
        RMFaceActionIcon *icon = [[RMFaceActionIcon alloc] initWithFrame:frame];
        icon.title = actionShortTitle;
        icon.expression = RMCharacterExpressionLove;
        if (action.parameters.count) {
            RMParameter *expressionParameter = (RMParameter *)action.parameters[0];
            RMCharacterExpression expression = [expressionParameter.value intValue];
            if (expression) {
                icon.expression = expression;
            }
        }
        return icon;
    } else if ([title isEqualToString:@"become $"]) {
        RMFaceActionIcon *icon = [[RMFaceActionIcon alloc] initWithFrame:frame];
        icon.title = actionShortTitle;
        icon.emotion = RMCharacterEmotionExcited;
        if (action.parameters.count) {
            RMParameter *emotionParameter = (RMParameter *)action.parameters[0];
            RMCharacterEmotion emotion = [emotionParameter.value intValue];
            if (emotion) {
                icon.emotion = emotion;
            }
        }
        return icon;
    } else if ([title isEqualToString:@"tilt"]) {
        RMTiltActionIcon *icon = [[RMTiltActionIcon alloc] initWithFrame:frame];
        icon.title = actionShortTitle;
        return icon;
    } else if ([title isEqualToString:@"turn on romo's light"]) {
        RMLightOnActionIcon *icon = [[RMLightOnActionIcon alloc] initWithFrame:frame];
        icon.title = actionShortTitle;
        return icon;
    } else if ([title isEqualToString:@"turn off romo's light"]) {
        RMLightOffActionIcon *icon = [[RMLightOffActionIcon alloc] initWithFrame:frame];
        icon.title = actionShortTitle;
        return icon;
    } else if ([title isEqualToString:@"blink romo's light"]) {
        RMLightBlinkActionIcon *icon = [[RMLightBlinkActionIcon alloc] initWithFrame:frame];
        icon.title = actionShortTitle;
        return icon;
    } else if ([title isEqualToString:@"shuffle music"]) {
        RMShuffleActionIcon *icon = [[RMShuffleActionIcon alloc] initWithFrame:frame];
        icon.title = actionTitle;
        return icon;
    } else if ([title isEqualToString:@"look"]) {
        RMLookActionIcon *icon = [[RMLookActionIcon alloc] initWithFrame:frame];
        icon.title = actionTitle;
        return icon;
    } else if ([title isEqualToString:@"drive in a square"]) {
        RMSquareActionIcon *icon = [[RMSquareActionIcon alloc] initWithFrame:frame];
        icon.title = actionTitle;
        return icon;
    } else if ([title isEqualToString:@"nod \"yes!\""]) {
        RMTiltActionIcon *icon = [[RMTiltActionIcon alloc] initWithFrame:frame];
        icon.title = actionShortTitle;
        icon.noddingYes = YES;
        return icon;
    } else if ([title isEqualToString:@"shake \"no!\""]) {
        RMNoActionIcon *icon = [[RMNoActionIcon alloc] initWithFrame:frame];
        icon.title = actionShortTitle;
        return icon;
    } else if ([title isEqualToString:@"backfire"]) {
        RMFartActionIcon *icon = [[RMFartActionIcon alloc] initWithFrame:frame];
        icon.title = actionShortTitle;
        return icon;
    } else if ([title isEqualToString:@"doodle"]) {
        RMDoodleActionIcon *icon = [[RMDoodleActionIcon alloc] initWithFrame:frame];
        icon.title = actionShortTitle;
        return icon;
    } else if ([title isEqualToString:@"sound the alarm"]) {
        RMAlarmActionIcon *icon = [[RMAlarmActionIcon alloc] initWithFrame:frame];
        icon.title = actionShortTitle;
        return icon;
    } else if ([title isEqualToString:@"start exploring"]) {
        RMExploreActionIcon *icon = [[RMExploreActionIcon alloc] initWithFrame:frame];
        icon.title = actionShortTitle;
        icon.stopping = NO;
        return icon;
    } else if ([title isEqualToString:@"stop exploring"]) {
        RMExploreActionIcon *icon = [[RMExploreActionIcon alloc] initWithFrame:frame];
        icon.title = actionShortTitle;
        icon.stopping = YES;
        return icon;
    } else if ([title isEqualToString:@"change my color"]) {
        RMFaceColorActionIcon *icon = [[RMFaceColorActionIcon alloc] initWithFrame:frame];
        icon.title = actionShortTitle;
        return icon;
    }

    RMActionIcon *icon = [[[self class] alloc] initWithFrame:frame];
    icon.title = actionShortTitle;
    return icon;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.image = [UIImage imageNamed:@"iconBackground.png"];
    }
    return self;
}

- (void)setAvailableCount:(int)availableCount
{
    _availableCount = availableCount;
    
    if (!availableCount) {
        [_availableBubble removeFromSuperview];
        self.userInteractionEnabled = NO;
        self.alpha = 0.35;
    } else {
        self.availableLabel.text = availableCount >= 0 ? [NSString stringWithFormat:@"%d", availableCount] : @"∞";
        self.availableLabel.size = [_availableLabel.text sizeWithFont:self.availableLabel.font];
        self.availableLabel.center = CGPointMake(self.availableBubble.width / 2.0, self.availableBubble.height / 2.0);
        [self addSubview:self.availableBubble];
    }
}

- (void)layoutForExpansion
{
    [super layoutForExpansion];
    
    _availableBubble.transform = CGAffineTransformMakeScale(0.003, 0.25);
}

#pragma mark - Private Properties

- (UILabel *)availableLabel
{
    if (!_availableLabel) {
        _availableLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _availableLabel.backgroundColor = [UIColor clearColor];
        _availableLabel.textColor = [UIColor whiteColor];
        _availableLabel.font = [UIFont fontWithSize:22];
        _availableLabel.layer.shadowColor = [UIColor colorWithHue:0.93 saturation:0.67 brightness:0.36 alpha:1.0].CGColor;
        _availableLabel.layer.shadowOffset = CGSizeMake(0.5, 1.5);
        _availableLabel.layer.shadowOpacity = 1.0;
        _availableLabel.layer.shadowRadius = 2.0;
        _availableLabel.layer.rasterizationScale = 2.0;
        _availableLabel.layer.shouldRasterize = YES;
        _availableLabel.clipsToBounds = NO;
    }
    return _availableLabel;
}

- (UIImageView *)availableBubble
{
    if (!_availableBubble) {
        _availableBubble = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"actionIconCountBubble.png"]];
        _availableBubble.origin = CGPointMake(12, 6);
        [_availableBubble addSubview:self.availableLabel];
    }
    return _availableBubble;
}

@end
