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

@interface iMBPhotosController (PrivateAPI)
- (NSString *)iconNameForPlaylist:(NSString*)name;
@end

static NSImage *_placeholder = nil;
static NSImage *_missing = nil;

@implementation iMBPhotosController

- (id) initWithPlaylistController:(NSTreeController*)ctrl
{
	if (self = [super initWithPlaylistController:ctrl]) {
		mySelection = [[NSMutableIndexSet alloc] init];
		myFilteredImages = [[NSMutableArray alloc] init];
		myCache = [[NSMutableDictionary dictionary] retain];
		myCacheLock = [[NSLock alloc] init];
		myInFlightImageOperations = [[NSMutableArray array] retain];
		
		if (!_placeholder)
		{
			NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"placeholder" ofType:@"png"];
			_placeholder = [[NSImage alloc] initWithContentsOfFile:path];
			path = [[NSBundle bundleForClass:[self class]] pathForResource:@"missing_image" ofType:@"png"];
			_missing = [[NSImage alloc] initWithContentsOfFile:path];
		}
		
		[NSBundle loadNibNamed:[self nibName] owner:self];
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
	
	[super dealloc];
}

- (void)awakeFromNib
{
	[oPhotoView setDelegate:self];
	
	[oPhotoView setPhotoHorizontalSpacing:15];
	[oPhotoView setPhotoVerticalSpacing:15];
	[oPhotoView setPhotoSize:75];
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
	[myCache removeAllObjects];
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
#pragma mark Threaded Image Loading

- (void)backgroundLoadOfImage:(NSDictionary *)rec
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// remove ourselves out of the queue
	[myCacheLock lock];
	[myInFlightImageOperations removeObject:rec];
	[myCacheLock unlock];
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *thumbPath;
	NSString *imagePath;
	NSImage *img;
	NSDictionary *fullResAttribs;
	 
	while (rec)
	{
		thumbPath = [rec objectForKey:@"ThumbPath"];
		imagePath = [rec objectForKey:@"ImagePath"];
		
		if (thumbPath)
		{
			img = [[NSImage alloc] initByReferencingFile:thumbPath];
		}
		else
		{
			fullResAttribs = [fm fileAttributesAtPath:imagePath traverseLink:YES];
			if ([[fullResAttribs objectForKey:NSFileSize] unsignedLongLongValue] < 1048576) // 1MB
			{
				img = [[NSImage alloc] initWithContentsOfFile:imagePath];
			}
			else //we have to gen a thumb from the full res one
			{
				NSString *tmpFile = [NSString stringWithFormat:@"/tmp/%@.jpg", [NSString uuid]];
				NSTask *sips = [[NSTask alloc] init];
				[sips setLaunchPath:@"/usr/bin/sips"];
				[sips setArguments:[NSArray arrayWithObjects:@"-Z", @"256", imagePath, @"--out", tmpFile, nil]];
				NSFileHandle *output = [NSFileHandle fileHandleWithNullDevice];
				[sips setStandardError:output];
				[sips setStandardOutput:output];
				
				[sips launch];
				[sips waitUntilExit];
				
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
		
		// get the last object in the queue because we would have scrolled and what is at the start won't be necessarily be what is displayed.
		[myCacheLock lock];
		[myCache setObject:img forKey:imagePath];
		[img release];
		rec = [myInFlightImageOperations lastObject];
		if (rec)
		{
			[myInFlightImageOperations removeObject:rec];
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
	NSImage *img = [myCache objectForKey:[rec objectForKey:@"ImagePath"]];
	[myCacheLock unlock];
	
	if (!img) img = [rec objectForKey:@"CachedThumb"];
	
	if (!img)
	{
		// background load the image
		[myCacheLock lock];
		BOOL needsToSpawnThread = ![myInFlightImageOperations containsObject:rec];
		[myCacheLock unlock];
		
		if (needsToSpawnThread)
		{
			[myCacheLock lock];
			[myInFlightImageOperations addObject:rec];
			[myCacheLock unlock];
			if (myThreadCount < 6)
			{
				myThreadCount++;
				[NSThread detachNewThreadSelector:@selector(backgroundLoadOfImage:)
										 toTarget:self
									   withObject:rec];
			}
		}
		else
		{
			//lets move it to the end of the queue so we get done next
			[myCacheLock lock];
			[myInFlightImageOperations removeObject:rec];
			[myInFlightImageOperations addObject:rec];
			[myCacheLock unlock];
		}
		
		// return the place holder image
		img = _placeholder;
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
