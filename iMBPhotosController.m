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
#import "iMedia.h"

#ifndef SAMPLE_INCOMING_DRAG
#define SAMPLE_INCOMING_DRAG 0
#endif


@interface NSObject (CompilerIsHappy)
+ (NSImage *)imageWithPath:(NSString *)path boundingBox:(NSSize)boundingBox;
@end

@interface iMBPhotosController (PrivateAPI)
- (NSString *)iconNameForPlaylist:(NSString*)name;
@end

static NSImage *_placeholder = nil;
static NSImage *_missing = nil;

@implementation iMBPhotosController

+ (void)initialize
{
	[iMBPhotosController setKeys:[NSArray arrayWithObject:@"images"] triggerChangeNotificationsForDependentKey:@"imageCount"];
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"UseEpeg"]];
}

- (id) initWithPlaylistController:(NSTreeController*)ctrl
{
	if (self = [super initWithPlaylistController:ctrl]) {
		mySelection = [[NSMutableIndexSet alloc] init];
		myFilteredImages = [[NSMutableArray alloc] init];
		myCache = [[NSMutableDictionary dictionary] retain];
		myCacheLock = [[NSLock alloc] init];
		myInFlightImageOperations = [[NSMutableArray array] retain];
		myProcessingImages = [[NSMutableSet set] retain];
		myEPEGLock = [[NSLock alloc] init];
		
		if (!_placeholder)
		{
			NSString *path = [[NSBundle bundleForClass:[iMBPhotosController class]] pathForResource:@"placeholder" ofType:@"png"];
			_placeholder = [[NSImage alloc] initWithContentsOfFile:path];
			path = [[NSBundle bundleForClass:[iMBPhotosController class]] pathForResource:@"missingImage" ofType:@"png"];
			_missing = [[NSImage alloc] initWithContentsOfFile:path];
			if (!_missing)
				NSLog(@"missingImage.png is missing. This can cause bad things to happen");
		}
		
		if (![[NSBundle bundleForClass:[iMBPhotosController class]] loadNibFile:@"iPhoto" 
                                                         externalNameTable:[NSDictionary dictionaryWithObjectsAndKeys:self, @"NSOwner", nil] 
                                                                  withZone:[self zone]])
        {
            NSLog(@"iPhoto.nib is missing. This can cause bad things to happen");
        }
	}
	return self;
}

- (void)dealloc
{
	[myEPEGLock release];
	[mySelection release];
	[myCache release];
	[myCacheLock release];
	[myImages release];
	[myFilteredImages release];
	[mySearchString release];
	[myInFlightImageOperations release];
	[mySelectedIndexPath release];
	[myProcessingImages release];
	
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
//	[oPhotoView setUseFading:[[NSUserDefaults standardUserDefaults] boolForKey:@"iMBUseFading"]];
#if SAMPLE_INCOMING_DRAG
	[oPhotoView registerForDraggedTypes:[NSArray arrayWithObject:NSTIFFPboardType]];
#endif
}

