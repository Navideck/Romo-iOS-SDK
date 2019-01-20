//
//  Network.h
//  Romo
//

#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <netinet/in.h>
#import <net/if.h>
#import <net/if_dl.h>
#import <sys/socket.h> 
#import <sys/sysctl.h>

#pragma mark - Constants --

typedef struct addrinfo AddressInfo;
typedef struct sockaddr SockAddress;
typedef int SocketType;
typedef int NativeSocket;
typedef int AddressFamily;

#pragma mark -
#pragma mark - NetworkUtils --

/**
 * Contains useful Network Utility class methods.
 */
@interface RMNetworkUtilities : NSObject

#pragma mark - Class Methods --

/**
 * Returns the constant header size used for describing data.
 * @return The size of the data header currently used.
 */
+ (uint32_t)headerSize;

/**
 * Packs an integer into the provided buffer at the designated offset.
 * @param integer The integer to pack.
 * @param buffer The buffer to pack the integer into.
 * @param offset The offset at which to pack the integer.
 */
+ (void)packInteger:(NSUInteger)integer intoBuffer:(uint8_t *)buffer offset:(uint32_t)offset;

+ (NSString *)WiFiName;

@end

#pragma mark -
#pragma mark - NSData (NetworkUtils) --

/**
 * Extends NSData to provide some Network Utility methods related to 
 */
@interface NSData (NetworkUtils)

#pragma mark - Methods --

/**
 * Creates a heap-allocated byte array with the data header included.
 * @return A heap-allocated byte array containing the NSData's bytes with the data header.
 */
- (char *)bytesWithHeader;

/**
 * Finds the size of the NSData object, taking into account the addition of the data header.
 * @return The size of the bytes plus the data header.
 */
- (NSUInteger)sizeWithHeader;

@end
