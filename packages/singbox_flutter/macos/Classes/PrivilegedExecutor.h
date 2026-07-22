#import <Foundation/Foundation.h>
#import <Security/Security.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C wrapper for the deprecated AuthorizationExecuteWithPrivileges API.
/// Swift cannot call deprecated C APIs directly; this ObjC bridge suppresses the warning.
@interface PrivilegedExecutor : NSObject

/// Runs `tool` as root using the given AuthorizationRef.
/// `arguments` is an NSArray of NSString, e.g. @[@"/tmp/script.sh"].
+ (OSStatus)executeWithPrivileges:(AuthorizationRef)auth
                             tool:(NSString *)tool
                        arguments:(NSArray<NSString *> *)arguments;

@end

NS_ASSUME_NONNULL_END
