//
//  NSURLCache+iMedia.h
//  iMediaBrowse
//
//  Created by Dan Wood on 2/16/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSURLCache ( iMedia )

- (void) cacheData:(NSData *)aData userInfo:(NSDictionary *)aUserInfo forPath:(NSString *)aPath;

- (NSData *)cachedDataForPath:(NSString *)aPath userInfo:(NSDictionary **)outUserInfo;	// will return nil if not cached

@end
