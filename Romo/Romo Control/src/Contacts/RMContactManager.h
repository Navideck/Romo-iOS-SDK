//
//  RMContactManager.h
//  Romo
//
//  Created on 11/12/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "RMContact+Helper.h"

@interface RMContactManager : NSObject

// Adding, Updating, and Removing Contacts
//==============================================================================
- (BOOL)updateOrAddContactWithID:(NSString *)romoID
                        userName:(NSString *)userName
                        romoName:(NSString *)romoName;

/** 
 Attempts to add a contact with given parameters.
 
 @returns YES if the contact was created or NO if the contact already exists in
 the DB.
 */
- (BOOL)addContactWithID:(NSString *)romoID
            withUserName:(NSString *)userName
            withRomoName:(NSString *)romoName;

/**
 Updates the contact's information
 */
- (BOOL)updateContactWithID:(NSString *)romoID
               withUserName:(NSString *)userName
               withRomoName:(NSString *)romoName;

/**
 Removes a contact with a given unique ID. 
 
 @returns YES if the contact was successfully removed, NO if the contact was 
 not in the DB.
 */
- (BOOL)removeContactWithID:(NSString *)romoID;

// Querying contacts
//==============================================================================
/**
 Gets a contact with a particular ID
 
 @returns A pointer to the RMContact (or nil if this contact does not exist)
 */
- (RMContact *)contactWithID:(NSString *)romoID;

/**
 Creates a list of all contacts sorted by connection date (most recent first)
 
 @returns The sorted list of all contacts
 */
- (NSArray *)getAllContacts;

@end
