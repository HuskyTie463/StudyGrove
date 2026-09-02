#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Runs `block` inside Objective-C `@try/@catch`.
/// Swift `do/catch` cannot catch `NSException` from FIRApp.
void FirebaseLaunchGuardRun(void (^ _Nonnull block)(void));

#ifdef __cplusplus
}
#endif
