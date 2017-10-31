#ifdef __OBJC__
#import <Cocoa/Cocoa.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "CGSSpaces.h"
#import "NSRunningApplication+Silica.h"
#import "NSScreen+Silica.h"
#import "SIAccessibilityElement.h"
#import "SIApplication.h"
#import "Silica.h"
#import "SISystemWideElement.h"
#import "SIUniversalAccessHelper.h"
#import "SIWindow.h"

FOUNDATION_EXPORT double SilicaVersionNumber;
FOUNDATION_EXPORT const unsigned char SilicaVersionString[];

