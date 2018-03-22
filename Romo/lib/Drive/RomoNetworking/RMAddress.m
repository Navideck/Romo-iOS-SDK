//
//  RMAddress.m
//  Romo
//

#import "RMAddress.h"

#pragma mark - Constants

#define KEY_HOST @"key_host"
#define KEY_PORT @"key_port"

#pragma mark -
#pragma mark - Address (Private)

@interface RMAddress ()
{
    AddressInfo *_info;
    AddressFamily _family;
    SockAddress *_sockAddress;
}

@end

#pragma mark -
#pragma mark -  Implementation (Address)

@implementation RMAddress

#pragma mark - Properties

@synthesize host=_host, port=_port;

#pragma mark - Creation

+ (RMAddress *)localAddressWithPort:(NSString *)port
{
    return [[RMAddress alloc] initLocalhostWithPort:port];
}

+ (RMAddress *)addressWithHost:(NSString *)host port:(NSString *)port
{
    return [[RMAddress alloc] initWithHost:host port:port];    
}

+ (RMAddress *)addressWithSockAddress:(SockAddress *)address
{
    return [[RMAddress alloc] initWithSockAddress:address];    
}

#pragma mark - Initialization

- (id)initLocalhostWithPort:(NSString *)port
{
    return [self initWithHost:@"localhost" port:port];
}

- (id)initWithHost:(NSString *)host port:(NSString *)port
{
    if (self = [super init])
    {
        [self setHost:host];
        [self setPort:port];
        
        _info = NULL;
        _family = 0;
        _sockAddress = NULL;
    }
    
    return self;
}

- (id)initWithSockAddress:(SockAddress *)address
{
    if (self = [super init])
    {        
        NSString *host = nil;
        NSString *port = nil;
        
        char bufferIPv4[INET_ADDRSTRLEN];
        char bufferIPv6[INET6_ADDRSTRLEN];
        
        switch (address->sa_family)
        {
            case AF_INET:
                inet_ntop(address->sa_family, &(((struct sockaddr_in *) address)->sin_addr), bufferIPv4, INET_ADDRSTRLEN);      
                host = @(bufferIPv4);
                port = [NSString stringWithFormat:@"%u", ntohs(((struct sockaddr_in *) address)->sin_port)];
                break;
                
            case AF_INET6:
                inet_ntop(address->sa_family, &(((struct sockaddr_in6 *) address)->sin6_addr), bufferIPv6, INET6_ADDRSTRLEN);        
                host = @(bufferIPv6);
                port = [NSString stringWithFormat:@"%u", ntohs(((struct sockaddr_in6 *) address)->sin6_port)]; 
                break;
                
            default:
                return nil;
        }
        
        [self setHost:host];
        [self setPort:port];
        
        _info = NULL;
        _family = address->sa_family;
        _sockAddress = address;
    }
    
    return self;
}

#pragma mark - Dealloc

- (void)dealloc
{
    
    if (_info)
        freeaddrinfo(_info);
    
}

#pragma mark - Methods

- (AddressInfo *)infoWithType:(SocketType)type
{
    if (!_info)
    {
        struct addrinfo hints, *res;
        
        memset(&hints, 0, sizeof(hints));
        
        hints.ai_flags = AI_PASSIVE;
        hints.ai_socktype = type;
        hints.ai_protocol = type == SOCK_STREAM ? IPPROTO_TCP : IPPROTO_UDP;
        hints.ai_family   = AF_INET;
        
        int gai_error;
        
        if ([_host isEqualToString:@"localhost"])
            gai_error = getaddrinfo(NULL, [_port UTF8String], &hints, &res);
        else
            gai_error = getaddrinfo([_host UTF8String], [_port UTF8String], &hints, &res);
        
        if (gai_error)
        {
            NSLog(@"Error: getaddrinfo returned error: %d", gai_error);
            
            return nil;
        }
        else
        {            
            _info = res;
            if (res->ai_addr)
            {
                _sockAddress = res->ai_addr;
                return res;
            }
            else 
            {
                return nil;            
            }
        }
    }
    
    return _info;
}

- (AddressFamily)family
{    
    if (!_family)
    {
        AddressInfo *info = [self infoWithType:0];
        _family = info->ai_family;
    }
    
    return _family;
}

- (SockAddress *)sockAddress
{
    if (!_sockAddress)
    {
        AddressInfo *info = [self infoWithType:0];
        _sockAddress = info->ai_addr;
    }
    
    return _sockAddress;
}

#pragma mark - Serializable

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super init])
    {
        [self setHost:[aDecoder decodeObjectForKey:KEY_HOST]];
        [self setPort:[aDecoder decodeObjectForKey:KEY_PORT]];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_host forKey:KEY_HOST];
    [aCoder encodeObject:_port forKey:KEY_PORT];
}

@end
