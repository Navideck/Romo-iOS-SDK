//
//  RMDrivableRomosResultsController.h
//  Romo
//
//  Created on 11/22/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@protocol RMDrivableRomosResultsControllerDelegate;

@interface RMDrivableRomosResultsController : NSObject

@property (nonatomic, weak) id <RMDrivableRomosResultsControllerDelegate> delegate;
@property (nonatomic, strong, readonly) NSArray *peerList;
@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly) NSUInteger localRomoCount;

- (BOOL)performFetch:(NSError **)error;
- (void)refresh;
- (void)removeContactWithRomoID:(NSString *)romoID;

@end

@protocol RMDrivableRomosResultsControllerDelegate <NSObject>

@optional
- (void)romoResultsControllerWillChangeContent:(RMDrivableRomosResultsController *)controller;
- (void)romoResultsController:(RMDrivableRomosResultsController *)controller
              didChangeObject:(id)object
                      atIndex:(NSUInteger)index
                forChangeType:(NSFetchedResultsChangeType)changeType
                     newIndex:(NSUInteger)newIndex;
- (void)romoResultsControllerDidChangeContent:(RMDrivableRomosResultsController *)controller;

@end
