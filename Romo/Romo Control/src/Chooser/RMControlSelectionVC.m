//
//  RMControlSelectionVC.m
//  Romo
//
//  Created on 11/25/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMControlSelectionVC.h"
#import "RMDrivableRomosResultsController.h"
//#import "RMTelepresenceClientViewController.h"
#import "RMWiFiDriveRemoteVC.h"
#import "RMWifiPeerRomoCell.h"
#import "RMTelepresencePeerRomoCell.h"
#import "RMControlDialPadCell.h"
#import "RMNoLocalRomosCell.h"
#import "RMPeer.h"
#import "RMContact.h"
#import "RMPlanetSpaceSceneView.h"
#import "UIView+Additions.h"
#import "RMAlertView.h"
#import "RMRomoDialer.h"
#import "RMWifiToolbar.h"
#import "Reachability.h"
#import "RMNetworkUtilities.h"

NSString * const kWifiPeerReuseIdentifier = @"WifiPeerReuseIdentifier";
NSString * const kTelepresencePeerReuseIdentifier = @"TelepresencePeerReuseIdentifier";
NSString * const kDialPadReuseIdentifier = @"DialPadReuseIdentifier";
NSString * const kNoLocalRomoReuseIdentifier = @"NoLocalRomoReuseIdentifier";

typedef enum {
    RMSelectionSectionNoRomos = 0,
    RMSelectionSectionPeerRomos = 1,
    RMSelectionSectionDialPad = 2
} RMSelectionSection;

@interface RMControlSelectionVC () <RMDrivableRomosResultsControllerDelegate, UICollectionViewDataSource, UICollectionViewDelegate, RMWiFiDriveRemoteVCDelegate>

// Data sources
@property (nonatomic, strong) RMDrivableRomosResultsController *romosResultsController;

// Views
@property (nonatomic, strong) RMPlanetSpaceSceneView *scene;
@property (nonatomic, strong) RMRomoDialer *dialer; // For iPad only, iPhone uses a cell.
@property (nonatomic, strong) RMWifiToolbar *toolbar;

@end

@implementation RMControlSelectionVC

#pragma mark - Predefined layouts

+ (UICollectionViewLayout *)standardLayout
{
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumLineSpacing = 0;
    layout.minimumInteritemSpacing = 0;
    
    if (iPad) {
        layout.itemSize = CGSizeMake([UIScreen mainScreen].bounds.size.width / 2.0,
                                     [UIScreen mainScreen].bounds.size.height - [RMWifiToolbar preferredHeight]);
    } else {
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        layout.itemSize = CGSizeMake(screenSize.width, screenSize.height - [RMWifiToolbar preferredHeight]);
    }
    
    return layout;
}

#pragma mark - UIViewController lifecycle

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    

    // Setup the results controller. This handles fetching all the peers (both local and remote contacts)
    self.romosResultsController = [[RMDrivableRomosResultsController alloc] init];
    self.romosResultsController.delegate = self;
    [self.romosResultsController performFetch:nil];
    
    // Add the space scene
    self.scene = [[RMPlanetSpaceSceneView alloc] initWithFrame:self.view.bounds];
    self.scene.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scene];
    [self.view sendSubviewToBack:self.scene];
    
    // Add the toolbar
    self.toolbar = [[RMWifiToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.width, [RMWifiToolbar preferredHeight])];
    self.toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.toolbar];
    
    // Set display and interaction properties of the UICollectionView
    self.collectionView.frame = CGRectMake(0, [RMWifiToolbar preferredHeight], self.view.width, self.view.height - [RMWifiToolbar preferredHeight]);
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.alwaysBounceHorizontal = YES;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.pagingEnabled = iPad ? NO : YES;
    
    if (iPad && [UIDevice currentDevice].isTelepresenceController) {
        // On the ipad we show the dialer outside of the collection view
        self.dialer = [[RMRomoDialer alloc] initWithFrame:CGRectMake(0, 0, 320, 460)];
        self.dialer.center = CGPointMake(self.view.boundsCenter.x, 300);
        [self.dialer.callButton addTarget:self action:@selector(handleCallPress:) forControlEvents:UIControlEventTouchUpInside];
        
        [self.view addSubview:self.dialer];
    }
    
    // Register the cell classes
    [self.collectionView registerClass:[RMWifiPeerRomoCell class] forCellWithReuseIdentifier:kWifiPeerReuseIdentifier];
    [self.collectionView registerClass:[RMTelepresencePeerRomoCell class] forCellWithReuseIdentifier:kTelepresencePeerReuseIdentifier];
    [self.collectionView registerClass:[RMControlDialPadCell class] forCellWithReuseIdentifier:kDialPadReuseIdentifier];
    [self.collectionView registerClass:[RMNoLocalRomosCell class] forCellWithReuseIdentifier:kNoLocalRomoReuseIdentifier];
    
    // Update the wifi name
    [self updateWifiName];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    // Gesture recognizer for the deletion of telepresence Romos
    UISwipeGestureRecognizer *swipeUpGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeOnCell:)];
    swipeUpGesture.direction = UISwipeGestureRecognizerDirectionUp;
    [self.collectionView addGestureRecognizer:swipeUpGesture];
    
    UISwipeGestureRecognizer *swipeDownGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeOnCell:)];
    swipeDownGesture.direction = UISwipeGestureRecognizerDirectionDown;
    [self.collectionView addGestureRecognizer:swipeDownGesture];
}

