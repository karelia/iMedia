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

@interface QTMovie (QTMoviePrivateInTigerButPublicInLeopard)
- (void)setIdling:(BOOL)state;
@end

static NSImage *_placeholder = nil;

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
        
		if (!_placeholder)
		{
			NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"placeholder" ofType:@"png"];
			_placeholder = [[NSImage alloc] initWithContentsOfFile:path];
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

- (void)backgroundLoadOfInFlightImage:(id)unused
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	// remove ourselves out of the queue
	
	OSErr err = EnterMoviesOnThread(0);	// we will be using QuickTime on the current thread.  See TN2125
	if (noErr != err) NSLog(@"Error entering movies on thread");
	
	[myCacheLock lock];
	NSString *imagePath = [[myInFlightImageOperations lastObject] retain];
	if (imagePath)
	{
		[myInFlightImageOperations removeObject:imagePath];
		[myProcessingImages addObject:imagePath];
	}
	[myCacheLock unlock];
	
	NSImage *img;
	
	while (imagePath)
	{
		NSMutableDictionary *rec = (NSMutableDictionary *)[self recordForPath:imagePath];
		
		// Look up thumbnail image, I assume from an iPhoto movie record
		NSString *thumbPath = [rec objectForKey:@"ThumbPath"];
		
		if (thumbPath)
		{
			img = [[NSImage alloc] initByReferencingFile:thumbPath];
		}
		else
		{
			@try {
				QTMovie *movie = [rec objectForKey:@"qtmovie"];

				(void)AttachMovieToCurrentThread([movie quickTimeMovie]);	// get access to movie from this thread.  Don't care if it succeeded or not
            
				if ([movie respondsToSelector:@selector(setIdling:)])
					[movie setIdling:NO];
				
				if ((!movie /* ???? && [error code] == -2126 */) || [movie isDRMProtected])
				{
					NSString *drmIcon = [[NSBundle bundleForClass:[self class]] pathForResource:@"drm_movie" ofType:@"png"];
					img = [[NSImage alloc] initWithContentsOfFile:drmIcon];
				}
				else
				{
                    img = [[movie betterPosterImage] retain];
				}
				
			} 
			@catch (NSException *ex) {
				NSLog(@"Failed to load movie: %@", imagePath);
			}
			@finally {
				// We would normally have to DetachMovieFromCurrentThread but we're done with the movie now!
				[rec removeObjectForKey:@"qtmovie"];
			}
		}
		// Valid movie but no image -- load file icon.
		if (!img || NSEqualSizes([img size], NSZeroSize))
		{
			img = [[[NSWorkspace sharedWorkspace] iconForFile:[rec objectForKey:@"ImagePath"]] retain];
			[img setScalesWhenResized:YES];
			[img setSize:NSMakeSize(128,128)];
		}
		
		[myCacheLock lock];
        [myCache setObject:img forKey:imagePath];
        [img release];
		
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
	
	err = ExitMoviesOnThread();	// balance EnterMoviesOnThread
	if (noErr != err) NSLog(@"Error entering movies on thread");

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

- (NSString *)photoView:(MUPhotoView *)view titleForPhotoAtIndex:(unsigned)index
{
	if ([[self browser] showsFilenamesInPhotoBasedBrowsers])
        return [self photoView:view captionForPhotoAtIndex:index];
    
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
            QTMovie *mov = [QTMovie movieWithAttributes: [NSDictionary dictionaryWithObjectsAndKeys:
                [QTDataReference dataReferenceWithReferenceToFile:imagePath], QTMovieDataReferenceAttribute,
                [NSNumber numberWithBool:NO], QTMovieAskUnresolvedDataRefsAttribute, nil] 
                                                  error:&movieError];
            
            if (mov)	// make sure we really have a movie -- in some cases, canInitWithFile returns YES but we still get nil
            {
                // do a background thread load if we have a spare processor, and if this movie is thread-safe
                unsigned int maxThreadCount = [NSProcessInfo numberOfProcessors] - 1;
                maxThreadCount = MAX(maxThreadCount, 1);    // Allow at least 1 background thread
                if (myThreadCount < maxThreadCount
                    &&
                    noErr == DetachMovieFromCurrentThread([mov quickTimeMovie]) )	// -2098 = componentNotThreadSafeErr
                {
                    [myCacheLock lock];
                    [rec setObject:mov forKey:@"qtmovie"];
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
                    NSImage *img = [mov betterPosterImage];
                    
                    if (img)
                    {
                        [myCacheLock lock];
                        [myCache setObject:img forKey:imagePath];
                        [myCacheLock unlock];
                        [oPhotoView setNeedsDisplay:YES];
                    }
                }
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
	NSString *imagePath = [rec objectForKey:@"Preview"];
	[myCacheLock lock];
	NSImage *img = [myCache objectForKey:imagePath];		// preview image is keyed by the path of the preview
	[myCacheLock unlock];
		
	if (!img)	// need to generate
    {
        [myImageRecordsToLoad addObject:rec];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startLoadingOneMovie:) object:self];
        [self performSelector:@selector(startLoadingOneMovie:) withObject:self afterDelay:0.001f inModes:[NSArray arrayWithObjects:NSDefaultRunLoopMode,NSModalPanelRunLoopMode,
            NSEventTrackingRunLoopMode,nil]];
        
        // Use a placeholder for now
        img = [[NSWorkspace sharedWorkspace] iconForFile:imagePath];
        [img setScalesWhenResized:YES];
        [img setSize:NSMakeSize(128,128)];
        [myCache setObject:img forKey:imagePath];
	}
	return img;
}

#warning -- check for movie leaks -- Tim's diagnostic output gave me some warnings
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
	if (index < [myImages count])
	{
		movieIndex = index;
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
		NSString *path = [[myImages objectAtIndex:index] objectForKey:@"ImagePath"];
		
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
	}
}

@end
