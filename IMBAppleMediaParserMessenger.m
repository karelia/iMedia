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

#import "SBUtilities.h"
#import "NSObject+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "NSImage+iMedia.h"
#import "NSString+iMedia.h"
#import "IMBConfig.h"
#import "IMBAppleMediaParserMessenger.h"
#import "IMBAppleMediaParser.h"
#import "IMBNode.h"
#import "IMBImageObjectViewController.h"
#import "IMBiPhotoEventObjectViewController.h"
#import "IMBFaceObjectViewController.h"


@implementation IMBAppleMediaParserMessenger


// Returns the dispatch-once token. Token must be static. Must be subclassed.

+ (dispatch_once_t *)onceTokenRef
{
	[self imb_throwAbstractBaseClassExceptionForSelector:_cmd];
	return 0;
}

//----------------------------------------------------------------------------------------------------------------------

// Returns the bundle identifier of the associated app. Must be subclassed.

+ (NSString *) bundleIdentifier
{
	[self imb_throwAbstractBaseClassExceptionForSelector:_cmd];
	return nil;
}


// Returns the key for known (iPhoto/Aperture) libraries in com.apple.iApps preferences file. Must be subclassed.

+ (NSString *) preferencesLibraryPathsKey
{
	[self imb_throwAbstractBaseClassExceptionForSelector:_cmd];
	return nil;
}


// Returns the library resource name. Must be subclassed.

+ (NSString *) libraryName
{
	[self imb_throwAbstractBaseClassExceptionForSelector:_cmd];
	return nil;
}


// Check if App is installed (iPhoto or Aperture)

+ (NSString*) appPath
{
	return [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:[self bundleIdentifier]];
}


+ (BOOL) isInstalled
{
	return [self appPath] != nil;
}


+ (BOOL) isEventsNode:(IMBNode *)inNode
{
    return [[inNode.attributes objectForKey:@"nodeType"] isEqual:kIMBiPhotoNodeObjectTypeEvent];
}


+ (BOOL) isFacesNode:(IMBNode *)inNode
{
    return [[inNode.attributes objectForKey:@"nodeType"] isEqual:kIMBiPhotoNodeObjectTypeFace];
}


//----------------------------------------------------------------------------------------------------------------------
// Library root is parent directory of metadata XML file

- (NSURL *)libraryRootURLForMediaSource:(NSURL *)inMediaSource
{
    if (inMediaSource)
    {
        return [inMediaSource URLByDeletingLastPathComponent];
    }
    return [super libraryRootURLForMediaSource:inMediaSource];
}


//----------------------------------------------------------------------------------------------------------------------

#pragma mark
#pragma mark Parser instantiation

// Designated factory method for creating parsers

- (IMBAppleMediaParser *)newParserWithMediaSource:(NSURL *)inMediaSource
{
    Class messengerClass = [self class];
    IMBAppleMediaParser *parser = (IMBAppleMediaParser *)[super newParser];
    
    // All parsers are kept in static list
    
    [[messengerClass parsers] addObject:parser];
    [parser release];
    
    if (inMediaSource)
    {
        NSString* path = [inMediaSource path];
        parser.identifier = [NSString stringWithFormat:@"%@:/%@", [[self class] identifier], path];
        parser.mediaType = self.mediaType;
        parser.mediaSource = inMediaSource;
        parser.appPath = [messengerClass appPath];
    }
    return parser;
}


- (IMBParser *)newParser
{
    return [self newParserWithMediaSource:nil];
}



//----------------------------------------------------------------------------------------------------------------------
// This method is called on the XPC service side. Discover the path to the AlbumData.xml file and create  
// an IMBParser instance preconfigured with that path...

