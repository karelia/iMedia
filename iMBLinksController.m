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
#import "iMedia.h"

@implementation iMBLinksController

- (id)initWithPlaylistController:(NSTreeController *)ctrl
{
	if (self = [super initWithPlaylistController:ctrl]) {
		[NSBundle loadNibNamed:@"Links" owner:self];
	}
	return self;
}

#warning Please put in a progress view when switching to links tab; this might be slow loading.


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
	return LocalizedStringInThisBundle(@"Links", @"Browser Name");
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
    [types addObject:NSStringPboardType];
	
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
    
    // for NSStringPboardType
    BOOL addedStringPboardType = NO;
	
	while (cur = [e nextObject])
	{
        unsigned int contextIndex = [cur unsignedIntValue];
		NSDictionary *link = [content objectAtIndex:contextIndex];
		NSString *loc = [link objectForKey:@"URL"];
		
		NSURL *url = [NSURL URLWithString:loc];
		[urls addObject:url];
        
        [URLsAsStrings addObject:loc];
        [titles addObject:[link objectForKey:@"Name"]];
        
        if ( NO == addedStringPboardType )
        {
            // we just add the first URL we find
            [pboard setPropertyList:loc forType:NSStringPboardType];
            addedStringPboardType = YES;
        }
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
	[types addObject:@"WebURLsWithTitlesPboardType"]; // a type that Safari declares
	
	[pboard declareTypes:types
				   owner:nil];
	NSMutableArray *urls = [NSMutableArray array];
	// for WebURLsWithTitlesPboardType
    NSMutableArray *URLsWithTitles = [NSMutableArray array];
    NSMutableArray *URLsAsStrings = [NSMutableArray array];
    NSMutableArray *titles = [NSMutableArray array];
	
	NSEnumerator *e = [[playlist attributeForKey:@"Links"] objectEnumerator];
	NSDictionary *cur;
	
	while (cur = [e nextObject])
	{
		NSString *loc = [cur objectForKey:@"URL"];
#warning What if NSURL can't be constructed?  e.g. if it's a javascript bookmarkelet?  We need to exit gracefully.
		
		[urls addObject:[NSURL URLWithString:loc]];
		
		[URLsAsStrings addObject:loc];
        [titles addObject:[cur objectForKey:@"Name"]];
	}
	[pboard setPropertyList:urls forType:NSURLPboardType];
	[URLsWithTitles insertObject:URLsAsStrings atIndex:0];
    [URLsWithTitles insertObject:titles atIndex:1];
    [pboard setPropertyList:URLsWithTitles forType:@"WebURLsWithTitlesPboardType"];
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

#warning Suggestion: Could favicons be shown?  Only if we can use Safari's cache, and NOT slow down
#warning responsiveness with network loads of images!

@end