#pragma mark - Notifications

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    [self.romosResultsController refresh];
    [self updateWifiName];
    [self.collectionView reloadData];
}

#pragma mark - Refresh

#pragma mark - Connecting to other romos

- (void)handleCallWithNumber:(NSString *)number
{
//    RMTelepresenceClientViewController *controller =
//    [[RMTelepresenceClientViewController alloc] initWithNumber:number completion:^(NSError *error) {
//        if (error) {
//            DDLogError(@"Error: %@", [error localizedDescription]);
//        }
//        
//        [self dismissViewControllerAnimated:YES completion:nil];
//    }];
//    
//    [self presentViewController:controller animated:YES completion:nil];
}

- (void)handleLocalConnectionWithPeer:(RMPeer *)peer
{
    if ([peer.appVersion isEqualToString:RMRomoWiFiDriveVersion]) {
        RMWiFiDriveRemoteVC *driveController = [[RMWiFiDriveRemoteVC alloc] init];
        driveController.delegate = self;
        driveController.remotePeer = peer;
        [self presentViewController:driveController animated:YES completion:nil];
        
    } else {
        [[[RMAlertView alloc] initWithTitle:NSLocalizedString(@"App Out of Date", @"App Out of Date")
                                    message:NSLocalizedString(@"Download the latest version of the Romo app on both devices.", @"Download the latest version of the Romo app on both devices.")
                                   delegate:nil] show];
    }
}

#pragma mark - Updating UI

- (void)updateWifiName
{
    NetworkStatus internetStatus = [[Reachability reachabilityForLocalWiFi] currentReachabilityStatus];
    
    if (internetStatus != NotReachable) {
        [self.toolbar setTitleText:[RMNetworkUtilities WiFiName]];
    } else {
        [self.toolbar setTitleText:NSLocalizedString(@"No Wi-Fi", @"No Wi-Fi")];
    }
    
    [self performSelector:@selector(updateWifiName) withObject:nil afterDelay:5.0];
}

#pragma mark - Handling UI events

// iPad only
- (void)handleCallPress:(id)sender
{
    [self handleCallWithNumber:self.dialer.inputNumber];
}

#pragma mark - Handling Gestures

- (void)handleSwipeOnCell:(UISwipeGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        CGPoint swipePoint = [gestureRecognizer locationInView:self.collectionView];
        NSIndexPath *swipeIndexPath = [self.collectionView indexPathForItemAtPoint:swipePoint];
        
        if (self.romosResultsController.peerList.count == 0) {
            return;
        }
        
        id data = self.romosResultsController.peerList[swipeIndexPath.row];
        if ([data isKindOfClass:[RMContact class]]) {
            RMTelepresencePeerRomoCell *cell = (RMTelepresencePeerRomoCell *)[self.collectionView cellForItemAtIndexPath:swipeIndexPath];
            if (gestureRecognizer.direction == UISwipeGestureRecognizerDirectionUp) {
                cell.deleteButton.hidden = NO;
                [cell.deleteButton addTarget:self action:@selector(handleTelepresenceRomoDeleteButton:) forControlEvents:UIControlEventTouchUpInside];
                cell.deleteButton.tag = swipeIndexPath.row;
            } else {
                cell.deleteButton.hidden = YES;
                [cell.deleteButton removeTarget:self action:@selector(handleTelepresenceRomoDeleteButton:) forControlEvents:UIControlEventTouchUpInside];
            }
        }
    }
}

- (void)handleTelepresenceRomoDeleteButton:(UIButton *)sender
{
    sender.hidden = YES;
    if (self.romosResultsController.peerList[sender.tag]) {
        RMContact *data = (RMContact *)self.romosResultsController.peerList[sender.tag];
        [self.romosResultsController removeContactWithRomoID:data.romoID];
    }
}

#pragma mark - Cells

