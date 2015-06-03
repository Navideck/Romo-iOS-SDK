//
//  RMRomoDialer.h
//  Romo
//

#import <UIKit/UIKit.h>

@interface RMRomoDialer : UIView

/**
 The number currently entered
 e.g. 123-456 -> "123456"
 */
@property (nonatomic, strong, readonly) NSString *inputNumber;

/**
 The button that calls the input number
 */
@property (nonatomic, strong, readonly) UIButton *callButton;

+ (CGFloat)preferredHeight;

@end
