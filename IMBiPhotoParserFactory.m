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

#import "IMBiPhotoParserFactory.h"
#import "IMBiPhotoImageParser.h"
#import "IMBiPhotoMovieParser.h"
#import "IMBParserController.h"
#import "NSWorkspace+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "IMBConfig.h"

#import "SBUtilities.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Specify parameters for image subclass and register it...
 
@implementation IMBiPhotoImageParserFactory

+ (NSString*) mediaType
{
	return kIMBMediaTypeImage;
}

+ (Class) parserClass
{
	return [IMBiPhotoImageParser class];
}
					
+ (NSString*) identifier
{
	return @"com.karelia.imedia.iPhoto.image";
}

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserFactoryClass:self forMediaType:[self mediaType]];
	[pool drain];
}

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Specify parameters for movie subclass and register it...
 
@implementation IMBiPhotoMovieParserFactory

+ (NSString*) mediaType
{
	return kIMBMediaTypeMovie;
}

+ (Class) parserClass
{
	return [IMBiPhotoMovieParser class];
}
						
+ (NSString*) identifier
{
	return @"com.karelia.imedia.iPhoto.movie";
}

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserFactoryClass:self forMediaType:[self mediaType]];
	[pool drain];
}

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBiPhotoParserFactory


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


// Check if iPhoto is installed...

- (NSString*) iPhotoPath
{
	return [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.iPhoto"];
}


- (BOOL) isInstalled
{
	return [self iPhotoPath] != nil;
}


// This method is called on the XPC service side. Discover the path to the AlbumData.xml file and create  
// an IMBParser instance preconfigured with that path...

- (NSArray*) parserInstancesWithError:(NSError**)outError
{
	NSMutableArray* parsers = [NSMutableArray array];;
	
	if ([self isInstalled])
	{
		CFArrayRef recentLibraries = SBPreferencesCopyAppValue((CFStringRef)@"iPhotoRecentDatabases",(CFStringRef)@"com.apple.iApps");
		NSArray* libraries = (NSArray*)recentLibraries;
		
		for (NSString* library in libraries)
		{
			NSURL* url = [NSURL URLWithString:library];
			NSString* path = [url path];
			BOOL changed;
			
			if ([[NSFileManager imb_threadSafeManager] imb_fileExistsAtPath:&path wasChanged:&changed])
			{
				// Create a parser instance preconfigure with that path...
				
				Class parserClass = [[self class] parserClass];
				IMBiPhotoParser* parser = [[parserClass alloc] init];
				
				parser.identifier = [NSString stringWithFormat:@"%@/%@",[[self class] identifier],path];
				parser.mediaType = self.mediaType;
				parser.mediaSource = [NSURL fileURLWithPath:path];
				parser.appPath = self.iPhotoPath;
				
				[parsers addObject:parser];
				[parser release];

				// Exclude enclosing folder from being displayed by IMBFolderParser...
				
				NSString* libraryPath = [path stringByDeletingLastPathComponent];
				[IMBConfig registerLibraryPath:libraryPath];
			}
		}
	}
	
	return (NSArray*)parsers;
}


//----------------------------------------------------------------------------------------------------------------------


@end

