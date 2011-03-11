/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2011 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2011 by Karelia Software et al.
 
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


#pragma mark HEADERS

#import "IMBConfig.h"
#import "IMBCommon.h"
#import "NSWorkspace+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

static NSString* sIMBPrefsKeyFormat = @"iMedia2_%@";
static NSString* sIMBShowsGroupNodesKey = @"showsGroupNodes";
//static NSString* sIMBUseGlobalViewTypeKey = @"useGlobalViewType";
static NSString* sIMBDownloadFolderPathKey = @"downloadFolderPath";
static NSString* sIMBViewerAppPathsKey = @"viewerAppPaths";
static NSString* sIMBEditorAppPathsKey = @"editorAppPaths";
static NSString* sIMBFlickrDownloadSizeKey = @"flickrDownloadSize";

static BOOL sUseGlobalViewType = NO;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBConfig


//----------------------------------------------------------------------------------------------------------------------


// Low level accessors for preferences values...

+ (void) registerDefaultPrefsValue:(id)inValue forKey:(NSString*)inKey
{
	NSString* key = [NSString stringWithFormat:sIMBPrefsKeyFormat,inKey];
	NSDictionary* defaults = [NSDictionary dictionaryWithObjectsAndKeys:inValue,key,nil];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}


+ (void) setPrefsValue:(id)inValue forKey:(NSString*)inKey
{
	NSString* key = [NSString stringWithFormat:sIMBPrefsKeyFormat,inKey];
	
	if (inValue)
		[[NSUserDefaults standardUserDefaults] setObject:inValue forKey:key];
	else
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
}


+ (id) prefsValueForKey:(NSString*)inKey
{
	NSString* key = [NSString stringWithFormat:sIMBPrefsKeyFormat,inKey];
	return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}


//----------------------------------------------------------------------------------------------------------------------


// Store the specified dictionary in the iMedia section of the preferences under its class name...

+ (void) registerDefaultPrefs:(NSMutableDictionary*)inClassDict forClass:(Class)inClass
{
	[self registerDefaultPrefsValue:inClassDict forKey:NSStringFromClass(inClass)];
}


// Store the specified dictionary in the iMedia section of the preferences under its class name...

+ (void) setPrefs:(NSMutableDictionary*)inClassDict forClass:(Class)inClass
{
	[self setPrefsValue:inClassDict forKey:NSStringFromClass(inClass)];
}


// Return a mutable copy of the class specific preference dictionary. If it doesn't exist yet, then return an
// empty dictionary...

+ (NSMutableDictionary*) prefsForClass:(Class)inClass
{
	return [NSMutableDictionary dictionaryWithDictionary:[self prefsValueForKey:NSStringFromClass(inClass)]];
}


//----------------------------------------------------------------------------------------------------------------------


// Determines whether the group nodes (LIBRARIES, FOLDERS, INTERNET, DEVICES) are visible in the outline view...

+ (void) setShowsGroupNodes:(BOOL)inState
{
	[self setPrefsValue:[NSNumber numberWithBool:inState] forKey:sIMBShowsGroupNodesKey];
}


+ (BOOL) showsGroupNodes
{
	return [[self prefsValueForKey:sIMBShowsGroupNodesKey] boolValue];
}


//----------------------------------------------------------------------------------------------------------------------


+ (void) setUseGlobalViewType:(BOOL)inState
{
	sUseGlobalViewType = inState;
}


+ (BOOL) useGlobalViewType
{
	return sUseGlobalViewType;
}


//----------------------------------------------------------------------------------------------------------------------


// Make global view type preference value an observable property

+ (void) setGlobalViewType:(NSNumber*)viewType
{
	NSString* key = @"globalViewType";
	[self willChangeValueForKey:key];
	[self setPrefsValue:viewType forKey:key];
	[self didChangeValueForKey:key];
}


+ (NSNumber*) globalViewType
{
	return (NSNumber*) [self prefsValueForKey:@"globalViewType"];
}


//----------------------------------------------------------------------------------------------------------------------


// Sets the path to the download folder. Default is ~/Downloads...

+ (void) setDownloadFolderPath:(NSString*)inPath
{
	[self setPrefsValue:inPath forKey:sIMBDownloadFolderPathKey];
}


+ (NSString*) downloadFolderPath
{
	return [self prefsValueForKey:sIMBDownloadFolderPathKey];
}

//----------------------------------------------------------------------------------------------------------------------


+ (void) setFlickrDownloadSize:(IMBFlickrSizeSpecifier)inFlickrSize;
{
	[self setPrefsValue:[NSNumber numberWithInt:inFlickrSize] forKey:sIMBFlickrDownloadSizeKey];
}


+ (IMBFlickrSizeSpecifier) flickrDownloadSize
{
	return [[self prefsValueForKey:sIMBFlickrDownloadSizeKey] intValue];
}

