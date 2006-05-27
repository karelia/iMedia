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

#import "iMBPhotosController.h"
#import "iMediaBrowser.h"
#import "MUPhotoView.h"
#import "iMBLibraryNode.h"
#import "NSWorkspace+Extensions.h"
#import "iMedia.h"
#import "NSPasteboard+iMedia.h"

@interface iMBPhotosController (PrivateAPI)
- (NSString *)iconNameForPlaylist:(NSString*)name;
@end

@implementation iMBPhotosController

- (id) initWithPlaylistController:(NSTreeController*)ctrl
{
	if (self = [super initWithPlaylistController:ctrl]) {
		mySelection = [[NSMutableIndexSet alloc] init];
		myFilteredImages = [[NSMutableArray alloc] init];
		[NSBundle loadNibNamed:[self nibName] owner:self];
	}
	return self;
}

- (void)dealloc
{
	[mySelection release];
	[myCache release];
	[myImages release];
	[myFilteredImages release];
	[mySearchString release];
	
	[super dealloc];
}

- (void)awakeFromNib
{
	[oPhotoView setPhotoHorizontalSpacing:15];
	[oPhotoView setPhotoVerticalSpacing:15];
	[oPhotoView setPhotoSize:75];
	[oPhotoView setDelegate:self];
}

- (NSString *)nibName
{
	return @"iPhoto";
}

- (void)refilter
{
	[mySelection removeAllIndexes];
	[myFilteredImages removeAllObjects];
	
	if ([mySearchString length] == 0) return;
	
	NSEnumerator *e = [myImages objectEnumerator];
	NSDictionary *cur;
	
	while (cur = [e nextObject])
	{
		if ([[cur objectForKey:@"Caption"] rangeOfString:mySearchString options:NSCaseInsensitiveSearch].location != NSNotFound ||
			[[cur objectForKey:@"ImagePath"] rangeOfString:mySearchString options:NSCaseInsensitiveSearch].location != NSNotFound)
		{
			[myFilteredImages addObject:cur];
		}
	}
}

- (IBAction)search:(id)sender
{
	[mySearchString autorelease];
	mySearchString = [[sender stringValue] copy];
	
	[self refilter];
	[oPhotoView setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark Media Browser Protocol Overrides

static NSImage *_toolbarIcon = nil;

- (NSImage*)toolbarIcon
{
	if(_toolbarIcon == nil)
	{
		_toolbarIcon = [[[NSWorkspace sharedWorkspace] iconForAppWithBundleIdentifier:@"com.apple.iPhoto"] retain];
		[_toolbarIcon setScalesWhenResized:YES];
		[_toolbarIcon setSize:NSMakeSize(32,32)];
	}
	return _toolbarIcon;
}

- (NSString *)mediaType
{
	return @"photos";
}

- (NSString *)name
{
	return LocalizedStringInThisBundle(@"Photos", @"Name of Data Type");
}

- (void)willActivate
{
	[super willActivate];
	[self bind:@"images" 
	  toObject:[self controller] 
		 withKeyPath:@"selection.Images" 
	   options:nil];
	
	[[oPhotoView window] makeFirstResponder:oPhotoView];
}

- (void)didDeactivate
{
	[self unbind:@"images"];
}

- (void)writePlaylist:(iMBLibraryNode *)playlist toPasteboard:(NSPasteboard *)pboard
{
	NSMutableArray *files = [NSMutableArray array];
	NSMutableArray *captions = [NSMutableArray array];
	NSMutableArray *images = [NSMutableArray array];
	NSMutableArray *albums = [NSMutableArray array];
	
	NSMutableArray *types = [NSMutableArray array]; // OLD BEHAVIOR: arrayWithArray:[pboard types]];
	[types addObjectsFromArray:[NSPasteboard fileAndURLTypes]];
	[types addObject:@"ImageDataListPboardType"];
	[types addObject:@"AlbumDataListPboardType"];
	[pboard declareTypes:types owner:nil];
	
	//we store the images as an attribute in the node
	NSArray *imageRecords = [playlist attributeForKey:@"Images"];
	NSEnumerator *e = [imageRecords objectEnumerator];
	NSDictionary *rec;
				
	while (rec = [e nextObject]) {
		[files addObject:[rec objectForKey:@"ImagePath"]];
		[captions addObject:[rec objectForKey:@"Caption"]];
		//[iphotoData setObject:rec forKey:cur]; //the key should be irrelavant
	}
	[pboard writeURLs:nil files:files names:captions];

	NSDictionary *plist = [NSDictionary dictionaryWithObjectsAndKeys:albums, @"List of Albums", images, @"Master Image List", nil];
	[pboard setPropertyList:plist forType:@"AlbumDataListPboardType"];
	
}

#pragma mark -
#pragma mark MUPhotoView Delegate Methods

- (void)setImages:(NSArray *)images
{
	[myImages autorelease];
	myImages = [images retain];
	[myCache removeAllObjects];
	[self refilter];
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
	
	NSImage *img = [rec objectForKey:@"CachedThumb"];
	if (!img)
	{
		NSString *thumbPath = [rec objectForKey:@"ThumbPath"];
		if (thumbPath)
		{
			img = [myCache objectForKey:thumbPath];
			if (!img)
			{
				img = [[[NSImage alloc] initByReferencingFile:thumbPath] autorelease];
			}
			if (!img)
			{
				// The file doesn't exist so we need to display the ? image
				
			}
			if (img)
			{
				[(NSMutableDictionary *)rec setObject:img forKey:@"CachedThumb"];
			}
		}
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

- (void)photoView:(MUPhotoView *)view fillPasteboardForDrag:(NSPasteboard *)pboard
{
	NSMutableArray *fileList = [NSMutableArray array];
	NSMutableArray *captions = [NSMutableArray array];
	NSMutableDictionary *iphotoData = [NSMutableDictionary dictionary];
	
	NSMutableArray *types = [NSMutableArray array]; 
	[types addObjectsFromArray:[NSPasteboard fileAndURLTypes]];
	[types addObject:@"ImageDataListPboardType"];
	[pboard declareTypes:types owner:nil];
	
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
			[fileList addObject:[cur objectForKey:@"ImagePath"]];
			[captions addObject:[cur objectForKey:@"Caption"]];
			[iphotoData setObject:cur forKey:[NSNumber numberWithInt:i]];
		}
	}
				
	[pboard writeURLs:nil files:fileList names:captions];
	[pboard setPropertyList:iphotoData forType:@"ImageDataListPboardType"];
	
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