- (void)refilter
{
	[mySelection removeAllIndexes];
	[self willChangeValueForKey:@"images"];
	[myFilteredImages removeAllObjects];
	
	if ([mySearchString length]) 
	{
		iMBLibraryNode *selectedNode = [[[self controller] selectedObjects] lastObject];
		[myFilteredImages addObjectsFromArray:[selectedNode searchAttribute:@"Images" withKeys:[NSArray arrayWithObjects:@"Caption", @"ImagePath", nil] matching:mySearchString]];		
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
    return [[NSBundle bundleForClass:[iMBPhotosController class]] localizedStringForKey:@"Photos" value:@"" table:nil];
}

- (void)refresh
{
	[super refresh];
	[self unbind:@"images"];
	[self bind:@"images" 
	  toObject:[self controller] 
		 withKeyPath:@"selection.Images" 
	   options:nil];
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
    [super didDeactivate];
}

- (Class)parserForFolderDrop
{
	return NSClassFromString(@"iMBPicturesFolder");
}

- (void)writeItems:(NSArray *)items fromAlbum:(NSString *)albumName toPasteboard:(NSPasteboard *)pboard
{
	NSMutableArray *files = [NSMutableArray array];
	NSMutableArray *captions = [NSMutableArray array];
	NSMutableDictionary *images = [NSMutableDictionary dictionary];
	NSMutableDictionary *album = [NSMutableDictionary dictionary];
	[album setObject:@"Regular" forKey:@"Album Type"];
	[album setObject:[NSNumber numberWithInt:1] forKey:@"AlbumId"];
	[album setObject:albumName forKey:@"AlbumName"];
	NSMutableArray *imageCount = [NSMutableArray array];
	int i;
	for (i = 1; i <= [items count]; i++)
	{
		[imageCount addObject:[NSNumber numberWithInt:i]];
	}
	[album setObject:imageCount forKey:@"KeyList"];
	
	NSMutableArray *types = [NSMutableArray array]; // OLD BEHAVIOR: arrayWithArray:[pboard types]];
	[types addObjectsFromArray:[NSPasteboard fileAndURLTypes]];
	[types addObject:@"AlbumDataListPboardType"];
	[types addObject:@"ImageDataListPboardType"];
   [types addObject:iMBNativePasteboardFlavor]; // Native iMB Data

	[pboard declareTypes:types owner:nil];
	
	NSEnumerator *e = [items objectEnumerator];
	NSDictionary *rec;
	i = 1;
	while (rec = [e nextObject])
   {
		[files addObject:[rec objectForKey:@"ImagePath"]];
		[captions addObject:[rec objectForKey:@"Caption"]];
		[images setObject:rec forKey:[NSNumber numberWithInt:i]];
		i++;
		//[iphotoData setObject:rec forKey:cur]; //the key should be irrelavant
	}
   NSDictionary* nativeData = [NSDictionary dictionaryWithObjectsAndKeys:
                                             [self className], iMBControllerClassName,
                                             items, iMBNativeDataArray,
                                             nil];
   [pboard setData:[NSArchiver archivedDataWithRootObject:nativeData] forType:iMBNativePasteboardFlavor]; // Native iMB Data
	[pboard writeURLs:nil files:files names:captions];
	
	NSDictionary *plist = [NSDictionary dictionaryWithObjectsAndKeys:[NSArray arrayWithObject:album], @"List of Albums", images, @"Master Image List", nil];
	[pboard setString:[plist description] forType:@"AlbumDataListPboardType"];
	[pboard setString:[images description] forType:@"ImageDataListPboardType"];
}

- (void)writePlaylist:(iMBLibraryNode *)playlist toPasteboard:(NSPasteboard *)pboard
{
	[self writeItems:[playlist valueForKey:@"Images"] fromAlbum:[playlist name] toPasteboard:pboard];	
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

- (NSArray *)selectedRecords
{
	NSMutableArray *records = [NSMutableArray array];
	int i, c = [myImages count];
	
	for (i = 0; i < c; i++)
	{
		if ([mySelection containsIndex:i])
		{
			[records addObject:[myImages objectAtIndex:i]];
		}
	}
	
	return records;
}

#pragma mark -
#pragma mark Threaded Image Loading

- (NSDictionary *)recordForPath:(NSString *)path
{
	NSEnumerator *e = [myImages objectEnumerator];
	NSDictionary *cur;
	
	while (cur = [e nextObject])
	{
		if ([[cur objectForKey:@"ImagePath"] isEqualToString:path])
		{
			return cur;
		}
	}
	return nil;
}

NSSize LimitMaxWidthHeight(NSSize ofSize, float toMaxDimension);
NSSize LimitMaxWidthHeight(NSSize ofSize, float toMaxDimension)
	{
	float max = fmax(ofSize.width, ofSize.height);
	if (max <= toMaxDimension)
		return ofSize;
		
	if (ofSize.width >= ofSize.height)
		{
		ofSize.width = toMaxDimension;
		ofSize.height *= toMaxDimension / max;
		}
	else
		{
		ofSize.height = toMaxDimension;
		ofSize.width *= toMaxDimension / max;
		}
	
	return ofSize;
	}

- (void)backgroundLoad
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// remove ourselves out of the queue
	[myCacheLock lock];
	NSString* imagePath = [[myInFlightImageOperations lastObject] retain];
	if (imagePath)
	{
		[myInFlightImageOperations removeObject:imagePath];
		[myProcessingImages addObject:imagePath];
	}
	[myCacheLock unlock];
	
	NSString *thumbPath;
	NSImage *img;
	NSDictionary *rec;
	BOOL useEpeg = [[NSUserDefaults standardUserDefaults] boolForKey:@"UseEpeg"];
	 
	while (imagePath)
	{
		rec = [self recordForPath:imagePath];
		img = nil;
		thumbPath = [rec objectForKey:@"ThumbPath"];
		
		if (thumbPath)
		{
			img = [[NSImage alloc] initByReferencingFile:thumbPath];
		}
		else
		{
			NSString* pathExtension = [[imagePath pathExtension] lowercaseString];
			if (useEpeg &&
				([pathExtension isEqualToString:@"jpg"] ||
				 [pathExtension isEqualToString:@"jpeg"]))
			{
				Class epeg = NSClassFromString(@"EpegWrapper");
				if (epeg)
				{
					[myEPEGLock lock];
					img = [[epeg imageWithPath:imagePath boundingBox:NSMakeSize(256,256)] retain];
					[myEPEGLock unlock];
				}
			}
		}
		
		// if still no image... use high res
		if (!img)
		{
			img = [[NSImage alloc] initWithContentsOfFile:imagePath];
			if (img)
			{
				NSSize imageSize = [img size];
				NSSize thumbSize = LimitMaxWidthHeight(imageSize, 256);
				if (!NSEqualSizes(imageSize, thumbSize))
				{
					NSImage* thumbImage = [[NSImage alloc] initWithSize:thumbSize];
					if (thumbImage)
					{
						[thumbImage setCachedSeparately:YES]; // See http://lists.apple.com/archives/cocoa-dev/2004/Oct/msg01339.html
						if (![img isFlipped])
							[thumbImage setFlipped:YES];
						[thumbImage lockFocus];
						[img drawInRect:NSMakeRect(0, 0, thumbSize.width, thumbSize.height) fromRect:NSMakeRect(0, 0, imageSize.width, imageSize.height) operation:NSCompositeCopy fraction:1.0];
						
						[thumbImage unlockFocus];
						[img release];
						img = thumbImage;
					}
				}
			}
		}
#warning TODO: Perhaps handle alias files, resolve a file if it's really an alias.
		
		if (!img) // we have a bad egg... need to display a ? icon
		{
			img = [_missing retain];
		}
		
		[myCacheLock lock];
		if (img && ![myCache objectForKey:imagePath])
		{
			[myCache setObject:img forKey:imagePath];
			[img release];
		}
		
		// get the last object in the queue because we would have scrolled and what is at the start won't be necessarily be what is displayed.
		[myProcessingImages removeObject:imagePath];
		[imagePath release];
		imagePath = [[myInFlightImageOperations lastObject] retain];
		if (imagePath)
		{
			[myInFlightImageOperations removeObject:imagePath];
			[myProcessingImages addObject:imagePath];
		}
		[myCacheLock unlock];
        
		[oPhotoView performSelectorOnMainThread:@selector(setNeedsDisplay:)
									 withObject:[NSNumber numberWithBool:YES]
								  waitUntilDone:NO];
	}
	
	myThreadCount--;
	[pool release];
}

#pragma mark -
#pragma mark MUPhotoView Delegate Methods

- (void)setImages:(NSArray *)images
{
	[myImages autorelease];
	myImages = [images retain];
	NSIndexPath *selectionIndex = [[self controller] selectionIndexPath];
	// only clear the cache if we go to another parser
	if (!([selectionIndex isSubPathOf:mySelectedIndexPath] || 
		  [mySelectedIndexPath isSubPathOf:selectionIndex] || 
		  [mySelectedIndexPath isPeerPathOf:selectionIndex]))
	{
		[myCache removeAllObjects];
	}
	[mySelectedIndexPath autorelease];
	mySelectedIndexPath = [selectionIndex retain];
	
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

- (NSString *)photoView:(MUPhotoView *)view titleForPhotoAtIndex:(unsigned)index
{
	if ([[self browser] showsFilenamesInPhotoBasedBrowsers])
        return [self photoView:view captionForPhotoAtIndex:index];
    
	return nil;
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
	//try the caches
	[myCacheLock lock];
	NSString *imagePath = [rec objectForKey:@"ImagePath"];
	NSImage *img = [myCache objectForKey:imagePath];
	[myCacheLock unlock];
	
	if (!img) img = [rec objectForKey:@"CachedThumb"];
	
	if (!img)
	{
		// background load the image
		[myCacheLock lock];
		BOOL alreadyQueued = (([myInFlightImageOperations containsObject:imagePath]) || ([myProcessingImages containsObject:imagePath]));
		
		if (!alreadyQueued)
		{
			[myInFlightImageOperations addObject:imagePath];
			if (myThreadCount < [NSProcessInfo numberOfProcessors])
			{
				myThreadCount++;
				[NSThread detachNewThreadSelector:@selector(backgroundLoad)
										 toTarget:self
									   withObject:nil];
			}
		}
		else
		{
			//lets move it to the end of the queue so we get done next
			[myInFlightImageOperations removeObject:imagePath];
			[myInFlightImageOperations addObject:imagePath];
		}
		[myCacheLock unlock];
		img = nil; //return nil so the image view draws a bezierpath
	}
	return img;
}

- (void)photoView:(MUPhotoView *)view didSetSelectionIndexes:(NSIndexSet *)indexes
{
	[mySelection removeAllIndexes];
	[mySelection addIndexes:indexes];
	
	NSArray *selection = [self selectedRecords];
	NSEvent *evt = [NSApp currentEvent];
	NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:selection, @"records", evt, @"event", nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:iMediaBrowserSelectionDidChangeNotification
														object:self
													  userInfo:d];
}

- (void)photoView:(MUPhotoView *)view doubleClickOnPhotoAtIndex:(unsigned)index withFrame:(NSRect)frame
{
	NSArray *selection = [self selectedRecords];
	NSEvent *evt = [NSApp currentEvent];
	NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:selection, @"records", evt, @"event", nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:iMediaBrowserSelectionDidChangeNotification
														object:self
													  userInfo:d];
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
	[self writeItems:items fromAlbum:[[NSBundle bundleForClass:[iMBPhotosController class]] localizedStringForKey:@"Selection" value:@"" table:nil] toPasteboard:pboard];
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

#pragma mark -
#pragma mark Sample Incoming drag code

#if SAMPLE_INCOMING_DRAG

#warning -- SAMPLE_INCOMING_DRAG is enabled

@interface NSObject (iMediaHack)
- (id)observedObject;
@end

@implementation iMBPhotosController (SampleIncomingDragging)
- (NSArray*)fineTunePlaylistDragTypes:(NSArray *)defaultTypes
{
	NSMutableArray* result = [NSMutableArray arrayWithObject:NSTIFFPboardType];
	[result addObjectsFromArray:defaultTypes];
	return result;
}


- (NSDragOperation)playlistOutlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)index tryDefaultHandling:(BOOL*)tryDefault
{
	NSDragOperation result = NSDragOperationNone;
	*tryDefault = YES;
	NSPasteboard* pboard = [info draggingPasteboard];
	if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSTIFFPboardType]])
	{
		if (index == NSOutlineViewDropOnItemIndex) // We don't allow inter-item drags
		{
			iMBLibraryNode* node = [item observedObject];
			if (node) // You would also want to check that the node is able to receive the drop here
			{
				result = NSDragOperationCopy;
				*tryDefault = NO;
			}
			else
				; // It must be a drop to the whole view
		}
	}
	return result;
}

