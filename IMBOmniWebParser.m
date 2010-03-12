/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2009 by Karelia Software et al.
 
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


// Author: Unknown


#import "IMBOmniWebParser.h"
#import "IMBNode.h"
#import "IMBParserController.h"
#import "IMBXBELParser.h"

@implementation IMBOmniWebParser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeLink];
	
	[pool release];
}

- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super initWithMediaType:inMediaType])
	{
		NSArray *appSupport = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES);

		self.mediaSource = [[appSupport objectAtIndex:0] stringByAppendingPathComponent:@"OmniWeb 5/Bookmarks.html"];
	}
	return self;
}

- (IMBNode *)parseDatabase
{
	NSBundle *bndl = [NSBundle bundleForClass:[self class]];
	NSURL *docURL = [NSURL fileURLWithPath:[self databasePath]];
	NSURL *xsltURL = [NSURL fileURLWithPath:[bndl pathForResource:@"OmniwebBookmarksToXBEL" ofType:@"xslt"]];
	NSError *err;
	NSXMLDocument *xml = [[[NSXMLDocument alloc] initWithContentsOfURL:docURL
															  options:NSXMLDocumentTidyHTML
																error:&err] autorelease];
	xml = [xml objectByApplyingXSLTAtURL:xsltURL
							   arguments:nil
								   error:&err];
	//NSLog(@"%@", [xml XMLStringWithOptions:NSXMLNodePrettyPrint]);
	IMBNode *library = nil;
	
	if (xml)
	{
		library = [[IMBNode alloc] init];
		[library setName:NSLocalizedStringWithDefaultValue(
														   @"OmniWeb",
														   nil,IMBBundle(),
														   @"OmniWeb",
														   @"OmniWeb application name")];
		[library setIconName:@"com.omnigroup.OmniWeb5"];
        [library setIdentifier:@"OmniWeb"];
///        [library setParserClassName:NSStringFromClass([self class])];
///		[library setWatchedPath:_database];
		
		IMBXBELParser *parser = [[IMBXBELParser alloc] init];
		[parser parseWithXMLDocument:xml node:library];
		[parser release];
	}

	return [library autorelease];
}

@end
