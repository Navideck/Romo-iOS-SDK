//
//  IntelHexLine.m
//  AaronTest
//
//  Created on 2013-02-10.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "IntelHexLine.h"

@interface IntelHexLine()

@property (nonatomic) uint8_t cksum;

@end

@implementation IntelHexLine


// TODO: use an input stream instead of NSScanner
- (id)initWithString:(NSString *)line number:(NSUInteger)number
{
    self = [super init];
    NSRange range;
    
    if (line == nil) {
        return nil;
    }

    _cksum = 0x00;
    _lineNumber = number;
    
    range.location = BYTE_COUNT_START_INDEX;
    range.length = BYTE_COUNT_LENGTH;
    [[NSScanner scannerWithString:[line substringWithRange:range]] scanHexInt:&_byteCount];
    _cksum += _byteCount;
    
    
    range.location = ADDRESS_START_INDEX;
    range.length = ADDRESS_LENGTH;
    [[NSScanner scannerWithString:[line substringWithRange:range]] scanHexInt:(NSUInteger *)&_address];
    _cksum += _address.lowByte;
    _cksum += _address.highByte;
    
    range.location = TYPE_START_INDEX;
    range.length = TYPE_LENGTH;
    [[NSScanner scannerWithString:[line substringWithRange:range]] scanHexInt:&_type];
    _cksum += _type;
    
    
    switch(_type) {
        case DATA:
            range.length = 2;
            _data = [[NSMutableArray alloc] init];
            _bytes = malloc(_byteCount);
            for(int i = 0; i < _byteCount; i++)
            {
                unsigned int b;
                range.location = DATA_START_INDEX + 2*i;
                [[NSScanner scannerWithString:[line substringWithRange:range]] scanHexInt:&b];
                [_data addObject:[NSNumber numberWithInt:b]];
                _bytes[i] = (uint8_t)b;
                _cksum += b;
            }
            
            break;
        case END_OF_FILE:
            _data = NULL;
            break;
            
        case EXTENDED_SEGMENT_ADDRESS:
        case START_SEGMENT_ADDRESS:
        case EXTENDED_LINEAR_ADDRESS:
        case START_LINEAR_ADDRESS:
        default:
            NSLog(@"record type unsupported");
            return nil;
    }
    
    
    range.location += 2;
    range.length = CHECKSUM_LENGTH;
    [[NSScanner scannerWithString:[line substringWithRange:range]] scanHexInt:&_checksum];
    
    _cksum ^= 0xFF;
    _cksum += 0x01;
    
    if (_cksum != _checksum) {
        NSLog(@"ERROR: checksum mismatch on line %d (read: %.2X expected: %.2X)", _lineNumber, _checksum, _cksum);
        return nil;
    }
    
    return self;
}

- (id)initWithBytes:(uint8_t *)bytes
{
    self = [super init];
    if (bytes[0] != ':') {
        NSLog(@"Error: line did not start with ':'");
        return nil;
    }
    
    NSString *countStr = [[NSString alloc] initWithBytes:bytes+1 length:2 encoding:NSASCIIStringEncoding];
    _byteCount = [countStr intValue];
    
    return self;
}

- (void)dealloc
{
    if (_bytes) {
        free(_bytes);
    }
}

@end
