//
//  RMRomoteDrivePopoverController.m
//  Romo
//

#import "RMRomoteDrivePopoverController.h"
#import "UIView+Additions.h"
#import "UIColor+RMColor.h"

@interface RMRomoteDrivePopoverController () {
    UILabel* _titleLabel;
    UIButton* _backButton;
}

@end

@implementation RMRomoteDrivePopoverController

- (id)initWithTitle:(NSString *)title
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {                
        [self presentPopoverWithTitle:title];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 144);
    self.view.backgroundColor = [UIColor romoWhite];
    self.view.userInteractionEnabled = YES;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    // catching touch events
    touches = touches;
}

- (void)presentPopoverWithTitle:(NSString *)title {    
    RMRomoteDrivePopover* popover = [[RMRomoteDrivePopover alloc] initWithTitle:title previousPopover:self.popover];
    popover.delegate = self.delegate;
    popover.previousPopover = self.popover;
    [self.view addSubview:popover];
    self.popover = popover;
    
    if (self.popover) {
        [self.view addSubview:_backButton];
    }
    
    if (popover.previousPopover) {
        popover.left = self.view.width/3;
        popover.alpha = 0;
        
        [UIView animateWithDuration:0.25
                         animations:^{
                             popover.left = 0;
                             popover.alpha = 1.0;
                             popover.previousPopover.left = -self.view.width/3;
                             popover.previousPopover.alpha = 0.0;
                         } completion:^(BOOL finished) {
                             [popover.previousPopover removeFromSuperview];
                         }];
    }
}

- (void)dismissPopover {
    [self.view addSubview:self.popover.previousPopover];
    [UIView animateWithDuration:0.25
                     animations:^{
                         self.popover.left = self.view.width/3;
                         self.popover.alpha = 0.0;
                         self.popover.previousPopover.left = 0;
                         self.popover.previousPopover.alpha = 1.0;
                     } completion:^(BOOL finished) {
                         [self.popover removeFromSuperview];
                         self.popover = self.popover.previousPopover;
                         if (!self.popover.previousPopover) {
                             [self->_backButton removeFromSuperview];
                         }
                     }];
}

- (void)presentRootPopover {
    while (self.popover.previousPopover) {
        [self.popover removeFromSuperview];
        self.popover = self.popover.previousPopover;
    }
    self.popover.alpha = 1.0;
    self.popover.left = 0;
    [self.view addSubview:self.popover];
    
    [_backButton removeFromSuperview];
}

- (void)setTitle:(NSString *)title {
    _titleLabel.text = title;
    
}

@end
