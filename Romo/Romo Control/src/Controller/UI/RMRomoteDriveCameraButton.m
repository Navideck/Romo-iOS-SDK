//
//  RMRomoteDriveCameraButton.m
//

#import "RMRomoteDriveCameraButton.h"
#import "UIColor+RMColor.h"
#import "UIView+Additions.h"

@implementation RMRomoteDriveCameraButton

+ (id)cameraButton {
    return [[RMRomoteDriveCameraButton alloc] initWithFrame:CGRectMake(0, 0, 60, 60)];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor romoWhite];
        self.layer.borderWidth = 1;
        self.layer.borderColor = [UIColor romoGray].CGColor;
        self.layer.cornerRadius = self.width/2;
        self.clipsToBounds = YES;
        
        [self setImage:[UIImage imageNamed:@"R3UI-Controller-Camera.png"] forState:UIControlStateNormal];
        [self setImage:[UIImage imageNamed:@"R3UI-Controller-CameraHighlighted.png"] forState:UIControlStateHighlighted];
    }
    return self;
}

- (void)setFrame:(CGRect)frame
{
    super.frame = frame;
    self.layer.cornerRadius = self.width/2;
}

- (void)setHighlighted:(BOOL)highlighted
{
    if (!self.waiting) {
        super.highlighted = highlighted;
        if (highlighted) {
            self.backgroundColor = [UIColor romoBlue];
        } else {
            self.backgroundColor = [UIColor romoWhite];
        }
    }
}

- (void)setWaiting:(BOOL)waiting
{
    _waiting = waiting;
    
    self.userInteractionEnabled = !waiting;
    
    if (waiting) {
        self.backgroundColor = [UIColor romoBlue];
        [self setImage:nil forState:UIControlStateNormal];
        [self setImage:nil forState:UIControlStateHighlighted];
        
        if (!_waitingView) {
            _waitingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
            _waitingView.center = CGPointMake(self.width/2, self.height/2);
        }
        [self addSubview:_waitingView];
        [_waitingView startAnimating];
        
    } else {
        self.backgroundColor = [UIColor romoWhite];
        [self setImage:[UIImage imageNamed:@"R3UI-Controller-Camera.png"] forState:UIControlStateNormal];
        [self setImage:[UIImage imageNamed:@"R3UI-Controller-CameraHighlighted.png"] forState:UIControlStateHighlighted];
        
        [_waitingView removeFromSuperview];
        [_waitingView stopAnimating];

        self.highlighted = NO;
    }
}

@end
