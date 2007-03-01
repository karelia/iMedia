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
 
 iMedia Browser Home Page: <http://imedia.karelia.com/>
 
 Please send fixes to <imedia@lists.karelia.com>

*/

#import "iMBMoviesController.h"
#import <QTKit/QTKit.h>
#import "iMediaBrowser.h"
#import "iMBLibraryNode.h"
#import "iMedia.h"
#import "MUPhotoView.h"
#import "NSURLCache+iMedia.h"

#define MAX_POSTER_SIZE (NSMakeSize(240, 180))	// our thumbnail view maxes out at 240.

@interface iMBMoviesController (PrivateAPI)
- (NSString *)iconNameForPlaylist:(NSString*)name;
@end

@interface QTMovie (QTMoviePrivateInTigerButPublicInLeopard)
- (void)setIdling:(BOOL)state;
@end

@implementation iMBMoviesController

+ (void)initialize
{
	[iMBMoviesController setKeys:[NSArray arrayWithObject:@"images"] triggerChangeNotificationsForDependentKey:@"imageCount"];
}

- (id)initWithPlaylistController:(NSTreeController*)ctrl
{
	if (self = [super initWithPlaylistController:ctrl]) {
		mySelection = [[NSMutableIndexSet allocWithZone:[self zone]] init];
		myFilteredImages = [[NSMutableArray allocWithZone:[self zone]] init];
		myCache = [[NSMutableDictionary dictionary] retain];
		myInFlightImageOperations = [[NSMutableArray allocWithZone:[self zone]] init];
        myImageRecordsToLoad = [[NSMutableArray allocWithZone:[self zone]] init];
		myProcessingImages = [[NSMutableSet set] retain];
		myCacheLock = [[NSLock allocWithZone:[self zone]] init];
        		
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
	[myImageRecordsToLoad release];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
    
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
			LocalizedStringInThisBundle(@"%{value1}@ movies", @"Formatting: tracks of audio -- song or sound effect")
									forKey:@"NSDisplayPattern"];
	
	[counterField bind:@"displayPatternValue1"
			  toObject:self
		   withKeyPath:@"imageCount"
			   options:optionsDict];
// It would be nice to properly show single/plural form; maybe also indicate # selected if there is a selection.  How to do with bindings?
}

- (IBAction)play:(id)sender
{
	[previewMovieView play:sender];
}

- (void)viewResized:(NSNotification *)n
{
	NSRect r = [oPhotoView photoRectForIndex:movieIndex];
	[previewMovieView setFrame:r];
}

- (void)refilter
{
	[self willChangeValueForKey:@"images"];
	[mySelection removeAllIndexes];
	[myFilteredImages removeAllObjects];
	[self postSelectionChangeNotification:[self selectedItems]];

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

// Store the image that is from the given path.
- (void) saveImageForPath:(NSString *)imagePath
{
	[myCacheLock lock];
	NSImage *anImage = [myCache objectForKey:imagePath];		// preview image is keyed by the path of the preview
	[myCacheLock unlock];

    NSAssert1 (anImage != nil, @"Found no cached image for '%@'", imagePath);
    
	NSData *data = [anImage TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0];    
	if (data)
	{
		[[NSURLCache sharedURLCache] cacheData:data forPath:[imagePath stringByAppendingPathExtension:@"tiff"]];
        
        // Images are sometimes drawn upside down after saving. I don't know why, but as the saved image is correct we can create
        // a new one that works. Does someone know why this is?
        anImage = [[NSImage allocWithZone:[self zone]] initWithData:data];
        if (anImage)
        {
            [anImage setDataRetained:YES];
            [anImage setScalesWhenResized:YES];
            [myCacheLock lock];
            [myCache setObject:anImage forKey:imagePath];
            [anImage release];
            [myCacheLock unlock];
        }
	}
}

- (NSArray*) selectedItems
{
	NSArray* records = nil;
	if ([mySearchString length] > 0)
	{
		records = [myFilteredImages objectsAtIndexes:mySelection];
	}
	else
	{
		records = [myImages objectsAtIndexes:mySelection];
	}
	return records;
}

#pragma mark -
#pragma mark Media Browser Protocol

- (Class)parserForFolderDrop
{
	return NSClassFromString(@"iMBMoviesFolder");
}

- (void)refresh
{
	[super refresh];
	[self unbind:@"images"];
	[previewMovieView pause:self];
	[previewMovieView removeFromSuperview];
	[self bind:@"images" 
	  toObject:[self controller] 
		 withKeyPath:@"selection.Movies" 
	   options:nil];
}

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
   [types addObject:iMBNativePasteboardFlavor]; // Native iMB Data
	
	NSEnumerator *e = [items objectEnumerator];
	NSDictionary *cur;
	NSMutableArray *files = [NSMutableArray array];
	NSMutableArray *names = [NSMutableArray array];
	
   NSMutableArray* nativeDataArray = [NSMutableArray arrayWithCapacity:[items count]];
	while (cur = [e nextObject])
	{
      [nativeDataArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:
         [cur objectForKey:@"ImagePath"], @"ImagePath",
         [cur objectForKey:@"Caption"], @"Caption",
         nil]];
         
		[files addObject:[cur objectForKey:@"ImagePath"]];
		[names addObject:[cur objectForKey:@"Caption"]];
	}
   NSDictionary* nativeData = [NSDictionary dictionaryWithObjectsAndKeys:
                                             [self className], iMBControllerClassName,
                                             nativeDataArray, iMBNativeDataArray,
                                             nil];
   [pboard setData:[NSArchiver archivedDataWithRootObject:nativeData] forType:iMBNativePasteboardFlavor]; // Native iMB Data
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

