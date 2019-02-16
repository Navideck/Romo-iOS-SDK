//
//  RMDoodleActionView.m
//  Romo
//

#import "RMDoodleActionView.h"
#import <QuartzCore/QuartzCore.h>
#import <Romo/RMMath.h>
#import "UIView+Additions.h"
#import "RMDoodle.h"
#import "RMDoodleView.h"

@interface RMDoodleActionView ()
@property (nonatomic, strong) RMDoodleView *doodleView;

@end

@implementation RMDoodleActionView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self.contentView addSubview:self.doodleView];
    }
    return self;
}

#pragma mark - Public Methods

- (void)setParameters:(NSArray *)parameters
{
    super.parameters = parameters;
    
    for (RMParameter *parameter in parameters) {
        if (parameter.type == RMParameterDoodle) {
            self.doodleView.doodle = parameter.value;
            self.editing = self.editing;
        }
    }
}

- (void)setEditing:(BOOL)editing
{
    super.editing = editing;
    
    self.doodleView.frame = self.contentView.bounds;
    self.doodleView.userInteractionEnabled = editing;
}

#pragma mark - Private Properties

- (RMDoodleView *)doodleView
{
    if (!_doodleView) {
        _doodleView = [[RMDoodleView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    return _doodleView;
}

@end
