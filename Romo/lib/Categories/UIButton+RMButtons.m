//
//  UIButton+RMButtons.m
//  Romo
//

#import "UIButton+RMButtons.h"
#import "UIView+Additions.h"
#import "UIImage+Tint.h"

static const CGFloat buttonHeight = 64.0;
static const CGFloat buttonWidth = 64.0;

static const CGFloat chevronLeft = 16.0;
static const CGFloat chevronWidth = 12.0;
static const CGFloat chevronHeight = 24.0;

static const CGFloat imageViewLeft = 32.0;
static const CGFloat imageViewSize = 25.0;

static const int imageViewTag = 144;

@implementation UIButton (RMButtons)

+ (UIButton *)backButtonWithImage:(UIImage *)image
{
    UIButton *backButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, buttonWidth, buttonHeight)];
    
    [backButton setImage:[UIImage imageNamed:@"backButtonChevron.png"] forState:UIControlStateNormal];
    [backButton setImage:[UIImage imageNamed:@"backButtonChevronHighlighted.png"] forState:UIControlStateHighlighted];
    backButton.imageEdgeInsets = UIEdgeInsetsMake((buttonHeight - chevronHeight) / 2.0, chevronLeft, (buttonHeight - chevronHeight) / 2.0, buttonWidth - chevronWidth - chevronLeft);
    
    [backButton addSubview:[self imageViewForImage:image]];
    
    [backButton addTarget:backButton action:@selector(handleTouchDown:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
    [backButton addTarget:backButton action:@selector(handleTouchUp:) forControlEvents:UIControlEventTouchCancel | UIControlEventTouchDragExit | UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    
    return backButton;
}

- (void)setImage:(UIImage *)image
{
    UIImageView *oldImageView = nil;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIImageView class]] && subview.tag == imageViewTag) {
            oldImageView = (UIImageView *)subview;
        }
    }
    
    
    UIImageView *newImageView = [UIButton imageViewForImage:image];
    newImageView.alpha = 0.0;
    [self addSubview:newImageView];
    
    [UIView animateWithDuration:0.65
                     animations:^{
                         newImageView.alpha = 1.0;
                     } completion:^(BOOL finished) {
                         [oldImageView removeFromSuperview];
                     }];
}

- (void)handleTouchDown:(UIButton *)button
{
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIImageView class]] && subview.tag == imageViewTag) {
            UIImageView *imageView = (UIImageView *)subview;
            imageView.highlighted = YES;
        }
    }
}

- (void)handleTouchUp:(UIButton *)button
{
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIImageView class]] && subview.tag == imageViewTag) {
            UIImageView *imageView = (UIImageView *)subview;
            imageView.highlighted = NO;
        }
    }
}

+ (UIImageView *)imageViewForImage:(UIImage *)image
{
    if (image) {
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(imageViewLeft, (buttonHeight - imageViewSize) / 2.0, imageViewSize, imageViewSize)];
        imageView.image = image;
        imageView.layer.cornerRadius = imageViewSize / 2.0;
        imageView.clipsToBounds = YES;
        imageView.highlightedImage = [image tintedImageWithColor:[UIColor colorWithWhite:1.0 alpha:0.45]];
        imageView.tag = imageViewTag;
        return imageView;
    }
    return nil;
}

@end