//
//  RMContact+Helper.m
//  Romo
//
//  Created on 11/12/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
#import "RMContact+Helper.h"

@implementation RMContact (Helper)

//------------------------------------------------------------------------------
+ (RMContact *)createContact:(NSString *)userName
                withRomoName:(NSString *)romoName
              withRomoNumber:(NSString *)romoID
               withTimestamp:(NSDate *)lastCallDate
      inManagedObjectContext:(NSManagedObjectContext *)context
{
    RMContact *contact = [self getContactWithID:romoID
                         inManagedObjectContext:context];
    if (!contact) {
        contact = [NSEntityDescription insertNewObjectForEntityForName:@"RMContact"
                                                inManagedObjectContext:context];
        contact.userName     = userName;
        contact.romoName     = romoName;
        contact.romoID       = romoID;
        contact.lastCallDate = lastCallDate;
    }
    return contact;
}

//------------------------------------------------------------------------------
+ (RMContact *)getContactWithID:(NSString *)romoID
         inManagedObjectContext:(NSManagedObjectContext *)context
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"romoID == %@", romoID];
    return [RMContact _queryForPersonWithPredicate:predicate inManagedObjectContext:context];
}

//------------------------------------------------------------------------------
+ (NSArray *)getAllPeopleInManagedObjectContect:(NSManagedObjectContext *)context
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"RMContact"];
    
    // Sort by date
    NSSortDescriptor *sortByDate = [[NSSortDescriptor alloc] initWithKey:@"lastCallDate" ascending:NO];
    request.sortDescriptors = @[sortByDate];
    
    NSError *error;
    NSArray *allPeople = [context executeFetchRequest:request error:&error];
    if (error) {
        NSLog(@"%@", error);
        return nil;
    } else {
        return allPeople;
    }
}

// Helper method for running an NSFetchRequest for an RMContact with a
//  given predicate
//------------------------------------------------------------------------------
+ (RMContact *)_queryForPersonWithPredicate:(NSPredicate *)predicate
                     inManagedObjectContext:(NSManagedObjectContext *)context
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"RMContact"];
    request.predicate = predicate;
    
    NSError *error;
    NSArray *contacts = [context executeFetchRequest:request error:&error];
    if (error) {
        NSLog(@"%@", error);
        return nil;
    } else {
        if (contacts.count) {
            return [contacts firstObject];
        } else {
            return nil;
        }
    }
}

@end
