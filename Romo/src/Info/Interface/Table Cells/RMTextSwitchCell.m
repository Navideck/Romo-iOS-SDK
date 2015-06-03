//
//  RMTextButtonCell
//  Romo
//

#import "RMTextSwitchCell.h"
#import "UIColor+RMColor.h"
#import "UIFont+RMFont.h"
#import "UIView+Additions.h"

@interface RMTextSwitchCell ()

@property (nonatomic, strong) UIView *dividerLine;
@property (nonatomic, strong, readwrite) UISwitch *switchButton;

@end

@implementation RMTextSwitchCell

+ (instancetype)dequeueOrCreateCellForTableView:(UITableView *)tableView
{
    static NSString *identifier = @"RMTextButtonCell";
    id cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    
    if (cell == nil) {
        cell = [[self alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    
    return cell;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        
        self.mainLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.mainLabel.font = [UIFont smallFont];
        self.mainLabel.textColor = [UIColor whiteColor];
        self.mainLabel.backgroundColor = [UIColor clearColor];
        
        self.switchButton = [[UISwitch alloc] initWithFrame:CGRectZero];
        self.switchButton.tintColor = [UIColor romoBlue];
        
        [self addSubview:self.mainLabel];
        [self addSubview:self.switchButton];
        [self addSubview:self.dividerLine];
        
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)layoutSubviews
{
    self.mainLabel.frame = CGRectMake(20, 19, 197, 21);
    self.dividerLine.frame = CGRectMake(0, self.bounds.size.height - 0.5, self.bounds.size.width, 0.5);

    self.switchButton.centerY = self.height / 2.0;
    self.switchButton.right = self.width - 12;
}

@end
