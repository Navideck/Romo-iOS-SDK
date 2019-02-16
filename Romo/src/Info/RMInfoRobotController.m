//
//  RMInfoRobotController.m
//  Romo
//

#import "RMInfoRobotController.h"
#import "UIView+Additions.h"
#import "UIColor+RMColor.h"
#import <Romo/UIDevice+UDID.h>
#import "UIFont+RMFont.h"
#import "RMAppDelegate.h"
#import "RMInfoRobotView.h"
#import "RMTextLabelCell.h"
#import "RMTextSwitchCell.h"
#import "RMTextInputCell.h"
#import "RMTextButtonCell.h"
#import "RMSpaceScene.h"
#import "RMPopupWebview.h"
#import "Reachability.h"
#import "RMNetworkUtilities.h"
#import "RMSoundEffect.h"
//#import "RMTelepresencePresence.h"
#import <Romo/UIDevice+Romo.h>

static NSString *telepresenceNumberKey = @"telepresenceNumberKey";

typedef enum RMInfoRobotControllerRow {
    RMInfoRobotControllerRowName = 0,
    RMInfoRobotControllerRowRomoNumber,
    RMInfoRobotControllerRowSoundEffects,
    RMInfoRobotControllerRowIdleMovement,
    RMInfoRobotControllerRowAppVersion,
    RMInfoRobotControllerRowFirmware,
    RMInfoRobotControllerRowHardware,
    RMInfoRobotControllerRowSerial,
    RMInfoRobotControllerRowLicense,
    RMInfoRobotControllerRowCount
} RMInfoRobotControllerRow;

@interface RMInfoRobotController () <UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate>

@property (nonatomic, strong) RMInfoRobotView *view;

@property (nonatomic, strong) NSString *telepresenceNumber;
@property (nonatomic, strong) NSString *firmwareVersion;
@property (nonatomic, strong) NSString *bootloaderVersion;
@property (nonatomic, strong) NSString *hardwareVersion;
@property (nonatomic, strong) NSString *wifiName;
@property (nonatomic, strong) NSString *serialNumber;
@property (nonatomic, strong) RMPopupWebview *popupWebview;

@end

@implementation RMInfoRobotController

@dynamic view;

- (RMRomoFunctionalities)initiallyActiveFunctionalities
{
    // Only allow broadcasting
    return RMRomoFunctionalityBroadcasting;
}

- (RMRomoInterruptions)initiallyAllowedInterruptions
{
    // We'll allow for firmware updating to interrupt
    return RMRomoInterruptionFirmwareUpdating;
}

- (void)loadView
{
    self.view = [[RMInfoRobotView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"Info-View-Title", @"Dashboard");
    
    self.view.tableView.delegate = self;
    self.view.tableView.dataSource = self;
    [self.view.tableView reloadData];
    
    if ([UIDevice currentDevice].isDockableTelepresenceDevice) {
        NSString *cachedTelepresenceNumber = [[NSUserDefaults standardUserDefaults] valueForKey:telepresenceNumberKey];
        self.telepresenceNumber = cachedTelepresenceNumber.length ? cachedTelepresenceNumber : NSLocalizedString(@"TP-Number-Loading-Title", @"Loading...");
        [self fetchTelepresenceNumber];
    }
    
    [self.view.dismissButton addTarget:self action:@selector(handleDismissButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)controllerWillBecomeActive
{
    [super controllerWillBecomeActive];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRobotDidConnectNotification:)
                                                 name:RMCoreRobotDidConnectNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRobotDidDisconnectNotification:)
                                                 name:RMCoreRobotDidDisconnectNotification
                                               object:nil];
    
    self.view.spaceScene.cameraLocation = RMPoint3DMake(0, 0.5, -0.25);
    [self.view.spaceScene setCameraLocation:RMPoint3DMake(0, 0, -0.25) animatedWithDuration:0.65 completion:nil];
}

