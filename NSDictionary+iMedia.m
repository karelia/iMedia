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
 
 This file was authored by Dan Wood and Terrence Talbot. 
 
 NOTE: THESE METHODS ARE SIMILAR OR IDENTICAL TO METHODS IN SANDVOX.
 PLEASE BE SURE TO "SYNC" THEM UP IF ANY FIXES ARE MADE HERE.
 */


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "NSDictionary+iMedia.h"

#import "NSString+iMedia.h"

#import "IMBTimecodeTransformer.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation NSDictionary (iMedia)


//----------------------------------------------------------------------------------------------------------------------


// This method is useful for sorting images by image size, provided that the metadata dictionary contains  
// width and height values...
//
// This method is invoked by bindings in IMBImageView.xib

- (NSComparisonResult) imb_metadataSizeCompare:(NSDictionary*)inDictionary
{
	NSInteger w1 = [[self objectForKey:@"width"] integerValue];
	NSInteger h1 = [[self objectForKey:@"height"] integerValue];
	NSInteger s1 = w1 * h1;

	NSInteger w2 = [[inDictionary objectForKey:@"width"] integerValue];
	NSInteger h2 = [[inDictionary objectForKey:@"height"] integerValue];
	NSInteger s2 = w2 * h2;
	
	if (s1 == s2) return NSOrderedSame;
	else if (s1 < s2) return NSOrderedAscending;
	else return NSOrderedDescending;
}


//----------------------------------------------------------------------------------------------------------------------

+ (NSString*)imb_metadataDescriptionForMovieMetadata:(NSDictionary*)inMetadata
{
	NSMutableString* description = [NSMutableString string];
	NSNumber* duration = [inMetadata objectForKey:@"duration"];
	NSNumber* width = [inMetadata objectForKey:@"width"];
	NSNumber* height = [inMetadata objectForKey:@"height"];
	NSString *path = [inMetadata objectForKey:@"path"];
	NSString *comment = [inMetadata objectForKey:@"comment"];
	if (comment) comment = [comment stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	NSString* type = [inMetadata objectForKey:@"ImageType"];		// like MooV
	NSString* UTI = nil;

	if (type != nil) {
		UTI = [NSString imb_UTIForFileType:type];
	}
	
	if (UTI == nil) {
		UTI = [NSString imb_UTIForFileAtPath:path];
	}
	
	NSString *kind = [NSString imb_descriptionForUTI:UTI];
	
	if (kind)
	{
		if (description.length > 0) [description imb_appendNewline];
		[description appendString:kind];
	}
	
	if (width != nil && height != nil)
	{
		if (description.length > 0) [description imb_appendNewline];
		[description appendFormat:@"%@×%@",width,height];
	}
	
	if (duration)
	{
		NSString* durationLabel = NSLocalizedStringWithDefaultValue(
																	@"Time",
																	nil,IMBBundle(),
																	@"Time",
																	@"Time label in metadataDescription");
		
		NSValueTransformer *timecodeTransformer = [NSValueTransformer valueTransformerForName:NSStringFromClass([IMBTimecodeTransformer class])];
		NSString* durationString = [timecodeTransformer transformedValue:duration];
		if (description.length > 0) [description imb_appendNewline];
		[description appendFormat:@"%@: %@",durationLabel,durationString];
	}
	
	if (comment && ![comment isEqualToString:@""])
	{
		NSString* commentLabel = NSLocalizedStringWithDefaultValue(
																   @"Comment",
																   nil,IMBBundle(),
																   @"Comment",
																   @"Comment label in metadataDescription");
		
		if (description.length > 0) [description imb_appendNewline];
		[description appendFormat:@"%@: %@",commentLabel,comment];
	}
	
	return description;
}	

+ (NSString*)imb_metadataDescriptionForAudioMetadata:(NSDictionary*)inMetadata
{
	NSMutableString* description = [NSMutableString string];
	NSNumber* duration = [inMetadata objectForKey:@"duration"];
	NSString* artist = [inMetadata objectForKey:@"artist"];
	NSString* album = [inMetadata objectForKey:@"album"];
	NSString* comment = [inMetadata objectForKey:@"Comments"];
	if (comment) comment = [comment stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSString* kind = [inMetadata objectForKey:@"Kind"];
	NSNumber* width = [inMetadata objectForKey:@"Video Width"];
	NSNumber* height = [inMetadata objectForKey:@"Video Height"];
	NSNumber* hasVideo = [inMetadata objectForKey:@"Has Video"];
	
	if (hasVideo)
	{
		if (kind)
		{
			// Note: This "kind" will be a bit different from others, since it comes from dictionary.
			// Thus we see "QuickTime movie file" rather than "QuickTime Movie" from other parsers,
			// which gets the UTI description from the file.
			if (description.length > 0) [description imb_appendNewline];
			[description appendString:kind];
		}
		
		if (width != nil && height != nil)
		{
			if (description.length > 0) [description imb_appendNewline];
			[description appendFormat:@"%@×%@",width,height];
		}
	}
	else
	{
		if (artist)
		{
			NSString* artistLabel = NSLocalizedStringWithDefaultValue(
																	  @"Artist",
																	  nil,IMBBundle(),
																	  @"Artist",
																	  @"Artist label in metadataDescription");
			
			if (description.length > 0) [description imb_appendNewline];
			[description appendFormat:@"%@: %@",artistLabel,artist];
		}
		
		if (album)
		{
			NSString* albumLabel = NSLocalizedStringWithDefaultValue(
																	 @"Album",
																	 nil,IMBBundle(),
																	 @"Album",
																	 @"Album label in metadataDescription");
			
			if (description.length > 0) [description imb_appendNewline];
			[description appendFormat:@"%@: %@",albumLabel,album];
		}
	}
	
	if (duration)
	{
		NSString* durationLabel = NSLocalizedStringWithDefaultValue(
																	@"Time",
																	nil,IMBBundle(),
																	@"Time",
																	@"Time label in metadataDescription");
		
		NSValueTransformer *timecodeTransformer = [NSValueTransformer valueTransformerForName:NSStringFromClass([IMBTimecodeTransformer class])];
		NSString* durationString = [timecodeTransformer transformedValue:duration];
		if (description.length > 0) [description imb_appendNewline];
		[description appendFormat:@"%@: %@",durationLabel,durationString];
	}
	
	if (comment && ![comment isEqualToString:@""])
	{
		NSString* commentLabel = NSLocalizedStringWithDefaultValue(
																   @"Comment",
																   nil,IMBBundle(),
																   @"Comment",
																   @"Comment label in metadataDescription");
		
		if (description.length > 0) [description imb_appendNewline];
		[description appendFormat:@"%@: %@",commentLabel,comment];
	}
	
	return description;
}

@end


@implementation NSMutableDictionary (iMedia)

- (void) imb_safeSetObject:(id)inObject forKey:(id)inKey
{
	if (inObject != nil) {
		[self setObject:inObject forKey:inKey];
	}
	else {
		[self removeObjectForKey:inKey];
	}
}

@end
