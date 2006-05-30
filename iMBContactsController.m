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

#import "iMBContactsController.h"
#import "iMBLibraryNode.h"
#import "iMedia.h"
#import "NSPasteboard+iMedia.h"

@implementation iMBContactsController

- (id)initWithPlaylistController:(NSTreeController *)ctrl
{
	if (self = [super initWithPlaylistController:ctrl]) {
		[NSBundle loadNibNamed:@"Contacts" owner:self];
	}
	return self;
}

- (void)awakeFromNib
{
	//[oLinkController setDelegate:self];
}

- (NSString *)mediaType
{
	return @"contacts";
}

static NSImage *_toolbarIcon = nil;

- (NSImage*)toolbarIcon
{
	if(_toolbarIcon == nil)
	{
		NSBundle *b = [NSBundle bundleForClass:[self class]];
		NSString *p = [b pathForResource:@"contacts" ofType:@"png"];
		_toolbarIcon = [[NSImage alloc] initWithContentsOfFile:p];
		[_toolbarIcon setScalesWhenResized:YES];
		[_toolbarIcon setSize:NSMakeSize(32,32)];
	}
	return _toolbarIcon;
}


- (NSString *)name
{
	return LocalizedStringInThisBundle(@"Contacts", @"Name of Data Type");
}

- (NSView *)browserView
{
	return oView;
}

- (void)willActivate
{
	[super willActivate];
	[oPhotoView bind:@"images" 
			toObject:[self controller] 
		 withKeyPath:@"selection.People" 
			 options:nil];
	[oPhotoView prepare];
	[[oPhotoView window] makeFirstResponder:oPhotoView];
}

- (void)didDeactivate
{
	[oPhotoView unbind:@"images"];
}

- (BOOL)tableView:(NSTableView *)tv
		writeRows:(NSArray*)rows
	 toPasteboard:(NSPasteboard*)pboard
{
	NSMutableArray *types = [NSMutableArray array]; // OLD BEHAVIOR: arrayWithArray:[pboard types]];
	[types addObjectsFromArray:[NSPasteboard fileAndURLTypes]];
	
	[pboard declareTypes:types owner:nil];
	
	NSArray *content = nil; //[oLinkController arrangedObjects];
	NSEnumerator *e = [rows objectEnumerator];
	NSNumber *cur;
	NSMutableArray *urls = [NSMutableArray array];
    NSMutableArray *titles = [NSMutableArray array];
    	
	while (cur = [e nextObject])
	{
        unsigned int contextIndex = [cur unsignedIntValue];
		NSDictionary *link = [content objectAtIndex:contextIndex];
		NSString *loc = [link objectForKey:@"URL"];
		
		NSURL *url = [NSURL URLWithString:loc];
		[urls addObject:url];
        
        [titles addObject:[link objectForKey:@"Name"]];
        
	}
 	[pboard writeURLs:urls files:nil names:titles];

	return YES;
}

- (void)writePlaylist:(iMBLibraryNode *)playlist toPasteboard:(NSPasteboard *)pboard
{
	NSMutableArray *types = [NSMutableArray array]; // OLD BEHAVIOR: arrayWithArray:[pboard types]];
	[types addObjectsFromArray:[NSPasteboard fileAndURLTypes]];
	
	[pboard declareTypes:types  owner:nil];
	NSMutableArray *urls = [NSMutableArray array];
	// for WebURLsWithTitlesPboardType
    NSMutableArray *titles = [NSMutableArray array];
	
	NSEnumerator *e = [[playlist attributeForKey:@"People"] objectEnumerator];
	NSDictionary *cur;
	
	while (cur = [e nextObject])
	{
		NSString *loc = [cur objectForKey:@"URL"];
		[urls addObject:[NSURL URLWithString:loc]];
		
        [titles addObject:[cur objectForKey:@"Name"]];
	}
 	[pboard writeURLs:urls files:nil names:titles];
}

@end
