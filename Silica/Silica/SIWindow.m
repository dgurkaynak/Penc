//
//  SIWindow.m
//  Silica
//

#import "SIWindow.h"

#import <Carbon/Carbon.h>
#import "NSScreen+Silica.h"
#import "SIApplication.h"
#import "SISystemWideElement.h"
#import "SIUniversalAccessHelper.h"

@interface SIWindow ()
@property (nonatomic, assign) CGWindowID _windowID;
@end

@implementation SIWindow

#pragma mark Window Accessors

+ (NSArray *)allWindows {
    if (![SIUniversalAccessHelper isAccessibilityTrusted]) return nil;
    
    NSMutableArray *windows = [NSMutableArray array];
    
    for (SIApplication *application in [SIApplication runningApplications]) {
        [windows addObjectsFromArray:[application windows]];
    }
    
    return windows;
}

+ (NSArray *)visibleWindows {
    if (![SIUniversalAccessHelper isAccessibilityTrusted]) return nil;

    return [[self allWindows] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SIWindow *win, NSDictionary *bindings) {
        return ![[win app] isHidden]
        && ![win isWindowMinimized]
        && [win isNormalWindow];
    }]];
}

+ (SIWindow *)focusedWindow {
    if (![SIUniversalAccessHelper isAccessibilityTrusted]) return nil;

    CFTypeRef applicationRef;
    AXUIElementCopyAttributeValue([SISystemWideElement systemWideElement].axElementRef, kAXFocusedApplicationAttribute, &applicationRef);

    if (applicationRef) {
        CFTypeRef windowRef;
        AXError result = AXUIElementCopyAttributeValue(applicationRef, (CFStringRef)NSAccessibilityFocusedWindowAttribute, &windowRef);

        CFRelease(applicationRef);

        if (result == kAXErrorSuccess) {
            SIWindow *window = [[SIWindow alloc] initWithAXElement:windowRef];

            if ([window isSheet]) {
                SIAccessibilityElement *parent = [window elementForKey:kAXParentAttribute];
                if (parent) {
                    return [[SIWindow alloc] initWithAXElement:parent.axElementRef];
                }
            }

            return window;
        }
    }
    
    return nil;
}

- (NSArray *)otherWindowsOnSameScreen {
    return [[SIWindow visibleWindows] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SIWindow *win, NSDictionary *bindings) {
        return ![self isEqual:win] && [[self screen] isEqual: [win screen]];
    }]];
}

- (NSArray *)otherWindowsOnAllScreens {
    return [[SIWindow visibleWindows] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SIWindow *win, NSDictionary *bindings) {
        return ![self isEqual:win];
    }]];
}

- (NSArray *)windowsToWest {
    return [[self windowsInDirectionFn:^double(double angle) { return M_PI - fabs(angle); }
                     shouldDisregardFn:^BOOL(double deltaX, double deltaY) { return (deltaX >= 0); }] valueForKeyPath:@"win"];
}

- (NSArray *)windowsToEast {
    return [[self windowsInDirectionFn:^double(double angle) { return 0.0 - angle; }
                     shouldDisregardFn:^BOOL(double deltaX, double deltaY) { return (deltaX <= 0); }] valueForKeyPath:@"win"];
}

- (NSArray *)windowsToNorth {
    return [[self windowsInDirectionFn:^double(double angle) { return -M_PI_2 - angle; }
                     shouldDisregardFn:^BOOL(double deltaX, double deltaY) { return (deltaY >= 0); }] valueForKeyPath:@"win"];
}

- (NSArray *)windowsToSouth {
    return [[self windowsInDirectionFn:^double(double angle) { return M_PI_2 - angle; }
                     shouldDisregardFn:^BOOL(double deltaX, double deltaY) { return (deltaY <= 0); }] valueForKeyPath:@"win"];
}

#pragma mark Window Properties

- (CGWindowID)windowID {
    if (self._windowID == kCGNullWindowID) {
        CGWindowID windowID;
        AXError error = _AXUIElementGetWindow(self.axElementRef, &windowID);
        if (error != kAXErrorSuccess) {
            return NO;
        }
        
        self._windowID = windowID;
    }
    
    return self._windowID;
}

- (NSString *)title {
    return [self stringForKey:kAXTitleAttribute];
}

- (NSString *)role {
    return [self stringForKey:kAXRoleAttribute];
}

- (NSString *)subrole {
    return [self stringForKey:kAXSubroleAttribute];
}

- (BOOL)isWindowMinimized {
    return [[self numberForKey:kAXMinimizedAttribute] boolValue];
}

- (BOOL)isNormalWindow {
    NSString *subrole = [self subrole];
    if (subrole) {
        return [subrole isEqualToString:(__bridge NSString *)kAXStandardWindowSubrole];
    }
    return YES;
}

