//
//  SIUniversalAccessHelper.m
//  Silica
//

#import "SIUniversalAccessHelper.h"

@implementation SIUniversalAccessHelper

+ (BOOL)isAccessibilityTrusted {
    return AXIsProcessTrustedWithOptions(NULL);
}

+ (BOOL)accessibilityEnabled {
    return AXAPIEnabled();
}

+ (void)complainIfNeeded {
    if (!self.isAccessibilityTrusted) {
        [NSApp activateIgnoringOtherApps:YES];

        NSString *applicationName = NSBundle.mainBundle.infoDictionary[(__bridge NSString *)kCFBundleNameKey];
        NSString *alertTitle = [NSString stringWithFormat:@"%@ Requires Universal Access", applicationName];
        NSString *firstLine = [NSString stringWithFormat:@"For %@ to function properly, access for assistive devices must be enabled first.\n\n", applicationName];

        NSInteger result = NSRunAlertPanel(alertTitle,
                                           firstLine,
                                           @"To enable this feature, click \"Enable access for assistive devices\" in the Universal Access pane of System Preferences.",
                                           @"Open Universal Access",
                                           @"Dismiss",
                                           nil);
        
        if (result == NSAlertDefaultReturn) {
            NSString *src = @"tell application \"System Preferences\"\nactivate\nset current pane to pane \"com.apple.preference.universalaccess\"\nend tell";
            NSAppleScript *a = [[NSAppleScript alloc] initWithSource:src];
            [a executeAndReturnError:nil];
        }
    }
}

@end
