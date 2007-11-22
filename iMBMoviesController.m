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
- (NSArray*) selectedItems;
- (NSDictionary *)displayableAttributesOfMovie:(QTMovie *)aMovie;
- (NSString *)imageCountPluralityAdjustedString;
@end

@interface QTMovie (QTMoviePrivateInTigerButPublicInLeopard)
- (void)setIdling:(BOOL)state;
@end

@implementation iMBMoviesController

+ (void)initialize
{
	if ( self == [iMBMoviesController class] ) 
	{
		// Only do some work when not called because one of our subclasses does not implement +initialize
	[iMBMoviesController setKeys:[NSArray arrayWithObject:@"images"] triggerChangeNotificationsForDependentKey:@"imageCount"];
}
}

- (id)initWithPlaylistController:(NSTreeController*)ctrl
{
	if (self = [super initWithPlaylistController:ctrl]) {
		mySelection = [[NSMutableIndexSet allocWithZone:[self zone]] init];
		myFilteredImages = [[NSMutableArray allocWithZone:[self zone]] init];
		myImageCache = [[NSMutableDictionary dictionary] retain];
		myMetaCache = [[NSMutableDictionary dictionary] retain];
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
	[myImageCache release];
	[myMetaCache release];
	[myProcessingImages release];
	[myInFlightImageOperations release];
	[myCacheLock release];
	[myImageRecordsToLoad release];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
    
	[super dealloc];
}

- (void)finalize
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[super finalize];
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
	[NSDictionary dictionaryWithObject:@"%{value1}@ %{value2}@"  
								forKey:NSDisplayPatternBindingOption];
	
	[counterField bind:@"displayPatternValue1"
			  toObject:self
		   withKeyPath:@"imageCount"
			   options:optionsDict];

	[counterField bind:@"displayPatternValue2"
			  toObject:self
		   withKeyPath:@"imageCountPluralityAdjustedString"
			   options:optionsDict];
	// It would be nice to also indicate # selected if there is a selection.  How to do with bindings?
}

