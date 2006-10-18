/*
 
 Permission is hereby granted, free of charge, to any person obtaining a 
 copy of this software and associated documentation files (the "Software"), 
 to deal in the Software without restriction, including without limitation 
 the rights to use, copy, modify, merge, publish, distribute, sublicense, 
 and/or sell copies of the Software, and to permit persons to whom the Software 
 is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in 
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS 
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
 AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 Please send fixes to
	<ghulands@framedphotographics.com>
	<ben@scriptsoftware.com>
 
 */

#import "NSAttributedString+iMedia.h"


@implementation NSAttributedString (iMedia)

+ (NSAttributedString *)attributedStringWithName:(NSString *)name image:(NSImage *)image
{	
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@", name]];
	
    if (image != nil) {
		
		[result setAttributes:
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithFloat:3.0],
				NSBaselineOffsetAttributeName, nil]
			range:NSMakeRange(0,[result length])];
		
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
