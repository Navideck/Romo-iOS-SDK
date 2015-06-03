//
//  UIImage+Tint.m
//  Romo
//

#import "UIImage+Tint.h"

@implementation UIImage (Tint)

- (UIImage *)tintedImageWithColor:(UIColor *)color
{
    UIGraphicsBeginImageContextWithOptions(self.size, NO, [UIScreen mainScreen].scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect area = CGRectMake(0, 0, self.size.width, self.size.height);
    
    CGContextScaleCTM(context, 1, -1);
    CGContextTranslateCTM(context, 0, -area.size.height);
    CGContextSaveGState(context);
    CGContextClipToMask(context, area, self.CGImage);
    [color set];
    CGContextFillRect(context, area);
    CGContextRestoreGState(context);
    CGContextSetBlendMode(context, kCGBlendModeScreen);
    
    CGContextDrawImage(context, area, self.CGImage);
    UIImage *colorizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return colorizedImage;
}

@end
