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

#import "iMBMoviesController.h"
#import <QTKit/QTKit.h>
#import "iMediaBrowser.h"
#import "iMBLibraryNode.h"
#import "iMedia.h"
#import "MUPhotoView.h"

@interface iMBMoviesController (PrivateAPI)
- (NSString *)iconNameForPlaylist:(NSString*)name;
@end

static NSImage *_missing = nil;
static NSImage *_placeholder = nil;

@implementation iMBMoviesController

+ (void)initialize
{
	[iMBMoviesController setKeys:[NSArray arrayWithObject:@"images"] triggerChangeNotificationsForDependentKey:@"imageCount"];
}

- (id)initWithPlaylistController:(NSTreeController*)ctrl
{
	if (self = [super initWithPlaylistController:ctrl]) {
		mySelection = [[NSMutableIndexSet alloc] init];
		myFilteredImages = [[NSMutableArray alloc] init];
		myCache = [[NSMutableDictionary dictionary] retain];
		myInFlightImageOperations = [[NSMutableArray alloc] init];
		myProcessingImages = [[NSMutableSet set] retain];
		myCacheLock = [[NSLock alloc] init];
		
		if (!_placeholder)
		{
			NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"placeholder" ofType:@"png"];
			_placeholder = [[NSImage alloc] initWithContentsOfFile:path];
			path = [[NSBundle bundleForClass:[self class]] pathForResource:@"missing_image" ofType:@"png"];
			_missing = [[NSImage alloc] initWithContentsOfFile:path];
		}
		
		[NSBundle loadNibNamed:@"Movies" owner:self];
	}
	return self;
}

- (void)dealloc
{
	[previewMovieView release];
	[mySelection release];
	[myImages release];
	[myFilteredImages release];
	[mySearchString release];
	[myCache release];
	[myProcessingImages release];
	[myInFlightImageOperations release];
	[myCacheLock release];
	
	[super dealloc];
}

- (void)awakeFromNib
{
	[oPhotoView setDelegate:self];
	[oSlider setFloatValue:[oPhotoView photoSize]];	// initialize.  Changes are put into defaults.
	[oPhotoView setPhotoHorizontalSpacing:15];
	[oPhotoView setPhotoVerticalSpacing:15];
}

- (IBAction)play:(id)sender
{
	[previewMovieView play:sender];
}

- (void)viewResized:(NSNotification *)n
{
	NSRect r = [oPhotoView photoRectForIndex:movieIndex];
	[previewMovieView setFrame:r];
	[previewMovieView play:self];
}

- (void)refilter
{
	[self willChangeValueForKey:@"images"];
	[mySelection removeAllIndexes];
	[myFilteredImages removeAllObjects];
	
	if ([mySearchString length] == 0) return;
	
	iMBLibraryNode *selectedNode = [[[self controller] selectedObjects] lastObject];
	
	[myFilteredImages addObjectsFromArray:[selectedNode searchAttribute:@"Movies" withKeys:[NSArray arrayWithObjects:@"Caption", @"ImagePath", nil] matching:mySearchString]];
	
	[self didChangeValueForKey:@"images"];
}

- (IBAction)search:(id)sender
{
	[mySearchString autorelease];
	mySearchString = [[sender stringValue] copy];
	
	[self refilter];
	[oPhotoView setNeedsDisplay:YES];
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
#pragma mark Media Browser Protocol

- (void)willActivate
{
	[super willActivate];
	[self bind:@"images" 
	  toObject:[self controller] 
		 withKeyPath:@"selection.Movies" 
	   options:nil];
	[[oPhotoView window] makeFirstResponder:oPhotoView];
}

- (void)didDeactivate
{
	[self unbind:@"images"];
	[previewMovieView pause:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[previewMovieView removeFromSuperview];
}

static NSImage *_toolbarIcon = nil;

- (NSImage*)toolbarIcon
{
	if(_toolbarIcon == nil)
	{
		// Try to use iMovie, or older iMovie, or quicktime player for movies.
		NSString *identifier = @"com.apple.iMovie";
		NSString *path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:identifier];
		if (nil == path)
		{
			identifier = @"com.apple.iMovie3";
			path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:identifier];
		}
		if (nil == path)
		{
			identifier = @"com.apple.quicktimeplayer";
		}
		_toolbarIcon = [[[NSWorkspace sharedWorkspace] iconForAppWithBundleIdentifier:identifier] retain];
		[_toolbarIcon setScalesWhenResized:YES];
		[_toolbarIcon setSize:NSMakeSize(32,32)];
	}
	return _toolbarIcon;
}

- (NSString *)mediaType
{
	return @"movies";
}

- (NSString *)name
{
	return LocalizedStringInThisBundle(@"Movies", @"Name of Data Type");
}

- (NSString *)iconNameForPlaylist:(NSString*)name
{
	return @"MBQuicktime.png";
}

