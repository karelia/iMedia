/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2010 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2010 by Karelia Software et al.
 
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
	kIMBBadgeTypeStop,
	kIMBBadgeTypeEject,
	kIMBBadgeTypeOffline
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


//----------------------------------------------------------------------------------------------------------------------


// User Interface constants...

#define kIMBMaxThumbnailSize 128

// Common error codes...

#define kIMBErrorDomain @"com.karelia.imedia"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark MACROS

#ifndef IMBRelease
#define IMBRelease(object) if (object) {[object release]; object=nil;}
#endif

#ifndef IMBBundle
#define IMBBundle() [NSBundle bundleForClass:NSClassFromString(@"IMBConfig")]
#endif


// Version checks in a centralized location for easy safe-adoption of features conditional on running OS version

#ifndef NSAppKitVersionNumber10_6
#define NSAppKitVersionNumber10_6 1000	// NOTE(jalkut): I don't think this is exactly right, my 10.6.1 system reports 1038.1,
										// but it's "good enough" in that it's higher than 10.5's version of 949.x,
										// and it was the constant already in use in the source code.
										// (I'm guessing it was a pre-GM Snow Leopard version number)
#endif

#define IMBRunningOnSnowLeopardOrNewer()	(NSAppKitVersionNumber >= NSAppKitVersionNumber10_6)
#define IMB_COMPILING_WITH_SNOW_LEOPARD_OR_NEWER_SDK  defined(MAC_OS_X_VERSION_10_6)

// If you are getting duplicate protocol declaration warnings because you already declare dummy
// compatibility protocols in your host application, just make sure IMB_HOST_APP_DECLARES_DUMMY_PROTOCOLS
// is defined and non-zero, to prevent this redundant definition of the same protocol.

#if IMB_HOST_APP_DECLARES_DUMMY_PROTOCOLS
#define IMB_SHOULD_DECLARE_DUMMY_PROTOCOLS 0
#else
#define IMB_SHOULD_DECLARE_DUMMY_PROTOCOLS	!IMB_COMPILING_WITH_SNOW_LEOPARD_OR_NEWER_SDK
#endif

//----------------------------------------------------------------------------------------------------------------------
