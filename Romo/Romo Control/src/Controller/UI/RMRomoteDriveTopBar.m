
#import "RMRomoteDriveTopBar.h"
#import "UIButton+RMButtons.h"
#import "UIView+Additions.h"

@implementation RMRomoteDriveTopBar

- (id)initWithFrame:(CGRect)frame
{
    return [self initWithDelegate:nil];
}

- (id)initWithDelegate:(id<RMRomoteDriveTopBarDelegate>)delegate
{
    self = [super initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 42)];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
        self.backButton = [UIButton backButtonWithImage:nil];
        self.backButton.centerY = self.height/2;
        self.backButton.left = 16;
        self.backButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [self.backButton addTarget:self.delegate action:@selector(didTouchBackButton:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.backButton];

        self.settingsButton = [RMRomoteDriveSettingsButton settingsButton];
        self.settingsButton.centerY = self.height/2;
        self.settingsButton.right = self.width - 16;
        self.settingsButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [self.settingsButton addTarget:self.delegate action:@selector(didTouchSettingsButton:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.settingsButton];
    }
    
    return self;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    for (UIView *view in self.subviews) {
        if (!view.hidden && view.userInteractionEnabled && [view pointInside:[self convertPoint:point toView:view] withEvent:event]) {
            return YES;
        }
    }
    return NO;
}

@end
