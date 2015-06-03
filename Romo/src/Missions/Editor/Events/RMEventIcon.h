//
//  RMEventIcon.h
//  Romo
//

#import <UIKit/UIKit.h>

@class RMEvent;

@interface RMEventIcon : UIView

@property (nonatomic, strong) RMEvent *event;

/** Shows title text for the event */
@property (nonatomic) BOOL showsTitle;

/** 
 Defaults to event's parameterless name
 Only visible if showsTitle is YES
 */
@property (nonatomic, strong) NSString *title;

- (id)initWithEvent:(RMEvent *)event;

@end
