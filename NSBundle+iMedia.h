//
//  NSBundle+iMedia.h
//  iMedia
//
//  Created by Jörg Jacobsen on 26.11.12.
//
//

#import <Foundation/Foundation.h>

@interface NSBundle (iMedia)

// Returns the XPC service bundle with inIdentifier contained inside of this bundle
// Returns nil if this bundle does not contain such XPC service bundle
//
- (NSBundle *) XPCServiceBundleWithIdentifier:(NSString *)inIdentifier;

// Returns whether this bundle supports execution of an XPC service identified by inIdentifier.
// Note that "support" comprises two requirements:
// 1. Bundle contains an XPC service bundle of given identifier
// 2. App currently runs on an OS version supporting XPC services
//
- (BOOL) supportsXPCServiceWithIdentifier:(NSString *)inIdentifier;

@end
