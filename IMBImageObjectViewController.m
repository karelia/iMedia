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


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBImageObjectViewController.h"
#import "IMBObjectArrayController.h"
//#import "IMBPanelController.h"
#import "IMBCommon.h"
#import "IMBConfig.h"
#import "IMBObjectsPromise.h"
#import "NSWorkspace+iMedia.h"

//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBImageObjectViewController


//----------------------------------------------------------------------------------------------------------------------


+ (void) load
{
	[IMBObjectViewController registerObjectViewControllerClass:[self class] forMediaType:kIMBMediaTypeImage];
}


+ (void) initialize
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSMutableDictionary* classDict = [NSMutableDictionary dictionary];
	[classDict setObject:[NSNumber numberWithUnsignedInteger:kIMBObjectViewTypeIcon] forKey:@"viewType"];
	[classDict setObject:[NSNumber numberWithDouble:0.5] forKey:@"iconSize"];
	[IMBConfig registerDefaultPrefs:classDict forClass:self.class];
	[pool drain];
}


- (void) awakeFromNib
{
	[super awakeFromNib];
		 
	ibObjectArrayController.searchableProperties = [NSArray arrayWithObjects:
		@"name",
		@"metadata.Comment",
		@"metadata.ImagePath",
		@"metadata.iMediaKeywords",
		nil];

	[[[_tableView tableColumnWithIdentifier:@"name"] headerCell] setStringValue:NSLocalizedStringWithDefaultValue(
        @"IMBImageViewController.tableColumn.name", 
        nil,
        IMBBundle(), 
        @"Name", 
        @"Column title - should be a short word")];
        
	[[[_tableView tableColumnWithIdentifier:@"size"] headerCell] setStringValue:NSLocalizedStringWithDefaultValue(
        @"IMBImageViewController.tableColumn.size", 
        nil,
        IMBBundle(), 
        @"Size", 
        @"Column title - should be a short word")];	
}


//----------------------------------------------------------------------------------------------------------------------


+ (NSString*) mediaType
{
	return kIMBMediaTypeImage;
}

+ (NSString*) nibName
{
	return @"IMBImageObjectViewController";
}


//----------------------------------------------------------------------------------------------------------------------


+ (NSString*) objectCountFormatSingular
{
	return NSLocalizedStringWithDefaultValue(
		@"IMBImageViewController.countFormatSingular",
		nil,IMBBundle(),
		@"%d image",
		@"Format string for object count in singluar");
}


+ (NSString*) objectCountFormatPlural
{
	return NSLocalizedStringWithDefaultValue(
		@"IMBImageViewController.countFormatPlural",
		nil,IMBBundle(),
		@"%d images",
		@"Format string for object count in plural");
}


//----------------------------------------------------------------------------------------------------------------------


@end

