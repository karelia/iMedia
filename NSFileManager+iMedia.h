//
//  NSFileManager+iMedia.h
//  iMediaBrowse
//
//  Created by Greg Hulands on 27/05/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSFileManager (iMedia)

- (BOOL)isPathHidden:(NSString *)path;

@end