- (BOOL)importPasteboard:(NSPasteboard*)pboard intoLibraryNode:(iMBLibraryNode*)node
{ // Your real importing code would go here
	return YES;
}

- (BOOL)playlistOutlineView:(NSOutlineView *)outlineView
				 acceptDrop:(id <NSDraggingInfo>)info
					   item:(id)item
				 childIndex:(int)index
		 tryDefaultHandling:(BOOL*)tryDefault
{
	BOOL result = NO;
	*tryDefault = YES;
	
	NSPasteboard* pboard = [info draggingPasteboard];
	if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSTIFFPboardType]])
	{
		*tryDefault = NO;
		result = [self importPasteboard:pboard intoLibraryNode:[item observedObject]];
	}
	
	return result;
}

// Support for dragging directly into the photoview
- (NSDragOperation)photoView:(MUPhotoView *)view draggingEntered:(id <NSDraggingInfo>)sender
{
	NSArray* selectedNodes = [[self controller] selectedObjects];
	if ([selectedNodes count] != 1)
		return NSDragOperationNone;
		
	NSPasteboard* pboard = [sender draggingPasteboard];
	if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSTIFFPboardType]])
		return NSDragOperationCopy;
	
	return NSDragOperationNone;
}


- (BOOL)photoView:(MUPhotoView *)view performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard* pboard = [sender draggingPasteboard];
	
	NSArray* selectedLibraryNodes = [[self controller] selectedObjects];
	if ([selectedLibraryNodes count] != 1)
		return NO;
	
	iMBLibraryNode* node = [selectedLibraryNodes objectAtIndex:0];
	
	return [self importPasteboard:pboard intoLibraryNode:node];
}


@end
#endif SAMPLE_INCOMING_DRAG