- (BOOL)isSheet {
    return [[self stringForKey:kAXRoleAttribute] isEqualToString:(__bridge NSString *)kAXSheetRole];
}

- (BOOL)isActive {
    if ([[self numberForKey:kAXHiddenAttribute] boolValue]) return NO;
    if ([[self numberForKey:kAXMinimizedAttribute] boolValue]) return NO;
    return YES;
}

- (BOOL)isOnScreen {
    if (!self.isActive) {
        return NO;
    }
    
    CFArrayRef windowDescriptions = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    BOOL isActive = NO;
    for (NSDictionary *dictionary in (__bridge NSArray *)windowDescriptions) {
        CGWindowID otherWindowID = [dictionary[(__bridge NSString *)kCGWindowNumber] intValue];
        if (otherWindowID == self.windowID) {
            isActive = YES;
            break;
        }
    }
    
    CFRelease(windowDescriptions);
    
    return isActive;
}

- (SIApplication *)app {
    NSRunningApplication *runningApplication = [NSRunningApplication runningApplicationWithProcessIdentifier:self.processIdentifier];
    if (!runningApplication) {
        return nil;
    }
    return [SIApplication applicationWithRunningApplication:runningApplication];
}

#pragma mark Screen

- (NSScreen *)screen {
    CGRect windowFrame = [self frame];
    
    CGFloat lastVolume = 0;
    NSScreen *lastScreen = nil;
    
    for (NSScreen *screen in [NSScreen screens]) {
        CGRect screenFrame = [screen frameIncludingDockAndMenu];
        CGRect intersection = CGRectIntersection(windowFrame, screenFrame);
        CGFloat volume = intersection.size.width * intersection.size.height;
        
        if (volume > lastVolume) {
            lastVolume = volume;
            lastScreen = screen;
        }
    }
    
    return lastScreen;
}

- (void)moveToScreen:(NSScreen *)screen {
    self.position = screen.frameWithoutDockOrMenu.origin;
}

#pragma mark Space

- (void)moveToSpace:(NSUInteger)space {
    if (space > 16) return;

    SIAccessibilityElement *zoomButtonElement = [self elementForKey:kAXZoomButtonAttribute];
    CGRect zoomButtonFrame = zoomButtonElement.frame;
    CGRect windowFrame = self.frame;

    CGEventRef defaultEvent = CGEventCreate(NULL);
    CGPoint startingCursorPoint = CGEventGetLocation(defaultEvent);
    CGPoint mouseCursorPoint = {
        .x = (zoomButtonElement ? CGRectGetMaxX(zoomButtonFrame) + 5.0 : windowFrame.origin.x + 5.0),
        .y = windowFrame.origin.y + 5.0
    };

    CGEventRef mouseMoveEvent = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, mouseCursorPoint, kCGMouseButtonLeft);
    CGEventRef mouseDownEvent = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, mouseCursorPoint, kCGMouseButtonLeft);
    CGEventRef mouseUpEvent = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseUp, mouseCursorPoint, kCGMouseButtonLeft);
    CGEventRef mouseRestoreEvent = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, startingCursorPoint, kCGMouseButtonLeft);

    CGKeyCode keyCode = 0xFF;
    NSString *keyCodeString = [NSString stringWithFormat:@"%@", @(space)];

    if (keyCodeString.length > 0) {
        switch ([keyCodeString characterAtIndex:keyCodeString.length - 1]) {
            case '1':
                keyCode = kVK_ANSI_1;
                break;
            case '2':
                keyCode = kVK_ANSI_2;
                break;
            case '3':
                keyCode = kVK_ANSI_3;
                break;
            case '4':
                keyCode = kVK_ANSI_4;
                break;
            case '5':
                keyCode = kVK_ANSI_5;
                break;
            case '6':
                keyCode = kVK_ANSI_6;
                break;
            case '7':
                keyCode = kVK_ANSI_7;
                break;
            case '8':
                keyCode = kVK_ANSI_8;
                break;
            case '9':
                keyCode = kVK_ANSI_9;
                break;
            case '0':
            default:
                keyCode = kVK_ANSI_0;
                break;
        }
    }

    CGEventRef keyboardEvent = CGEventCreateKeyboardEvent(NULL, keyCode, true);
    CGEventRef keyboardEventUp = CGEventCreateKeyboardEvent(NULL, keyCode, false);

    CGEventSetFlags(mouseMoveEvent, 0);
    CGEventSetFlags(mouseDownEvent, 0);
    CGEventSetFlags(mouseUpEvent, 0);
    CGEventSetFlags(keyboardEvent, kCGEventFlagMaskControl);
    CGEventSetFlags(keyboardEventUp, 0);

    // Move the mouse into place at the window's toolbar
    CGEventPost(kCGHIDEventTap, mouseMoveEvent);
    // Mouse down to grab hold of the window
    CGEventPost(kCGHIDEventTap, mouseDownEvent);
    // Send the shortcut command to get Mission Control to switch spaces from under the window.
    CGEventPost(kCGHIDEventTap, keyboardEvent);
    CGEventPost(kCGHIDEventTap, keyboardEventUp);

    double delayInSeconds = 0.5;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        // Let go of the window.
        CGEventPost(kCGHIDEventTap, mouseUpEvent);
        // Move the cursor back to its previous position.
        CGEventPost(kCGHIDEventTap, mouseRestoreEvent);
        CFRelease(mouseUpEvent);
        CFRelease(mouseRestoreEvent);
    });

    CFRelease(defaultEvent);
    CFRelease(mouseMoveEvent);
    CFRelease(mouseDownEvent);
    CFRelease(keyboardEvent);
    CFRelease(keyboardEventUp);
}

