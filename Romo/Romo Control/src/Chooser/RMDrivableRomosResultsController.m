//
//  RMDrivableRomosResultsController.m
//  Romo
//
//  Created on 11/22/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "RMDrivableRomosResultsController.h"
#import "RMContactManager.h"
#import "RMControlAppDelegate.h"
#import "RMSessionManager.h"
#import "RMConnection.h"

@interface RMDrivableRomosResultsController () <NSFetchedResultsControllerDelegate, RMConnectionDelegate>

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSFetchedResultsController *contactsController;

@property (nonatomic, strong) NSArray *localPeerList;
@property (nonatomic, strong, readwrite) NSArray *peerList;

@end

@implementation RMDrivableRomosResultsController

- (BOOL)performFetch:(NSError **)error
{
    self.localPeerList = @[];
    
    [RMSessionManager shared].connectionDelegate = self;
    return [self createContactsFecthedRequest:error];
}

- (void)refresh
{
    [self willChangePeerList];
    self.localPeerList = [RMSessionManager shared].peerList;
    [self regeneratePeerList];
    [self didChangePeerList];
}

- (void)removeContactWithRomoID:(NSString *)romoID
{
    // Empty the peerLis first
    // So that when we try to delete an item at index 2,
    // the item at index 3 doesn't throw an exception
    self.peerList = @[];
    RMContactManager *contactManager = [[RMContactManager alloc] init];
    if([contactManager removeContactWithID:romoID]) {
        [self refresh];
    }
}

#pragma mark - Getting number of fetched objects

- (NSUInteger)count
{
    return self.peerList.count;
}

- (NSUInteger)localRomoCount
{
    return self.localPeerList.count;
}

#pragma mark - Interacting with contacts

- (NSManagedObjectContext *)managedObjectContext
{
    if (!_managedObjectContext) {
        _managedObjectContext = [(RMControlAppDelegate *)([UIApplication sharedApplication].delegate) managedObjectContext];
    }
    return _managedObjectContext;
}

- (BOOL)createContactsFecthedRequest:(NSError **)error
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"RMContact"];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"lastCallDate" ascending:NO];
    
    fetchRequest.sortDescriptors = @[sortDescriptor];
    
    self.contactsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                  managedObjectContext:[self managedObjectContext]
                                                                    sectionNameKeyPath:nil
                                                                             cacheName:nil];
    
    self.contactsController.delegate = self;
    
    // Perform the initial fetch
    if (![self.contactsController performFetch:error]) {
        DDLogError(@"Failed to fetch local contacts: %@", (*error).localizedDescription);
        return NO;
    } else {
        [self willChangePeerList];
        [self regeneratePeerList];
        [self didChangePeerList];
        
        return YES;
    }
}

#pragma mark - Regenerating the peer list

- (void)willChangePeerList
{
    if ([self.delegate respondsToSelector:@selector(romoResultsControllerWillChangeContent:)]) {
        [self.delegate romoResultsControllerWillChangeContent:self];
    }
}

- (void)didChangePeerList
{
    if ([self.delegate respondsToSelector:@selector(romoResultsControllerDidChangeContent:)]) {
        [self.delegate romoResultsControllerDidChangeContent:self];
    }
}

- (void)regeneratePeerList
{
    self.peerList = [self.localPeerList arrayByAddingObjectsFromArray:self.contactsController.fetchedObjects];
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self willChangePeerList];
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    NSUInteger index = indexPath.row + self.localPeerList.count;
    NSUInteger newIndex = newIndexPath.row + self.localPeerList.count;
    
    
    switch (type) {
        case NSFetchedResultsChangeInsert:
            index = NSNotFound;
            break;
            
        case NSFetchedResultsChangeDelete:
            newIndex = NSNotFound;
            break;
            
        default:
            break;
    }
    
    if ([self.delegate respondsToSelector:@selector(romoResultsController:didChangeObject:atIndex:forChangeType:newIndex:)]) {
        [self.delegate romoResultsController:self
                             didChangeObject:anObject
                                     atIndex:index
                               forChangeType:type
                                    newIndex:newIndex];
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self regeneratePeerList];
    [self didChangePeerList];
}

#pragma mark - RMConnectionDelegate

- (void)peerAdded:(RMPeer *)peer
{
//    NSLog(@"peerAdded, %@", [[RMSessionManager shared].peerList valueForKeyPath:@"name"]);
    
    NSUInteger index = [self.localPeerList indexOfObject:peer];
    
    if (index != NSNotFound) {
        [self peerUpdated:peer];
        return;
    }
    
    
    [self willChangePeerList];
    
    self.localPeerList = [self.localPeerList arrayByAddingObject:peer];
    [self regeneratePeerList];
    
    if ([self.delegate respondsToSelector:@selector(romoResultsController:didChangeObject:atIndex:forChangeType:newIndex:)]) {
        [self.delegate romoResultsController:self
                             didChangeObject:peer
                                     atIndex:NSNotFound
                               forChangeType:NSFetchedResultsChangeInsert
                                    newIndex:self.localPeerList.count - 1];
    }
    
    [self didChangePeerList];
}

- (void)peerUpdated:(RMPeer *)peer
{
//    NSLog(@"peerUpdated, %@", [[RMSessionManager shared].peerList valueForKeyPath:@"name"]);
    
    NSUInteger index = [self.localPeerList indexOfObject:peer];
    
    if (index == NSNotFound) {
        return;
    }
    
    [self willChangePeerList];
    
    self.localPeerList = [self.localPeerList arrayByAddingObject:peer];
    [self regeneratePeerList];
    
    if ([self.delegate respondsToSelector:@selector(romoResultsController:didChangeObject:atIndex:forChangeType:newIndex:)]) {
        [self.delegate romoResultsController:self
                             didChangeObject:peer
                                     atIndex:index
                               forChangeType:NSFetchedResultsChangeUpdate
                                    newIndex:index];
    }
    
    [self didChangePeerList];
}

- (void)peerRemoved:(RMPeer *)peer
{
//    NSLog(@"peerRemoved, %@", [[RMSessionManager shared].peerList valueForKeyPath:@"name"]);
    
    NSUInteger index = [self.localPeerList indexOfObject:peer];
    
    if (index == NSNotFound) {
        return;
    }
    
    [self willChangePeerList];
    
    self.localPeerList = [self.localPeerList filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.identifier != %@", peer.identifier]];
    [self regeneratePeerList];
    
    if ([self.delegate respondsToSelector:@selector(romoResultsController:didChangeObject:atIndex:forChangeType:newIndex:)]) {
        [self.delegate romoResultsController:self
                             didChangeObject:peer
                                     atIndex:index
                               forChangeType:NSFetchedResultsChangeDelete
                                    newIndex:NSNotFound];
    }
    
    [self didChangePeerList];}

- (void)sessionInitiated:(RMSession *)session
{
    
}

@end