- (void)controllerDidBecomeActive
{
    [super controllerDidBecomeActive];
    // Fetch network name
    self.wifiName = ([[Reachability reachabilityForLocalWiFi] currentReachabilityStatus] != NotReachable) ? [RMNetworkUtilities WiFiName] : NSLocalizedString(@"No Wi-Fi", @"Generic No Wi-Fi Title");
    
    [self fetchHardwareAndFirmwareVersions];
    
    [RMSoundEffect playBackgroundEffectWithName:spaceLoopSound repeats:YES gain:1.0];
    [self.view.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:RMInfoRobotControllerRowName inSection:0]]
                               withRowAnimation:UITableViewRowAnimationNone];
}

- (void)controllerWillResignActive
{
    [super controllerWillResignActive];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    RMTextInputCell *cell = (id)[self.view.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:RMInfoRobotControllerRowName inSection:0]];
    [cell.inputField resignFirstResponder];
    
    NSString *nameWithoutSpaces = [cell.inputField.text stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (nameWithoutSpaces.length > 1) {
        self.Romo.name = cell.inputField.text;
    }
    
    [self.view.spaceScene setCameraLocation:RMPoint3DMake(0, 0.5, -0.25) animatedWithDuration:0.35 completion:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setTitle:(NSString *)title
{
    super.title = title;
    
    CGFloat actualFontSize;
    self.view.titleLabel.text = title;
    self.view.titleLabel.size = [title sizeWithFont:[UIFont largeFont]
                                        minFontSize:18
                                     actualFontSize:&actualFontSize
                                           forWidth:self.view.width - 160
                                      lineBreakMode:NSLineBreakByClipping];
    self.view.titleLabel.font = [UIFont fontWithSize:actualFontSize];
    self.view.titleLabel.center = CGPointMake(self.view.navigationBar.width / 2.0, self.view.navigationBar.height / 2.0);
}


#pragma mark - UI Events

- (void)handleDismissButtonTouch:(id)sender
{
    [RMSoundEffect stopBackgroundEffect];
    [RMSoundEffect playForegroundEffectWithName:backButtonSound repeats:NO gain:1.0];
    [[(RMTextInputCell *)[self.view.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:RMInfoRobotControllerRowName inSection:0]] inputField] resignFirstResponder];
    
    ((RMAppDelegate *)[UIApplication sharedApplication].delegate).robotController = ((RMAppDelegate *)[UIApplication sharedApplication].delegate).defaultController;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    RMTextInputCell *cell = (id)[self.view.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:RMInfoRobotControllerRowName inSection:0]];
    
    NSString *nameWithoutSpaces = [textField.text stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (nameWithoutSpaces.length > 1 && textField == cell.inputField) {
        [textField resignFirstResponder];
        self.Romo.name = textField.text;
        return YES;
    }
    return NO;
}

- (void)handleLicenseLinkTap:(id)sender
{
    self.popupWebview.top = self.view.bottom;
    NSURLRequest *txtFileRequest = [[NSURLRequest alloc] initWithURL:[[NSBundle mainBundle] URLForResource:@"software-legal" withExtension:@"txt"]];

    [self.popupWebview.webView loadRequest:txtFileRequest];
    
    [self.view addSubview:self.popupWebview];
    [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         self.popupWebview.top = 0;
                     } completion:nil];
}

- (void)handleDismissWebviewButtonTouch:(id)sender
{
    [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         self.popupWebview.top = self.view.height;
                     } completion:^(BOOL finished) {
                         [self.popupWebview removeFromSuperview];
                         self.popupWebview = nil;
                     }];
}

#pragma mark - RMRomoDelegate

- (UIView *)characterView
{
    return nil;
}

#pragma mark - Private Methods

- (void)fetchTelepresenceNumber
{
//    if ([[UIDevice currentDevice] isDockableTelepresenceDevice]) {
//        [[RMTelepresencePresence sharedInstance] fetchNumber:^(NSError *error) {
//            if (error) {
//                
//            } else {
//                self.telepresenceNumber = [RMTelepresencePresence sharedInstance].number;
//                
//                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:RMInfoRobotControllerRowRomoNumber inSection:0];
//                [self.view.tableView reloadRowsAtIndexPaths:@[indexPath]
//                                           withRowAnimation:UITableViewRowAnimationNone];
//            }
//        }];
//    }
}