//----------------------------------------------------------------------------------------------------------------------


// Path to an external viewer app. Defaults to Preview for images and QuickTime Player for audio/video content...

+ (void) setViewerApp:(NSString*)inAppPath forMediaType:(NSString*)inMediaType
{
	NSMutableDictionary* viewerAppPaths = [NSMutableDictionary dictionaryWithDictionary:[self prefsValueForKey:sIMBViewerAppPathsKey]];
	if (inAppPath) [viewerAppPaths setObject:inAppPath forKey:inMediaType];
	[self setPrefsValue:viewerAppPaths forKey:sIMBViewerAppPathsKey];
}


+ (NSString*) viewerAppForMediaType:(NSString*)inMediaType
{
	NSDictionary* viewerAppPaths = [self prefsValueForKey:sIMBViewerAppPathsKey];
	return [viewerAppPaths objectForKey:inMediaType];
}


//----------------------------------------------------------------------------------------------------------------------


// Path to an external editor app. May not be available for all media types...

+ (void) setEditorApp:(NSString*)inAppPath forMediaType:(NSString*)inMediaType
{
	NSMutableDictionary* editorAppPaths = [NSMutableDictionary dictionaryWithDictionary:[self prefsValueForKey:sIMBEditorAppPathsKey]];
	if (inAppPath) [editorAppPaths setObject:inAppPath forKey:inMediaType];
	[self setPrefsValue:editorAppPaths forKey:sIMBEditorAppPathsKey];
}


+ (NSString*) editorAppForMediaType:(NSString*)inMediaType
{
	NSDictionary* editorAppPaths = [self prefsValueForKey:sIMBEditorAppPathsKey];
	return [editorAppPaths objectForKey:inMediaType];
}


//----------------------------------------------------------------------------------------------------------------------


// Set default preferences values...

+ (void) registerDefaultValues
{
	NSString* path = [NSHomeDirectory() stringByAppendingPathComponent:@"Downloads"];	// brute force fallback
	NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory,NSUserDomainMask,YES);
	if ([paths count] > 0) path = [paths objectAtIndex:0];
	
	[self registerDefaultPrefsValue:[NSNumber numberWithBool:YES] forKey:sIMBShowsGroupNodesKey];
	[self registerDefaultPrefsValue:path forKey:sIMBDownloadFolderPathKey];
	[self registerDefaultPrefsValue:[NSNumber numberWithInt:kIMBFlickrSizeSpecifierLarge] forKey:sIMBFlickrDownloadSizeKey];

	NSString* preview = [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.Preview"];
	NSString* qtplayerx = [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.QuickTimePlayerX"];
	NSString* safari = [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.Safari"];
	NSString* addressbook = [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.AddressBook"];
	NSString* photoshop = [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:@"com.adobe.Photoshop"];

	NSMutableDictionary* viewerAppPaths = [NSMutableDictionary dictionary];
	if (preview) [viewerAppPaths setObject:preview forKey:kIMBMediaTypeImage];
	if (qtplayerx) [viewerAppPaths setObject:qtplayerx forKey:kIMBMediaTypeAudio];
	if (qtplayerx) [viewerAppPaths setObject:qtplayerx forKey:kIMBMediaTypeMovie];
	if (safari) [viewerAppPaths setObject:safari forKey:kIMBMediaTypeLink];
	if (addressbook) [viewerAppPaths setObject:addressbook forKey:kIMBMediaTypeContact];
	[self registerDefaultPrefsValue:viewerAppPaths forKey:sIMBViewerAppPathsKey];

	NSMutableDictionary* editorAppPaths = [NSMutableDictionary dictionary];
	if (photoshop) [editorAppPaths setObject:photoshop forKey:kIMBMediaTypeImage];
	[self registerDefaultPrefsValue:editorAppPaths forKey:sIMBEditorAppPathsKey];
}

+ (void)load		// register default values automatically
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[self registerDefaultValues];
	[pool drain];
}

//----------------------------------------------------------------------------------------------------------------------

/*
	Library paths.  Each parser should register any path of a library that it uses, so that other parser
	(e.g. folder parser, spotlight parser, etc.) can exclude that path from showing up in the source list.
 
 */

static NSMutableSet *sLibraryPaths = nil;

+ (void)registerLibraryPath:(NSString *)aPath
{
	if (nil == sLibraryPaths)
	{
		sLibraryPaths = [NSMutableSet new];
	}
	[sLibraryPaths addObject:aPath];
}

+ (BOOL) isLibraryPath:(NSString *)aPath
{
	return [sLibraryPaths containsObject:aPath];
}

// Future: We may need a method that loops through the library paths and asks if the given
// path is a subpath of any of these paths.


//----------------------------------------------------------------------------------------------------------------------



@end
 