- (UICollectionViewCell *)peerCellForIndexPath:(NSIndexPath *)indexPath
{
    id data = self.romosResultsController.peerList[indexPath.row];
    NSString *reuseIdentifier = nil;
    
    // We need to determine if this is a local Wifi peer or a saved telepresence contact.
    // This is determined from the data's class.
    if ([data isKindOfClass:[RMPeer class]]) {
        reuseIdentifier = kWifiPeerReuseIdentifier;
    } else if ([data isKindOfClass:[RMContact class]]) {
        reuseIdentifier = kTelepresencePeerReuseIdentifier;
    }
    
    if (reuseIdentifier) {
        RMPeerRomoCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
        
        cell.data = data;
        [cell update];
        
        return cell;
    } else {
        DDLogError(@"A peer cell was requested, but no reuseIdentifier was found for the data's class: %@", [data class]);
        return nil;
    }
}

- (UICollectionViewCell *)dialPadCellForIndexPath:(NSIndexPath *)indexPath
{
    RMControlDialPadCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:kDialPadReuseIdentifier forIndexPath:indexPath];
    
    [cell setCallPressBlock:^ (NSString *number) {
        [self handleCallWithNumber:number];
    }];
    
    return cell;
}

- (UICollectionViewCell *)noLocalRomosCellForIndexPath:(NSIndexPath *)indexPath
{
    RMControlDialPadCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:kNoLocalRomoReuseIdentifier forIndexPath:indexPath];
    return cell;
}

#pragma mark - RMDrivableRomosResultsControllerDelegate

- (void)romoResultsController:(RMDrivableRomosResultsController *)controller
              didChangeObject:(id)object
                      atIndex:(NSUInteger)index
                forChangeType:(NSFetchedResultsChangeType)changeType
                     newIndex:(NSUInteger)newIndex
{
    // TODO: move remote romos to another section and use indexPaths
    
    NSArray *visibleCells = [self.collectionView visibleCells];
    UICollectionViewCell *currentCell = [visibleCells firstObject];
    NSIndexPath *currentIndexPath = [self.collectionView indexPathForCell:currentCell];
    
    [self.collectionView reloadData];
    
    // If on no-romo message, don't do custom scrolling
    if (iPad == NO && currentIndexPath.section == RMSelectionSectionNoRomos) {
        return;
    }
    
    // If on the DPad, let's just make sure we stay on it.
    if (currentIndexPath.section == RMSelectionSectionDialPad) {
        [self.collectionView scrollToItemAtIndexPath:currentIndexPath
                                    atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                            animated:NO];
        
        return;
    }
    
    
    // Else we need to make sure we stay on the currently selected Romo.
    NSUInteger romoSection = iPad ? 0 : RMSelectionSectionPeerRomos;
    
    switch (changeType) {
        case NSFetchedResultsChangeInsert:
            if (currentCell && currentIndexPath.row >= newIndex) {
                [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:currentIndexPath.row + 1 inSection:romoSection]
                                            atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                                    animated:NO];
            }
            break;
            
        case NSFetchedResultsChangeDelete:
            if (controller.peerList.count > 0 && currentIndexPath.row > index) {
                [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:currentIndexPath.row - 1 inSection:romoSection]
                                            atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                                    animated:NO];
            }
            break;
            
        default:
            break;
    }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    if (iPad) {
        return 1;
    } else {
        return [UIDevice currentDevice].isTelepresenceController ? 3 : 2;
    }
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (iPad) {
        return self.romosResultsController.count;
    }
    
    switch ((RMSelectionSection)section) {
        case RMSelectionSectionNoRomos:
            return self.romosResultsController.localRomoCount ? 0 : 1;
            
        case RMSelectionSectionPeerRomos:
            return self.romosResultsController.count;
            
        case RMSelectionSectionDialPad:
            return 1;
    }
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (iPad) {
        return [self peerCellForIndexPath:indexPath];
    }
    
    switch ((RMSelectionSection)indexPath.section) {
        case RMSelectionSectionNoRomos:
            return [self noLocalRomosCellForIndexPath:indexPath];
            
        case RMSelectionSectionPeerRomos:
            return [self peerCellForIndexPath:indexPath];
            
        case RMSelectionSectionDialPad:
            return [self dialPadCellForIndexPath:indexPath];
    }
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (iPad || indexPath.section == RMSelectionSectionPeerRomos) {
        id data = self.romosResultsController.peerList[indexPath.row];
        
        if ([data isKindOfClass:[RMPeer class]]) {
            [self handleLocalConnectionWithPeer:data];
        } else if ([data isKindOfClass:[RMContact class]]) {
            RMTelepresencePeerRomoCell *cell = (RMTelepresencePeerRomoCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
            // If the item is not currently being deleted
            // make the call
            if (cell.deleteButton.hidden == YES) {
                [self handleCallWithNumber:[data romoID]];
            }
        }
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self.scene scrollToPosition:scrollView.contentOffset
           withTotalContentWidth:(self.view.width * (2 + self.romosResultsController.peerList.count))];
}

#pragma mark - RMWiFiDriveRemoteVCDelegate

- (void)dismissDriveVC:(RMWiFiDriveRemoteVC *)driveVC
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