- (void)handleRobotDidConnectNotification:(NSNotification *)notification
{
    [self fetchHardwareAndFirmwareVersions];
}

- (void)handleRobotDidDisconnectNotification:(NSNotification *)notification
{
    [self fetchHardwareAndFirmwareVersions];
}

- (void)fetchHardwareAndFirmwareVersions
{
    self.firmwareVersion = self.Romo.robot.identification.firmwareVersion.length ? self.Romo.robot.identification.firmwareVersion : @"–";
    self.hardwareVersion = self.Romo.robot.identification.hardwareVersion.length ? self.Romo.robot.identification.hardwareVersion : @"–";
    self.serialNumber = self.Romo.robot.identification.serialNumber.length ? self.Romo.robot.identification.serialNumber : @"–";
    self.bootloaderVersion = self.Romo.robot.identification.bootloaderVersion.length ? self.Romo.robot.identification.bootloaderVersion : @"–";
    
    int offset = [[UIDevice currentDevice] isDockableTelepresenceDevice] ? 0 : 1;
    [self.view.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:RMInfoRobotControllerRowFirmware-offset inSection:0],
                                                  [NSIndexPath indexPathForRow:RMInfoRobotControllerRowHardware-offset inSection:0],
                                                  [NSIndexPath indexPathForRow:RMInfoRobotControllerRowSerial-offset inSection:0]]
                               withRowAnimation:UITableViewRowAnimationNone];
}

