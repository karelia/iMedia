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


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "NSPasteboard+iMedia.h"
#import "IMBObject.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark GLOBALS

static IMBParserMessenger* sDraggingParserMessenger = nil;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation NSPasteboard (iMediaInternal)

// This method must be called when putting IMBObjects on teh pasteboard. Since the parserMessenger is not
// encoded by IMBObject, we need to keep this info around separately, so that we can assign the property 
// again when the IMBObjects are pulled from the pasteboard (see imb_IMBObjects method)...

- (void) imb_setParserMessenger:(IMBParserMessenger*)inParserMessenger
{
	sDraggingParserMessenger = inParserMessenger;
}


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation NSPasteboard (iMediaPublic)


//----------------------------------------------------------------------------------------------------------------------


// Check if we have any IMBObjects on the pasteboard...

- (BOOL) imb_containsIMBObjects
{
	NSArray* types = [self types];
	return [types containsObject:kIMBObjectPasteboardType];
}


// Get all IMBObjects from the pasteboard. Please note that IMBObjects are archived/unarchived without their
// IMBPArserMessenger. However the messenger is essential so we need to restore it from teh remembered pointer
// in sDraggingParserMessenger. This should suffice, since there can only be a single messenger involved in 
// a dragging operation...

- (NSArray*) imb_IMBObjects
{
	NSArray* items = self.pasteboardItems;
	NSMutableArray* objects = [NSMutableArray arrayWithCapacity:items.count];
	
	for (NSPasteboardItem* item in items)
	{
		NSData* data = [item dataForType:kIMBObjectPasteboardType];
		IMBObject* object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		object.parserMessenger = sDraggingParserMessenger;
		if (object) [objects addObject:object];
	}
	
	return (NSArray*) objects;
}


//----------------------------------------------------------------------------------------------------------------------


// Check if we have any file NSURLs on the pasteboard...

- (BOOL) imb_containsFileURLs
{
	NSArray* types = [self types];
	return [types containsObject:(NSString*)kUTTypeFileURL];
}


// Get all NSURLs from the pasteboard...

- (NSArray*) imb_fileURLs
{
	NSArray* items = self.pasteboardItems;
	NSMutableArray* urls = [NSMutableArray arrayWithCapacity:items.count];
	
	for (NSPasteboardItem* item in items)
	{
		NSString* str = [item stringForType:(NSString*)kUTTypeFileURL];
		NSURL* url = [NSURL URLWithString:str];
		if (url) [urls addObject:url];
	}
	
	return (NSArray*) urls;
}


//----------------------------------------------------------------------------------------------------------------------


@end
