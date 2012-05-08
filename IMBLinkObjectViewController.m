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

#import "IMBLinkObjectViewController.h"
#import "IMBObjectArrayController.h"
#import "IMBConfig.h"
#import "IMBObject.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBLinkObjectViewController


//----------------------------------------------------------------------------------------------------------------------


+ (void) load
{
	[IMBObjectViewController registerObjectViewControllerClass:[self class] forMediaType:kIMBMediaTypeLink];
}


+ (void) initialize
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSMutableDictionary* classDict = [NSMutableDictionary dictionary];
	[classDict setObject:[NSNumber numberWithUnsignedInteger:kIMBObjectViewTypeList] forKey:@"viewType"];
	[classDict setObject:[NSNumber numberWithDouble:0.5] forKey:@"iconSize"];
	[IMBConfig registerDefaultPrefs:classDict forClass:self.class];
	[pool drain];
}


- (void) awakeFromNib
{
	[super awakeFromNib];
	
	ibObjectArrayController.searchableProperties = [NSArray arrayWithObjects:
		@"name",
		nil];
}


- (void) dealloc
{
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Customize Subclass


+ (NSString*) mediaType
{
	return kIMBMediaTypeLink;
}

+ (NSString*) nibName
{
	return @"IMBLinkObjectViewController";
}


+ (NSString*) objectCountFormatSingular
{
	return NSLocalizedStringWithDefaultValue(
		@"IMBLinkViewController.countFormatSingular",
		nil,IMBBundle(),
		@"%d URL",
		@"Format string for object count in singluar");
}

+ (NSString*) objectCountFormatPlural
{
	return NSLocalizedStringWithDefaultValue(
		@"IMBLinkViewController.countFormatPlural",
		nil,IMBBundle(),
		@"%d URLs",
		@"Format string for object count in plural");
}


//----------------------------------------------------------------------------------------------------------------------


// The Links panel doesn't have an icon or combo view

- (void) setViewType:(NSUInteger)inViewType
{
	if (inViewType < 1) inViewType = 1;
	if (inViewType > 1) inViewType = 1;
	[super setViewType:inViewType];
}


- (NSUInteger) viewType
{
	NSUInteger viewType = [super viewType];
	if (viewType < 1) viewType = 1;
	if (viewType > 1) viewType = 1;
	return viewType;
}


//----------------------------------------------------------------------------------------------------------------------


- (IBAction) quicklook:(id)inSender
{
	// Don't try to do quicklook for links
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Dragging


// The link view controller vends objects that have urls to web resources, not local files. 
// So we can put the web urls onto the pastboard directly. No need to do anything fancy...

- (NSUInteger) writeItemsAtIndexes:(NSIndexSet*)inIndexes toPasteboard:(NSPasteboard*)inPasteboard
{
	NSIndexSet* indexes = [self filteredDraggingIndexes:inIndexes]; 
	NSArray* objects = [[ibObjectArrayController arrangedObjects] objectsAtIndexes:indexes];
	NSMutableArray* pasteboardItems = [NSMutableArray arrayWithCapacity:objects.count];
	
	for (IMBObject* object in objects)
	{
		NSURL* url = object.URL;
		NSPasteboardItem* item = [[NSPasteboardItem alloc] init];
		if (url) [item setString:[url absoluteString] forType:(NSString*)kUTTypeURL];
		[pasteboardItems addObject:item];
		[item release];
	}
	
	[inPasteboard clearContents];
	[inPasteboard writeObjects:pasteboardItems];
	return pasteboardItems.count;
}


//----------------------------------------------------------------------------------------------------------------------

@end

