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


#pragma mark HEADERS

#import "IMBApertureVideoParser.h"
#import "IMBObject.h"
#import "NSDictionary+iMedia.h"
#import "NSURL+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBApertureVideoParser ()

- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBApertureVideoParser


//----------------------------------------------------------------------------------------------------------------------
// Returns the key under which the master resource is found inside its metadata dictionary in ApertureData.xml
// (this key may vary for different media types. Default is the key for image media types).
// Override here for Aperture movies.

+ (NSString *)objectLocationKey
{
    return @"OriginalPath";
}


//----------------------------------------------------------------------------------------------------------------------


// This method must return an appropriate prefix for IMBObject identifiers. Refer to the method
// -[IMBParser iMedia2PersistentResourceIdentifierForObject:] to see how it is used. Historically we used class names as the prefix. 
// However, during the evolution of iMedia class names can change and identifier string would thus also change. 
// This is undesirable, as things that depend of the immutability of identifier strings would break. One such 
// example are the object badges, which use object identifiers. To guarrantee backward compatibilty, a parser 
// class must override this method to return a prefix that matches the historic class name...

- (NSString*) iMedia2PersistentResourceIdentifierPrefix
{
	return @"IMBApertureVideoParser";
}


// Exclude some album types...

//- (BOOL) shouldUseAlbumType:(NSString*)inAlbumType
//{
//	if ([inAlbumType isEqualToString:@"94"]) return NO;
//	if ([inAlbumType isEqualToString:@"97"]) return NO;
////	if ([inAlbumType isEqualToString:@"98"]) return NO;
//	if ([inAlbumType isEqualToString:@"99"]) return NO;
//	return YES;
//}


// Exclude everything but movie files...

- (BOOL) shouldUseObject:(NSString*)inObjectType
{
	return [inObjectType isEqualToString:@"Movie"];
}


//----------------------------------------------------------------------------------------------------------------------


// Loaded lazily when actually needed for display. Here we combine the metadata we got from the Aperture XML file
// (which was available immediately, but not enough information) with more information that we obtain via ImageIO.
// This takes a little longer, but since it only done laziy for those object that are actually visible it's fine.
// Please note that this method may be called on a background thread...

- (void) loadMetadataForObject:(IMBObject*)inObject
{
	NSURL* videoURL = [inObject URL];

	if (videoURL == nil) {
		return;
	}
	
	NSMutableDictionary* metadata = [NSMutableDictionary dictionaryWithDictionary:inObject.preliminaryMetadata];
	
	[metadata setObject:[videoURL path] forKey:@"path"];
	[metadata addEntriesFromDictionary:[NSURL imb_metadataFromVideoAtURL:videoURL]];
	
	NSString* description = [self metadataDescriptionForMetadata:metadata];

	if ([NSThread isMainThread])
	{
		inObject.metadata = metadata;
		inObject.metadataDescription = description;
	}
	else
	{
		NSArray* modes = [NSArray arrayWithObject:NSRunLoopCommonModes];
		[inObject performSelectorOnMainThread:@selector(setMetadata:) withObject:metadata waitUntilDone:NO modes:modes];
		[inObject performSelectorOnMainThread:@selector(setMetadataDescription:) withObject:description waitUntilDone:NO modes:modes];
	}
}


- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata
{
	return [NSDictionary imb_metadataDescriptionForMovieMetadata:inMetadata];
}

//----------------------------------------------------------------------------------------------------------------------


@end
