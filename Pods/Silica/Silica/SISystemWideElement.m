//
//  SISystemWideElement.m
//  Silica
//

#import "SISystemWideElement.h"

@implementation SISystemWideElement

+ (SISystemWideElement *)systemWideElement {
    static SISystemWideElement *sharedElement = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        AXUIElementRef elementRef = AXUIElementCreateSystemWide();
        sharedElement = [[SISystemWideElement alloc] initWithAXElement:elementRef];
        CFRelease(elementRef);
    });
    return sharedElement;
}

@end
