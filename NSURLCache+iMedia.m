//
//  NSURLCache+iMedia.m
//  iMediaBrowse
//
//  Created by Dan Wood on 2/16/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//
// Inspired by some code contributed by Robert Blum <r.blum@gmx.net>
//
// This seems to be somewhat related to what we are doing:
// http://www.cocoabuilder.com/archive/message/cocoa/2003/7/14/73912
//

#import "NSURLCache+iMedia.h"

static NSString *sApplicationCachingScheme = @"iMediaCache";

@implementation NSURLCache ( iMedia )

- (void) cacheData:(NSData *)aData forPath:(NSString *)aPath;
{
	
	NSURL *cacheURL = [NSURL fileURLWithPath:aPath]; // [[[NSURL alloc] initWithScheme:sApplicationCachingScheme host:@"" path:aPath] autorelease];
	NSURLResponse *response = [[[NSURLResponse alloc] initWithURL:cacheURL
														 MIMEType:@"application/octet-stream"
											expectedContentLength:[aData length]
												 textEncodingName:nil] autorelease];
	NSCachedURLResponse *cachedResponse = [[[NSCachedURLResponse alloc] initWithResponse:response data:aData] autorelease];
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

- (NSData *)cachedDataForPath:(NSString *)aPath;	// will return nil if not cached
{
	NSURL *cacheURL = [NSURL fileURLWithPath:aPath]; // [[[NSURL alloc] initWithScheme:sApplicationCachingScheme host:@"" path:aPath] autorelease];
	NSURLRequest *request = [NSURLRequest requestWithURL:cacheURL];
	NSCachedURLResponse *lookupResponse = [self cachedResponseForRequest:request];
	NSData  *result = [lookupResponse data];
	
//	if (result)
//		NSLog(@"found data for %@", aPath);
//	else
//		NSLog(@"NOT found..... %@", aPath);
	
	return result;
}

@end
