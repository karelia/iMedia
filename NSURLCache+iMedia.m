/*
 iMedia Browser <http://karelia.com/imedia>
 
 Copyright (c) 2005-2007 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 iMedia Browser is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2007 by Karelia Software et al.
 
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


//
// Inspired by some code contributed by Robert Blum <r.blum@gmx.net>
//

// This seems to be somewhat related to what we are doing:
// http://www.cocoabuilder.com/archive/message/cocoa/2003/7/14/73912


#import "NSURLCache+iMedia.h"

//static NSString *sApplicationCachingScheme = @"iMediaCache";

@implementation NSURLCache ( iMedia )

- (void) cacheData:(NSData *)aData userInfo:(NSDictionary *)aUserInfo forPath:(NSString *)aPath;
{
	
	NSURL *cacheURL = [NSURL fileURLWithPath:aPath]; // [[[NSURL alloc] initWithScheme:sApplicationCachingScheme host:@"" path:aPath] autorelease];
	NSURLResponse *response = [[[NSURLResponse alloc] initWithURL:cacheURL
														 MIMEType:@"application/octet-stream"
											expectedContentLength:[aData length]
												 textEncodingName:nil] autorelease];
	NSCachedURLResponse *cachedResponse = [[[NSCachedURLResponse alloc] initWithResponse:response
																					data:aData
																				userInfo:aUserInfo
																		   storagePolicy:NSURLCacheStorageAllowed] autorelease];
	NSURLRequest *request = [NSURLRequest requestWithURL:cacheURL];
	[self storeCachedResponse:cachedResponse forRequest:request];
	
	// TEST
	//
	// Apparently using our own pseudo-URL scheme format is NOT working. When we create a new NSURLRequest, 
	// cachedResponseForRequest returns NIL.  It's as if the URL Request is not matching the original request it was cached with.
	// One possibility may be that our pseudo URL may not consider the two requests to be identical.  Maybe the we need an
	// NSURLProtocol that implements canonicalRequestForRequest:  <http://www.cocoabuilder.com/archive/message/cocoa/2003/7/14/73913>
//	{
//		NSCachedURLResponse *lookupResponse = [self cachedResponseForRequest:request];
//
//		NSURLRequest *request2 = [NSURLRequest requestWithURL:cacheURL];
//		NSCachedURLResponse *lookupResponse2 = [self cachedResponseForRequest:request2];	// shouldn't be NIL!!!!
//
//		NSLog(@"looking up before, then after caching: %@ %@", lookupResponse, lookupResponse2);
//	}
}

- (NSData *)cachedDataForPath:(NSString *)aPath userInfo:(NSDictionary **)outUserInfo;	// will return nil if not cached
{
	NSURL *cacheURL = [NSURL fileURLWithPath:aPath]; // [[[NSURL alloc] initWithScheme:sApplicationCachingScheme host:@"" path:aPath] autorelease];
	NSURLRequest *request = [NSURLRequest requestWithURL:cacheURL];
	NSCachedURLResponse *lookupResponse = [self cachedResponseForRequest:request];
	NSData  *result = [lookupResponse data];
	NSDictionary *userInfo = [lookupResponse userInfo];
	if (outUserInfo)
	{
		*outUserInfo = userInfo;
	}
	
//	if (result)
//		NSLog(@"found data for %@", aPath);
//	else
//		NSLog(@"NOT found..... %@", aPath);
	
	return result;
}

@end
