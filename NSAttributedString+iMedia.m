//
//  NSAttributedString+iMedia.m
//  iMediaBrowse
//
//  Created by Greg Hulands on 27/05/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "NSAttributedString+iMedia.h"


@implementation NSAttributedString (iMedia)

+ (NSAttributedString *)attributedStringWithName:(NSString *)name image:(NSImage *)image
{	
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@", name]];
	
    if (image != nil) {
		
        NSFileWrapper *wrapper = nil;
        NSTextAttachment *attachment = nil;
        NSAttributedString *icon = nil;
		
        // need a filewrapper to create an NSTextAttachment
        wrapper = [[NSFileWrapper alloc] init];
		
        // set the icon (this is what'll show up in attributed strings)
        [wrapper setIcon:image];
        
        // you need an attachment to create the attributed string as an RTFd
        attachment = [[NSTextAttachment alloc] initWithFileWrapper:wrapper];
        
        // finally, the attributed string for the icon
        icon = [NSAttributedString attributedStringWithAttachment:attachment];
        [result insertAttributedString:icon atIndex:0];
		
        // cleanup
        [wrapper release];
        [attachment release];	
    }
    
    return [result autorelease];
}

@end
