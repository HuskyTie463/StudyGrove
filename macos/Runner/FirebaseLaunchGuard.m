#import "FirebaseLaunchGuard.h"

#if __has_include(<FirebaseCore/FirebaseCore.h>)
#import <FirebaseCore/FirebaseCore.h>
#define SG_HAS_FIREBASE_CORE 1
#elif __has_include(<FirebaseCore/FIRApp.h>)
#import <FirebaseCore/FIRApp.h>
#import <FirebaseCore/FIROptions.h>
#define SG_HAS_FIREBASE_CORE 1
#endif

static void ConfigureDefaultFirebaseAppIfNeeded(void) {
#if SG_HAS_FIREBASE_CORE
  if ([FIRApp allApps][@"__FIRAPP_DEFAULT"] != nil) {
    return;
  }
  FIROptions *options = [FIROptions defaultOptions];
  if (options == nil) {
    NSLog(@"StudyGrove: GoogleService-Info.plist was not found; skipping native FIRApp configure.");
    return;
  }
  [FIRApp configureWithOptions:options];
#endif
}

void FirebaseLaunchGuardRun(void (^block)(void)) {
  @try {
    ConfigureDefaultFirebaseAppIfNeeded();
  } @catch (NSException *exception) {
    NSLog(@"StudyGrove: native FIRApp configure failed (%@): %@", exception.name,
          exception.reason);
  }

  @try {
    if (block != nil) {
      block();
    }
  } @catch (NSException *exception) {
    NSLog(@"StudyGrove: plugin registration failed (%@): %@", exception.name, exception.reason);
  }
}
