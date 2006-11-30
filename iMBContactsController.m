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
#import "MUPhotoView.h"
#import <AddressBook/AddressBook.h>

@implementation iMBContactsController

+ (void)initialize
{
	[iMBContactsController setKeys:[NSArray arrayWithObject:@"images"] triggerChangeNotificationsForDependentKey:@"imageCount"];
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

- (void)awakeFromNib
{
	[oPhotoView setDelegate:self];
	[oPhotoView setUseOutlineBorder:NO];
	[oPhotoView setUseHighQualityResize:NO];
	[oPhotoView setBackgroundColor:[NSColor whiteColor]];

	[oSlider setFloatValue:[oPhotoView photoSize]];	// initialize.  Changes are put into defaults.
	[oPhotoView setPhotoHorizontalSpacing:15];
	[oPhotoView setPhotoVerticalSpacing:15];
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
	
	while (cur = [e nextObject])
	{
		ABPerson *person = [cur objectForKey:@"ABPerson"];
		NSData *vcard = [person vCardRepresentation];
		[vcards addObject:[[[NSString alloc] initWithData:vcard encoding:NSUTF8StringEncoding] autorelease]];
		NSString *vCardFile = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.vcf", [cur objectForKey:@"Caption"]]];
		[vcard writeToFile:vCardFile atomically:YES];
		[files addObject:vCardFile];
		[uids addObject:[person uniqueId]];
		
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

- (NSImage *)photoView:(MUPhotoView *)view photoAtIndex:(unsigned)index
{
	NSDictionary *rec;
	if ([mySearchString length] > 0)
	{
		rec = [myFilteredImages objectAtIndex:index];
	}
	else
	{
		rec = [myImages objectAtIndex:index];
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

- (NSData *)photoView:(MUPhotoView *)view pasteboardDataForPhotoAtIndex:(unsigned)index dataType:(NSString *)type
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

- (NSString *)photoView:(MUPhotoView *)view captionForPhotoAtIndex:(unsigned)index
{
	NSDictionary *rec;
	if ([mySearchString length] > 0)
	{
		rec = [myFilteredImages objectAtIndex:index];
	}
	else
	{
		rec = [myImages objectAtIndex:index];
	}
	return [rec objectForKey:@"Caption"];
}


@end
