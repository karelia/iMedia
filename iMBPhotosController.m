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
		
		if (!_placeholder)
		{
			NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"placeholder" ofType:@"png"];
			_placeholder = [[NSImage alloc] initWithContentsOfFile:path];
			path = [[NSBundle bundleForClass:[self class]] pathForResource:@"missing_image" ofType:@"png"];
			_missing = [[NSImage alloc] initWithContentsOfFile:path];
		}
		
		[NSBundle loadNibNamed:@"iPhoto" owner:self];
	}
	return self;
}

- (void)dealloc
{
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
	
	iMBLibraryNode *selectedNode = [[[self controller] selectedObjects] lastObject];
	
	[myFilteredImages addObjectsFromArray:[selectedNode searchAttribute:@"Images" withKeys:[NSArray arrayWithObjects:@"Caption", @"ImagePath", nil] matching:mySearchString]];
	
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
	[myCache removeAllObjects];
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
	[pboard declareTypes:types owner:nil];
	
	NSEnumerator *e = [items objectEnumerator];
	NSDictionary *rec;
	i = 1;
	while (rec = [e nextObject]) {
		[files addObject:[rec objectForKey:@"ImagePath"]];
		[captions addObject:[rec objectForKey:@"Caption"]];
		NSMutableDictionary *copy = [rec mutableCopy];
		[copy removeObjectForKey:@"CachedThumb"];
		[images setObject:copy forKey:[NSNumber numberWithInt:i]];
		[copy release];
		i++;
		//[iphotoData setObject:rec forKey:cur]; //the key should be irrelavant
	}
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

- (void)backgroundLoadOfImage:(NSString *)imagePath
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// remove ourselves out of the queue
	[myCacheLock lock];
	imagePath = [[myInFlightImageOperations lastObject] retain];
	if (imagePath)
	{
		[myInFlightImageOperations removeObject:imagePath];
		[myProcessingImages addObject:imagePath];
	}
	[myCacheLock unlock];
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *thumbPath;
	NSImage *img;
	NSDictionary *fullResAttribs;
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
			if (useEpeg && 
				([[[imagePath pathExtension] lowercaseString] isEqualToString:@"jpg"] ||
				 [[[imagePath pathExtension] lowercaseString] isEqualToString:@"jpeg"]))
			{
				Class epeg = NSClassFromString(@"EpegWrapper");
				if (epeg)
				{
					img = [[epeg imageWithPath:imagePath boundingBox:NSMakeSize(256,256)] retain];
				}
			}
			
			if (!img)//we have to gen a thumb from the full res one
			{
				NSString *tmpFile = [NSString stringWithFormat:@"/tmp/%@.jpg", [NSString uuid]];
				NSTask *sips = [[NSTask alloc] init];
				[sips setLaunchPath:@"/usr/bin/sips"];
				[sips setArguments:[NSArray arrayWithObjects:@"-Z", @"256", imagePath, @"--out", tmpFile, nil]];
				NSFileHandle *output = [NSFileHandle fileHandleWithNullDevice];
				[sips setStandardError:output];
				[sips setStandardOutput:output];
				
				NSLog(@"sips %@", imagePath);
				[sips launch];
				[sips waitUntilExit];
				NSLog(@"DONE %@", imagePath);
				
				img = [[NSImage alloc] initWithContentsOfFile:tmpFile];
				[img size];
				
				[sips release];
				[fm removeFileAtPath:tmpFile handler:nil];	
			}
		}
		
		// if still no image... use high res
		if (!img)
		{
			img = [[NSImage alloc] initWithContentsOfFile:imagePath];
		}
		
		if (!img) // we have a bad egg... need to display a ? icon
		{
			img = [_missing retain];
		}
		
		[myCacheLock lock];
		if (![myCache objectForKey:imagePath])
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
				[NSThread detachNewThreadSelector:@selector(backgroundLoadOfImage:)
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
	[self writeItems:items fromAlbum:LocalizedStringInThisBundle(@"Selection", @"Photo selection for pasteboard album name") toPasteboard:pboard];
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
