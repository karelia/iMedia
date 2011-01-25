//
//  NSWindow_Flipr.h
//  Flipr
//
//  Created by Rainer Brockerhoff on 12/20/06.
//  Copyright 2006,2007 Rainer Brockerhoff. Some rights reserved.
//

#import <Cocoa/Cocoa.h>

// Read the "ReadMe.rtf" file for general discussion.

@interface NSWindow (NSWindow_Flipr)

// Call during initialization this to prepare the flipping window.
// If you don't call this, the first flip will take a little longer.

+ (NSWindow*)flippingWindow;

// Call this if you want to release the flipping window. If you flip
// again after calling this, it will take a little longer.

+ (void)releaseFlippingWindow;

// Call this on a visible window to flip it and show the parameter window,
// which is supposed to not be on-screen.

- (void)flipToShowWindow:(NSWindow*)window forward:(BOOL)forward reflectInto:(NSImageView*)reflection;

@end
