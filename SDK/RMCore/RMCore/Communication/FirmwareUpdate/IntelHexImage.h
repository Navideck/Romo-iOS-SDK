//
//  IntelHexImage.h
//  AaronTest
//
//  Created on 2013-02-10.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IntelHexLine.h"

#define ATMEGA_PAGE_SIZE 128 //in bytes


@interface IntelHexImage : NSObject

#pragma mark - Initialization

/**
 Initializes an IntelHexFile object with the contents of the given file.
 @return An initialized IntelHexFile object
 @param path of the intel hex file to load
 */
- (id)initWithContentsOfFile:(NSString *)path;

/**
 Initializes an IntelHexFile object with the content of the given url
 @return An initialized IntelHexFile object
 @param url of the intel hex file to load
 */
- (id)initWithContentsOfURL:(NSString *)url;

/**
 Reads a block of data of upto blockSize bytes, starting from the given
 offset in the dataBuf to the buffer provided.
 @return number of bytes read
 @param destination buffer (should be at least blockSize bytes)
 @param offset in dataBuf at which to start reading
 */
- (NSUInteger)readBlock:(uint8_t *)dest :(NSUInteger)dataBufOffset;

/**
 Reads the current block of data (as defined by blockSize and blockIndex)
 and stores it in the provided buffer
 @return number of bytes read
 @param destination buffer (should be at least blockSize bytes)
 */
- (NSUInteger)readCurrentBlock:(uint8_t *)dest;

/**
 Reads the current block of data (as defined by blockSize and blockIndex)
 and returns it as an NSData object
 @return NSData object containing the current block of data
 @param offset in dataBuf at which to start reading
 */
- (NSData *)readBlock:(NSUInteger)dataBufOffset;

/**
 Reads the current block of data (as defined by blockSize and blockIndex)
 and returns it as an NSData object
 @return NSData object containing the current block of data
 */
- (NSData *)readCurrentBlock;

/**
 Set the internal index and offsets to the next block of data.  This advances
 to the 'next' datablock for use with readBlock
 */
- (void)incrementBlockIndex;

/**
 Reset the internal index and data offsets to the first block of data
 */
- (void)resetDataBufOffset;

/**
 The buffer containing flash data
 */
@property (nonatomic) NSMutableData *dataBuf;

/**
 The address of the current block with byte addressing
 */
@property (nonatomic, readonly) Address address;

/**
 The address of the current block with word address (used in STK500 protocol)
 */
@property (nonatomic, readonly) Address wordAddress;

/**
 The number of bytes of data
 */
@property (nonatomic, readonly) NSUInteger length; //length of hex data in bytes

/**
 The size of the datablocks we are dealing with
 */
@property (nonatomic) NSUInteger blockSize; //maximum block size

/**
 The index of the current data block we are dealing with
 */
@property (nonatomic) NSUInteger blockIndex; //current block being used

/**
 The total number of datablocks for the image
 */
@property (nonatomic, readonly) NSUInteger blockCount; //total number of blocks

/**
 The memory address (with byte addressing) of the beginning of the flash image
 */
@property (nonatomic) NSUInteger startAddress; //first address of

@end
