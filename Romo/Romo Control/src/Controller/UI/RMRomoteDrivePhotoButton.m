//
//  RMRomoteDrivePhotoButton.m
//

#import "RMRomoteDrivePhotoButton.h"
#import "UIView+Additions.h"
#import "UIColor+RMColor.h"

@implementation RMRomoteDrivePhotoButton

+ (id)photoButton
{
    return [[RMRomoteDrivePhotoButton alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
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
        
        self.imageView.contentMode = UIViewContentModeScaleAspectFill;
        
        self.photo = nil;
    }
    return self;
}

- (void)setPhoto:(UIImage *)photo
{
    _photo = photo;
    
    self.hidden = !_photo;
    
    [self setImage:photo forState:UIControlStateNormal];
    [self setImage:photo forState:UIControlStateHighlighted];
}

- (void)setFrame:(CGRect)frame
{
    super.frame = frame;
    self.layer.cornerRadius = self.width/2;
}

- (void)setHighlighted:(BOOL)highlighted {
    super.highlighted = highlighted;
    self.imageView.alpha = highlighted ? 0.65 : 1.0;
}

@end
