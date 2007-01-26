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
		_toolbarIcon = [[[NSWorkspace sharedWorkspace] iconForAppWithBundleIdentifier:@"com.apple.Safari"] retain];
		[_toolbarIcon setSize:NSMakeSize(32,32)];
	}
	return _toolbarIcon;
}


- (NSString *)name
{
	return LocalizedStringInThisBundle(@"Links", @"Name of Data Type");
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
	NSMutableArray *types = [NSMutableArray array]; // OLD BEHAVIOR: arrayWithArray:[pboard types]];
	[types addObjectsFromArray:[NSPasteboard URLTypes]];
   [types addObject:iMBNativePasteboardFlavor]; // Native iMB Data

	[pboard declareTypes:types owner:nil];
	
	NSArray *content = [oLinkController arrangedObjects];
	NSEnumerator *e = [rows objectEnumerator];
	NSNumber *cur;
	NSMutableArray *urls = [NSMutableArray array];
   NSMutableArray *titles = [NSMutableArray array];
   NSMutableArray* nativeDataArray = [NSMutableArray arrayWithCapacity:[rows count]];
	while (cur = [e nextObject])
	{
      unsigned int contextIndex = [cur unsignedIntValue];
		NSDictionary *link = [content objectAtIndex:contextIndex];
      
      [nativeDataArray addObject:link];

		NSURL *url = [NSURL URLWithString:[link objectForKey:@"URL"]];
		if (nil != url)
		{
			[urls addObject:url];
			[titles addObject:[link objectForKey:@"Name"]];
		}
	}
   NSDictionary* nativeData = [NSDictionary dictionaryWithObjectsAndKeys:
                                             [self className], iMBControllerClassName,
                                             nativeDataArray, iMBNativeDataArray,
                                             nil];
   [pboard setData:[NSArchiver archivedDataWithRootObject:nativeData] forType:iMBNativePasteboardFlavor]; // Native iMB Data
 	[pboard writeURLs:urls files:nil names:titles];
   
	return YES;
}

- (void)writePlaylist:(iMBLibraryNode *)playlist toPasteboard:(NSPasteboard *)pboard
{
	NSMutableArray *types = [NSMutableArray array]; // OLD BEHAVIOR: arrayWithArray:[pboard types]];
	[types addObjectsFromArray:[NSPasteboard URLTypes]];
	
	[pboard declareTypes:types owner:nil];

	NSMutableArray *urls = [NSMutableArray array];
	// for WebURLsWithTitlesPboardType
    NSMutableArray *titles = [NSMutableArray array];
	
	NSEnumerator *e = [[playlist valueForKey:@"Links"] objectEnumerator];
	NSDictionary *cur;
	
	while (cur = [e nextObject])
	{
		NSURL *url = [NSURL URLWithString:[cur objectForKey:@"URL"]];
		if (nil != url)
		{
			[urls addObject:url];
			[titles addObject:[cur objectForKey:@"Name"]];
		}
	}
 	[pboard writeURLs:urls files:nil names:titles];
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
