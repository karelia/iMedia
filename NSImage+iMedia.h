//
//  NSImage+iMedia.h
//  iMediaBrowse
//
//  Created by Greg Hulands on 4/05/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSImage (iMedia)

// Try to load an image out of the bundle for another application and if not found fallback to one of our own.
+ (NSImage *)imageResourceNamed:(NSString *)name fromApplication:(NSString *)bundleID fallbackTo:(NSString *)imageInOurBundle;

+ (NSImage *)imageFromFirefoxEmbeddedIcon:(NSString *)base64WithMime;
@end