#pragma mark Window Actions

- (void)maximize {
    CGRect screenRect = [[self screen] frameWithoutDockOrMenu];
    [self setFrame: screenRect];
}

- (void)minimize {
    [self setWindowMinimized:YES];
}

- (void)unMinimize {
    [self setWindowMinimized:NO];
}

- (void)setWindowMinimized:(BOOL)flag {
    [self setWindowProperty:NSAccessibilityMinimizedAttribute withValue:@(flag)];
}

- (BOOL)setWindowProperty:(NSString *)propType withValue:(id)value {
    if ([value isKindOfClass:[NSNumber class]]) {
        AXError result = AXUIElementSetAttributeValue(self.axElementRef, (__bridge CFStringRef)(propType), (__bridge CFTypeRef)(value));
        if (result == kAXErrorSuccess)
            return YES;
    }
    return NO;
}

#pragma mark Window Focus

- (BOOL)focusWindow {
    NSRunningApplication *runningApplication = [NSRunningApplication runningApplicationWithProcessIdentifier:self.processIdentifier];
    BOOL success = [runningApplication activateWithOptions:NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps];
    if (!success) {
        return NO;
    }

    AXError error = AXUIElementSetAttributeValue(self.axElementRef, (CFStringRef)NSAccessibilityMainAttribute, kCFBooleanTrue);
    if (error != kAXErrorSuccess) {
        return NO;
    }

    return YES;
}

NSPoint SIMidpoint(NSRect r) {
    return NSMakePoint(NSMidX(r), NSMidY(r));
}

- (NSArray *)windowsInDirectionFn:(double(^)(double angle))whichDirectionFn
                shouldDisregardFn:(BOOL(^)(double deltaX, double deltaY))shouldDisregardFn {
    SIWindow *thisWindow = [SIWindow focusedWindow];
    NSPoint startingPoint = SIMidpoint([thisWindow frame]);
    
    NSArray *otherWindows = [thisWindow otherWindowsOnAllScreens];
    NSMutableArray *closestOtherWindows = [NSMutableArray arrayWithCapacity:[otherWindows count]];
    
    for (SIWindow *win in otherWindows) {
        NSPoint otherPoint = SIMidpoint([win frame]);
        
        double deltaX = otherPoint.x - startingPoint.x;
        double deltaY = otherPoint.y - startingPoint.y;
        
        if (shouldDisregardFn(deltaX, deltaY))
            continue;
        
        double angle = atan2(deltaY, deltaX);
        double distance = hypot(deltaX, deltaY);
        
        double angleDifference = whichDirectionFn(angle);
        
        double score = distance / cos(angleDifference / 2.0);
        
        [closestOtherWindows addObject:@{
         @"score": @(score),
         @"win": win,
         }];
    }
    
    NSArray *sortedOtherWindows = [closestOtherWindows sortedArrayUsingComparator:^NSComparisonResult(NSDictionary* pair1, NSDictionary* pair2) {
        return [[pair1 objectForKey:@"score"] compare:[pair2 objectForKey:@"score"]];
    }];
    
    return sortedOtherWindows;
}

- (void)focusFirstValidWindowIn:(NSArray*)closestWindows {
    for (SIWindow *win in closestWindows) {
        if ([win focusWindow]) break;
    }
}

- (void)focusWindowLeft {
    [self focusFirstValidWindowIn:[self windowsToWest]];
}

- (void)focusWindowRight {
    [self focusFirstValidWindowIn:[self windowsToEast]];
}

- (void)focusWindowUp {
    [self focusFirstValidWindowIn:[self windowsToNorth]];
}

- (void)focusWindowDown {
    [self focusFirstValidWindowIn:[self windowsToSouth]];
}

@end
