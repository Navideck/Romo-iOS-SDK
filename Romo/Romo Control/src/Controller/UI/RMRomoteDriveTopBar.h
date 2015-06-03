//
//  RMRomoteDriveTopBar.h
//

#import "RMRomoteDriveSettingsButton.h"

@protocol RMRomoteDriveTopBarDelegate <NSObject>

- (void)didTouchBackButton:(UIButton *)backButton;
- (void)didTouchSettingsButton:(RMRomoteDriveSettingsButton *)settingsButton;

@end

@interface RMRomoteDriveTopBar : UIView

@property (nonatomic, weak) id<RMRomoteDriveTopBarDelegate> delegate;
@property (nonatomic, strong) UIButton* backButton;
@property (nonatomic, strong) RMRomoteDriveSettingsButton* settingsButton;

- (id)initWithDelegate:(id<RMRomoteDriveTopBarDelegate>)delegate;

@end
