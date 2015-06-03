//
//  RMDpad.h
//  RMRomoteDriveVC
//

#import <UIKit/UIKit.h>

typedef enum {
    RMDpadSectorNone = 0,
    RMDpadSectorUp = 2,
    RMDpadSectorLeft = 4,
    RMDpadSectorCenter = 5,
    RMDpadSectorRight = 6,
    RMDpadSectorDown = 8
} RMDpadSector;

@protocol RMDpadDelegate;

@interface RMDpad : UIView

@property (nonatomic, weak) id<RMDpadDelegate>delegate;

- (id)initWithFrame:(CGRect)frame imageName:(NSString*)imageName centerSize:(CGSize)centerSize;

@end

@protocol RMDpadDelegate <NSObject>

- (void)dPad:(RMDpad *)dpad didTouchSector:(RMDpadSector)sector;
- (void)dPadTouchEnded:(RMDpad *)dpad;

@end

