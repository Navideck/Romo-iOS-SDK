//
//  IntelHexImage.m
//  AaronTest
//
//  Created on 2013-02-10.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "IntelHexImage.h"

@interface IntelHexImage()

@property (nonatomic) NSArray *lines;
@property (nonatomic) NSUInteger currentDataBufOffset;
@property (nonatomic) NSUInteger lineIndex;
@property (nonatomic) NSUInteger lineCount;

@end


@implementation IntelHexImage


- (Address)address
{
    return (Address)(self.currentDataBufOffset + self.startAddress);
}

- (Address)wordAddress
{
    return (Address)((self.currentDataBufOffset + self.startAddress)/2);
}

- (NSUInteger)blockCount
{
    return(self.dataBuf.length/self.blockSize);
}

- (NSUInteger)length
{
    return self.dataBuf.length;
}


- (id)initWithContentsOfFile:(NSString *)path
{
    self = [super init];
    if (self) {
        NSString *fileData;
        fileData = [[NSString alloc] initWithContentsOfFile:path encoding:NSASCIIStringEncoding error:nil];
        _currentDataBufOffset = 0;
        _lineIndex = 0;
        _lines = [fileData componentsSeparatedByString:@"\n"];
        _lineCount = [_lines count]-1;
        
        [self fillDataBuf];
    }
    return self;
}


- (id)initWithContentsOfURL:(NSURL *)url
{
    self = [super init];
    if (self) {
        NSString *fileData;
        fileData = [[NSString alloc] initWithContentsOfURL:url encoding:NSASCIIStringEncoding error:nil];
        _currentDataBufOffset = 0;
        _lineIndex = 0;
        _lines = [fileData componentsSeparatedByString:@"\n"];
        _lineCount = [_lines count]-1;
        
        [self fillDataBuf];
    }
    return self;
}


- (void)fillDataBuf
{
    self.startAddress = [[IntelHexLine alloc] initWithString:_lines[0] number:0].address.val;
    self.currentDataBufOffset = self.startAddress;
    self.dataBuf = [[NSMutableData alloc] init];
    
    for(int i=0; i<[self.lines count]-1; i++) {
        NSString *line = [self.lines objectAtIndex:i];
        IntelHexLine *iLine = [[IntelHexLine alloc] initWithString:line number:self.lineIndex++];

        // add the data from each line of the file to the databuffer
        [self.dataBuf appendBytes:iLine.bytes length:iLine.byteCount];
        
        // check if the address has jumped beyond where we think index should be
        // in that case pad the buffer with 0xFF so code maintains it's relative
        // position
        if (iLine.address.val > self.currentDataBufOffset) {
            NSData *fill = [[NSMutableData alloc] initWithCapacity:iLine.address.val - self.currentDataBufOffset];
            [self.dataBuf appendData:fill];
        }
        
        self.currentDataBufOffset += iLine.byteCount;
    }
}


- (NSUInteger)readBlock:(uint8_t *)dest :(NSUInteger)dataBufOffset
{
    NSRange r;
    
    // you're already at or past the end of the buffer, so you get no bytes
    if (dataBufOffset >= self.dataBuf.length) {
        return 0;
    }
    
    r.location = dataBufOffset;
    r.length = (self.blockSize+dataBufOffset < self.dataBuf.length) ? self.blockSize : (self.dataBuf.length - dataBufOffset);
    
    [self.dataBuf getBytes:dest range:r];
    
    return r.length;
}


- (NSData *)readBlock:(NSUInteger)dataBufOffset
{
    NSRange r;
    
    if (dataBufOffset >= self.dataBuf.length) {
        return 0;
    }
    
    r.location = dataBufOffset;
    r.length = (self.blockSize+dataBufOffset < self.dataBuf.length) ? self.blockSize : (self.dataBuf.length - dataBufOffset);

    return [self.dataBuf subdataWithRange:r];
}


- (NSUInteger)readCurrentBlock:(uint8_t *)dest
{
    return [self readBlock:dest :self.currentDataBufOffset];
}


- (NSData *)readCurrentBlock
{
    return [self readBlock:self.currentDataBufOffset];
}


- (void)increaseDataBufOffset:(NSUInteger)bytes
{
    self.currentDataBufOffset += bytes;
}


- (void)resetDataBufOffset
{
    self.blockIndex = 0;
    self.currentDataBufOffset = 0;
}


- (void)incrementBlockIndex
{
    self.blockIndex++;
    [self increaseDataBufOffset:self.blockSize];
}

@end
