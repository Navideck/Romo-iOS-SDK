//
//  RMTextLabelCell.m
//  Romo
//

#import "RMTextLabelCell.h"
#import "UIColor+RMColor.h"
#import "UIFont+RMFont.h"

@interface RMTextLabelCell ()

@property (nonatomic, strong) UIView *dividerLine;

@end

@implementation RMTextLabelCell

+ (instancetype)dequeueOrCreateCellForTableView:(UITableView *)tableView
{
    static NSString *identifier = @"RMTextLabelCell";
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
        
        self.secondaryLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.secondaryLabel.font = [UIFont mediumFont];
        self.secondaryLabel.minimumScaleFactor = 0.65;
        self.secondaryLabel.adjustsFontSizeToFitWidth = YES;
        self.secondaryLabel.textColor = [UIColor whiteColor];
        self.secondaryLabel.textAlignment = NSTextAlignmentRight;
        self.secondaryLabel.backgroundColor = [UIColor clearColor];
        
        [self addSubview:self.mainLabel];
        [self addSubview:self.secondaryLabel];
        [self addSubview:self.dividerLine];

        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)layoutSubviews
{
    self.mainLabel.frame = CGRectMake(20, 19, 197, 21);
    self.secondaryLabel.frame = CGRectMake(145, 16, 155, 28);
    self.dividerLine.frame = CGRectMake(0, self.bounds.size.height - 0.5, self.bounds.size.width, 0.5);
}

@end
