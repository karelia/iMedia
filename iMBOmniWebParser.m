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

#import "iMBOmniWebParser.h"
#import "iMBLibraryNode.h"
#import "iMediaBrowser.h"
#import "iMedia.h"
#import "iMBXBELParser.h"

@implementation iMBOmniWebParser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[iMediaBrowser registerParser:[self class] forMediaType:@"links"];
	
	[pool release];
}

- (id)init
{
	NSArray *appSupport = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES);
	if (self = [super initWithContentsOfFile:[[appSupport objectAtIndex:0] stringByAppendingPathComponent:@"OmniWeb 5/Bookmarks.html"]])
	{
		
	}
	return self;
}

- (iMBLibraryNode *)parseDatabase
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
	NSLog(@"%@", [xml XMLStringWithOptions:NSXMLNodePrettyPrint]);
	iMBLibraryNode *library = nil;
	
	if (xml)
	{
		library = [[iMBLibraryNode alloc] init];
		[library setName:LocalizedStringInThisBundle(@"OmniWeb", @"OmniWeb")];
		[library setIconName:@"com.omnigroup.OmniWeb5"];
		
		iMBXBELParser *parser = [[iMBXBELParser alloc] init];
		[parser parseWithXMLDocument:xml node:library];
		[parser release];
	}

	return [library autorelease];
}

@end
