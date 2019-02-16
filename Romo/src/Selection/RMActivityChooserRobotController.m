//
//  RMActivityChooserRobotController.m
//  Romo
//

#import "RMActivityChooserRobotController.h"
#import <Romo/UIDevice+Romo.h>
#import "RMActivityChooserView.h"
#import "RMAppDelegate.h"
#import "RMMissionRobotController.h"
#import "RMSandboxMission.h"
#import "RMChaseRobotController.h"
#import "RMLineFollowRobotController.h"
#import "RMAlertView.h"
//#import "RMTelepresencePresence.h"

@interface RMActivityChooserRobotController () <RMActivityRobotControllerDelegate>

@property (nonatomic, strong) RMActivityChooserView *view;

@end

@implementation RMActivityChooserRobotController

@dynamic view;

- (void)loadView
{
    self.view = [[RMActivityChooserView alloc] initWithFrame:[UIScreen mainScreen].bounds];

    [self.view.backButton addTarget:self
                             action:@selector(handleBackButtonTouch:)
                   forControlEvents:UIControlEventTouchUpInside];

    [self.view.missionsButton addTarget:self
                             action:@selector(handleMissionsButtonTouch:)
                   forControlEvents:UIControlEventTouchUpInside];

    [self.view.theLabButton addTarget:self
                             action:@selector(handleTheLabButtonTouch:)
                   forControlEvents:UIControlEventTouchUpInside];

    [self.view.chaseButton addTarget:self
                             action:@selector(handleChaseButtonTouch:)
                   forControlEvents:UIControlEventTouchUpInside];
    
    [self.view.lineFollowButton addTarget:self
                                   action:@selector(handleLineFollowButtonTouch:)
                         forControlEvents:UIControlEventTouchUpInside];
    
    [self.view.RomoControlButton addTarget:self
                                   action:@selector(handleRomoControlButtonTouch:)
                         forControlEvents:UIControlEventTouchUpInside];
    
    self.title = NSLocalizedString(@"Romo",@"Romo");
}

- (RMRomoFunctionalities)initiallyActiveFunctionalities
{
    // We don't need anything external running
    return RMRomoFunctionalityNone;
}

- (RMRomoInterruptions)initiallyAllowedInterruptions
{
    // never interrupt
    return RMRomoInterruptionNone;
}

#pragma mark - RMActivityRobotControllerDelegate

- (void)activityDidFinish:(RMActivityRobotController *)activity
{
    // Pop back to Romo
    [(RMAppDelegate *)[UIApplication sharedApplication].delegate popRobotController];
}

#pragma mark - Private Methods

- (void)handleBackButtonTouch:(id)sender
{
    RMRobotController *defaultController = ((RMAppDelegate *)[UIApplication sharedApplication].delegate).defaultController;
    ((RMAppDelegate *)[UIApplication sharedApplication].delegate).robotController = defaultController;
}

- (void)handleMissionsButtonTouch:(id)sender
{
    RMMissionRobotController *missionRobotController = [[RMMissionRobotController alloc] init];
    [((RMAppDelegate *)[UIApplication sharedApplication].delegate) pushRobotController:missionRobotController];
}

- (void)handleTheLabButtonTouch:(id)sender
{
    RMMissionRobotController *theLabController = [[RMMissionRobotController alloc] initWithMission:[[RMSandboxMission alloc] initWithChapter:RMChapterTheLab index:0]];
    [((RMAppDelegate *)[UIApplication sharedApplication].delegate) pushRobotController:theLabController];
}

- (void)handleChaseButtonTouch:(id)sender
{
    RMChaseRobotController *chaseRobotController = [[RMChaseRobotController alloc] init];
    chaseRobotController.delegate = self;
    [(RMAppDelegate *)[UIApplication sharedApplication].delegate pushRobotController:chaseRobotController];
}

- (void)handleLineFollowButtonTouch:(id)sender
{
    RMLineFollowRobotController *lineFollowRobotController = [[RMLineFollowRobotController alloc] init];
    lineFollowRobotController.delegate = self;
    [(RMAppDelegate *)[UIApplication sharedApplication].delegate pushRobotController:lineFollowRobotController];
}

- (void)handleRomoControlButtonTouch:(id)sender
{
    [self showRomoControlAlert];
}

- (void)showRomoControlAlert
{
    NSString *messageTemplate = nil;
    if ([UIDevice currentDevice].isDockableTelepresenceDevice) {
        messageTemplate = NSLocalizedString(@"RomoControl-Message-Compatible-Device", @"Visit http://romo.tv on another iDevice or computer to control me.\n\n"
                                            "My Romo number is:\n%@");
    } else {
        messageTemplate = NSLocalizedString(@"RomoControl-Message-NonCompatible-Device", @"Visit http://romo.tv on another local iDevice to control me.");
    }
    
    NSString *romoNumber = @"123-456-7890";
    
//    NSString *romoNumber = [[RMTelepresencePresence sharedInstance] number];

//    if ([UIDevice currentDevice].isDockableTelepresenceDevice && !romoNumber.length) {
//        [[RMTelepresencePresence sharedInstance] fetchNumber:^(NSError *error) {
//            if (error) {
//                [[[RMAlertView alloc] initWithTitle:NSLocalizedString(@"Error", @"Error")
//                                            message:NSLocalizedString(@"RomoControl-Message-Number-Error", @"There was an issue fetching my Romo number. Make sure you are connected to the internet.")
//                                           delegate:nil] show];
//            } else {
//                [self showRomoControlAlert];
//            }
//        }];
//    }
    
    RMAlertView *alert = [[RMAlertView alloc] initWithTitle:NSLocalizedString(@"RomoControl-Alert-Title", @"Romo Control")
                                                    message:[NSString stringWithFormat:messageTemplate, romoNumber]
                                                   delegate:nil];
    
    [alert setCompletionHandler:^ {
        self.Romo.activeFunctionalities = disableFunctionality(RMRomoFunctionalityBroadcasting, self.Romo.activeFunctionalities);
        
        [UIView animateWithDuration:0.25 animations:^{
            self.view.missionsButton.alpha = 1.0;
            self.view.theLabButton.alpha = 1.0;
            self.view.lineFollowButton.alpha = 1.0;
            self.view.chaseButton.alpha = 1.0;
            self.view.RomoControlButton.alpha = 1.0;
        }];
    }];
    
    [alert show];
    
    [UIView animateWithDuration:0.25 animations:^{
        self.view.missionsButton.alpha = 0.0;
        self.view.theLabButton.alpha = 0.0;
        self.view.lineFollowButton.alpha = 0.0;
        self.view.chaseButton.alpha = 0.0;
        self.view.RomoControlButton.alpha = 0.0;
    }];
    
    self.Romo.activeFunctionalities = enableFunctionality(RMRomoFunctionalityBroadcasting, self.Romo.activeFunctionalities);
}

#pragma mark - Private Properties

- (void)setTitle:(NSString *)title
{
    [super setTitle:NSLocalizedString(title, @"title")];
    self.view.titleLabel.text = NSLocalizedString(title, @"title");
}


@end
