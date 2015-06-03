//
//  RMiPadVC.m
//  Romo
//

#import "RMiPadVC.h"
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "UIImage+Tint.h"
#import "RMGradientLabel.h"
#import "RMSpaceScene.h"
#import "RMDockingRequiredVC.h"

@interface RMiPadVC ()

@end

@implementation RMiPadVC

- (void)viewDidLoad
{
    [super viewDidLoad];

    RMSpaceScene *spaceScene = [[RMSpaceScene alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:spaceScene];
    
    UIImageView *window = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"debriefingWindow.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(37, 37, 37, 37) resizingMode:UIImageResizingModeStretch]];
    window.frame = CGRectMake(0, 0, 360, 280);
    window.center = CGPointMake(self.view.width / 2.0, self.view.height / 2.0);
    window.userInteractionEnabled = YES;
    [self.view addSubview:window];
    
    RMGradientLabel *titleLabel = [[RMGradientLabel alloc] initWithFrame:CGRectZero];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = [UIFont fontWithSize:32.0];
    titleLabel.text = NSLocalizedString(@"iPad-Drive-Title", @"Download Romo Control");
    titleLabel.size = [titleLabel.text sizeWithFont:titleLabel.font];
    titleLabel.gradientColor = [UIColor greenColor];
    titleLabel.centerX = window.width / 2.0;
    titleLabel.top = 32;
    [window addSubview:titleLabel];
    
    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    subtitleLabel.backgroundColor = [UIColor clearColor];
    subtitleLabel.textColor = [UIColor whiteColor];
    subtitleLabel.font = [UIFont fontWithSize:18.0];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.text = NSLocalizedString(@"iPad-Drive-Subtitle", @"To take control of a Romo, download the all-new Romo Control app from the App Store");
    subtitleLabel.size = [subtitleLabel.text sizeWithFont:subtitleLabel.font constrainedToSize:CGSizeMake(window.width - 80, 72)];
    subtitleLabel.top = titleLabel.bottom + 16;
    subtitleLabel.centerX = window.width / 2.0;
    [window addSubview:subtitleLabel];
    
    UIImageView *bar = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"debriefingWindowBar.png"]];
    bar.centerX = window.width / 2;
    bar.bottom = window.height - 10;
    [window addSubview:bar];
    
    UIButton *downloadButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, window.width / 2, 64)];
    [downloadButton addTarget:self action:@selector(handleDownloadButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
    downloadButton.titleLabel.font = [UIFont fontWithSize:18.0];
    [downloadButton setTitle: NSLocalizedString(@"iPad-Drive-Continue", @"CONTINUE") forState:UIControlStateNormal];
    UIColor *color = [UIColor colorWithPatternImage:[RMGradientLabel gradientImageForColor:[UIColor greenColor] label:downloadButton.titleLabel]];
    [downloadButton setTitleColor:color forState:UIControlStateNormal];
    [downloadButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
    NSString *thumbnailName = @"debriefingContinueChevronGreen.png";
    [downloadButton setImage:[UIImage imageNamed:thumbnailName] forState:UIControlStateNormal];
    [downloadButton setImage:[[UIImage imageNamed:thumbnailName] tintedImageWithColor:[UIColor colorWithWhite:1.0 alpha:0.65]] forState:UIControlStateHighlighted];
    downloadButton.titleEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 38);
    downloadButton.imageEdgeInsets = UIEdgeInsetsMake(0, downloadButton.width - 44, 0, 0);
    downloadButton.bottom = bar.bottom;
    downloadButton.centerX = window.width / 2.0;
    [window addSubview:downloadButton];
}

- (UIView *)characterView
{
    return nil;
}

#pragma mark - Private Methods

- (void)handleDownloadButtonTouch:(UIButton *)downloadButton
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:RMRomoControlAppStoreURL]];
}

@end
