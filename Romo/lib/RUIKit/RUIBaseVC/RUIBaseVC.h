//
//  RUIBaseVC.h
//  RUISettings
//

#import "RUITextView.h"
#import "Analytics/Analytics.h"
#import <QuartzCore/QuartzCore.h>

@interface RUIBaseVC : UIViewController

@property (nonatomic, strong) RUITextView   *instructions;
@property (nonatomic, strong) NSDictionary  *imageDict;

@end
