//
//  RMGradientLabel.h
//  Romo
//

#import <UIKit/UIKit.h>

@interface RMGradientLabel : UILabel

/**
 Currently accepts [UIColor greenColor] and [UIColor magentaColor];
 */
@property (nonatomic, strong) UIColor *gradientColor;

+ (UIImage *)gradientImageForColor:(UIColor *)color label:(UILabel *)label;

@end
