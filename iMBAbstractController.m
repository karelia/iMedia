/*
 iMedia Browser <http://kareia.com/imedia>
 
 Copyright (c) 2005-2007 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 iMedia Browser is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2007 by Karelia Software et al.
 
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

- (void)setBrowser:(iMediaBrowser *)browser
{
	myBrowser = browser;
}

- (iMediaBrowser *)browser
{
	return myBrowser;
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

- (NSDragOperation)playlistOutlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)aIndex tryDefaultHandling:(BOOL*)tryDefault

{
	*tryDefault = YES;
	return NSDragOperationNone;
}

- (BOOL)playlistOutlineView:(NSOutlineView *)outlineView
				 acceptDrop:(id <NSDraggingInfo>)info
					   item:(id)item
				 childIndex:(int)aIndex
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

- (IBAction)reloadMediaBrowser:(id)sender		// OBSOLETE - GOING AWAY WHEN THE NIBS LOSE THIER VERSION
{
	[[iMediaBrowser sharedBrowser] reloadMediaBrowser:sender];
}

- (NSTreeController *)controller
{
	return [[myController retain] autorelease];
}

- (void)postSelectionChangeNotification:(NSArray *)selectedObjects
{
	NSEvent *evt = [NSApp currentEvent];
	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
		selectedObjects, @"Selection", 
		evt, @"Event",
		selectedObjects, @"records", // XXX legacy keys for backwards compatability
		evt, @"event", nil];	// XXX legacy key for backwards compatability
	[[NSNotificationCenter defaultCenter] postNotificationName:iMediaBrowserSelectionDidChangeNotification
														object:self
													  userInfo:info];
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
