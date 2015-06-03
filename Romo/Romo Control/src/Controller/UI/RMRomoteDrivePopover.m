//
//  RMRomoteDrivePopover.m
//  Romo
//

#import "RMRomoteDrivePopover.h"
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "UIColor+RMColor.h"

@interface RMRomoteDrivePopover () {
    UILabel* _titleLabel;
}

@end

@implementation RMRomoteDrivePopover

- (id)initWithTitle:(NSString *)title previousPopover:(RMRomoteDrivePopover *)previousPopover
{
    self = [super initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 144)];
    if (self) {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 32, self.width, 24)];
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textColor = [UIColor romoBlack];
        _titleLabel.font = [UIFont romoBoldFontWithSize:[UIFont romoLargeFontSize]];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_titleLabel];
        
        self.title = title;
        self.previousPopover = previousPopover;
        
        if ([title isEqualToString:@"Settings"]) {
            RMRomoteDriveButton *controllersButton = [RMRomoteDriveButton buttonWithTitle:@"Controllers"];
            controllersButton.left = 16;
            controllersButton.top = 70;
            controllersButton.showsTitle = YES;
            [controllersButton addTarget:self.delegate action:@selector(didTouchPopoverButton:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:controllersButton];
            
            RMRomoteDriveButton *audioButton = [RMRomoteDriveButton buttonWithTitle:@"Audio"];
            audioButton.left = controllersButton.right + 24;
            audioButton.top = 70;
            audioButton.showsTitle = YES;
            audioButton.canToggle = YES;
            if ([[NSUserDefaults standardUserDefaults] objectForKey:@"romo-3 controller-muting"] == nil) {
                audioButton.active = YES;
            } else {
                audioButton.active = [[NSUserDefaults standardUserDefaults] boolForKey:@"romo-3 controller-muting"];
            }
            [audioButton addTarget:self.delegate action:@selector(didTouchPopoverButton:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:audioButton];
            
        } else if ([title isEqualToString:@"Controllers"]) {            
            NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"ControllerSettings" ofType:@"plist"];
            NSArray *controllerOptions = [NSDictionary dictionaryWithContentsOfFile:plistPath][@"driving-method"][@"values"];
            
            UIScrollView* controllersView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 70, self.width, self.height - 70)];
            controllersView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self addSubview:controllersView];

            for (int i = 0; i < controllerOptions.count; i++) {
                NSDictionary *item = controllerOptions[i];
                RMRomoteDriveButton *button = [RMRomoteDriveButton buttonWithTitle:item[@"title"]];
                button.showsTitle = YES;
                button.left = 16 + 64*i;
                button.canToggle = NO;
                button.exclusiveTouch = YES;
                [button addTarget:self.delegate action:@selector(didTouchPopoverButton:) forControlEvents:UIControlEventTouchUpInside];
                [controllersView addSubview:button];
            }
            
            CGFloat contentWidth = (controllerOptions.count-1)*64 + 40 + 16*2;
            controllersView.contentSize = CGSizeMake(contentWidth, controllersView.height);
            if (contentWidth < self.width) {
                controllersView.width = contentWidth;
                controllersView.centerX = self.width/2;
            }
        }

    }
    return self;
}

- (void)setTitle:(NSString *)title {
    _titleLabel.text = title;
}

@end
