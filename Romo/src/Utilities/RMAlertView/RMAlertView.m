//
//  RomoPopupView.m
//  RomoPopUpView
//

#import "RMAlertView.h"
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "UIColor+RMColor.h"
#import "RMAppDelegate.h"

@interface RMAlertView ()

@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;

@end

@implementation RMAlertView

+ (void)dismissAll
{
    [[[[UIApplication sharedApplication].delegate window] subviews] enumerateObjectsUsingBlock:^(id view, NSUInteger idx, BOOL *stop) {
        if ([view isKindOfClass:[RMAlertView class]]) {
            [view dismiss];
        }
    }];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _contentView = [[UIView alloc] initWithFrame:self.bounds];
        [self addSubview:self.contentView];
        
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message delegate:(id<RMAlertViewDelegate>)delegate
{
    self = [self initWithFrame:[UIScreen mainScreen].bounds];
    if (self) {
        self.title = title;
        self.message = message;
        self.delegate = delegate;
    }
    return self;
}

- (void)show
{
    self.alpha = 0.0;
    self.contentView.transform= CGAffineTransformMakeScale(0.1, 0.1);

    UIWindow *window = [[UIApplication sharedApplication].delegate window];
    [window addSubview:self];

    [UIView animateWithDuration:0.25 delay:0.25 options:0
                     animations:^{
                         self.alpha = 1.0;
                         self.contentView.transform= CGAffineTransformMakeScale(1.15, 1.15);
                     } completion:^(BOOL finished) {
                         [UIView animateWithDuration:0.25
                                          animations:^{
                                              self.contentView.transform = CGAffineTransformIdentity;
                                          }];
                     }];
}

- (void)dismiss
{
    [UIView animateWithDuration:0.25
                     animations:^{
                         self.contentView.transform= CGAffineTransformMakeScale(1.15, 1.15);
                     } completion:^(BOOL finished) {
                         [UIView animateWithDuration:0.25
                                          animations:^{
                                              self.alpha = 0.0;
                                              self.contentView.transform = CGAffineTransformMakeScale(0.1, 0.1);
                                          } completion:^(BOOL finished) {
                                              [self.delegate alertViewDidDismiss:self];
                                              [self removeFromSuperview];
                                              
                                              if (self.completionHandler) {
                                                  self.completionHandler();
                                              }
                                          }];
                     }];
}

- (void)handleTapGesture:(UIGestureRecognizer *)sender
{
    [self dismiss];
}

- (void)setTitle:(NSString *)title
{
    _title = title;
    self.titleLabel.text = title;
}

- (void)setMessage:(NSString *)message
{
    _message = message;
    
    
    self.messageLabel.text = message;
    self.messageLabel.size = [_messageLabel.text sizeWithFont:_messageLabel.font
                                        constrainedToSize:CGSizeMake(self.width - 60, 220)
                                            lineBreakMode:_messageLabel.lineBreakMode];
    self.messageLabel.centerX = self.width/2;
    self.messageLabel.top = self.height / 2 - 74;
}

- (UILabel *)titleLabel
{
    if (!_titleLabel) {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, self.height/2 - 120, self.width - 40, 42)];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textColor = [UIColor romoWhite];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.font = [UIFont voiceForRomoWithSize:34];
        _titleLabel.adjustsFontSizeToFitWidth = YES;
        _titleLabel.minimumScaleFactor = 0.5;
        [self.contentView addSubview:_titleLabel];
    }
    return _titleLabel;
}

- (UILabel *)messageLabel
{
    if (!_messageLabel) {
        _messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _messageLabel.backgroundColor = [UIColor clearColor];
        _messageLabel.textColor = [UIColor romoWhite];
        _messageLabel.textAlignment = NSTextAlignmentCenter;
        _messageLabel.font = [UIFont fontWithSize:18];
        _messageLabel.numberOfLines = 0;
        [self.contentView addSubview:_messageLabel];
    }
    return _messageLabel;
}

@end
