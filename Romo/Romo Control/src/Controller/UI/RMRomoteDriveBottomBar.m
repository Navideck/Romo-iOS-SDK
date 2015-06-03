//
//  RMRomoteDriveBottomBar.h
//

#import "RMRomoteDriveBottomBar.h"
#import "UIView+Additions.h"

@implementation RMRomoteDriveBottomBar

- (id)initWithFrame:(CGRect)frame
{
    return [self initWithDelegate:nil];
}

- (id)initWithDelegate:(id<RMRomoteDriveBottomBarDelegate>)delegate
{
    self = [super initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 62)];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
        self.photosButton = [RMRomoteDrivePhotoButton photoButton];
        self.photosButton.centerY = self.height/2;
        self.photosButton.left = self.width/2 - 140;
        self.photosButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [self.photosButton addTarget:self.delegate action:@selector(didTouchPhotosButton:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.photosButton];
        
        self.cameraButton = [RMRomoteDriveCameraButton cameraButton];
        self.cameraButton.center = CGPointMake(self.width/2, self.height/2);
        self.cameraButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [self.cameraButton addTarget:self.delegate action:@selector(didTouchCameraButton:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.cameraButton];
        
        self.expressionsButton = [RMRomoteDriveExpressionButton buttonWithExpression:8];
        self.expressionsButton.centerY = self.height/2;
        self.expressionsButton.right = self.width/2 + 140;
        self.expressionsButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [self.expressionsButton addTarget:self.delegate action:@selector(didTouchExpressionsButton:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.expressionsButton];
    }
    return self;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    for (UIView *view in self.subviews) {
        if (!view.hidden && view.userInteractionEnabled && [view pointInside:[self convertPoint:point toView:view] withEvent:event]) {
            return YES;
        }
    }
    return NO;
}

@end
