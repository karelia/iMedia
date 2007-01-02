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

#import "iMBAbstractController.h"

#import "iMBLibraryNode.h"

NSString *iMBNativePasteboardFlavor=@"iMBNativePasteboardFlavor";
NSString *iMBControllerClassName=@"iMBControllerClassName";
NSString *iMBNativeDataArray=@"iMBNativeDataArray";

@interface NSObject (iMediaHack)
- (id)observedObject;
@end


@implementation iMBAbstractController

- (id)initWithPlaylistController:(NSTreeController *)ctrl
{
	if (self = [super init])
	{
		myController = [ctrl retain];
	}
	return self;
}

- (void)dealloc
{
	[myController release];
	[super dealloc];
}

- (NSString *)mediaType
{
	return nil;
}

- (NSImage *)toolbarIcon
{
	return nil;
}

- (NSString *)name
{
	return nil;
}

- (NSView *)browserView
{
	return oView;
}

- (void)willActivate
{
	
}

- (void)didDeactivate
{
	
}

- (Class)parserForFolderDrop
{
	return nil; 
}


- (NSArray*)fineTunePlaylistDragTypes:(NSArray *)defaultTypes
{
	return defaultTypes;
}

- (BOOL)allowPlaylistFolderDrop:(NSString*)path
{
	return ![[NSWorkspace sharedWorkspace] isFilePackageAtPath:path];
}

- (NSDragOperation)playlistOutlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)index tryDefaultHandling:(BOOL*)tryDefault

{
	*tryDefault = YES;
	return NSDragOperationNone;
}

- (BOOL)playlistOutlineView:(NSOutlineView *)outlineView
				 acceptDrop:(id <NSDraggingInfo>)info
					   item:(id)item
				 childIndex:(int)index
		 tryDefaultHandling:(BOOL*)tryDefault
{
	*tryDefault = YES;
	return NO;
}

- (void)writePlaylist:(iMBLibraryNode *)playlist toPasteboard:(NSPasteboard *)pboard
{
	
}

- (void)refresh
{
	[myController rearrangeObjects];
}

- (NSTreeController *)controller
{
	return [[myController retain] autorelease];
}

- (void)postSelectionChangeNotification:(NSArray *)selectedObjects
{
	[[NSNotificationCenter defaultCenter] postNotificationName:iMediaBrowserSelectionDidChangeNotification
														object:self
													  userInfo:[NSDictionary dictionaryWithObject:selectedObjects forKey:@"Selection"]];
}

- (NSArray *)rootNodes
{
	NSMutableArray *nodes = [NSMutableArray array];
	NSEnumerator *e = [[myController content] object];
	id cur;
	
	while (cur = [e nextObject])
	{
		[nodes addObject:[cur observedObject]];
	}
	return nodes;
}

@end
