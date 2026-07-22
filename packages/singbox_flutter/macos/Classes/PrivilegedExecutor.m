#import "PrivilegedExecutor.h"

@implementation PrivilegedExecutor

+ (OSStatus)executeWithPrivileges:(AuthorizationRef)auth
                             tool:(NSString *)tool
                        arguments:(NSArray<NSString *> *)arguments {
    // 构建 null 结尾的 char* 数组
    NSUInteger count = arguments.count;
    char **argv = (char **)malloc((count + 1) * sizeof(char *));
    if (!argv) return errAuthorizationInternal;

    for (NSUInteger i = 0; i < count; i++) {
        argv[i] = (char *)[arguments[i] UTF8String];
    }
    argv[count] = NULL;

    FILE *io = NULL;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    OSStatus status = AuthorizationExecuteWithPrivileges(
        auth,
        [tool fileSystemRepresentation],
        kAuthorizationFlagDefaults,
        argv,
        &io
    );
#pragma clang diagnostic pop

    free(argv);
    if (io) fclose(io);
    return status;
}

@end
