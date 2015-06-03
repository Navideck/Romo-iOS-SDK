//
//  RUITankSlider.h
//  Romo
//

#import <UIKit/UIKit.h>

@protocol RMTankSliderDelegate;

@interface RMTankSlider : UIView

@property (nonatomic, weak) id<RMTankSliderDelegate> delegate;
@property (nonatomic) CGFloat value;
@property (nonatomic, copy) NSString *gripperText;

+ (id)tankSlider;

@end

@protocol RMTankSliderDelegate <NSObject>

- (void)slider:(id)slider didChangeToValue:(CGFloat)sliderValue;

@end
