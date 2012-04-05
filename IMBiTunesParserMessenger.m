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


// Author: Peter Baumgartner, Jörg Jacobsen


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBiTunesParserMessenger.h"
#import "IMBiTunesAudioParser.h"
#import "IMBiTunesMovieParser.h"
#import "IMBParserController.h"
#import "NSWorkspace+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "IMBConfig.h"
#import "IMBCommon.h"
#import "SBUtilities.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark GLOBALS

static NSMutableArray* sParsers = nil;
static dispatch_once_t sOnceToken = 0;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBiTunesParserMessenger


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if ((self = [super init]))
	{
		self.mediaSource = nil;	// Will be discovered in XPC service
		self.mediaType = [[self class] mediaType];
		self.isUserAdded = NO;
	}
	
	return self;
}


- (void) dealloc
{
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


// Check if iTunes is installed...

- (NSString*) iTunesPath
{
	return [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.iTunes"];
}


- (BOOL) isInstalled
{
	return [self iTunesPath] != nil;
}


//----------------------------------------------------------------------------------------------------------------------


// This method is called on the XPC service side. Discover the path to the iTunesLibrary.xml file and create  
// an IMBParser instance preconfigured with that path...

- (NSArray*) parserInstancesWithError:(NSError**)outError
{
    dispatch_once(&sOnceToken,
    ^{
		if ([self isInstalled])
		{
			CFArrayRef recentLibraries = SBPreferencesCopyAppValue((CFStringRef)@"iTunesRecentDatabases",(CFStringRef)@"com.apple.iApps");
			NSArray* libraries = (NSArray*)recentLibraries;
			sParsers = [[NSMutableArray alloc] initWithCapacity:libraries.count];
			
			for (NSString* library in libraries)
			{
				NSURL* url = [NSURL URLWithString:library];
				NSString* path = [url path];
				BOOL changed;
				
				if ([[NSFileManager imb_threadSafeManager] imb_fileExistsAtPath:&path wasChanged:&changed])
				{
					// Create a parser instance preconfigure with that path...
					
					IMBiTunesAudioParser* parser = (IMBiTunesAudioParser*)[self newParser];
					parser.identifier = [NSString stringWithFormat:@"%@:/%@",[[self class] identifier],path];
					parser.mediaType = self.mediaType;
					parser.mediaSource = url;
					parser.appPath = self.iTunesPath;
					parser.shouldDisplayLibraryName = libraries.count > 1;

					[sParsers addObject:parser];
					[parser release];

					// Exclude enclosing folder from being displayed by IMBFolderParser...
					
					NSString* libraryPath = [path stringByDeletingLastPathComponent];
					[IMBConfig registerLibraryPath:libraryPath];
				}
			}
		}
	});

	return (NSArray*)sParsers;
}


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Specify parameters for image subclass and register it...
 
@implementation IMBiTunesAudioParserMessenger

+ (NSString*) mediaType
{
	return kIMBMediaTypeAudio;
}

+ (NSString*) parserClassName
{
	return @"IMBiTunesAudioParser";
}
					
+ (NSString*) identifier
{
	return @"com.karelia.imedia.iTunes";
}

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserMessengerClass:self forMediaType:[self mediaType]];
	[pool drain];
}

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Specify parameters for movie subclass and register it...
 
@implementation IMBiTunesMovieParserMessenger

+ (NSString*) mediaType
{
	return kIMBMediaTypeMovie;
}

+ (NSString*) parserClassName
{
	return @"IMBiTunesMovieParser";
}
						
+ (NSString*) identifier
{
	return @"com.karelia.imedia.iTunes";
}

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserMessengerClass:self forMediaType:[self mediaType]];
	[pool drain];
}

@end


//----------------------------------------------------------------------------------------------------------------------

