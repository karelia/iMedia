/*
 iMedia Browser <http://kareia.com/imedia>
 
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
	e.g., About window,Acknowledgments window, or similar, either a) the original
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


#import "iMBPhotosController.h"
#import "iMediaBrowser.h"
#import "MUPhotoView.h"
#import "iMBLibraryNode.h"
#import "iMedia.h"

#ifndef SAMPLE_INCOMING_DRAG
#define SAMPLE_INCOMING_DRAG 0
#endif

#define MAX_THUMB_SIZE 240	// our thumbnail view maxes out at 240.


@interface NSObject (CompilerIsHappy)
+ (NSImage *)imageWithPath:(NSString *)path boundingBox:(NSSize)boundingBox;
@end

@interface iMBPhotosController (PrivateAPI)
- (NSString *)iconNameForPlaylist:(NSString*)name;
@end

static NSImage *sMissingImage = nil;
static Class sNSCGImageRepClass = nil;

@implementation iMBPhotosController

+ (void)initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[iMBPhotosController setKeys:[NSArray arrayWithObject:@"images"] triggerChangeNotificationsForDependentKey:@"imageCount"];
	[iMBPhotosController setKeys:[NSArray arrayWithObject:@"images"] triggerChangeNotificationsForDependentKey:@"imageCountString"];
	
	sNSCGImageRepClass = NSClassFromString(@"NSCGImageRep");	// private class; we're being careful here
	if (![sNSCGImageRepClass respondsToSelector:@selector(initWithCGImage:)])
	{
		sNSCGImageRepClass = nil;	// make sure this class will do the job for us!
	}
	
	NSString *path = [[NSBundle bundleForClass:[iMBPhotosController class]] pathForResource:@"missingImage" ofType:@"png"];
	sMissingImage = [[NSImage alloc] initWithContentsOfFile:path];
	if (!sMissingImage)
		NSLog(@"missingImage.png is missing. This can cause bad things to happen");
	
	[pool release];
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
		
		[self loadNib];
	}
	return self;
}

- (void)setBrowser:(iMediaBrowser *)browser	// hook up captions prefs now that we have a browser associated with this controller.
{
	[super setBrowser:browser];
	[oPhotoView setShowCaptions:[browser prefersFilenamesInPhotoBasedBrowsers]];
}

- (void)loadNib
{
	if (![[NSBundle bundleForClass:[iMBPhotosController class]] loadNibFile:@"iPhoto" 
														  externalNameTable:[NSDictionary dictionaryWithObjectsAndKeys:self, @"NSOwner", nil] 
																   withZone:[self zone]])
	{
		NSLog(@"iPhoto.nib is missing. This can cause bad things to happen");
	}
}


- (void)dealloc
{
	[mySelection release];
	[myCache release];
	[myCacheLock release];
	[myImages release];
	[myImageDict release];
	[myFilteredImages release];
	[mySearchString release];
	[myInFlightImageOperations release];
	[mySelectedIndexPath release];
	[myProcessingImages release];
	
	[oView release];
	
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


	NSDictionary *optionsDict =
		[NSDictionary dictionaryWithObject:
			LocalizedStringInThisBundle(@"%{value1}@ photos", @"Formatting: number of photos displayed")
									forKey:@"NSDisplayPattern"];
	
	[counterField bind:@"displayPatternValue1"
			  toObject:self
		   withKeyPath:@"imageCount"
			   options:optionsDict];
// It would be nice to properly show single/plural form; maybe also indicate # selected if there is a selection.  How to do with bindings?


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

- (void)clearCache
{
	[myCacheLock lock];	// ============================================================ LOCK
	[myCache removeAllObjects];
	[myCacheLock unlock];	// ======================================================== UNLOCK
}

#pragma mark -
#pragma mark Media Browser Protocol Overrides

static NSImage *_toolbarIcon = nil;

- (NSImage*)toolbarIcon
{
	if (_toolbarIcon == nil)
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
	return LocalizedStringInThisBundle(@"Photos", @"Photos media type");
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
	unsigned int i;
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
	NSArray *whichPhotos = nil;
	
	if ([mySearchString length] > 0)
	{
		whichPhotos = myFilteredImages;
	}
	else
	{
		whichPhotos = myImages;
	}
	int i, c = [myImages count];
	
	for (i = 0; i < c; i++)
	{
		if ([mySelection containsIndex:i])
		{
			[records addObject:[whichPhotos objectAtIndex:i]];
		}
	}
	
	return records;
}

#pragma mark -
#pragma mark Threaded Image Loading


- (NSDictionary *)recordForPath:(NSString *)path
{
	return [myImageDict objectForKey:@"path"];
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
	[myCacheLock lock];	// ============================================================ LOCK
	NSString* imagePathRetained = [[myInFlightImageOperations lastObject] retain];
	if (imagePathRetained)
	{
		[myInFlightImageOperations removeObject:imagePathRetained];
		[myProcessingImages addObject:imagePathRetained];
	}
	[myCacheLock unlock];	// ======================================================== UNLOCK
	
	NSString *thumbPath;
	NSImage *img;
	NSDictionary *rec;
	 
	while (imagePathRetained)
	{
		rec = [self recordForPath:imagePathRetained];
		img = nil;
		thumbPath = [rec objectForKey:@"ThumbPath"];
		
		if (thumbPath)
		{
			img = [[NSImage alloc] initByReferencingFile:thumbPath];
		}
		
		// If we didn't have a thumbnail, create it from Core Graphics.
		if (!img)
		{
			// Some versions of iPhoto somehow link to aliases of images instead of the images themselves.
			// so resolve the path if it is an alias. This may occur if the iPhoto preferences dictate that
			// the photos should not be copied into the Pictures folder. It may also occur during some
			// upgrade events.
			NSString *resolvedPath = [[NSFileManager defaultManager] pathResolved:imagePathRetained];
			NSURL *url = [NSURL fileURLWithPath:resolvedPath];
			CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
			if (source)
			{
				// image thumbnail options
				NSDictionary* thumbOpts = [NSDictionary dictionaryWithObjectsAndKeys:
					(id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailWithTransform,
					(id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailFromImageIfAbsent,
					[NSNumber numberWithInt:MAX_THUMB_SIZE], (id)kCGImageSourceThumbnailMaxPixelSize, 
					nil];
				
				// make image thumbnail
				CGImageRef theCGImage = CGImageSourceCreateThumbnailAtIndex(source, 0, (CFDictionaryRef)thumbOpts);
				
				if (theCGImage)
				{
					// Now draw into an NSImage
					NSRect imageRect = NSMakeRect(0.0, 0.0, 0.0, 0.0);
					CGContextRef imageContext = nil;
					
					// Get the image dimensions.
					imageRect.size.height = CGImageGetHeight(theCGImage);
					imageRect.size.width = CGImageGetWidth(theCGImage);
					
					// Create a new image to receive the Quartz image data.
					img = [[[NSImage alloc] initWithSize:imageRect.size] autorelease];
					[img setFlipped:YES];
					
					// Try to use private NSCGImageRep
					if (sNSCGImageRepClass)
					{
						id cgRep = [[[sNSCGImageRepClass alloc] initWithCGImage:theCGImage] autorelease];
						[img addRepresentation:cgRep];
					}
					else	// not found, go the old-fashioned route (which may have some sort of deadlock with drawing?
					{
						[img lockFocus];
						
						// Get the Quartz context and draw.
						imageContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
						CGContextDrawImage(imageContext, *(CGRect*)&imageRect, theCGImage);
						[img unlockFocus];
					}
					CFRelease(theCGImage);
				}
				CFRelease(source);
			}
		}
		
		if (!img) // we have a bad egg... need to display a ? icon
		{
			img = sMissingImage;
			if (thumbPath)
			{
				NSLog(@"Unable to load thumb image at %@", thumbPath);
			}
			else
			{
				NSLog(@"Unable to load image at %@", imagePathRetained);
			}
		}
		
		[myCacheLock lock];	// ============================================================ LOCK
		if (img && ![myCache objectForKey:imagePathRetained])
		{
			[myCache setObject:img forKey:imagePathRetained];
		}
		
		// get the last object in the queue because we would have scrolled and what is at the start won't be necessarily be what is displayed.
		[myProcessingImages removeObject:imagePathRetained];
		[imagePathRetained release];
		// Now try to get another one. Or nil.
		imagePathRetained = [[myInFlightImageOperations lastObject] retain];
		if (imagePathRetained)
		{
			[myInFlightImageOperations removeObject:imagePathRetained];
			[myProcessingImages addObject:imagePathRetained];
		}
		[myCacheLock unlock];	// ======================================================== UNLOCK
        
		[oPhotoView performSelectorOnMainThread:@selector(setNeedsDisplay:)
									 withObject:[NSNumber numberWithBool:YES]
								  waitUntilDone:NO];
	}
	
	myThreadCount--;
	[pool release];
}

#pragma mark -
#pragma mark MUPhotoView Delegate Methods

- (void)setImages:(NSArray *)images	// not called from code directly; set by binding in willActivate
{
	[myImages autorelease];
	[myImageDict autorelease];
	myImages = [images retain];
	
	// Make a dictionary that echos myImages
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	NSEnumerator *enumerator = [myImages objectEnumerator];
	NSDictionary *record;

	while ((record = [enumerator nextObject]) != nil)
	{
		[dict setObject:record forKey:[record objectForKey:@"ImagePath"]];
	}
	myImageDict = [[NSDictionary alloc] initWithDictionary:dict];	// retained
	
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
	[myCacheLock lock];	// ============================================================ LOCK
	NSString *imagePath = [rec objectForKey:@"ImagePath"];
	NSImage *img = [myCache objectForKey:imagePath];
	
	if (!img) img = [rec objectForKey:@"CachedThumb"];
	
	if (!img)
	{
		// background load the image
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
		img = nil; //return nil so the image view draws a bezierpath
	}
	[myCacheLock unlock];	// ======================================================== UNLOCK

	return img;
}

- (void)photoView:(MUPhotoView *)view didSetSelectionIndexes:(NSIndexSet *)indexes
{
	[mySelection removeAllIndexes];
	[mySelection addIndexes:indexes];
	
	[self postSelectionChangeNotification:[self selectedRecords]];
}

- (void)photoView:(MUPhotoView *)view doubleClickOnPhotoAtIndex:(unsigned)aIndex withFrame:(NSRect)frame
{
	[self postSelectionChangeNotification:[self selectedRecords]];
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
			[items addObject:cur];
		}
	}
	[self writeItems:items fromAlbum:[[NSBundle bundleForClass:[iMBPhotosController class]] localizedStringForKey:@"Selection" value:@"" table:nil] toPasteboard:pboard];
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
	NSString *result = [rec objectForKey:@"Caption"];
	return result;
}

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
	
	NSString *imagePath = [rec objectForKey:@"ImagePath"];
	if (!imagePath)
	{
		[result appendString:[rec objectForKey:@"Caption"]];	// the title of the image, often the file name.
	}
	else
	{
		NSString *fileName = [imagePath lastPathComponent];
		[result appendFormat:@"%@", fileName];
		
		// Some versions of iPhoto somehow link to aliases of images instead of the images themselves.
		// so resolve the path if it is an alias. This may occur if the iPhoto preferences dictate that
		// the photos should not be copied into the Pictures folder. It may also occur during some
		// upgrade events.
		NSString *resolvedPath = [[NSFileManager defaultManager] pathResolved:imagePath];
		NSDictionary *metadata = [NSImage metadataFromImageAtPath:resolvedPath];
		NSString *dimensionsFormat = LocalizedStringInThisBundle(@"\n%.0f \\U2715 %.0f", @"format for width X height");
		[result appendFormat:dimensionsFormat,
			[[metadata objectForKey:@"width"]  floatValue],
			[[metadata objectForKey:@"height"] floatValue]];
		NSString *dateTimeLocalized = [metadata objectForKey:@"dateTimeLocalized"];
		if (dateTimeLocalized)
		{
			[result appendFormat:@"\n%@", dateTimeLocalized];
		}
		int rating = [[rec objectForKey:@"Rating"] intValue];
		NSString *comment = [rec objectForKey:@"Comment"];
		BOOL hasComment = (nil != comment && ![comment isEqualToString:@""]);
		NSArray *keywords = [rec objectForKey:@"iMediaKeywords"];
		BOOL hasKeywords = keywords && [keywords count];
		if (rating > 0 || hasComment || hasKeywords)
		{
			[result appendString:@"\n"];	// extra blank line before comment or rating
			if (hasComment)
			{
				[result appendFormat:@"\n%@", comment];
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
	}
	return result;
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


- (NSDragOperation)playlistOutlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)aIndex tryDefaultHandling:(BOOL*)tryDefault
{
	NSDragOperation result = NSDragOperationNone;
	*tryDefault = YES;
	NSPasteboard* pboard = [info draggingPasteboard];
	if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSTIFFPboardType]])
	{
		if (aIndex == NSOutlineViewDropOnItemIndex) // We don't allow inter-item drags
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
				 childIndex:(int)aIndex
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
