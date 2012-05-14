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


#pragma mark HEADERS

#import "IMBParserController.h"
#import "IMBParser.h"
#import "IMBApertureParserMessenger.h"


//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Specify parameters for image subclass and register it...

@implementation IMBApertureImageParserMessenger

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserMessengerClass:self forMediaType:[self mediaType]];
	[pool drain];
}

+ (NSString*) mediaType
{
return kIMBMediaTypeImage;
}

+ (NSString*) parserClassName
{
	return @"IMBApertureParser";
}

+ (NSString*) identifier
{
	return @"com.karelia.imedia.Aperture.image";
}


//----------------------------------------------------------------------------------------------------------------------
// Returns the list of parsers this messenger instantiated

+ (NSMutableArray *)parsers
{
    static NSMutableArray *parsers = nil;
    
    if (!parsers) parsers = [[NSMutableArray alloc] init];
    return parsers;
}


//----------------------------------------------------------------------------------------------------------------------
// Returns the dispatch-once token

+ (dispatch_once_t *)onceTokenRef
{
    static dispatch_once_t onceToken = 0;
    
    return &onceToken;
}


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Specify parameters for video subclass and register it...

@implementation IMBApertureVideoParserMessenger

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserMessengerClass:self forMediaType:[self mediaType]];
	[pool drain];
}

+ (NSString*) mediaType
{
	return kIMBMediaTypeMovie;
}

+ (NSString*) parserClassName
{
	return @"IMBApertureVideoParser";
}


+ (NSString*) identifier
{
	return @"com.karelia.imedia.Aperture.movie";
}


//----------------------------------------------------------------------------------------------------------------------
// Returns the list of parsers this messenger instantiated

+ (NSMutableArray *)parsers
{
    static NSMutableArray *parsers = nil;
    
    if (!parsers) parsers = [[NSMutableArray alloc] init];
    return parsers;
}


//----------------------------------------------------------------------------------------------------------------------
// Returns the dispatch-once token

+ (dispatch_once_t *)onceTokenRef
{
    static dispatch_once_t onceToken = 0;
    
    return &onceToken;
}


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Specify parameters for video subclass and register it...

@implementation IMBApertureAudioParserMessenger

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserMessengerClass:self forMediaType:[self mediaType]];
	[pool drain];
}

+ (NSString*) mediaType
{
	return kIMBMediaTypeAudio;
}

+ (NSString*) parserClassName
{
	return @"IMBApertureAudioParser";
}

//----------------------------------------------------------------------------------------------------------------------
// Returns the list of parsers this messenger instantiated

+ (NSMutableArray *)parsers
{
    static NSMutableArray *parsers = nil;
    
    if (!parsers) parsers = [[NSMutableArray alloc] init];
    return parsers;
}


//----------------------------------------------------------------------------------------------------------------------
// Returns the dispatch-once token

+ (dispatch_once_t *)onceTokenRef
{
    static dispatch_once_t onceToken = 0;
    
    return &onceToken;
}


+ (NSString*) identifier
{
	return @"com.karelia.imedia.Aperture.audio";
}

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBApertureParserMessenger


//----------------------------------------------------------------------------------------------------------------------


// Returns the bundle identifier of iPhoto

+ (NSString *) bundleIdentifier
{
	return @"com.apple.Aperture";
}

// Returns the key for Aperture libraries in com.apple.iApps

+ (NSString *) librariesKey
{
	return @"ApertureLibraries";
}


//----------------------------------------------------------------------------------------------------------------------
// Both image and movie use the same xpc service, so override this method...

+ (NSString*) xpcSerivceIdentifier
{
	return @"com.karelia.imedia.Aperture";
}


- (void) dealloc
{
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------

@end
