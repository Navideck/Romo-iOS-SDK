//
//  RMCharacterColorFill.h
//  Wave
//

#import <UIKit/UIKit.h>

@interface RMCharacterColorFill : UIView

@property (nonatomic, strong) UIColor *fillColor;

@property (nonatomic) float fillAmount;

/**
 When true, fills the background with gray as the progress fills
 Defaults to YES
 */
@property (nonatomic) BOOL hasBackgroundFill;

@end
