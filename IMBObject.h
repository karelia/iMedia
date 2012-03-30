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


#pragma mark HEADERS

#import <Quartz/Quartz.h>
#import "IMBImageItem.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

extern NSString* kIMBQuickLookImageProperty;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CLASSES

@class IMBParserMessenger;


//----------------------------------------------------------------------------------------------------------------------


// IMBObject encapsulates information about a single media item (e.g. image file or audio file). The location 
// property uniquely identifies the item. In the case of files it could be a path or NSURL...

@interface IMBObject : NSObject <NSCopying,NSCoding,IMBImageItem,QLPreviewItem,NSPasteboardWriting>
{
	id _location;												
	NSString* _name;
	NSDictionary* _preliminaryMetadata;
	NSDictionary* _metadata;
	NSString* _metadataDescription;
    NSString* _parserIdentifier;
	IMBParserMessenger* _parserMessenger;
	
	NSUInteger _index;
    BOOL _shouldDrawAdornments;
	BOOL _shouldDisableTitle;
    BOOL _isLoadingThumbnail;
	
	id _imageLocation;
	id _imageRepresentation;								
	NSString* _imageRepresentationType;		
	BOOL _needsImageRepresentation;
	NSUInteger _imageVersion;
	
	NSURL* _bookmarkBaseURL;
	NSData* _bookmark;
}

// Primary properties...

@property (retain) id location;								// Path, URL, or other location info
@property (retain) NSString* name;							// Display name for user interface
@property (readonly) NSImage* icon;							// Small icon to be displayed in list view
@property (readonly) NSString* identifier;					// Unique identifier for this object
@property (retain) NSDictionary* preliminaryMetadata;		// Immediate (cheap) metadata
@property (retain) NSDictionary* metadata;					// On demand (expensive) metadata (also contains preliminaryMetadata), initially nil
@property (retain) NSString* metadataDescription;			// Metadata as display in UI (optional)
@property (retain) NSString* parserIdentifier;				// Identifier of IMBParser that created this object
@property (retain) IMBParserMessenger* parserMessenger;		// IMBParserMessenger that created this object

// Helpers...

@property (assign) NSUInteger index;						// Index of object in the array (optional)
@property (assign) BOOL shouldDrawAdornments;				// YES if border/shadow should be drawn
@property (assign) BOOL shouldDisableTitle;					// YES if title should be shown as disabled (e.g. not draggable)
@property (readonly) BOOL isSelectable;
@property (readonly) BOOL isDraggable;

- (NSString*) path;											// Convert location to path
- (NSURL*) URL;												// Convert location to url
- (NSURL*) imageLocationURL;                                // Convert imageLocation to url
- (BOOL) isLocalFile;										// Is this object a local file
- (NSString*) type;											// Returns type of file if possible
- (NSString*) tooltipString;

// Derived Properties. See IKImageBrowserItem for documentation.   
// These methods are used for displaying in an IKImageBrowserView...

@property (retain) id imageLocation;						// Optional url or path if different from location (e.g. lores thumbnail)
@property (retain) id imageRepresentation;	
@property (retain) NSString* imageRepresentationType;
@property (assign) BOOL needsImageRepresentation;
@property (assign) NSUInteger imageVersion;
@property (nonatomic, readonly) NSString* imageUID;
@property (readonly) NSString* imageTitle;

// Asynchronous loading of thumbnails...
																	
- (void) loadThumbnail;	
- (BOOL) unloadThumbnail;
@property (readonly) BOOL isLoadingThumbnail;

- (void) loadMetadata;  // observe .metadata property to know when finished
//- (void) postProcessLocalURL:(NSURL*)inLocalURL;

// Security Scoped Bookmark Support...

- (void) requestBookmarkWithCompletionBlock:(void(^)(NSError*))inCompletionBlock;
- (NSURL*) URLByResolvingBookmark;

@property (retain) NSURL* bookmarkBaseURL;
@property (retain) NSData* bookmark;


@end


//----------------------------------------------------------------------------------------------------------------------
