//
//  RMContactManager.m
//  Romo
//
//  Created on 11/12/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
#import "RMContactManager.h"
#import "RMControlAppDelegate.h"

//==============================================================================
@interface RMContactManager ()

@property (nonatomic, strong) NSManagedObjectContext *context;

@end

//==============================================================================
@implementation RMContactManager

#pragma mark - Initialization / Teardown
//------------------------------------------------------------------------------
- (id)init
{
    self = [super init];
    if (self) {
        // Grab the NSManagedObjectContext from the app delegate
        _context = ((RMControlAppDelegate *)[UIApplication sharedApplication].delegate).managedObjectContext;
    }
    return self;
}

#pragma mark - Adding, Removing, and Updating Contacts
//------------------------------------------------------------------------------
- (BOOL)updateOrAddContactWithID:(NSString *)romoID
                        userName:(NSString *)userName
                        romoName:(NSString *)romoName
{
    return [self updateContactWithID:romoID withUserName:userName withRomoName:romoName] ||
            [self addContactWithID:romoID withUserName:userName withRomoName:romoName];
}

//------------------------------------------------------------------------------
- (BOOL)addContactWithID:(NSString *)romoID
            withUserName:(NSString *)userName
            withRomoName:(NSString *)romoName
{
    // See if the contact already exists
    RMContact *newContact = [RMContact getContactWithID:romoID
                                 inManagedObjectContext:self.context];
    // If so, return no
    if (newContact) {
        return NO;
    }
    // Otherwise, create the contact and save the context
    else {
        [RMContact createContact:userName
                    withRomoName:romoName
                  withRomoNumber:romoID
                   withTimestamp:[NSDate date]
          inManagedObjectContext:self.context];
        [self saveContext];
        return YES;
    }
}

//------------------------------------------------------------------------------
- (BOOL)updateContactWithID:(NSString *)romoID
               withUserName:(NSString *)userName
               withRomoName:(NSString *)romoName
{
    RMContact *contactToUpdate = [RMContact getContactWithID:romoID
                                      inManagedObjectContext:self.context];
    if (contactToUpdate) {
        contactToUpdate.userName = userName;
        contactToUpdate.romoName = romoName;
        contactToUpdate.lastCallDate = [NSDate date];
        return YES;
    } else {
        return NO;
    }
}

//------------------------------------------------------------------------------
- (BOOL)removeContactWithID:(NSString *)romoID
{
    RMContact *contactToRemove = [RMContact getContactWithID:romoID
                                      inManagedObjectContext:self.context];
    
    if (contactToRemove) {
        [self.context deleteObject:contactToRemove];
        [self saveContext];
        return YES;
    } else {
        return NO;
    }
}

#pragma mark - Querying Contacts
//------------------------------------------------------------------------------
- (RMContact *)contactWithID:(NSString *)romoID
{
    return [RMContact getContactWithID:romoID
                inManagedObjectContext:self.context];
}

//------------------------------------------------------------------------------
- (NSArray *)getAllContacts
{
    return [RMContact getAllPeopleInManagedObjectContect:self.context];
}

#pragma mark - Core Data Syncing
//------------------------------------------------------------------------------
- (void)saveContext
{
    NSError *error;
    if ([self.context hasChanges] && ![self.context save:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
}

@end
