/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2012 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 The new architecture for version 2.0 was developed by Peter Baumgartner.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 The iMedia Browser Framework is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2012 by Karelia Software et al.
 
	Redistributions in binary form must include, in an end-user-visible manner,
	e.g., About window, Acknowledgments window, or similar, either a) the original
	terms stated here, including this list of conditions, the disclaimer noted
	below, and the aforementioned copyright notice, or b) the aforementioned
	copyright notice and a link to karelia.com/imedia.
 
	Neither the name of Karelia Software, nor Sandvox, nor the names of
	contributors to iMedia Browser may be used to endorse or promote products
	derived from the Software without prior and express written permission from
	Karelia Software or individual contributors, as appropriate.
 
 Disclaimer: THE SOFTWARE IS PROVIDED BY THE COPYRIGHT OWNER AND CONTRIBUTORS
 "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
 LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
 AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH, THE
 SOFTWARE OR THE USE OF, OR OTHER DEALINGS IN, THE SOFTWARE.
 */


//----------------------------------------------------------------------------------------------------------------------


// Author: Jörg Jacobsen


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS


#import <iMedia/iMedia.h>
#import "IMBTestTextView.h"
#import "IMBTestAppDelegate.h"
#import "NSPasteboard+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


@implementation IMBTestTextView

-(BOOL)performDragOperation:(id<NSDraggingInfo>)inSender
{
    BOOL delegateToSuper = YES;
    
	// Get an array of IMBObjects from the dragging pasteboard...
	
	NSPasteboard* pasteboard = [inSender draggingPasteboard];
	NSArray* objects = [pasteboard imb_IMBObjects];
    
    for (IMBObject *object in objects)
    {
        // Do we need to load an image from the internet? (this is for Facebook and the like)
        if ((![object.imageLocation isFileURL]) &&
            [object.imageRepresentationType isEqualToString:IKImageBrowserNSDataRepresentationType])
        {
            delegateToSuper = NO;
            
//            // Load image asynchronously
//            NSImage *image = [[NSImage alloc] initWithContentsOfURL:[object location]];
//            
//            // Update progress indicator (optional)
//            
//            // Wait for load to finish
//            
//            // Insert image into text view
//            NSTextAttachmentCell *attachmentCell = [[NSTextAttachmentCell alloc] initImageCell:image];
//            NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
//            [attachment setAttachmentCell: attachmentCell ];
//            NSAttributedString *attributedString = [NSAttributedString  attributedStringWithAttachment: attachment];
//            [[self textStorage] appendAttributedString:attributedString];
//            [self setNeedsDisplay:YES];
        }
    }
	
    if (YES) {
        return [super performDragOperation:inSender];
    } else {
        return YES;
    }
}


- (void) concludeDragOperation:(id<NSDraggingInfo>)inSender
{
    //	[super concludeDragOperation:inSender];
	
	// Get an array of IMBObjects from the dragging pasteboard...
	
	NSPasteboard* pasteboard = [inSender draggingPasteboard];
	NSArray* objects = [pasteboard imb_IMBObjects];
	
    for (IMBObject *object in objects)
    {
        // Do we need to load an image from the internet? (this is for Facebook and the like)
        if ((![object.imageLocation isFileURL]) &&
            [object.imageRepresentationType isEqualToString:IKImageBrowserNSDataRepresentationType])
        {
            // Load image asynchronously
            NSImage *image = [[NSImage alloc] initWithContentsOfURL:[object location]];
            
            // Update progress indicator (optional)
            
            // Wait for load to finish
            
            // Insert image into text view
            NSTextAttachmentCell *attachmentCell = [[NSTextAttachmentCell alloc] initImageCell:image];
            NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
            [attachment setAttachmentCell: attachmentCell];
            NSAttributedString *attributedString = [NSAttributedString  attributedStringWithAttachment: attachment];
            [[self textStorage] beginEditing];
            NSLog(@"Cursor position: %ld", (unsigned long)[self selectedRange].location);
            [[self textStorage] insertAttributedString:attributedString atIndex:[self selectedRange].location];
            [[self textStorage] endEditing];
            [self setNeedsDisplay:YES];
        }
    }
	
	// Tell the app delegate so that it can update its badge cache with these objects...
	
	[(IMBTestAppDelegate*) draggingDelegate concludeDragOperationForObjects:objects];
}


//----------------------------------------------------------------------------------------------------------------------


@end
