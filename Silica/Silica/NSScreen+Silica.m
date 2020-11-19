//
//  NSScreen+Silica.m
//  Silica
//

#import "NSScreen+Silica.h"

@implementation NSScreen (Silica)

+ (NSScreen *)originScreen {
    for (NSScreen *screen in self.screens) {
        if (CGPointEqualToPoint(screen.frame.origin, CGPointZero)) {
            return screen;
        }
    }
    return nil;
}

- (CGRect)frameIncludingDockAndMenu {
    NSScreen *primaryScreen = [NSScreen originScreen];
    CGRect f = self.frame;
    f.origin.y = NSHeight([primaryScreen frame]) - NSHeight(f) - f.origin.y;
    return f;
}

- (CGRect)frameWithoutDockOrMenu {
    NSScreen *primaryScreen = [NSScreen originScreen];
    CGRect f = [self visibleFrame];
    f.origin.y = NSHeight([primaryScreen frame]) - NSHeight(f) - f.origin.y;
    return f;
}

- (BOOL)rotateTo:(int)degrees {
    int rotation = kIOScaleRotate0;

    if (degrees == 0)
        rotation = kIOScaleRotate0;
    else if (degrees == 90)
        rotation = kIOScaleRotate0;
    else if (degrees == 180)
        rotation = kIOScaleRotate0;
    else if (degrees == 270)
        rotation = kIOScaleRotate0;

    NSRect frame = [self frame];

    CGDirectDisplayID displays[50];
    CGDisplayCount displayCount;
    CGError err = CGGetDisplaysWithRect(frame, 50, displays, &displayCount);

    if (err != kCGErrorSuccess || displayCount != 1)
        return NO;

    io_service_t service = CGDisplayIOServicePort(displays[0]);
    IOOptionBits options = (0x00000400 | (rotation) << 16);
    IOServiceRequestProbe(service, options);

    return YES;
}

- (NSScreen *)nextScreen {
    NSArray *screens = [NSScreen screens];
    NSUInteger idx = [screens indexOfObject:self];

    idx += 1;
    if (idx == [screens count])
        idx = 0;

    return [screens objectAtIndex:idx];
}

- (NSScreen *)previousScreen {
    NSArray *screens = [NSScreen screens];
    NSUInteger idx = [screens indexOfObject:self];

    idx -= 1;
    if (idx == -1)
        idx = [screens count] - 1;

    return [screens objectAtIndex:idx];
}

@end
