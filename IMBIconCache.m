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


// Author: Unknown


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBIconCache.h"
#import "IMBCommon.h"
#import "NSImage+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


static IMBIconCache* sSharedIconCache;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBIconCache


//----------------------------------------------------------------------------------------------------------------------


+ (IMBIconCache*) sharedIconCache
{
	@synchronized(self)
	{
		if (sSharedIconCache == nil)
		{
			sSharedIconCache = [[IMBIconCache alloc] init];
		}
	}
	
	return sSharedIconCache;
}


- (id) init
{
	if (self = [super init])
	{
		_iconCache = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_iconCache);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


- (NSImage*) __loadIconForType:(NSString*)name fromBundleID:(NSString*)bundleID withMappingTable:(const IMBIconTypeMapping*)mappingTable highlight:(BOOL)inHighlight
{
	if ((name != nil) && (bundleID != nil) && (mappingTable != NULL))
	{
		unsigned int iconIndex;

		// iterate over the entries in the table...
		for (iconIndex = 0; iconIndex < mappingTable->fCount; iconIndex++)
		{
			const IMBIconTypeMappingEntry* entry = &mappingTable->fEntries[iconIndex];

			// check for a match with the current entry's icon type
			if ([name isEqualToString:entry->fIconType])
			{
                // Highlight icon name is derivable
                
                NSString* effectiveIconName = entry->fApplicationIconName;
                NSString* effectiveFallbackIconName = entry->fFallbackIconName;
                if (inHighlight && mappingTable->fHighlightPostfix)
                {
                    effectiveIconName = [entry->fApplicationIconName stringByAppendingString:mappingTable->fHighlightPostfix];
                    
                    if (entry->fFallbackIconName) {
                        effectiveFallbackIconName = [entry->fFallbackIconName stringByAppendingString:mappingTable->fHighlightPostfix];
                    }
                }
                
				// first try to find the specified image in the application bundle associated with the parser
				NSImage* image = [NSImage imb_imageForResource:effectiveIconName
											 fromAppWithBundleIdentifier:bundleID
												  fallbackName:effectiveFallbackIconName];
                
                if (image) {
                    NSLog(@"Loaded image %@", effectiveIconName);
                } else {
                    NSLog(@"Could not load image %@", effectiveIconName);
                }

				// if the image doesn't exist, try using another image at a specific location (but not for highlight icon)
				if ((image == nil) && (entry->fAlternateBundlePath != nil) && !inHighlight)
				{
					NSBundle* bundle = [NSBundle bundleWithPath:entry->fAlternateBundlePath];
					NSString* path = [bundle pathForResource:entry->fAlternateIconName ofType:nil];

					image = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
					[image setSize:NSMakeSize(16.0,16.0)];
				}

				if (image != nil)
					return image;
			}
		}

		// if no type-specific image was found, use the fallback image (but not for highlight icon)
        if (!inHighlight)
        {
            return [NSImage imb_imageForResource:mappingTable->fUnknownTypeEntry.fApplicationIconName
                     fromAppWithBundleIdentifier:bundleID
                                    fallbackName:mappingTable->fUnknownTypeEntry.fFallbackIconName];
        }
	}

	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


- (NSImage*) iconForType:(NSString*)inType fromBundleID:(NSString*)inBundleID withMappingTable:(const IMBIconTypeMapping*)inMappingTable highlight:(BOOL)inHighlight
{
	NSImage* image = nil;

	if (inType != nil)
	{
		@synchronized(self)
		{
            NSString* typeKey = inType;
            if (inHighlight && inMappingTable->fHighlightPostfix)
            {
                typeKey = [inType stringByAppendingString:inMappingTable->fHighlightPostfix];
            }
            
			NSMutableDictionary* bundleCache = [_iconCache objectForKey:inBundleID];
			
			if (bundleCache == nil)
			{
				bundleCache = [NSMutableDictionary dictionary];
				[_iconCache setObject:bundleCache forKey:inBundleID];
			}

			image = [bundleCache objectForKey:typeKey];
			
			if (image == nil)
			{
				image = [self __loadIconForType:inType
                                   fromBundleID:inBundleID
                               withMappingTable:inMappingTable
                                      highlight:inHighlight];
                
				if (image) [bundleCache setObject:image forKey:typeKey];
				else if(!inHighlight) image = [NSImage imb_sharedGenericFolderIcon];
			}
		}
	}

	return image;
}


//----------------------------------------------------------------------------------------------------------------------


@end
