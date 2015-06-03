//
//  RMParameterInput.h
//  Romo
//

#import <UIKit/UIKit.h>
#import "RMParameter.h"

@protocol RMParameterInputDelegate;

@interface RMParameterInput : UIView

@property (nonatomic, weak) id<RMParameterInputDelegate> delegate;

/** Current value of the input */
@property (nonatomic, strong) id value;

/** 
 The Parameter that this value is editing
 Note: the input does NOT modify the Parameter's value
 */
@property (nonatomic, strong) RMParameter *parameter;

@end

@protocol RMParameterInputDelegate <NSObject>

- (void)input:(RMParameterInput *)input didChangeValue:(id)value;

@end