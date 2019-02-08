//
//  MasterViewController.h
//  RMCoreTest
//
//  Created by Dan Kane on 6/26/12.
//  Copyright (c) 2012 DK Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <RMCore/RMCore.h>

@class LEDTestViewController;

@interface MasterViewController : UITableViewController <UIAlertViewDelegate> {
    UIAlertView *alert;
}


@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *mfrLabel;
@property (weak, nonatomic) IBOutlet UILabel *modelLabel;
@property (weak, nonatomic) IBOutlet UILabel *serialLabel;
@property (weak, nonatomic) IBOutlet UILabel *firmwareLabel;
@property (weak, nonatomic) IBOutlet UILabel *hardwareLabel;
@property (weak, nonatomic) IBOutlet UILabel *bootloaderLabel;
@property (weak, nonatomic) IBOutlet UILabel *driveLabel;

- (void)updateInfoName:(NSString *)name
          manufacturer:(NSString *)mfr
           modelNumber:(NSString *)mn
          serialNumber:(NSString *)sn
           firmwareRev:(NSString *)fr
           hardwareRev:(NSString *)hr
         bootloaderRev:(NSString *)bl;

@end