- (void)setBrowser:(iMediaBrowser *)browser	// hook up captions prefs now that we have a browser associated with this controller.
{
	[super setBrowser:browser];
	[oPhotoView setShowCaptions:[browser prefersFilenamesInPhotoBasedBrowsers]];
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
	NSImage *anImage = [myImageCache objectForKey:imagePath];		// preview image is keyed by the path of the preview
	NSDictionary *userInfo = [myMetaCache objectForKey:imagePath];		// preview image is keyed by the path of the preview
	[myCacheLock unlock];

    NSAssert1 (anImage != nil, @"Found no cached image for '%@'", imagePath);
    NSAssert1 (userInfo != nil, @"Found no metadata for '%@'", imagePath);
    
	NSData *data = [anImage TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0];    
	if (data)
	{
		[[NSURLCache sharedURLCache] cacheData:data userInfo:userInfo forPath:[imagePath stringByAppendingPathExtension:@"tif"]];
        
        // Images are sometimes drawn upside down after saving. I don't know why, but as the saved image is correct we can create
        // a new one that works. Does someone know why this is?
		// Doing this essentially converts the PICT representation to NSBitmapImageRep.
        anImage = [[NSImage allocWithZone:[self zone]] initWithData:data];
        if (anImage)
        {
            [anImage setDataRetained:YES];
            [anImage setScalesWhenResized:YES];
            [myCacheLock lock];
            [myImageCache setObject:anImage forKey:imagePath];
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

- (NSString *)imageCountPluralityAdjustedString
{
	int count = [[self imageCount] intValue];
	
	return abs(count) != 1 ? LocalizedStringInThisBundle(@"movies", @"plural form for showing how many items there are") :  LocalizedStringInThisBundle(@"movie", @"singular form for showing how many items there are");
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
                [myImageCache setObject:img forKey:imagePath];
				
				[myMetaCache setObject:[self displayableAttributesOfMovie:movie] forKey:imagePath];
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
		
		[oPhotoView performSelectorOnMainThread:@selector(forceRedisplay)
									 withObject:nil
								  waitUntilDone:NO];
	}
	
	myThreadCount--;
	
	[pool release];
}

- (NSDictionary *)displayableAttributesOfMovie:(QTMovie *)aMovie
{
	NSDictionary *attr = [aMovie movieAttributes];
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	
	
	NSArray *keys = [NSArray arrayWithObjects:
		QTMovieDisplayNameAttribute, QTMovieCopyrightAttribute, 
		QTMovieCreationTimeAttribute,
		QTMovieHasDurationAttribute, QTMovieDurationAttribute,
		QTMovieNaturalSizeAttribute, 
		nil];
	NSEnumerator *enumerator = [keys objectEnumerator];
	NSString *key;

	while ((key = [enumerator nextObject]) != nil)
	{
		id value = [attr objectForKey:key];
		if (value && (value != [NSNull null]))
		{
			[result setObject:value forKey:key];
		}
	}
	return [NSDictionary dictionaryWithDictionary:result];
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
		///NSLog(@"startLoadingOneMovie:%@ not already queued", imagePath);
        if ([QTMovie canInitWithFile:imagePath])
        {
			///NSLog(@"startLoadingOneMovie:%@ canInitWithFile", imagePath);

            NSError *movieError = nil;
            QTMovie *movie = [QTMovie movieWithAttributes: [NSDictionary dictionaryWithObjectsAndKeys:
                [QTDataReference dataReferenceWithReferenceToFile:imagePath], QTMovieDataReferenceAttribute,
                [NSNumber numberWithBool:NO], QTMovieAskUnresolvedDataRefsAttribute, nil] 
                                                  error:&movieError];
			            
            if (movie)	// make sure we really have a movie -- in some cases, canInitWithFile returns YES but we still get nil
            {
				///NSLog(@"startLoadingOneMovie:%@ movieWithAttributes", imagePath);

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
                        [myImageCache setObject:img forKey:imagePath];
						[myMetaCache setObject:[self displayableAttributesOfMovie:movie] forKey:imagePath];
                        [myCacheLock unlock];
                        [oPhotoView setNeedsDisplay:YES];
						[self saveImageForPath:imagePath];
                    }
                }
            }
			else
			{
				// Perhaps come up with some indication that this movie isn't really loadable?
				// NSLog(@"unable to make a movie from %@", imagePath);
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
	NSImage *img = [myImageCache objectForKey:imagePath];		// preview image is keyed by the path of the preview
	[myCacheLock unlock];
	
    if (!img)
    {   // Perhaps there's a ThumbPath
        NSString *thumbPath = [rec objectForKey:@"ThumbPath"];
        if (thumbPath)
        {
            img = [[[NSImage alloc] initByReferencingFile:thumbPath] autorelease];
            // cache in memory now
            [myCacheLock lock];
            [myImageCache setObject:img forKey:imagePath];
			// no movie metadata to cache now
            [myCacheLock unlock];
        }
    }
    
	if (!img)
	{   // look on disk cache
		NSDictionary *userInfo = nil;
		NSData *data = [[NSURLCache sharedURLCache] cachedDataForPath:[imagePath stringByAppendingPathExtension:@"tif"]
															 userInfo:&userInfo]; // will return nil if not cached
		if (data)
		{
			img = [[[NSImage alloc] initWithData:data] autorelease];
			if (img)
			{
				// cache in memory now --- maybe not needed since the NSURLCache actually caches in memory now!
				[myCacheLock lock];
				[myImageCache setObject:img forKey:imagePath];
				if (userInfo)
				{
					[myMetaCache setObject:userInfo forKey:imagePath];
				}
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
        [myImageCache setObject:img forKey:imagePath];
		// No movie could be generated, so also no metadata
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

- (NSString *)photoView:(MUPhotoView *)view titleForPhotoAtIndex:(unsigned)aIndex
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

// called in thread 1 so it's safe to open the movie for more info.
// BETTER YET -- PUT THE MOVIE METADATA WITH THE CACHED THUMBNAIL SO WE DON'T HAVE TO OPEN UP MOVIE AS WELL.
- (NSString *)photoView:(MUPhotoView *)view tooltipForPhotoAtIndex:(unsigned)aIndex
{
	NSMutableString *result = [NSMutableString string];
	NSDictionary *rec;
	if ([mySearchString length] > 0)
	{
		rec = [myFilteredImages objectAtIndex:aIndex];
	}
	else
	{
		rec = [myImages objectAtIndex:aIndex];
	}
	
	// GET METADATA, WE MIGHT USE THAT FOR DISPLAY NAME INSTEAD OF "Caption"
	NSDictionary *userInfo = nil;
	NSString *title = [rec objectForKey:@"Caption"];	// default
	NSString *imagePath = [rec objectForKey:@"ImagePath"];
	NSString *imagePathUTI = nil;

	if (imagePath)
	{
		// GET QUICKTIME METADATA
		
		[myCacheLock lock];
		userInfo = [myMetaCache objectForKey:imagePath];		// preview image is keyed by the path of the preview
		[myCacheLock unlock];
		imagePathUTI = [NSString UTIForFileAtPath:imagePath];

	}
	
	// Don't have User Info from cache?  Try to get it from the movie itself
	// TODO: Attributes generated from a movie file for the tooltip are not cached in memory.
	if (!userInfo && [NSString UTI:imagePathUTI conformsToUTI:(NSString *)kUTTypeAudiovisualContent])
	{
		// Get our own User info from the file directly by making a quicktime movie.
		NSError *error = nil;
		
		///NSLog(@"photoView:tooltipForPhotoAtIndex:%@ going to load movie", imagePath);

		QTDataReference *ref = [QTDataReference dataReferenceWithReferenceToFile:imagePath];
		QTMovie *movie = [[[QTMovie alloc] initWithAttributes:
			[NSDictionary dictionaryWithObjectsAndKeys: 
				ref, QTMovieDataReferenceAttribute,
				[NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute,
				nil] error:&error] autorelease];
		if (movie)
		{
			userInfo = [movie movieAttributes];
		}
	}
	
	// Possibly override title by using the metadata from quicktime file
	if (userInfo)
	{
		NSString *displayName = [userInfo objectForKey:QTMovieDisplayNameAttribute];
		if (displayName && ![displayName isEqual:title] && ![[NSNull null] isEqual:displayName])
		{
			title = displayName;	// and use the display name to override the title
		}
	}
	
	// APPEND THE TITLE FIRST
	[result appendString:title];	// the title of the image, often the file name.

	// APPEND SOME GENERAL ITUNES METADATA
	if ([rec objectForKey:@"Artist"]) [result appendFormat:@"\n%@", [rec objectForKey:@"Artist"]];
	if ([rec objectForKey:@"Album"]) [result appendFormat:@"\n%@", [rec objectForKey:@"Album"]];
	
	// APPEND GENERAL QUICKTIME METADATA
	if (userInfo)
	{
		NSString *copyright = [userInfo objectForKey:QTMovieCopyrightAttribute];
		if (copyright && ![[NSNull null] isEqual:copyright]) [result appendFormat:@"\n%@", copyright];
	}

	
	// ---------------------- COLLECT TECHNICAL METADATA
	
	float durationSeconds = 0.0;
	float width = 0.0;
	float height = 0.0;
	NSString *dateTimeLocalized = nil;
	
	// COLLECT TECHNICAL QUICKTIME METADATA
	if (userInfo)
	{
		NSDate *creationTime = [userInfo objectForKey:QTMovieCreationTimeAttribute];

		if (creationTime && ![[NSNull null] isEqual:creationTime])
		{
			NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
			[formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
			[formatter setDateStyle:NSDateFormatterMediumStyle];	// medium date
			[formatter setTimeStyle:NSDateFormatterShortStyle];	// no seconds
			dateTimeLocalized = [formatter stringFromDate:creationTime];
		}
		
		NSNumber *hasDuration = [userInfo objectForKey:QTMovieHasDurationAttribute];
		NSValue *durValue = [userInfo objectForKey:QTMovieDurationAttribute];
		
		if (hasDuration && ![[NSNull null] isEqual:hasDuration] && [hasDuration boolValue] && durValue)
		{
			QTTime durTime = [durValue QTTimeValue];
			if (durTime.timeScale == 0)
				durTime.timeScale = 60;	// make sure there's a time scale
			
			durationSeconds = durTime.timeValue / durTime.timeScale;
		}
		
		NSValue *sizeValue = [userInfo objectForKey:QTMovieNaturalSizeAttribute];

		if (sizeValue && ![[NSNull null] isEqual:sizeValue])
		{
			NSSize size = [sizeValue sizeValue];
			width = size.width;
			height = size.height;
		}
	}
	
		
	// COLLECT TECHNICAL ITUNES METADATA
	NSNumber *iTunesDuration = [rec objectForKey:@"Total Time"];
	if (iTunesDuration)
	{
		durationSeconds = [iTunesDuration floatValue] / 1000.0;
	}
		
	// -------------------------- OUTPUT TECHNICAL METADATA

	// OUTPUT DATE/TIME
	if (dateTimeLocalized)
	{
		[result appendFormat:@"\n%@", dateTimeLocalized];
	}
	
	// OUTPUT DIMENSIONS
	if (width >= 1.0 && height >= 1.0)
	{
		NSString *dimensionsFormat = LocalizedStringInThisBundle(@"\n%.0f \\U2715 %.0f", @"format for width X height");
		[result appendFormat:dimensionsFormat, width, height];
	}

	// OUTPUT DURATION	
	if (durationSeconds > 0.01)
	{
		int actualSeconds = (int) roundf(durationSeconds);
		div_t hours = div(actualSeconds,3600);
		div_t minutes = div(hours.rem,60);
		
		NSString *timeString = nil;
		// TODO: Internationalize these time strings if necessary.
		if (hours.quot == 0) {
			timeString = [NSString stringWithFormat:@"%d:%.2d", minutes.quot, minutes.rem];
		}
		else {
			timeString = [NSString stringWithFormat:@"%d:%02d:%02d", hours.quot, minutes.quot, minutes.rem];
		}
		[result appendFormat:@"\n%@", timeString];
	}		
	
	
	// --------------------- OUTPUT USER INFORMATION, IF ANY, AFTER A BLANK LINE
	
	int rating = [[rec objectForKey:@"Rating"] intValue];
	NSString *iTunesComments = [rec objectForKey:@"Comments"];
	BOOL hasITunesComment = (nil != iTunesComments && ![iTunesComments isEqualToString:@""]);
	NSString *iPhotoComment = [rec objectForKey:@"Comment"];
	BOOL hasIPhotoComment = (nil != iPhotoComment && ![iPhotoComment isEqualToString:@""]);
	NSArray *keywords = [rec objectForKey:@"iMediaKeywords"];
	BOOL hasKeywords = keywords && [keywords count];
	if (rating > 0 || hasITunesComment || hasIPhotoComment || hasKeywords)
	{
		[result appendString:@"\n"];	// extra blank line before comment or rating
		if (hasITunesComment)
		{
			[result appendFormat:@"\n%@", iTunesComments];
		}
		if (hasIPhotoComment)
		{
			[result appendFormat:@"\n%@", iPhotoComment];
		}
		if (rating > 0)
		{
			[result appendFormat:@"\n%@", 
				[NSString stringFromStarRating:rating]];
		}
		if (hasKeywords)
		{
			[result appendFormat:@"\n"];
			NSEnumerator *keywordsEnum = [keywords objectEnumerator];
			NSString *keyword;
			
			while ((keyword = [keywordsEnum nextObject]) != nil)
			{
				[result appendFormat:@"%@, ", keyword];
			}
			[result deleteCharactersInRange:NSMakeRange([result length] - 2, 2)];	// remove last comma+space
		}
	}
	return result;
	
	
	
	
	
	
	
	
	
	
	
	
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
		///NSLog(@"photoView:doubleClickOnPhotoAtIndex:%@ going to load movie", path);
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
