/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2012 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 The new architecture for version 2.0 was developed by Peter Baumgartner.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 The iMedia Browser Framework is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2012 by Karelia Software et al.
 
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


// Author: Peter Baumgartner, Mike Abdullah


//----------------------------------------------------------------------------------------------------------------------

#pragma mark ABSTRACT

/**
 IMBObject encapsulates information about a single media item (e.g. image file or audio file). The location
 property uniquely identifies the item.
 
 IMBObject is not designed to be thread-safe.
 */

#pragma mark HEADERS

#import <Quartz/Quartz.h>
#import "IMBCommon.h"
#import "IMBImageItem.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

extern NSString* kIMBObjectPasteboardType;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CLASSES

@class IMBParserMessenger;


//----------------------------------------------------------------------------------------------------------------------


@interface IMBObject : NSObject <NSCopying,NSCoding,IMBImageItem,QLPreviewItem,NSPasteboardItemDataProvider>
{
	NSURL *_location;												
	NSData* _bookmark;
    IMBResourceAccessibility _accessibility;
	NSString* _name;
	NSString* _identifier;
	NSString* _persistentResourceIdentifier;
	
	NSDictionary* _preliminaryMetadata;
	NSDictionary* _metadata;
	NSString* _metadataDescription;
	
	IMBParserMessenger* _parserMessenger;
    NSString* _parserIdentifier;
	NSError* _error;
	
	NSUInteger _index;
    BOOL _shouldDrawAdornments;
	BOOL _shouldDisableTitle;
    BOOL _isLoadingThumbnail;
	
	id _imageLocation;
	id _imageRepresentation;								
	NSString* _imageRepresentationType;		
	BOOL _needsImageRepresentation;
	NSUInteger _imageVersion;
}

@property (copy) NSURL *location;
@property (assign) IMBResourceAccessibility accessibility;	// What access do we have to the object's resource?
@property (retain) NSString* name;							// Display name for user interface
@property (readonly) NSImage* icon;							// Small icon to be displayed in list view
@property (retain) NSString* identifier;					// Unique identifier for this object
@property (retain) NSString* persistentResourceIdentifier;  // Unique persistent resource identifier for this object

@property (retain) NSDictionary* preliminaryMetadata;		// Immediate (cheap) metadata
@property (retain) NSDictionary* metadata;					// On demand (expensive) metadata (also contains preliminaryMetadata), initially nil
@property (retain) NSString* metadataDescription;			// Metadata as display in UI (optional)

@property (retain) IMBParserMessenger* parserMessenger;		// IMBParserMessenger that is responsible for this object
@property (retain) NSString* parserIdentifier;				// Identifier of IMBParser that created this object
@property (retain) NSError* error;							// Per object error...


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

// Visual appearance...

@property (assign) BOOL shouldDrawAdornments;				// YES if border/shadow should be drawn
@property (assign) BOOL shouldDisableTitle;					// YES if title should be shown as disabled (e.g. not draggable)
- (NSString*) tooltipString;

// Index of the file in the array. Setting this property is optional, but highly recommended as it speeds things up...

@property (assign) NSUInteger index;					

// Convenience accessors for the file...

- (NSURL*) URL;												// Converts self.location to a url
- (NSString*) type;											// Returns UTI of file if possible
- (NSString*) mediaType;					


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

// To display IMBObjects in an IKImageBrowserView, we need to implement the (informal) protocol IKImageBrowserItem...

@property (nonatomic,readonly) NSString* imageUID;
@property (retain) NSString* imageRepresentationType;
@property (retain) id imageRepresentation;	
@property (retain) id atomic_imageRepresentation;
@property (assign) NSUInteger imageVersion;
@property (readonly) NSString* imageTitle;
@property (readonly) BOOL isSelectable;

// The following methods are not part of the IKImageBrowserItem protocol, but act in a supporting manner...

@property (nonatomic, assign) BOOL needsImageRepresentation;			// Set to YES if an existing thumbnail should be reloaded
@property (readonly) BOOL isDraggable;						// Can this object be dragged from iMediaBrowser?

@property (retain) id imageLocation;						// Optional url if different from location (e.g. lores thumbnail)
- (NSURL*) imageLocationURL;                                // Convert imageLocation to url


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

// Use the following methods to lazily and asyncronously load thumbnails and metadata as they become visible. 
// Observe the properties imageRepresentation or metadata to find out when loading has finished...

@interface IMBObject (LazyLoading)

- (void) loadThumbnail;	
- (void) unloadThumbnail;
- (BOOL) isLoadingThumbnail;

- (void) loadMetadata; 
- (void) unloadMetadata;

// Store the imageRepresentation and add this object to the fifo cache. Older objects get bumped out off cache 
// and are thus unloaded. Please note that missing thumbnails will be replaced with a generic image...

- (void) storeReceivedImageRepresentation:(id)inImageRepresentation;

//- (void) postProcessLocalURL:(NSURL*)inLocalURL;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

// To access the real media file from a (sandboxed) host application, you cannot use the location or URL property
// of IMBObject. First, the object might not represent a local file, but a remote resource (e.g. on the internet)
// that needs to be downloaded first. And second, if your host app is sandboxed, having the NSURL to a local file
// would not do you any good, as your app wouldn't be allowed to access this file. 

// Instead use the methods below to request a bookmark. This is an asynchronous operation (which also automatically 
// downloads any remote resources to your harddisk). When you receive the bookmark in the completion block and 
// resolve it to a NSURL, the PowerBox authorized your app to access this file for the current launch session.
// In that respect it acts similarly to NSOpenPanel or drag & drop from the Finder.

@interface IMBObject (FileAccess)

/**
 @abstract
 Asynchronously requests a bookmark for self and sets it within self.
 Submits the completion block to the provided queue.
 
 @discussion
 If the bookmark is already stored with self calls the completion block synchronously.
 */
- (void) requestBookmarkWithQueue:(dispatch_queue_t)inQueue completionBlock:(void(^)(NSError*))inCompletionBlock;

/**
 @abstract
 Asynchronously requests a bookmark for self and sets it within self.
 Submits the completion block to the main queue.
 
 @discussion
 If the bookmark is already stored with self calls the completion block synchronously.
 
 @see
 requestBookmarkWithQueue:completionBlock:
 */
- (void) requestBookmarkWithCompletionBlock:(void(^)(NSError*))inCompletionBlock;

- (NSURL*) URLByResolvingBookmark;

@property (retain,readonly) NSData* bookmark;

@end


//----------------------------------------------------------------------------------------------------------------------
