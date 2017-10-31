//
//  SIUniversalAccessHelper.h
//  Silica
//

#import <Foundation/Foundation.h>

@interface SIUniversalAccessHelper : NSObject

/**
 *  @return YES if the current process has accessibility permissions and NO otherwise.
 */
+ (BOOL)isAccessibilityTrusted;

/**
 *  @return YES if accessibility is enabled and NO otherwise.
 */
+ (BOOL)accessibilityEnabled DEPRECATED_ATTRIBUTE;

/**
 *  If accessibility is not enabled presents an alert requesting that the user enable accessibility.
 */
+ (void)complainIfNeeded DEPRECATED_ATTRIBUTE;

@end
