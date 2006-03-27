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


#import "iMBLinksController.h"
#import "iMBLibraryNode.h"

@implementation iMBLinksController

- (id)initWithPlaylistController:(NSTreeController *)ctrl
{
	if (self = [super initWithPlaylistController:ctrl]) {
		[NSBundle loadNibNamed:@"Links" owner:self];
	}
	return self;
}

- (void)awakeFromNib
{
	[oLinkController setDelegate:self];
}

- (NSString *)mediaType
{
	return @"links";
}

static NSImage *_toolbarIcon = nil;

- (NSImage*)toolbarIcon
{
	if(_toolbarIcon == nil)
	{
		NSBundle *b = [NSBundle bundleForClass:[self class]];
		NSString *p = [b pathForResource:@"safari" ofType:@"png"];
		_toolbarIcon = [[NSImage alloc] initWithContentsOfFile:p];
		[_toolbarIcon setScalesWhenResized:YES];
		[_toolbarIcon setSize:NSMakeSize(32,32)];
	}
	return _toolbarIcon;
}


- (NSString *)name
{
	return NSLocalizedString(@"Links", @"Browser Name");
}

- (NSView *)browserView
{
	return oView;
}

- (void)didDeactivate
{
	
}

- (BOOL)tableView:(NSTableView *)tv
		writeRows:(NSArray*)rows
	 toPasteboard:(NSPasteboard*)pboard
{
	// we don't want to overwrite any other existing types on the pboard
	NSMutableArray *types = [NSMutableArray arrayWithArray:[pboard types]];
	[types addObject:NSURLPboardType];
    [types addObject:@"WebURLsWithTitlesPboardType"]; // a type that Safari declares
	
	[pboard declareTypes:types
				   owner:nil];
	
	NSArray *content = [oLinkController arrangedObjects];
	NSEnumerator *e = [rows objectEnumerator];
	NSNumber *cur;
	NSMutableArray *urls = [NSMutableArray array];
    
    // for WebURLsWithTitlesPboardType
    NSMutableArray *URLsWithTitles = [NSMutableArray array];
    NSMutableArray *URLsAsStrings = [NSMutableArray array];
    NSMutableArray *titles = [NSMutableArray array];
	
	while (cur = [e nextObject])
	{
		NSDictionary *link = [content objectAtIndex:[cur unsignedIntValue]];
		NSString *loc = [link objectForKey:@"URL"];
		
		NSURL *url = [NSURL URLWithString:loc];
		[urls addObject:url];
        
        [URLsAsStrings addObject:loc];
        [titles addObject:[link objectForKey:@"Name"]];
	}
	[pboard setPropertyList:urls forType:NSURLPboardType];
    
    [URLsWithTitles insertObject:URLsAsStrings atIndex:0];
    [URLsWithTitles insertObject:titles atIndex:1];
    [pboard setPropertyList:URLsWithTitles forType:@"WebURLsWithTitlesPboardType"];
	
	return YES;
}

- (void)writePlaylist:(iMBLibraryNode *)playlist toPasteboard:(NSPasteboard *)pboard
{
	// we don't want to overwrite any other existing types on the pboard
	NSMutableArray *types = [NSMutableArray arrayWithArray:[pboard types]];
	[types addObject:NSURLPboardType];
	
	[pboard declareTypes:types
				   owner:nil];
	NSMutableArray *urls = [NSMutableArray array];
	NSEnumerator *e = [[playlist attributeForKey:@"Links"] objectEnumerator];
	NSDictionary *cur;
	
	while (cur = [e nextObject])
	{
		[urls addObject:[NSURL URLWithString:[cur objectForKey:@"URL"]]];
	}
	[pboard setPropertyList:urls forType:NSURLPboardType];
}

- (IBAction)openInBrowser:(id)sender
{
	NSEnumerator *e = [[oLinkController selectedObjects] objectEnumerator];
	NSDictionary *cur;
	
	while (cur = [e nextObject])
	{		
		NSURL *url = [NSURL URLWithString:[cur objectForKey:@"URL"]];
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
}

@end