- (NSImage *) getPosterImageOrPlaceholderFromMovie:(QTMovie *)movie
{
	NSImage *img = nil;
	bool hasVideo = NO;
	
	if (movie)
	{
		NSDictionary *attr = [movie movieAttributes];
		NSValue *theSizeValue = [attr objectForKey:QTMovieNaturalSizeAttribute];
		NSSize size = [theSizeValue sizeValue];
		hasVideo = !NSEqualSizes(size,NSZeroSize);
	}
	if (!movie || !hasVideo)
	{
		img = (NSImage *)[NSNull null];		// don't try to load again
	}
	else if ((!movie /* ???? && [error code] == -2126 */) || [movie isDRMProtected])
	{
		NSString *drmIcon = [[NSBundle bundleForClass:[self class]] pathForResource:@"drm_movie" ofType:@"png"];
		img = [[[NSImage alloc] initWithContentsOfFile:drmIcon] autorelease];
	}
	else
	{
		img = [movie betterPosterImageWithMaxSize:MAX_POSTER_SIZE];
	}
	return img;
}

- (void)backgroundLoadOfInFlightImage:(id)unused
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	// remove ourselves out of the queue
		
	[myCacheLock lock];
	NSString *imagePath = [[myInFlightImageOperations lastObject] retain];
	if (imagePath)
	{
		[myInFlightImageOperations removeObject:imagePath];
		[myProcessingImages addObject:imagePath];
	}
	[myCacheLock unlock];
		
	while (imagePath)
	{
		NSMutableDictionary *rec = (NSMutableDictionary *)[self recordForPath:imagePath];
		
        @try {
            OSErr err = EnterMoviesOnThread(0);	// we will be using QuickTime on the current thread.  See TN2125
            if (noErr != err) NSLog(@"Error entering movies on thread");
            
            QTMovie *movie = [rec objectForKey:@"qtmovie"];
            
            err = AttachMovieToCurrentThread([movie quickTimeMovie]);	// get access to movie from this thread.  Don't care if it succeeded or not
            if (noErr != err) NSLog(@"Error attaching movie to current thread %d", err);
			
			NSImage *img = [self getPosterImageOrPlaceholderFromMovie:movie];
			
            if (img && (img != (NSImage *)[NSNull null]) )
				// Note: NSNull means no thumbnail can be generated.  This is NOT cached, meaning that each time we run the app,
				// it will query the movie again, not finding it in the cache.  I suppose we could optimize that by caching a
				// placeholder so that the file is not queried.
            {
                [myCacheLock lock];
                [myCache setObject:img forKey:imagePath];
                [myCacheLock unlock];
				if (img != (NSImage *)[NSNull null])
				{
					[self performSelectorOnMainThread:@selector(saveImageForPath:) withObject:imagePath waitUntilDone:NO];
				}
            }
        } 
        @catch (NSException *ex) {
            NSLog(@"Failed to load movie: %@", imagePath);
        }
        @finally {
            QTMovie *movie = [rec objectForKey:@"qtmovie"];
            OSErr err = DetachMovieFromCurrentThread([movie quickTimeMovie]); 	// -2098 = componentNotThreadSafeErr
            if (noErr != err) NSLog(@"Error detaching from background thread");
            
            [rec removeObjectForKey:@"qtmovie"];	// movie is still retained internally
            
            err = ExitMoviesOnThread();	// balance EnterMoviesOnThread
            if (noErr != err) NSLog(@"Error entering movies on thread");
            
        }
		
		[myCacheLock lock];		
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

- (NSString *)photoView:(MUPhotoView *)view titleForPhotoAtIndex:(unsigned)aIndex
{
	if ([[self browser] showsFilenamesInPhotoBasedBrowsers])
        return [self photoView:view captionForPhotoAtIndex:aIndex];
    
	return nil;
}

- (void) startLoadingOneMovie:sender
// This runs asynchronously in the main thread to do the non thread safe work involved when
// loading QuickTime movies. It also spawns off worker threads if possible.
// We do this via a performSelector:afterDelay: to allow the app to respond to events.
{
    NSMutableDictionary *rec = [myImageRecordsToLoad lastObject];
    if (!rec)
        return;
    
	[myCacheLock lock];
	NSString *imagePath = [rec objectForKey:@"Preview"];
    BOOL alreadyQueued = (([myInFlightImageOperations containsObject:imagePath]) || ([myProcessingImages containsObject:imagePath]));
    [myCacheLock unlock];
    
    if (!alreadyQueued)
    {
        if ([QTMovie canInitWithFile:imagePath])
        {
            NSError *movieError = nil;
            QTMovie *movie = [QTMovie movieWithAttributes: [NSDictionary dictionaryWithObjectsAndKeys:
                [QTDataReference dataReferenceWithReferenceToFile:imagePath], QTMovieDataReferenceAttribute,
                [NSNumber numberWithBool:NO], QTMovieAskUnresolvedDataRefsAttribute, nil] 
                                                  error:&movieError];
			            
            if (movie)	// make sure we really have a movie -- in some cases, canInitWithFile returns YES but we still get nil
            {
                if ([movie respondsToSelector:@selector(setIdling:)])
                    [movie setIdling:NO]; // Prevents crash due to missing gworld

                // do a background thread load if we have a spare processor, and if this movie is thread-safe
                unsigned int maxThreadCount = [NSProcessInfo numberOfProcessors] - 1;
                maxThreadCount = MAX(maxThreadCount, (unsigned int)1);    // Allow at least 1 background thread
                if (
#ifdef SINGLETHREADED
					NO &&	// define SINGLETHREADED to test the single-threaded mode
#endif
					myThreadCount < maxThreadCount
                    &&
                    noErr == DetachMovieFromCurrentThread([movie quickTimeMovie]) )	// -2098 = componentNotThreadSafeErr
                {
                    [myCacheLock lock];
                    [rec setObject:movie forKey:@"qtmovie"];
                    [myInFlightImageOperations addObject:imagePath];
                    [myCacheLock unlock];
                    myThreadCount++;
                    [NSThread detachNewThreadSelector:@selector(backgroundLoadOfInFlightImage:)
                                             toTarget:self
                                           withObject:nil];
                } 
                else 
                {
                    // Load movie on the main thread because we can't open on background thread
					NSImage *img = [self getPosterImageOrPlaceholderFromMovie:movie];
					if (img && (img != (NSImage *)[NSNull null]) )
                    {
                        [myCacheLock lock];
                        [myCache setObject:img forKey:imagePath];
                        [myCacheLock unlock];
                        [oPhotoView setNeedsDisplay:YES];
						[self saveImageForPath:imagePath];
                    }
                }
            }
			else
			{
				// Perhaps come up with some indication that this movie isn't really loadable?
				NSLog(@"unable to make a movie from %@", imagePath);
			}
        }
    }
    else
    {
        //lets move it to the end of the queue so we get done next
        [myCacheLock lock];
        [myInFlightImageOperations removeObject:imagePath];
        [myInFlightImageOperations addObject:imagePath];
        [myCacheLock unlock];
    }
    
    [myImageRecordsToLoad removeLastObject];
    if ([myImageRecordsToLoad count] > 0)
    {
        // There is still work to be done so let's continue after a tiny delay
        [self performSelector:_cmd withObject:self afterDelay:0.001f inModes:[NSArray arrayWithObjects:NSDefaultRunLoopMode,NSModalPanelRunLoopMode,
            NSEventTrackingRunLoopMode,nil]];
    }
}

- (NSImage *)photoView:(MUPhotoView *)view photoAtIndex:(unsigned)aIndex
{
	NSMutableDictionary *rec;
	if ([mySearchString length] > 0)
	{
		rec = [myFilteredImages objectAtIndex:aIndex];
	}
	else
	{
		rec = [myImages objectAtIndex:aIndex];
	}
    
	//try the caches
	NSString *imagePath = [rec objectForKey:@"Preview"];
	[myCacheLock lock];
	NSImage *img = [myCache objectForKey:imagePath];		// preview image is keyed by the path of the preview
	[myCacheLock unlock];
	
    if (!img)
    {   // Perhaps there's a ThumbPath
        NSString *thumbPath = [rec objectForKey:@"ThumbPath"];
        if (thumbPath)
        {
            img = [[[NSImage alloc] initByReferencingFile:thumbPath] autorelease];
            // cache in memory now
            [myCacheLock lock];
            [myCache setObject:img forKey:imagePath];
            [myCacheLock unlock];
        }
    }
    
	if (!img)
	{   // look on disk cache
		NSData *data = [[NSURLCache sharedURLCache] cachedDataForPath:[imagePath stringByAppendingPathExtension:@"tiff"]]; // will return nil if not cached
		if (data)
		{
			img = [[[NSImage alloc] initWithData:data] autorelease];
			if (img)
			{
				// cache in memory now --- maybe not needed since the NSURLCache actually caches in memory now!
				[myCacheLock lock];
				[myCache setObject:img forKey:imagePath];
				[myCacheLock unlock];
			}
		}
	}

	if (!img && (img != (NSImage *)[NSNull null]))	// need to generate, but not if NSNull
    {		
        [myImageRecordsToLoad addObject:rec];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startLoadingOneMovie:) object:self];
        [self performSelector:@selector(startLoadingOneMovie:) withObject:self afterDelay:0.001f inModes:[NSArray arrayWithObjects:NSDefaultRunLoopMode,NSModalPanelRunLoopMode,
            NSEventTrackingRunLoopMode,nil]];
        
        // Use a placeholder for now
        img = [[NSWorkspace sharedWorkspace] iconForFile:imagePath];
        [img setScalesWhenResized:YES];
        [img setSize:NSMakeSize(128,128)];
        [myCacheLock lock];
        [myCache setObject:img forKey:imagePath];
        [myCacheLock unlock];
	}
	if (img == (NSImage *)[NSNull null])	img = nil;	// don't return NSNull
	
	return img;
}

