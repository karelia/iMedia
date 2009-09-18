/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2009 by Karelia Software et al.
 
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

//----------------------------------------------------------------------------------------------------------------------

#pragma mark CLASSES

@class IMBParser;

//----------------------------------------------------------------------------------------------------------------------

// This object encapsulates information about a single media item (e.g. image file or audio file). The value 
// property uniquely identifies the item. In the case of files it could be a path or NSURL...

@interface IMBObject : NSObject <NSCopying,NSCoding>
{
	id _value;												
	NSString* _name;
	NSDictionary* _metadata;
	IMBParser* _parser;
}

@property (retain) id value;								// Path or URL
@property (retain) NSString* name;
@property (retain) NSDictionary* metadata;
@property (readonly) NSImage* icon;
@property (retain) IMBParser* parser;

- (BOOL) isEqual:(IMBObject*)inObject;						// Considered equal if value is equal

@end

//----------------------------------------------------------------------------------------------------------------------

// This subclass can be used for image or movie files, i.e. items that need a visual representation and are
// displayed with IKIMageBrowserView... 

@interface IMBVisualObject : IMBObject
{
	id _imageRepresentation;								
	NSString* _imageRepresentationType;		
	NSUInteger _imageVersion;
	NSImage *_thumbnailImage ;
    BOOL _imageLoading;
}

- (void)queueThumbnailImageLoad;			// Load the image (for dynamic table view)

@property (readonly) NSString* imageUID;
@property (retain) id imageRepresentation;					///< NSString, NSURL, NSImage, or CGImageRef
@property (retain) NSString* imageRepresentationType;		///< See IKImageBrowserItem for possible values
@property (readonly) NSString* imageTitle;
@property (assign) NSUInteger imageVersion;
@property (readwrite, retain) NSImage *thumbnailImage ;				// for dynamic table view, not IK browser view
																	// Property:  IMBObjectPropertyNamedThumbnailImage

// A nil image isn't loaded (or couldn't be loaded). An image that is in the process of loading has imageLoading set to YES
@property (readwrite) BOOL imageLoading;

@end

//----------------------------------------------------------------------------------------------------------------------

// This subclass is used to represent nodes in the object views (examples are folder and events). The reason we 
// have these hybrid objects is to have a double clickable item in the object views, which can be used to drill
// down the hierarchy... 

@interface IMBNodeObject : IMBVisualObject
{
	NSString* _path;
}

@property (retain) NSString* path;	

@end

//----------------------------------------------------------------------------------------------------------------------
