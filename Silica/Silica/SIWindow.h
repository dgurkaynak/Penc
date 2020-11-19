//
//  SIWindow.h
//  Silica
//

#import "SIAccessibilityElement.h"

NS_ASSUME_NONNULL_BEGIN

@class SIApplication;

/**
 *  Encapsulates a window element.
 */
@interface SIWindow : SIAccessibilityElement

#pragma mark Window Accessors
/**---------------------------------------------------------------------------------------
 * @name Window Accessors
 * ---------------------------------------------------------------------------------------
 */

/**
 *  Returns all windows.
 *
 *  @return An array of SIWindow objects representing all windows.
 */
+ (nullable NSArray *)allWindows;

/**
 * Returns all windows currently visible.
 *
 *  @return An array of SIWindow objects representing all windows currently visible.
 */
+ (nullable NSArray *)visibleWindows;

/**
 * Returns the currently focused window.
 *
 *  @return A SIWindow object representing the currently focused window or nil if no window is focused.
 */
+ (nullable SIWindow *)focusedWindow;

/**
 *  Takes the window's screen and returns all other windows on the same screen.
 *
 *  @return An array of SIWindow objects representing all other windows on the same screen.
 */
- (nullable NSArray *)otherWindowsOnSameScreen;

/**
 *  Returns all other visible windows, excluding the current window.
 *
 *  @return An array of SIWindow objects representing all other windows across all screens.
 */
- (nullable NSArray *)otherWindowsOnAllScreens;

/**
 *  Returns all windows in the global coordinate system whose centers lie to the west of the current window's center.
 *
 *  @return An array of SIWindow objects whose centers are to the west of the current window's center.
 */
- (nullable NSArray *)windowsToWest;

/**
 *  Returns all windows in the global coordinate system whose centers lie to the east of the current window's center.
 *
 *  @return An array of SIWindow objects whose centers are to the east of the current window's center.
 */
- (nullable NSArray *)windowsToEast;

/**
 *  Returns all windows in the global coordinate system whose centers lie to the north of the current window's center.
 *
 *  @return An array of SIWindow objects whose centers are to the north of the current window's center.
 */
- (nullable NSArray *)windowsToNorth;

/**
 *  Returns all windows in the global coordinate system whose centers lie to the south of the current window's center.
 *
 *  @return An array of SIWindow objects whose centers are to the south of the current window's center.
 */
- (nullable NSArray *)windowsToSouth;

#pragma mark Window Properties
/**---------------------------------------------------------------------------------------
 * @name Window Properties
 * ---------------------------------------------------------------------------------------
 */

/**
 * Returns the window ID of the window.
 *
 * @return The window ID of the window.
 */
- (CGWindowID)windowID;

/**
 *  Returns the title of the window.
 *
 *  @return The title of the window or nil if the window has no title.
 */
- (nullable NSString *)title;

/**
 *  Returns a BOOL indicating whether or not the window is minimized.
 *
 *  @return YES if the window is minimized and NO otherwise.
 */
- (BOOL)isWindowMinimized;

/**
 *  Returns a BOOL indicating whether or not the window is normal, i.e., if its role is a standard window.
 *
 *  @return YES if the window is normal and NO otherwise.
 */
- (BOOL)isNormalWindow;

/**
 *  Returns a BOOL indicating whether or not the window is a sheet.
 *
 *  @return YES if the window is a sheet and NO otherwise.
 */
- (BOOL)isSheet;

/**
 *  Returns a BOOL indicating whether or not the window is active and on screen.
 *
 *  @return YES if the window is active and on screen and NO otherwise.
 */
- (BOOL)isActive;

/**
 *  Returns a BOOL indicating whether or not the window is on screen.
 *
 *  @return YES if the window is on screen and NO otherwise.
 */
- (BOOL)isOnScreen;

/**
 *  Returns the application that owns the window.
 *
 *  @return A SIApplication instance for the application that owns the window.
 */
- (nullable SIApplication *)app;

#pragma mark Screen
/**---------------------------------------------------------------------------------------
 * @name Screen
 * ---------------------------------------------------------------------------------------
 */

/**
 *  Returns the screen that the window is most on. The algorithm is area-based such that the screen that contains the most of the window's area is considered to be the window's screen.
 *
 *  @return A NSScreen instance for the screen that the window is most on.
 */
- (nullable NSScreen *)screen;

/**
 *  Moves the window to the given screen.
 *
 *  The window is always positioned at the screen's origin.
 *
 *  @param screen The screen on which the window should be moved to.
 */
- (void)moveToScreen:(NSScreen *)screen;

#pragma mark Space
/**---------------------------------------------------------------------------------------
 * @name Space
 * ---------------------------------------------------------------------------------------
 */

/**
 *  Moves the window to a given space. The space is provided as a number between 1 and 16, which corresponds to the numerical index of the space defined by Mission Control.
 *
 *  This method relies on two things:
 *    1. Mission Control keyboard shortcuts must be turned on.
 *    2. Mission Control keyboard shortcuts must be of the form ^+space
 *
 *  @param space The space on which to move the window.
 */
- (void)moveToSpace:(NSUInteger)space;

#pragma mark Window Actions
/**---------------------------------------------------------------------------------------
 * @name Window Actions
 * ---------------------------------------------------------------------------------------
 */

/**
 *  Update the frame of the window to encompass the entire screen, excluding dock and menu bar.
 */
- (void)maximize;

/**
 *  Minimize the window.
 */
- (void)minimize;

/**
 *  Unminimize the window.
 */
- (void)unMinimize;

#pragma mark Window Focus
/**---------------------------------------------------------------------------------------
 * @name Window Focus
 * ---------------------------------------------------------------------------------------
 */

/**
 *  Bring the current window into focus.
 *
 *  @return YES if the window was successfully brought into focus and NO otherwise.
 */
- (BOOL)focusWindow;

/**
 *  Move window focus to the first window to the west of the current window.
 */
- (void)focusWindowLeft;

/**
 *  Move window focus to the first window to the east of the current window.
 */
- (void)focusWindowRight;

/**
 *  Move window focus to the first window to the north of the current window.
 */
- (void)focusWindowUp;

/**
 *  Move window focus to the first window to the south of the current window.
 */
- (void)focusWindowDown;

@end

NS_ASSUME_NONNULL_END
