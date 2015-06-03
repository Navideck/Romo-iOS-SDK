//
//  IntelHexLine.h
//  Object to represent one line of an Intel Hex memory image file.
//
//  Created on 2013-02-10.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <Foundation/Foundation.h>

#define BYTE_COUNT_START_INDEX  1
#define BYTE_COUNT_LENGTH       2
#define ADDRESS_START_INDEX     3
#define ADDRESS_LENGTH          4
#define TYPE_START_INDEX        7
#define TYPE_LENGTH             2
#define DATA_START_INDEX        9
#define CHECKSUM_LENGTH         2

typedef enum {
    DATA,
    END_OF_FILE,
    EXTENDED_SEGMENT_ADDRESS,
    START_SEGMENT_ADDRESS,
    EXTENDED_LINEAR_ADDRESS,
    START_LINEAR_ADDRESS
} IHEX_RECORD_TYPE;

typedef union {
    NSUInteger val;
    struct {
        uint8_t lowByte;
        uint8_t highByte;
    };
} Address;

@interface IntelHexLine : NSObject

/**
 Return an IntelHexLine object from the contents of the given string
 @return Initialized IntelHexLine object
 @param string which is one line of an intel hex image file
 @param line number corresponding to given string and resulting object
 */
- (id)initWithString:(NSString *)line number:(NSUInteger)number;

/**
 The data of the current object
 */
@property (nonatomic,readonly) NSMutableArray *data;

/**
 The data of the current object
 */
@property (nonatomic,readonly) uint8_t *bytes;

/**
 The line number of the current object
 */
@property (nonatomic,readonly) NSUInteger lineNumber;

/**
 The number of data bytes in the current object
 */
@property (nonatomic,readonly) NSUInteger byteCount;

/**
 The address of the data of the current object
 */
@property (nonatomic, readonly) Address address;

/**
 The record type of the current object
 */
@property (nonatomic,readonly) IHEX_RECORD_TYPE type;

/**
 The checksum of the current object as read from the file
 */
@property (nonatomic,readonly) NSUInteger checksum;


@end

