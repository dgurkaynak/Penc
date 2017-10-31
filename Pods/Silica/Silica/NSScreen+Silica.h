//
//  NSScreen+Silica.h
//  Silica
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  A category defining helper methods on NSScreen that are generally useful for window management.
 */
@interface NSScreen (Silica)

/**
 *  Returns the frame of the screen adjusted to a global coordinate system.
 *
 *  @return The frame of the screen adjusted to a global coordinate system.
 */
- (CGRect)frameIncludingDockAndMenu;

/**
 *  Returns the frame of the screen adjusted to a global coordinate system and adjusted to not include the dock or the menu.
 *
 *  @return The frame of the screen adjusted to a global coordinate system and adjusted to not include the dock or the menu.
 */
- (CGRect)frameWithoutDockOrMenu;

/**
 *  Returns the next screen in the global coordinate space.
 *
 *  @return The next screen in the global coordinate space.
 */
- (NSScreen *)nextScreen;

/**
 *  Returns the previous screen in the global coordinate space.
 *
 *  @return The previous screen in the global coordinate space.
 */
- (NSScreen *)previousScreen;

/**
 *  Rotates the screen by the supplied degrees.
 *
 *  @param degrees An integer expected to be one of (0, 90, 180, 270)
 *
 *  @return YES if the rotation was successful and NO otherwise.
 */
- (BOOL)rotateTo:(int)degrees;

@end

NS_ASSUME_NONNULL_END
