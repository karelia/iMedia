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


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS


// Options to control behavior of the framework...

enum
{
	kIMBOptionNone = 0,
	kIMBOptionForceRecursiveLoading = 1
};
typedef NSUInteger IMBOptions;


// File watcher type for an IMBNode...

enum 
{
	kIMBWatcherTypeNone,
	kIMBWatcherTypeKQueue,
	kIMBWatcherTypeFSEvent,
	kIMBWatcherTypeFirstCustom = 1000
};
typedef NSUInteger IMBWatcherType;


// Badge type for IMBNode. A corresponding icon will be displayed in the cell...

enum 
{
	kIMBBadgeTypeNone,
	kIMBBadgeTypeLoading,
	kIMBBadgeTypeReload,
	kIMBBadgeTypeWarning,
	kIMBBadgeTypeStop,
	kIMBBadgeTypeEject,
	kIMBBadgeTypeOffline,
	kIMBBadgeTypeNoAccessRights
};
typedef NSUInteger IMBBadgeType;


// Media types...

extern NSString* kIMBMediaTypeImage;
extern NSString* kIMBMediaTypeAudio;
extern NSString* kIMBMediaTypeMovie;
extern NSString* kIMBMediaTypeLink;
extern NSString* kIMBMediaTypeContact;


// Group types...

enum 
{
	kIMBGroupTypeLibrary,
	kIMBGroupTypeFolder,
	kIMBGroupTypeSearches,
	kIMBGroupTypeInternet,
	kIMBGroupTypeDevice,
	kIMBGroupTypeNone
};
typedef NSUInteger IMBGroupType;

// Error codes...

enum 
{
	kIMBErrorNone = 0,
	
	// General errors...
	
	kIMBErrorUnknown,
	kIMBErrorInvalidState,
	kIMBErrorItemNotFound,
	kIMBErrorFileAccessDenied,
	kIMBErrorNetworkNotReachable,
	
	// IMBObject level errors...
	
	kIMBErrorThumbnailNotAvailable,
	kIMBErrorMetadataNotAvailable,
	kIMBErrorFileNotAvailable,
};
typedef NSUInteger IMBErrorCode;


// Accessibility states of an item (like library of a top level IMBNode or media of an IMBObject)

typedef enum
{
    kIMBResourceDoesNotExist,
    kIMBResourceNoPermission,   // Implies that the resource exists
    kIMBResourceIsAccessible
} IMBResourceAccessibility;


//----------------------------------------------------------------------------------------------------------------------


// User Interface constants...

#define kIMBMaxThumbnailSize 256.0

// Common error codes...

#define kIMBErrorDomain @"com.karelia.imedia"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark TYPES

//#define IMBCompletionBlock XPCReturnValueHandler
typedef void (^IMBCompletionBlock)(id inResult,NSError* inError);


//----------------------------------------------------------------------------------------------------------------------


#pragma mark MACROS

#ifndef IMBRelease
#define IMBRelease(object) if (object) {[object release]; object=nil;}
#endif

#ifndef IMBDrain
#define IMBDrain(pool) if (pool) {[pool drain]; pool=nil;}
#endif

#ifndef IMBBundle
#define IMBBundle() [NSBundle bundleForClass:NSClassFromString(@"IMBConfig")]
#endif


// Version checks in a centralized location for easy safe-adoption of features conditional on running OS version

#ifndef NSAppKitVersionNumber10_6
#define NSAppKitVersionNumber10_6 1038
#endif

#ifndef NSAppKitVersionNumber10_7
#define NSAppKitVersionNumber10_7 1138
#endif

#ifndef NSAppKitVersionNumber10_7_2
#define NSAppKitVersionNumber10_7_2 1138.23
#endif

#define IMBRunningOnSnowLeopardOrNewer()	(NSAppKitVersionNumber >= NSAppKitVersionNumber10_6)
#define IMBRunningOnLionOrNewer()			(NSAppKitVersionNumber >= NSAppKitVersionNumber10_7)
#define IMBRunningOnLion1073OrNewer()		(NSAppKitVersionNumber > NSAppKitVersionNumber10_7_2)

#define IMB_COMPILING_WITH_LION_OR_NEWER_SDK  defined(MAC_OS_X_VERSION_10_7)
#define IMB_COMPILING_WITH_SNOW_LEOPARD_OR_NEWER_SDK  defined(MAC_OS_X_VERSION_10_6)


//----------------------------------------------------------------------------------------------------------------------


// We have to declare a fake prototypes because the 10.6 / 10.7 runtime interrogates our compliance with the protocol,
// rather that interrogating the presence of the particular method we implement...

#if ! IMB_COMPILING_WITH_LION_OR_NEWER_SDK

@protocol NSURLDownloadDelegate <NSObject> 
@end

#endif


#if ! IMB_COMPILING_WITH_SNOW_LEOPARD_OR_NEWER_SDK

@protocol NSPasteboardItemDataProvider <NSObject> 
@end

@protocol QLPreviewPanelDelegate <NSObject> 
@end

@protocol QLPreviewPanelDataSource <NSObject> 
@end

@protocol NSAnimationDelegate <NSObject> 
@end

#endif


//----------------------------------------------------------------------------------------------------------------------


// Flickr sizes

typedef enum
{ 
	kIMBFlickrSizeSpecifierOriginal = 0,
	kIMBFlickrSizeSpecifierSmall,		// 240 longest
	kIMBFlickrSizeSpecifierMedium,		// 500 longest
	kIMBFlickrSizeSpecifierLarge		// 1024 longest	
} 
IMBFlickrSizeSpecifier;


//----------------------------------------------------------------------------------------------------------------------



