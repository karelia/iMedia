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


// Author: Jörg Jacobsen


//----------------------------------------------------------------------------------------------------------------------


#pragma mark ABSTRACT
/*
 This class provides parsing functionality that is common to some media data storages provided by Apple
 (such as iPhoto and Aperture). Public property list files of iPhoto and Aperture share a lot of structure
 (specifically regarding faces data) so you can utilize this intermediate class to share corresponding
 functionality between iPhoto and Aperture parsers (and maybe other parsers to come).
 
 ATTENTION: This is an abstract class. Do not use an instance of this class, but use a specific subclass
            like IMBiPhotoParser or IMBApertureParser instead...
*/

//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import <Cocoa/Cocoa.h>
#import "IMBParser.h"
//#import "IMBSkimmableObjectViewController.h"
#import "IMBNodeObject.h"


//----------------------------------------------------------------------------------------------------------------------

#pragma mark CONSTANTS

// Provide different id spaces for events, faces and albums. Distinct ids must be guaranteed
// throughout the media tree in the outline view.

#define EVENTS_ID_SPACE @"EventId"
#define FACES_ID_SPACE  @"FaceId"
#define ALBUMS_ID_SPACE @"AlbumId"
#define PHOTO_STREAM_ID_SPACE @"PhotoStreamId"

// Since we will add an events node to the list of iPhoto albums and a faces node to iPhoto and Aperture
// we have to create (sub-)ids for them that are unique throughout their library. The ones chosen below
// are very, very likely to be.

#define EVENTS_NODE_ID       UINT_MAX-4811	// Very, very unlikely this not to be unique throughout library
#define FACES_NODE_ID        UINT_MAX-4812	// Very, very unlikely this not to be unique throughout library
#define PHOTO_STREAM_NODE_ID UINT_MAX-4813	// Very, very unlikely this not to be unique throughout library
#define ALL_PHOTOS_NODE_ID   UINT_MAX-4814	// Very, very unlikely this not to be unique throughout library

// node object types of interest for skimming

extern NSString* const kIMBiPhotoNodeObjectTypeEvent; // = @"events"
extern NSString* const kIMBiPhotoNodeObjectTypeFace;  // = @"faces"


//----------------------------------------------------------------------------------------------------------------------

#pragma mark -

@interface IMBAppleMediaParser : IMBParser /*<IMBSkimmableObjectViewControllerDelegate>*/
{
	NSString* _appPath;
	NSDictionary* _plist;
	NSDate* _modificationDate;
}

@property (retain) NSString* appPath;
@property (retain,readonly) NSDictionary* plist;
@property (retain,readonly) NSDate* modificationDate;


// Returns IKImageBrowserCGImageRepresentationType

- (NSString*) requestedImageRepresentationType;

// Returns events id space  (EVENTS_ID_SPACE) for album types "Event" and "Events".
// Returns faces id space  (FACES_ID_SPACE) for album types "Face" and "Faces".
// Otherwise returns the albums id space (ALBUMS_ID_SPACE).

- (NSString*) idSpaceForAlbumType:(NSString*) inAlbumType;

// Returns an identifier built from the provided id and id space. An example is "IMBiPhotoParser://FaceId/17"...

- (NSString*) identifierForId:(NSNumber*) inId inSpace:(NSString*) inIdSpace;

// Returns the index of the all photos album ("Photos") in given album list

- (NSUInteger) indexOfAllPhotosAlbumInAlbumList:(NSArray*)inAlbumList;

// Returns the index of the projects album ("Projects") in given album list
// Projects are to Aperture what events are to iPhoto - hence the method name for coherence

- (NSUInteger) indexOfEventsAlbumInAlbumList:(NSArray*)inAlbumList;

// Returns the index of the flagged album ("Flagged") in given album list

- (NSUInteger) indexOfFlaggedAlbumInAlbumList:(NSArray*)inAlbumList;

// Returns whether inNode is the events node

- (BOOL) isEventsNode:(IMBNode*)inNode;

// Returns whether node provided is the faces node

- (BOOL) isFacesNode:(IMBNode*)inNode;

// Returns whether inNode is the Photo Stream node

- (BOOL) isPhotoStreamNode:(IMBNode*)inNode;

// Returns node types for events node and faces node. nil otherwise.

- (NSString *)nodeTypeForNode:(IMBNode *)inNode;

// Returns whether an album of this type exposes a disclosure triangle or not.
// Takes care of album Types "Folder", "Faces" and "Events".
// Subclass for more specific behavior.

- (BOOL) isLeafAlbumType:(NSString*)inType;

// The image location represents an image path to the image to be used for display inside of the browser (a preview of
// of the original image). By default we use the path to the image's thumbnail (key: "ThumbPath").
// Subclass for distinct behavior.

- (NSString*) imageLocationForObject:(NSDictionary*)inObjectDict;

// Returns the image location for the clipped face in the image represented by inImageKey in the master image list
// (aka dictionary)

- (NSString*) imagePathForFaceIndex:(NSNumber*)inFaceIndex inImageWithKey:(NSString*)inImageKey;

// Returns the image location for the image represented by inImageKey in the master image list (aka dictionary)

- (NSString*) imagePathForImageKey:(NSString*)inImageKey;

// Specific method for populating Faces nodes (in Aperture and iPhoto library)

- (void) populateFacesNode:(IMBNode*)inNode withFaces:(NSDictionary*)inFaces images:(NSDictionary*)inImages;

@end
