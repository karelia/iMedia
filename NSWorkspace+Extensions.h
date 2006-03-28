//
//  NSWorkspace+Extensions.h
//  iMediaBrowse
//
//  Created by Jason Jobe on 3/28/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSWorkspace (iMediaExtensions)

- (NSImage *)iconForAppWithBundleIdentifier:(NSString *)bundleID;

@end