- (NSArray*) parserInstancesWithError:(NSError**)outError
{
    Class messengerClass = [self class];
    NSMutableArray *parsers = [messengerClass parsers];
    dispatch_once([messengerClass onceTokenRef],
	^{
		if ([messengerClass isInstalled])
		{
			CFArrayRef recentLibraries = SBPreferencesCopyAppValue(
											(CFStringRef)[messengerClass preferencesLibraryPathsKey],
											(CFStringRef)@"com.apple.iApps");

			// We decided it's a better user experience to only provide the most recently used library.
			// Most recently used library currently always stored at index 0 in library list.
			// (But still leave the code in place to be able to easily switch back to providing all known libraries)

			NSArray* libraries;
			if ([(NSArray*)recentLibraries count] > 0)
			{
				libraries = [NSArray arrayWithObject:[(NSArray*)recentLibraries objectAtIndex:0]];
			} else {
				libraries = [NSArray array];
			}

			for (NSString* library in libraries)
			{
				NSURL* url = [NSURL URLWithString:library];
				NSString* path = [url path];

				NSFileManager *fileManager = [[NSFileManager alloc] init];

				IMBAppleMediaParser* parser = [self newParserWithMediaSource:url];
				parser.shouldDisplayLibraryName = [libraries count] > 1;
				  
				//NSLog(@"%@ uses library: %@", [parser class], path);
				  
				// Exclude enclosing folder from being displayed by IMBFolderParser...
				  
				NSString* libraryPath = [path stringByDeletingLastPathComponent];
				[IMBConfig registerLibraryPath:libraryPath];

				[fileManager release];
			}
			if (recentLibraries) CFRelease(recentLibraries);
		}
	});
	
    // Every parser must have its current parser messenger set
    
    [self setParserMessengerForParsers];
    
	return (NSArray*)parsers;
}


#pragma mark -
#pragma mark Object description


+ (NSString*) objectCountFormatSingular
{
	return [IMBImageObjectViewController objectCountFormatSingular];
}


+ (NSString*) objectCountFormatPlural
{
	return [IMBImageObjectViewController objectCountFormatPlural];
}


//----------------------------------------------------------------------------------------------------------------------
// Events and Faces have other metadata than images or movies

- (NSString*) _countableMetadataDescriptionForMetadata:(NSDictionary*)inMetadata
{
	NSMutableString* metaDesc = [NSMutableString string];
	
	NSNumber* count = [inMetadata objectForKey:@"PhotoCount"];
	if (count)
	{
		NSString* formatString = [count intValue] > 1 ?
		[[self class] objectCountFormatPlural] :
		[[self class] objectCountFormatSingular];
		
		[metaDesc appendFormat:formatString, [count intValue]];
	}
	
	NSNumber* dateAsTimerInterval = [inMetadata objectForKey:@"RollDateAsTimerInterval"];
	if (dateAsTimerInterval)
	{
		[metaDesc imb_appendNewline];
		NSDate* eventDate = [NSDate dateWithTimeIntervalSinceReferenceDate:[dateAsTimerInterval doubleValue]];
		
		NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
		[formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
		[formatter setDateStyle:NSDateFormatterMediumStyle];	// medium date
		
		[metaDesc appendFormat:@"%@", [formatter stringFromDate:eventDate]];
		
		[formatter release];
	}
	return metaDesc;
}


//----------------------------------------------------------------------------------------------------------------------
// Convert metadata into a human readable string...

- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata
{
	// Events and Faces have other metadata than images
	
	if ([inMetadata objectForKey:@"PhotoCount"])		// Event, face, ...
	{
		return [self _countableMetadataDescriptionForMetadata:inMetadata];
	}
	
	// Image
	return [NSImage imb_imageMetadataDescriptionForMetadata:inMetadata];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark -
#pragma mark Custom view controller support

- (NSViewController*) customObjectViewControllerForNode:(IMBNode*)inNode
{
    // Use custom view for events
    
    if ([[self class] isEventsNode:inNode])
    {
        NSViewController* viewController = [[[IMBiPhotoEventObjectViewController alloc] init] autorelease];
        return viewController;
    }
    
    if ([[self class] isFacesNode:inNode])
    {
        NSViewController* viewController = [[[IMBFaceObjectViewController alloc] init] autorelease];
        return viewController;
    }
    
    return [super customObjectViewControllerForNode:inNode];
}

@end