- (void)photoView:(MUPhotoView *)view didSetSelectionIndexes:(NSIndexSet *)indexes
{
	[mySelection removeAllIndexes];
	[mySelection addIndexes:indexes];
	[self postSelectionChangeNotification:[self selectedItems]];
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
	NSMutableArray *fileList = [NSMutableArray array];
	NSMutableArray *captions = [NSMutableArray array];
	
	NSMutableArray *types = [NSMutableArray array]; 
	[types addObjectsFromArray:[NSPasteboard fileAndURLTypes]];
	[pboard declareTypes:types owner:nil];
	
	NSDictionary *cur;
	
	unsigned int i;
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

- (NSString *)photoView:(MUPhotoView *)view captionForPhotoAtIndex:(unsigned)aIndex
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

- (void)photoView:(MUPhotoView *)view doubleClickOnPhotoAtIndex:(unsigned)aIndex withFrame:(NSRect)frame
{
	if (aIndex < [myImages count])
	{
		movieIndex = aIndex;
		if (!previewMovieView)
		{
			previewMovieView = [[QTMovieView alloc] initWithFrame:frame];
			[previewMovieView setControllerVisible:NO];
			[previewMovieView setShowsResizeIndicator:NO];
			[previewMovieView setPreservesAspectRatio:YES];
		}
		else
		{
			[previewMovieView pause:self];
		}
		[previewMovieView setFrame:frame];
		NSString *path = [[myImages objectAtIndex:aIndex] objectForKey:@"ImagePath"];
		
		NSError *error = nil;
		QTDataReference *ref = [QTDataReference dataReferenceWithReferenceToFile:path];
		QTMovie *movie = [[[QTMovie alloc] initWithAttributes:
			[NSDictionary dictionaryWithObjectsAndKeys: 
				ref, QTMovieDataReferenceAttribute,
				[NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute,
				nil] error:&error] autorelease];
		if (!movie && [error code] == -2126)	// DRM, I think
		{
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
			
			// now start playing -- but after a delay to prevent a flash-frame of the movie at full size!
			[previewMovieView performSelector:@selector(play:) withObject:self afterDelay:0.0];
		}
		
		[self postSelectionChangeNotification:[self selectedItems]];
	}
}

@end
