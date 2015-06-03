//
//  RMRomoteDriveCameraButton.h
//

//

@interface RMRomoteDriveCameraButton : UIButton {
    UIActivityIndicatorView* _waitingView;
}

@property (nonatomic) BOOL waiting;

+ (id)cameraButton;

@end
