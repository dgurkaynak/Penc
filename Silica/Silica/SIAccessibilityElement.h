//
//  SIAccessibilityElement.h
//  Silica
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Object encapsulating an accessibility element. An accessibility element is anything from a button in a window to a running application.
 */
@interface SIAccessibilityElement : NSObject <NSCopying>

/**
 *  The C-level accessibility element.
 *
 *  This is exposed primarily for the purposes of subclassing.
 */
@property (nonatomic, assign, readonly) AXUIElementRef axElementRef;

/**
 *  :nodoc:
 */
- (instancetype)init NS_UNAVAILABLE;

/**
 *  Initializes the receiver as a wrapper around the supplied accessibility reference.
 *
 *  This is the designated initializer of this class.
 *
 *  @param axElementRef The accessibility element that is being encapsulated. Must not be nil.
 *
 *  @return A SIAccessibilityElement instance encapsulating the supplied AXUIElement.
 */
- (instancetype)initWithAXElement:(AXUIElementRef)axElementRef;

/**
 *  Returns a BOOL indicating whether or not the element can be resized.
 *
 *  @return YES if the element can be resized and NO otherwise.
 */
- (BOOL)isResizable;

/**
 *  Returns a BOOL indicating whether or not the element can be moved.
 *
 *  @return YES if the element can be resized and NO otherwise.
 */
- (BOOL)isMovable;

/**
 *  Returns the string value corresponding to the supplied key.
 *
 *  @param accessibilityValueKey The accessibility key to get the value from.
 *
 *  @return The string value corresponding to the supplied key. The return value is nil if the attribute does not exist or if the attribute is not a string.
 */
- (nullable NSString *)stringForKey:(CFStringRef)accessibilityValueKey;

/**
 *  Returns the number value corresponding to the supplied key.
 *
 *  @param accessibilityValueKey The accessibility key to get the value from.
 *
 *  @return The number value corresponding to the supplied key. The return value is nil if the attribute does not exist or if the attribute is not a number.
 */
- (nullable NSNumber *)numberForKey:(CFStringRef)accessibilityValueKey;

/**
 *  Returns the array value corresponding to the supplied key.
 *
 *  @param accessibilityValueKey The accessibility key to get the value from.
 *
 *  @return The array value corresponding to the supplied key. The return value is nil if the attribute does not exist or if the attribute is not an array.
 */
- (nullable NSArray *)arrayForKey:(CFStringRef)accessibilityValueKey;

/**
 *  Returns the accessibility element corresponding to the supplied key.
 *
 *  @param accessibilityValueKey The accessibility key to get the value from.
 *
 *  @return The accessibility element corresponding to the supplied key. The return value is nil if the attribute does not exist or if the attribute is not an accessibility element.
 */
- (nullable SIAccessibilityElement *)elementForKey:(CFStringRef)accessibilityValueKey;

/**
 *  Returns the frame of the accessibility element.
 *
 *  @return The frame of the accessibility element or CGRectNull if the element has no frame.
 */
- (CGRect)frame;

/**
 *  Updates the frame of the accessibility element.
 *
 *  Updates the frame of the accessibility element to match the input frame as closely as possible given known parameters.
 *
 *  The frame's size may be ignored if the size is not appreciably different from the current size.
 *
 *  @param frame The frame to move the element to.
 */
- (void)setFrame:(CGRect)frame;

/**
 *  Updates the position of the accessibility element.
 *
 *  @param position The point to move the accessibility element to.
 */
- (void)setPosition:(CGPoint)position;

/**
 *  Updates the size of the accessibility element.
 *
 *  @warning There are cases in which this method may fail. Accessibility seems to fail under a variety of conditions (e.g., increasing height while decreasing width). Callers should generally avoid calling this method and call setFrame: instead.
 *
 *  @param size The size to fit the accessibility element to.
 */
- (void)setSize:(CGSize)size;

/**
 *  Returns the pid of the process that owns the accessibility element.
 *
 *  @return The pid of the process that owns the accessibility element.
 */
- (pid_t)processIdentifier;

@end

NS_ASSUME_NONNULL_END
