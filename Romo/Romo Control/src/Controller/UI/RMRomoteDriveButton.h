//
//  RMRomoteDriveButton.h
//

#import <UIKit/UIKit.h>

@interface RMRomoteDriveButton : UIButton {
    UILabel* _titleLabel;
}

@property (nonatomic, copy) NSString* title;
@property (nonatomic) BOOL canToggle;
@property (nonatomic) BOOL active;
@property (nonatomic) BOOL showsTitle;

+ (id)buttonWithTitle:(NSString *)title;

@end
