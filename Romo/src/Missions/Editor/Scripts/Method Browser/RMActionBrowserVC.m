//
//  RMActionBrowser.m
//  Romo
//

#import "RMActionBrowserVC.h"
#import "UIView+Additions.h"
#import <QuartzCore/QuartzCore.h>
#import "UIFont+RMFont.h"
#import "UIButton+RMButtons.h"
#import "RMAction.h"
#import "RMActionIcon.h"

@interface RMActionBrowserVC () <RMButtonIconDelegate>

/** All of the icons shown */
@property (nonatomic, strong) NSMutableArray *icons;

/** Maps action buttons to actions */
@property (nonatomic, strong) NSMutableDictionary *iconMapping;

@end

@implementation RMActionBrowserVC

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.clipsToBounds = NO;
    
    self.icons = [NSMutableArray arrayWithCapacity:12];
    self.iconMapping = [NSMutableDictionary dictionary];

    [self.availableActions enumerateObjectsUsingBlock:^(RMAction *allowedAction, NSUInteger index, BOOL *stop) {
        RMAction *action = [allowedAction copy];
        
        RMActionIcon *icon = [[RMActionIcon alloc] initWithAction:action];
        icon.availableCount = action.availableCount;
        icon.origin = CGPointMake(108 * (index % 3), 140 * (index / 3));
        icon.delegate = self;
        [self.view addSubview:icon];
        [self.icons addObject:icon];
        
        self.iconMapping[icon.title] = action;
    }];

    self.view.height = 140 * ((self.icons.count + 2) / 3);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    for (RMActionIcon *actionIcon in self.icons) {
        [actionIcon startAnimating];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

    for (RMActionIcon *actionIcon in self.icons) {
        [actionIcon stopAnimating];
    }
}

#pragma mark - Icon Delegate

- (void)didTouchButtonIcon:(RMButtonIcon *)buttonIcon
{
    RMActionIcon *actionIcon = (RMActionIcon *)buttonIcon;
    RMAction *action = self.iconMapping[actionIcon.title];
    [self.delegate actionBrowser:self didSelectIcon:actionIcon withAction:action];
}

@end