- (RMPopupWebview *)popupWebview
{
    if (!_popupWebview) {
        _popupWebview = [[RMPopupWebview alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [_popupWebview.dismissButton addTarget:self action:@selector(handleDismissWebviewButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _popupWebview;
}

#pragma mark - UITableViewDelegate / UITableViewDataSource

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    RMTextInputCell *cell = (id)[self.view.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:RMInfoRobotControllerRowName inSection:0]];
    [cell.inputField resignFirstResponder];
    self.Romo.name = cell.inputField.text;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat yOffset = scrollView.contentOffset.y;
    self.view.spaceScene.cameraLocation = RMPoint3DMake(self.view.spaceScene.cameraLocation.x, 0.0025 * yOffset, self.view.spaceScene.cameraLocation.z);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if ([[UIDevice currentDevice] isDockableTelepresenceDevice]) {
        return RMInfoRobotControllerRowCount;
    } else {
        return RMInfoRobotControllerRowCount - 1;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger row = indexPath.row;
    if (row >= RMInfoRobotControllerRowRomoNumber && ![[UIDevice currentDevice] isDockableTelepresenceDevice]) {
        row++;
    }
    
    if (row == RMInfoRobotControllerRowName) {
        RMTextInputCell *cell = [RMTextInputCell dequeueOrCreateCellForTableView:tableView];
        
        cell.mainLabel.text = NSLocalizedString(@"Info-Label-Name", @"Name");
        cell.inputField.text = [self.Romo.name isEqualToString:@""] ? NSLocalizedString(@"Romo",@"Romo") : self.Romo.name;
        cell.inputField.delegate = self;
        cell.inputField.accessibilityLabel = @"Input Name";
        cell.inputField.isAccessibilityElement = YES;
        
        
        return cell;
    } else if (row == RMInfoRobotControllerRowAppVersion) {
        RMTextLabelCell *cell = [RMTextLabelCell dequeueOrCreateCellForTableView:tableView];
        
        cell.mainLabel.text = NSLocalizedString(@"Info-Label-AppVersion", @"App Version");
        cell.secondaryLabel.text = [NSString stringWithFormat:@"%@",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
        
        return cell;
    } else if (row == RMInfoRobotControllerRowRomoNumber) {
        RMTextLabelCell *cell = [RMTextLabelCell dequeueOrCreateCellForTableView:tableView];
        
        cell.mainLabel.text = NSLocalizedString(@"Info-Label-RomoNumber", @"Romo Number");
        cell.secondaryLabel.text = self.telepresenceNumber;
        
        return cell;
    } else if (row == RMInfoRobotControllerRowFirmware) {
        RMTextLabelCell *cell = [RMTextLabelCell dequeueOrCreateCellForTableView:tableView];
        
        cell.mainLabel.text = NSLocalizedString(@"Info-Label-Firmware", @"Firmware/Bootloader");
        cell.secondaryLabel.text = [NSString stringWithFormat:@"%@/%@",self.firmwareVersion,self.bootloaderVersion];
        
        return cell;
    } else if (row == RMInfoRobotControllerRowHardware) {
        RMTextLabelCell *cell = [RMTextLabelCell dequeueOrCreateCellForTableView:tableView];
        
        cell.mainLabel.text = NSLocalizedString(@"Info-Label-Network", @"Wi-Fi");
        cell.secondaryLabel.text = self.wifiName;
        
        return cell;
    } else if (row == RMInfoRobotControllerRowSerial) {
        RMTextLabelCell *cell = [RMTextLabelCell dequeueOrCreateCellForTableView:tableView];
        
        cell.mainLabel.text = NSLocalizedString(@"Info-Label-Serial", @"Serial Number");
        cell.secondaryLabel.text = self.serialNumber;
        
        return cell;
    } else if (row == RMInfoRobotControllerRowLicense) {
        RMTextButtonCell *cell = [RMTextButtonCell dequeueOrCreateCellForTableView:tableView];
        cell.mainLabel.text = NSLocalizedString(@"Info-Label-License", @"License");
        [cell.rightButton setTitle:NSLocalizedString(@"navideck.com/romo-x/legal", @"navideck.com/romo-x/legal") forState:UIControlStateNormal];
        [cell.rightButton addTarget:self action:@selector(handleLicenseLinkTap:) forControlEvents:UIControlEventTouchUpInside];
        
        return cell;
        
    } else if (row == RMInfoRobotControllerRowSoundEffects) {
        RMTextSwitchCell *cell = [RMTextSwitchCell dequeueOrCreateCellForTableView:tableView];
        
        cell.mainLabel.text = NSLocalizedString(@"Info-Label-SoundEffects", @"Sound Effects");
        cell.switchButton.tag = RMInfoRobotControllerRowSoundEffects;
        cell.switchButton.on = [[NSUserDefaults standardUserDefaults] boolForKey:soundEffectsEnabledKey];
        [cell.switchButton addTarget:self action:@selector(handleSwitchValueChange:) forControlEvents:UIControlEventValueChanged];
        
        return cell;
        
    } else if (row == RMInfoRobotControllerRowIdleMovement) {
        RMTextSwitchCell *cell = [RMTextSwitchCell dequeueOrCreateCellForTableView:tableView];
        
        cell.mainLabel.text = NSLocalizedString(@"Info-Label-IdleMovement", @"Idle Movements");
        cell.switchButton.tag = RMInfoRobotControllerRowIdleMovement;
        cell.switchButton.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"idleMovementEnabled"];
        [cell.switchButton addTarget:self action:@selector(handleSwitchValueChange:) forControlEvents:UIControlEventValueChanged];
        
        return cell;
    }

    return [[UITableViewCell alloc]init];
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([cell isKindOfClass:[RMTextInputCell class]]) {
        ((RMTextInputCell *)cell).inputField.delegate = nil;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    id cell = [tableView cellForRowAtIndexPath:indexPath];
    
    if ([cell isKindOfClass:[RMTextInputCell class]]) {
        [((RMTextInputCell *)cell).inputField becomeFirstResponder];
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

- (void)handleSwitchValueChange:(id)sender
{
    if ([sender isKindOfClass:[UISwitch class]]) {
        UISwitch *switchButton = (UISwitch *)sender;
        if (switchButton.tag == RMInfoRobotControllerRowSoundEffects) {
            [[NSUserDefaults standardUserDefaults] setBool:switchButton.isOn forKey:soundEffectsEnabledKey];
        } else if (switchButton.tag == RMInfoRobotControllerRowIdleMovement) {
            [[NSUserDefaults standardUserDefaults] setBool:switchButton.isOn forKey:@"idleMovementEnabled"];
        }
        
    }
}

@end
