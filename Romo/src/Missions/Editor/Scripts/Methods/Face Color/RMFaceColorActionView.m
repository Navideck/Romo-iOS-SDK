//
//  RMFaceColorActionView.m
//  Romo
//

#import "RMFaceColorActionView.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "RMProgressManager.h"
#import <Romo/RMMath.h>

@interface RMFaceColorActionView ()

@property (nonatomic, strong) UIImageView *iPhone;
@property (nonatomic, strong) UIImageView *screen;

@property (nonatomic, strong) UIImageView *faceColorBar;
@property (nonatomic, strong) UIView *knob;

@property (nonatomic, strong) UIColor *faceColor;

@end

@implementation RMFaceColorActionView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.title = @"";
        
        _iPhone = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"iphoneFull.png"]];
        self.iPhone.center = CGPointMake(self.contentView.width / 2, self.contentView.height / 2 + 20);
        self.iPhone.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView insertSubview:self.iPhone atIndex:0];
        
        _screen = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"romoFaceColorBig.png"]];
        self.screen.origin = CGPointMake(15, 44);
        self.screen.alpha = 1.0;
        self.screen.clipsToBounds = YES;
        self.screen.layer.borderWidth = 2;
        self.screen.layer.borderColor = [UIColor colorWithWhite:0.08 alpha:1.0].CGColor;
        [self.iPhone addSubview:self.screen];
    }
    return self;
}

- (void)setParameters:(NSArray *)parameters
{
    super.parameters = parameters;
    
    for (RMParameter *parameter in parameters) {
        if (parameter.type == RMParameterColor) {
            self.faceColor = parameter.value;
            
            // Get the float value of the hue to figure out where the knob should be
            CGFloat hue = 0;
            [self.faceColor getHue:&hue saturation:0 brightness:0 alpha:0];
            [self updateColorForLocation:hue * self.faceColorBar.width];
        }
    }
}

- (void)willLayoutForEditing:(BOOL)editing
{
    [super willLayoutForEditing:editing];
    
    if (editing) {
        self.faceColorBar.center = CGPointMake(self.width / 2.0, self.contentView.height / 2 + 200);
        [self.contentView addSubview:self.faceColorBar];
        
        self.knob.centerY = self.faceColorBar.centerY;
        [self.contentView addSubview:self.knob];
    }
}

- (void)setEditing:(BOOL)editing
{
    super.editing = editing;
    
    if (editing) {
        self.iPhone.center = CGPointMake(self.contentView.width / 2, self.contentView.height / 2);
        self.faceColorBar.center = CGPointMake(self.width / 2.0, self.contentView.height / 2 + 180);
        self.knob.centerY = self.faceColorBar.centerY;
    } else {
        self.iPhone.center = CGPointMake(self.contentView.width / 2, self.contentView.height / 2 + 32);
    }
}

- (void)didLayoutForEditing:(BOOL)editing
{
    [super didLayoutForEditing:editing];
    
    if (editing) {

    } else {
        [self.faceColorBar removeFromSuperview];
    }
}

#pragma mark - Touches

- (void)handleTap:(UIGestureRecognizer *)tap
{
    [self updateColorForLocation:[tap locationInView:self.faceColorBar].x];
}

#pragma mark - Private Methods

- (void)setFaceColor:(UIColor *)faceColor
{
    _faceColor = faceColor;
    self.screen.backgroundColor = faceColor;
    self.knob.backgroundColor = faceColor;
    
    for (RMParameter *parameter in self.parameters) {
        if (parameter.type == RMParameterColor) {
            parameter.value = faceColor;
        }
    }
}

- (void)updateColorForLocation:(CGFloat)location
{
    location = CLAMP(0, location, self.faceColorBar.width);
    
    // Move the knob to the tap location and compute the hue at that location
    float ratio = location / self.faceColorBar.width;
    self.knob.centerX = ratio * self.faceColorBar.width + self.faceColorBar.left;
    self.faceColor = [UIColor colorWithHue:ratio saturation:1.0 brightness:1.0 alpha:1.0];
}

- (UIImageView *)faceColorBar
{
    if (!_faceColorBar) {
        _faceColorBar = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"faceColorBar.png"]];
        _faceColorBar.height = 80.0;
        _faceColorBar.contentMode = UIViewContentModeScaleAspectFit;
        _faceColorBar.userInteractionEnabled = YES;
        _faceColorBar.centerX = self.width / 2.0;
        [_faceColorBar addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)]];
        [_faceColorBar addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)]];
    }
    return _faceColorBar;
}

- (UIView *)knob
{
    if (!_knob) {
        _knob = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
        _knob.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1.0].CGColor;
        _knob.layer.borderWidth = 3.0;
        _knob.layer.cornerRadius = _knob.width / 2.0;
        _knob.userInteractionEnabled = NO;
    }
    return _knob;
}

@end
