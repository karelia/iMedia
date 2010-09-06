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


#pragma mark HEADERS

#import "IMBImageViewController.h"
#import "IMBObjectArrayController.h"
#import "IMBPanelController.h"
#import "IMBCommon.h"
#import "IMBObjectPromise.h"
#import "NSWorkspace+iMedia.h"
#import "IMBFlickrObject.h"
#import "IMBFlickrNode.h"

//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBImageViewController


//----------------------------------------------------------------------------------------------------------------------


+ (void) load
{
	[IMBPanelController registerViewControllerClass:[self class] forMediaType:kIMBMediaTypeImage];
}


- (void) awakeFromNib
{
	[super awakeFromNib];
		 
	ibObjectArrayController.searchableProperties = [NSArray arrayWithObjects:
		@"name",
		nil];
}


//----------------------------------------------------------------------------------------------------------------------


+ (NSString*) mediaType
{
	return kIMBMediaTypeImage;
}

+ (NSString*) nibName
{
	return @"IMBImageView";
}


//----------------------------------------------------------------------------------------------------------------------


- (NSImage*) icon
{
	return [[NSWorkspace threadSafeWorkspace] iconForAppWithBundleIdentifier:@"com.apple.iPhoto"];
}

- (NSString*) displayName
{
	return NSLocalizedStringWithDefaultValue(
		@"IMBImageViewController.displayName",
		nil,IMBBundle(),
		@"Images",
		@"mediaType display name");
}


//----------------------------------------------------------------------------------------------------------------------


+ (NSString*) objectCountFormatSingular
{
	return NSLocalizedStringWithDefaultValue(
		@"IMBImageViewController.countFormatSingular",
		nil,IMBBundle(),
		@"%d image",
		@"Format string for object count in singluar");
}


+ (NSString*) objectCountFormatPlural
{
	return NSLocalizedStringWithDefaultValue(
		@"IMBImageViewController.countFormatPlural",
		nil,IMBBundle(),
		@"%d images",
		@"Format string for object count in plural");
}


//----------------------------------------------------------------------------------------------------------------------

#pragma mark -
#pragma mark ASync download

// Post process.  We use this to embed metadata after the download.
//
// This is really set up for Flickr images, though we may want to generatlize it some day.

- (void) postProcessDownload:(IMBObjectPromise *)promise;
{
	NSDictionary *objectsToLocalURLs = [promise objectsToLocalURLs];
	for (NSDictionary *promiseObject in objectsToLocalURLs)
	{
		if ([promiseObject isKindOfClass:[IMBFlickrObject class]])
		{
			NSURL *localURL = [objectsToLocalURLs objectForKey:promiseObject];
			NSDictionary *metadata = [((IMBFlickrObject *)promiseObject) metadata];
			
			NSURL *shortWebPageURL = [NSURL URLWithString:[@"http://flic.kr/p/" stringByAppendingString:
						[IMBFlickrNode base58EncodedValue:[[metadata objectForKey:@"id"] longLongValue]]]];

			NSString *licenseDescription = [IMBFlickrNode descriptionOfLicense:[[metadata objectForKey:@"license"] intValue]];
			NSString *credit = [metadata objectForKey:@"ownerName"];

			NSMutableData *data = [NSMutableData data];
			CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)localURL, NULL);
			CGImageDestinationRef dest = CGImageDestinationCreateWithData((CFMutableDataRef)data,
																				 (CFStringRef)@"public.jpeg", 1, NULL);

			NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
			if (!appName) appName = [[NSProcessInfo processInfo] processName];
			NSString *appSource = NSNotFound != [appName rangeOfString:@"iMedia"].location
				? appName
				: [NSString stringWithFormat:@"%@, iMedia Browser", appName];

			NSString *creatorAndURL = [NSString stringWithFormat:@"%@ - %@", credit, [shortWebPageURL absoluteString]];
			NSDictionary *IPTCProperties = [NSDictionary dictionaryWithObjectsAndKeys:
				creatorAndURL, kCGImagePropertyIPTCSource,
											licenseDescription, @"UsageTerms", // kCGImagePropertyIPTCRightsUsageTerms not in 10.5 headers
										 appSource, kCGImagePropertyIPTCOriginatingProgram,
										 nil];
			NSDictionary *properties = [NSDictionary dictionaryWithObject:IPTCProperties forKey:(NSString *)kCGImagePropertyIPTCDictionary];
			
			CGImageDestinationAddImageFromSource (dest, source, 0, (CFDictionaryRef) properties);

			BOOL success = CGImageDestinationFinalize(dest); // write metadata into the data object
			if(success)
			{
				// Write back, replacing the original URL with the one with the new metadata
				NSError *error = nil;
				success = [data writeToURL:localURL options:NSAtomicWrite error:&error];
				// Ignore error; atomic write should mean that original is not lost.
			}
			CFRelease(dest);
			CFRelease(source);
		}
	}
}


@end

