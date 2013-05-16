//
//  IMBFacebookParserMessenger.h
//  iMedia
//
//  Created by Jörg Jacobsen on 12.03.13.
//
//

#import <iMedia/iMedia.h>

@class PhFacebook;

@interface IMBFacebookParserMessenger : IMBParserMessenger

// Set Facebook accessor object on parser for subsequent use

- (void) setFacebookAccessor:(PhFacebook *)facebook error:(NSError **)outError;

@end
