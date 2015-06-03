//
//  RMRomoteDriveBottomBar.h
//

#import "RMRomoteDrivePhotoButton.h"
#import "RMRomoteDriveCameraButton.h"
#import "RMRomoteDriveExpressionButton.h"

@protocol RMRomoteDriveBottomBarDelegate <NSObject>

- (void)didTouchPhotosButton:(RMRomoteDrivePhotoButton *)photosButton;
- (void)didTouchCameraButton:(RMRomoteDriveCameraButton *)cameraButton;
- (void)didTouchExpressionsButton:(RMRomoteDriveExpressionButton *)expressionsButton;

@end

@interface RMRomoteDriveBottomBar : UIView

@property (nonatomic, weak) id<RMRomoteDriveBottomBarDelegate> delegate;
@property (nonatomic, strong) RMRomoteDrivePhotoButton* photosButton;
@property (nonatomic, strong) RMRomoteDriveCameraButton* cameraButton;
@property (nonatomic, strong) RMRomoteDriveExpressionButton* expressionsButton;

- (id)initWithDelegate:(id<RMRomoteDriveBottomBarDelegate>)delegate;

@end
