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
 
 iMedia Browser Home Page: <http://imedia.karelia.com/>
 
 Please send fixes to <imedia@lists.karelia.com>

*/

#import "iMBXBELParser.h"
#import "iMBLibraryNode.h"
#import "WebIconDatabase.h"
#import "NSAttributedString+iMedia.h"

@implementation iMBXBELParser

- (iMBLibraryNode *)recursivelyParseFolder:(NSXMLElement *)folder
{
	iMBLibraryNode *node = [[iMBLibraryNode alloc] init];
	[node setIconName:@"folder"];
	[node setName:[[[folder elementsForName:@"title"] objectAtIndex:0] stringValue]];
	NSEnumerator *e = [[folder elementsForName:@"folder"] objectEnumerator];
	NSXMLElement *cur;
	
	while (cur = [e nextObject])
	{
		iMBLibraryNode *subNode = [self recursivelyParseFolder:cur];
		[node addItem:subNode];
	}
	
	e = [[folder elementsForName:@"bookmark"] objectEnumerator];
	NSMutableDictionary *link;
	NSMutableArray *links = [NSMutableArray array];
	
	while (cur = [e nextObject])
	{
		link = [NSMutableDictionary dictionary];
		
		[link setObject:[[cur attributeForName:@"href"] stringValue] forKey:@"URL"];
		[link setObject:[[[cur elementsForName:@"title"] objectAtIndex:0] stringValue] forKey:@"Name"];
		
		NSImage *icon = [[WebIconDatabase sharedIconDatabase] iconForURL:[link objectForKey:@"URL"]
																withSize:NSMakeSize(16,16)
																   cache:YES];
		[link setObject:icon forKey:@"Icon"];
		id nameWithIcon = [NSAttributedString attributedStringWithName:[link objectForKey:@"Name"] image:icon];
		[link setObject:nameWithIcon forKey:@"NameWithIcon"];
		[links addObject:link];
	}
	[node setAttribute:links forKey:@"Links"];
	return [node autorelease];
}

- (void)parseWithXMLDocument:(NSXMLDocument *)xml node:(iMBLibraryNode *)node
{
	NSXMLElement *xbel = [xml rootElement];
	NSArray *folders = [xbel elementsForName:@"folder"];
	NSEnumerator *e = [folders objectEnumerator];
	NSXMLElement *cur;
	iMBLibraryNode *folder;
	
	while (cur = [e nextObject])
	{
		folder = [self recursivelyParseFolder:cur];
		[node addItem:folder];
	}
}

@end
