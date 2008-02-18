/*
 iMedia Browser <http://karelia.com/imedia/>
 
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


#import "iMBContactsController.h"
#import "iMBLibraryNode.h"
#import "iMedia.h"
#import "MUPhotoView.h"
#import <AddressBook/AddressBook.h>

@implementation iMBContactsController

+ (void)initialize
{
	[iMBContactsController setKeys:[NSArray arrayWithObject:@"images"] triggerChangeNotificationsForDependentKey:@"itemCount"];
	[iMBContactsController setKeys:[NSArray arrayWithObject:@"images"] triggerChangeNotificationsForDependentKey:@"itemCountString"];
}

- (id)initWithPlaylistController:(NSTreeController *)ctrl
{
	if (self = [super initWithPlaylistController:ctrl]) {
		mySelection = [[NSMutableIndexSet alloc] init];
		myFilteredImages = [[NSMutableArray alloc] init];
		
		[NSBundle loadNibNamed:@"Contacts" owner:self];
	}
	return self;
}

- (void)dealloc
{
    [mySelection release];
    [myImages release];
    [myFilteredImages release];
    [mySearchString release];
    [super dealloc];
}

- (void)awakeFromNib
{
	[oPhotoView setDelegate:self];
	[oPhotoView setUseOutlineBorder:NO];
	[oPhotoView setUseHighQualityResize:NO];
	[oPhotoView setBackgroundColor:[NSColor whiteColor]];

	[oSlider setFloatValue:[oPhotoView photoSize]];	// initialize.  Changes are put into defaults.
	[oPhotoView setPhotoHorizontalSpacing:15];
	[oPhotoView setPhotoVerticalSpacing:15];

	NSDictionary *optionsDict =
		[NSDictionary dictionaryWithObject:
			xxxxxxxxxxxxxTO_FIXxxxxxxx(@"%{value1}@ contacts", @"Formatting: number of contacts in address book")
									forKey:@"NSDisplayPattern"];
	
	[counterField bind:@"displayPatternValue1"
			  toObject:self
		   withKeyPath:@"imageCount"
			   options:optionsDict];
// It would be nice to properly show single/plural form; maybe also indicate # selected if there is a selection.  How to do with bindings?
}

- (void)setBrowser:(iMediaBrowser *)browser	// hook up captions prefs now that we have a browser associated with this controller.
{
	[super setBrowser:browser];
	[oPhotoView setShowCaptions:[browser prefersFilenamesInPhotoBasedBrowsers]];
}

- (void)refilter
{
	[mySelection removeAllIndexes];
	[self willChangeValueForKey:@"images"];
	[myFilteredImages removeAllObjects];
	
	if ([mySearchString length] == 0) return;
	
	NSEnumerator *e = [myImages objectEnumerator];
	NSDictionary *cur;
	
	while (cur = [e nextObject])
	{
		if ([[cur objectForKey:@"Caption"] rangeOfString:mySearchString options:NSCaseInsensitiveSearch].location != NSNotFound)
		{
			[myFilteredImages addObject:cur];
		}
	}
	[self didChangeValueForKey:@"images"];
}

- (IBAction)search:(id)sender
{
	[mySearchString autorelease];
	mySearchString = [[sender stringValue] copy];
	
	[self refilter];
	[oPhotoView setNeedsDisplay:YES];
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
		NSString *p = [[NSBundle bundleForClass:[self class]] pathForResource:@"contacts" ofType:@"png"];
		_toolbarIcon = [[NSImage alloc] initWithContentsOfFile:p];
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
	[self bind:@"images" 
	  toObject:[self controller] 
		 withKeyPath:@"selection.People" 
	   options:nil];
	[[oPhotoView window] makeFirstResponder:oPhotoView];
}

- (void)didDeactivate
{
	[self unbind:@"images"];
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

- (void)writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
	NSMutableArray *types = [NSMutableArray array]; // OLD BEHAVIOR: arrayWithArray:[pboard types]];
	[types addObjectsFromArray:[NSPasteboard fileAndURLTypes]];
	[types addObjectsFromArray:[NSArray arrayWithObjects:@"ABPeopleUIDsPboardType", @"Apple VCard pasteboard type", nil]];
   [types addObject:iMBNativePasteboardFlavor]; // Native iMB Data
	[pboard declareTypes:types  owner:nil];
	NSMutableArray *vcards = [NSMutableArray array];
	NSMutableArray *urls = [NSMutableArray array];
	NSMutableArray *files = [NSMutableArray array];
    NSMutableArray *titles = [NSMutableArray array];
	NSMutableArray *uids = [NSMutableArray array];
	
	NSEnumerator *e = [items objectEnumerator];
	NSDictionary *cur;
	NSString *dir = NSTemporaryDirectory();
	[[NSFileManager defaultManager] createDirectoryAtPath:dir attributes:nil];
   NSMutableArray* nativeDataArray = [NSMutableArray arrayWithCapacity:[items count]];
	while (cur = [e nextObject])
	{
		ABPerson *person = [cur objectForKey:@"ABPerson"];
		NSData *vcard = [person vCardRepresentation];
		[vcards addObject:[[[NSString alloc] initWithData:vcard encoding:NSUTF8StringEncoding] autorelease]];
		NSString *vCardFile = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.vcf", [cur objectForKey:@"Caption"]]];
		[vcard writeToFile:vCardFile atomically:YES];
		[files addObject:vCardFile];
		[uids addObject:[person uniqueId]];
		
      [nativeDataArray addObject:cur];

		NSArray *emails = [cur objectForKey:@"EmailAddresses"];
		if ([emails count] > 0)
		{
			[urls addObject:[NSURL URLWithString:[NSString stringWithFormat:@"mailto:%@",[emails objectAtIndex:0]]]];
		}
		else
		{
			[urls addObject:[NSURL fileURLWithPath:vCardFile]];
		}
		
        [titles addObject:[cur objectForKey:@"Caption"]];
	}
   NSDictionary* nativeData = [NSDictionary dictionaryWithObjectsAndKeys:
                                             [self className], iMBControllerClassName,
                                             nativeDataArray, iMBNativeDataArray,
                                             nil];
   [pboard setData:[NSArchiver archivedDataWithRootObject:nativeData] forType:iMBNativePasteboardFlavor]; // Native iMB Data
 	[pboard writeURLs:urls files:nil names:titles];
	[pboard setPropertyList:[vcards componentsJoinedByString:@"\n"] forType:@"Apple VCard pasteboard type"];
	[pboard setPropertyList:uids forType:@"ABPeopleUIDsPboardType"];
}

- (void)writePlaylist:(iMBLibraryNode *)playlist toPasteboard:(NSPasteboard *)pboard
{
	[self writeItems:[playlist valueForKey:@"People"] toPasteboard:pboard];
}

- (NSNumber *)imageCount
{
	int count;
	if ([mySearchString length] > 0)
	{
		count = [myFilteredImages count];
	}
	else
	{
		count = [myImages count];
	}
	
	return [NSNumber numberWithUnsignedInt:count];
}

- (void)setImageCount:(NSNumber *)count 
{
	// do nothing
}

#pragma mark -
#pragma mark MUPhotoView Delegate Methods

- (void)setImages:(NSArray *)images
{
	[myImages autorelease];
	myImages = [images retain];
	[self refilter];
	//reset the scroll position
	[oPhotoView scrollRectToVisible:NSMakeRect(0,0,1,1)];
	[oPhotoView setNeedsDisplay:YES];
}

- (NSArray *)images
{
	return myImages;
}

- (unsigned)photoCountForPhotoView:(MUPhotoView *)view
{
	if ([mySearchString length] > 0)
	{
		return [myFilteredImages count];
	}
	return [myImages count];
}

static NSImage *noAvatarImage = nil;

- (NSImage *)photoView:(MUPhotoView *)view photoAtIndex:(unsigned)aIndex
{
	NSDictionary *rec;
	if ([mySearchString length] > 0)
	{
		rec = [myFilteredImages objectAtIndex:aIndex];
	}
	else
	{
		rec = [myImages objectAtIndex:aIndex];
	}
	//try the caches
	NSImage *img = [rec objectForKey:@"CachedThumb"];
	
	if (!img) img = [rec objectForKey:@"CachedThumb"];
	
	if (!img)
	{
		NSData *iconData = [[rec objectForKey:@"ABPerson"] imageData];
		
		if (iconData)
		{
			img = [[[NSImage alloc] initWithData:iconData] autorelease];
		}
		else
		{
			if (!noAvatarImage)
			{
				NSString *imgPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"contact" ofType:@"png"];
				noAvatarImage = [[NSImage alloc] initWithContentsOfFile:imgPath];
			}
			img = noAvatarImage;
		}
		[(NSMutableDictionary *)rec setObject:img forKey:@"CachedThumb"];
	}
	
	return img;
}

- (void)photoView:(MUPhotoView *)view didSetSelectionIndexes:(NSIndexSet *)indexes
{
	[mySelection removeAllIndexes];
	[mySelection addIndexes:indexes];
}

- (NSIndexSet *)selectionIndexesForPhotoView:(MUPhotoView *)view
{
	return mySelection;
}

- (unsigned int)photoView:(MUPhotoView *)view draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return NSDragOperationCopy;
}

// MUPHOTOVIEW STYLE

- (NSArray *)pasteboardDragTypesForPhotoView:(MUPhotoView *)view
{
    return [[[NSArray alloc] init] autorelease];
}

- (NSData *)photoView:(MUPhotoView *)view pasteboardDataForPhotoAtIndex:(unsigned)aIndex dataType:(NSString *)type
{
    return nil;
}

// OUR STYLE

- (void)photoView:(MUPhotoView *)view fillPasteboardForDrag:(NSPasteboard *)pboard
{
	NSMutableArray *items = [NSMutableArray array];
	
	NSDictionary *cur;
	
	int i;
	for(i = 0; i < [myImages count]; i++) 
	{
		if ([mySelection containsIndex:i]) 
		{
			if ([mySearchString length] > 0)
			{
				cur = [myFilteredImages objectAtIndex:i];
			}
			else
			{
				cur = [myImages objectAtIndex:i];
			}
			[items addObject:cur];
		}
	}
	[self writeItems:items toPasteboard:pboard];
}

- (NSString *)photoView:(MUPhotoView *)view tooltipForPhotoAtIndex:(unsigned)aIndex
{
	NSDictionary *rec;
	if ([mySearchString length] > 0)
	{
		rec = [myFilteredImages objectAtIndex:aIndex];
	}
	else
	{
		rec = [myImages objectAtIndex:aIndex];
	}
	return [rec objectForKey:@"Caption"];
}

// TO DO: HOOK THIS UP
- (NSString *)contactsCountPluralityAdjustedString
{
	int count = [[self imageCount] intValue];
	
	return abs(count) != 1 ? LocalizedStringInThisBundle(@"contacts", @"plural form for showing how many items there are") :  LocalizedStringInThisBundle(@"contact", @"singular form for showing how many items there are");
}


@end
