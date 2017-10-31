//
//  SIApplication.h
//  Silica
//

#import "SIAccessibilityElement.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Block type for the handling of accessibility notifications.
 *
 *  @param accessibilityElement The accessibility element that the accessibility notification pertains to. Will always be an element either owned by the application or the application itself.
 */
typedef void (^SIAXNotificationHandler)(SIAccessibilityElement *accessibilityElement);

/**
 *  Accessibility wrapper for application elements.
 */
@interface SIApplication : SIAccessibilityElement

/**
 *  Attempts to construct an accessibility wrapper from an NSRunningApplication instance.
 *
 *  @param runningApplication A running application in the shared workspace.
 *
 *  @return A SIApplication instance if an accessibility element could be constructed from the running application instance. Returns nil otherwise.
 */
+ (instancetype)applicationWithRunningApplication:(NSRunningApplication *)runningApplication;

/**
 *  Returns all SIApplication instaces for all running applications.
 *
 *  @return All SIApplication instaces for all running applications.
 */
+ (nullable NSArray *)runningApplications;

/**
 *  Registers a notification handler for an accessibility notification.
 *
 *  Note that a strong reference to the handler is maintained, so any memory captured by the block will not be released until the notification handler is unregistered by calling unobserveNotification:withElement:
 *
 *  @param notification         The notification to register a handler for.
 *  @param accessibilityElement The accessibility element associated with the notification. Must be an element owned by the application or the application itself.
 *  @param handler              A block to be called when the notification is received for the accessibility element.
 *  @return YES if adding the observer succeeded, NO otherwise
 */
- (BOOL)observeNotification:(CFStringRef)notification withElement:(SIAccessibilityElement *)accessibilityElement handler:(SIAXNotificationHandler)handler;

/**
 *  Unregisters a notification handler for an accessibility notification.
 *
 *  If a notification handler was previously registered for the notification and accessibility element the application will unregister the notification handler and release its reference to the handler block and any captured state therein.
 *
 *  @param notification         The notification to unregister a handler for.
 *  @param accessibilityElement The accessibility element associated with the notification. Must be an element owned by the application or the application itself.
 */
- (void)unobserveNotification:(CFStringRef)notification withElement:(SIAccessibilityElement *)accessibilityElement;

/**
 *  Returns an array of SIWindow objects for all windows in the application.
 *
 *  @return An array of SIWindow objects for all windows in the application.
 */
- (NSArray *)windows;

/**
 *  Returns an array of SIWindow objects for all windows in the application that are currently visible.
 *
 *  @return An array of SIWindow objects for all windows in the application that are currently visible.
 */
- (NSArray *)visibleWindows;

/**
 *  Returns the title of the application.
 *
 *  @return The title of the application.
 */
- (nullable NSString *)title;

/**
 *  Returns a BOOL indicating whether or not the application is hidden.
 *
 *  @return YES if the application is hidden and NO otherwise.
 */
- (BOOL)isHidden;

/**
 *  Hides the application.
 */
- (void)hide;

/**
 *  Unhides the application.
 */
- (void)unhide;

/**
 *  Sends the application a kill signal.
 */
- (void)kill;

/**
 *  Sends the application a kill -9 signal.
 */
- (void)kill9;

/**
 *  Drops any cached windows so that the windows returned by a call to windows will be representative of the most up to date state of the application.
 */
- (void)dropWindowsCache;

@end

NS_ASSUME_NONNULL_END