- (void)writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
	NSMutableArray *types = [NSMutableArray array]; // OLD BEHAVIOR: arrayWithArray:[pboard types]];
	[types addObjectsFromArray:[NSPasteboard fileAndURLTypes]];
	[pboard declareTypes:types owner:nil];
	
	NSEnumerator *e = [items objectEnumerator];
	NSDictionary *cur;
	NSMutableArray *files = [NSMutableArray array];
	NSMutableArray *names = [NSMutableArray array];
	
	while (cur = [e nextObject])
	{
		[files addObject:[cur objectForKey:@"ImagePath"]];
		[names addObject:[cur objectForKey:@"Caption"]];
	}
	[pboard writeURLs:nil files:files names:names];
}

- (void)writePlaylist:(iMBLibraryNode *)playlist toPasteboard:(NSPasteboard *)pboard
{
	[self writeItems:[playlist valueForKey:@"Movies"] toPasteboard:pboard];
}

#pragma mark -
#pragma mark Threaded Image Loading

- (NSDictionary *)recordForPath:(NSString *)path
{
	NSEnumerator *e = [myImages objectEnumerator];
	NSDictionary *cur;
	
	while (cur = [e nextObject])
	{
		if ([[cur objectForKey:@"Preview"] isEqualToString:path])
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
	
	NSString *thumbPath;
	NSImage *img;
	NSDictionary *fullResAttribs;
	NSMutableDictionary *rec;
	
	while (imagePath)
	{
		rec = (NSMutableDictionary *)[self recordForPath:imagePath];		
		thumbPath = [rec objectForKey:@"ThumbPath"];
		
		if (thumbPath)
		{
			img = [[NSImage alloc] initByReferencingFile:thumbPath];
		}
		else
		{
			NSError *error = nil;
			QTMovie *movie;
			
			@try {
				movie = [rec objectForKey:@"qtmovie"];
				
				if ((!movie && [error code] == -2126) || [movie isDRMProtected])
				{
					NSString *drmIcon = [[NSBundle bundleForClass:[self class]] pathForResource:@"drm_movie" ofType:@"png"];
					img = [[NSImage alloc] initWithContentsOfFile:drmIcon];
				}
				else
				{
					img = [[movie posterImage] retain];
				}
			} 
			@catch (NSException *ex) {
				NSLog(@"Failed to load movie: %@", imagePath);
			}
			@finally {
				[rec removeObjectForKey:@"qtmovie"];
			}
		}
		
		if (!img) // we have a bad egg... need to display a ? icon
		{
			img = [_missing retain];
		}
		
		if (NSEqualSizes([img size], NSZeroSize))
		{
			img = [[[NSWorkspace sharedWorkspace] iconForFile:[rec objectForKey:@"ImagePath"]] retain];
			[img setScalesWhenResized:YES];
			[img setSize:NSMakeSize(128,128)];
		}
		
		[myCacheLock lock];
		if (![myCache objectForKey:imagePath])
		{
			[myCache setObject:img forKey:imagePath];
			[img autorelease];
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
	[self refilter];
	//reset the scroll position
	[previewMovieView removeFromSuperview];
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
	NSMutableDictionary *rec;
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
	NSString *imagePath = [rec objectForKey:@"Preview"];
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
			QTDataReference *ref = [QTDataReference dataReferenceWithReferenceToFile:imagePath];
			QTMovie *mov = [QTMovie movieWithDataReference:ref error:nil];
			[rec setObject:mov forKey:@"qtmovie"];
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
	
	NSMutableArray *types = [NSMutableArray array]; 
	[types addObjectsFromArray:[NSPasteboard fileAndURLTypes]];
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
		}
	}
				
	[pboard writeURLs:nil files:fileList names:captions];	
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

- (void)photoView:(MUPhotoView *)view doubleClickOnPhotoAtIndex:(unsigned)index withFrame:(NSRect)frame
{
	movieIndex = index;
	if (!previewMovieView)
	{
		previewMovieView = [[QTMovieView alloc] initWithFrame:frame];
		[previewMovieView setControllerVisible:NO];
		[previewMovieView setShowsResizeIndicator:NO];
		[previewMovieView setPreservesAspectRatio:YES];
	}
	[previewMovieView setFrame:frame];
	NSString *path = [[myImages objectAtIndex:index] objectForKey:@"Preview"];
	
	NSError *error = nil;
	QTDataReference *ref = [QTDataReference dataReferenceWithReferenceToFile:path];
	QTMovie *movie = [[[QTMovie alloc] initWithAttributes:
		[NSDictionary dictionaryWithObjectsAndKeys: 
			ref, QTMovieDataReferenceAttribute,
			[NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute,
			nil] error:&error] autorelease];
	if (!movie && [error code] == -2126)
	{
		//NSLog(@"Failed to load DRMd QTMovie: %@", error);
		[previewMovieView removeFromSuperview];
		[previewMovieView setMovie:nil];
	}
	else
	{
		[previewMovieView setMovie:movie];
		if (![previewMovieView superview])
		{
			[oPhotoView addSubview:previewMovieView];
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(viewResized:)
														 name:NSViewFrameDidChangeNotification
													   object:oPhotoView];
		}
	}
}

@end
