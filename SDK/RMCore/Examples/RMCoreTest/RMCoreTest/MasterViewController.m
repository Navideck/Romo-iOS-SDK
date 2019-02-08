//
//  MasterViewController.m
//  RMCoreTest
//
//  Created by Dan Kane on 6/26/12.
//  Copyright (c) 2012 DK Technologies. All rights reserved.
//

#import "MasterViewController.h"
#import "LEDTestViewController.h"
#import "MotorTestViewController.h"
#import "DriveTestViewController.h"
#import "RMCoreTestAppDelegate.h"
#import <RMCore/RMCoreRobot_Internal.h>

@interface MasterViewController () {
    NSArray *_categories;
}
@end

@implementation MasterViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = @"Categories";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    _categories = [[NSArray alloc] initWithObjects:
                   @"LEDs",
                   @"Motors",
                   @"Get Motor Current",
                   @"Show Battery Status",
                   @"Show Charging State",
                   @"Drive",
                   @"Reset Robot",
                   nil];
    
    alert = [[UIAlertView alloc] initWithTitle:@"Title"
                                       message:@"Message"
                                      delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidUnload
{
    [self setNameLabel:nil];
    [self setMfrLabel:nil];
    [self setModelLabel:nil];
    [self setSerialLabel:nil];
    [self setFirmwareLabel:nil];
    [self setHardwareLabel:nil];
    [self setBootloaderLabel:nil];
    [self setDriveLabel:nil];
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

//- (void)dataReceivedForCommand:(uint8_t)command
//{
//    if (command == CMD_GET_MOTOR_CURRENT) {
//        [alert setTitle:@"Motor Current"];
//        [alert setMessage:[NSString stringWithFormat:@"Left: %d\nRight: %d\nTilt: %d", _romo.motorCurrentLeft, _romo.motorCurrentRight, _romo.motorCurrentTilt]];
//        [alert show];
//    }
//}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _categories.count;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }


    NSDate *object = [_categories objectAtIndex:indexPath.row];
    cell.textLabel.text = [object description];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UIViewController *viewController;
    
    if ([[_categories objectAtIndex:indexPath.row] isEqualToString:@"LEDs"]) {
        viewController = [[LEDTestViewController alloc] initWithNibName:@"LEDTestViewController" bundle:nil];
    }
    else if ([[_categories objectAtIndex:indexPath.row] isEqualToString:@"Motors" ]) {
        viewController = [[MotorTestViewController alloc] initWithNibName:@"MotorTestViewController" bundle:nil];
    }
    else if ([[_categories objectAtIndex:indexPath.row] isEqualToString:@"Get Motor Current"]) {
        [alert setTitle:@"(L,R,tilt) Motor Current"];
        [alert setMessage:[NSString stringWithFormat:@"(%f, %f, %f)",ROBOT.leftDriveMotor.motorCurrent,ROBOT.rightDriveMotor.motorCurrent,ROBOT.tiltMotor.motorCurrent]];
        [alert show];
    }
    else if ([[_categories objectAtIndex:indexPath.row] isEqualToString:@"Show Battery Status"]) {
        [alert setTitle:@"Battery Status"];
        [alert setMessage:[NSString stringWithFormat:@"%d%%",(int)(ROBOT.vitals.batteryLevel * 100.0)]];
        [alert show];
    }
    else if ([[_categories objectAtIndex:indexPath.row] isEqualToString:@"Show Charging State"]) {
        [alert setTitle:@"Charging State"];
        [alert setMessage:[NSString stringWithFormat:@"%@",ROBOT.vitals.isCharging ? @"Charging" : @"Not charging"]];
        [alert show];
    }
    else if ([[_categories objectAtIndex:indexPath.row] isEqualToString:@"Drive"]) {
        viewController = [[DriveTestViewController alloc] initWithNibName:@"DriveTestViewController" bundle:nil];
    }
    else if ([[_categories objectAtIndex:indexPath.row] isEqualToString:@"Reset Robot"]) {
        [ROBOT performSelector:@selector(softReset)];
    }


    
    if (viewController)
        [self.navigationController pushViewController:viewController animated:YES];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)updateInfoName:(NSString *)name
          manufacturer:(NSString *)mfr
           modelNumber:(NSString *)mn
          serialNumber:(NSString *)sn
           firmwareRev:(NSString *)fr
           hardwareRev:(NSString *)hr
         bootloaderRev:(NSString *)bl
{
    [self.nameLabel setText:name];
    [self.mfrLabel setText:mfr];
    [self.modelLabel setText:mn];
    [self.serialLabel setText:sn];
    [self.firmwareLabel setText:fr];
    [self.hardwareLabel setText:hr];
    [self.bootloaderLabel setText:bl];
}


@end
