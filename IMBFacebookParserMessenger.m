//
//  IMBFacebookParserMessenger.m
//  iMedia
//
//  Created by Jörg Jacobsen on 12.03.13.
//
//

#import <PhFacebook/PhFacebook.h>
#import "IMBFacebookParserMessenger.h"
#import "IMBFacebookParser.h"
#import "IMBFacebookAccessController.h"
#import "NSImage+iMedia.h"
#import "SBUtilities.h"

@implementation IMBFacebookParserMessenger

// Use this switch if you want to turn off XPC service usage for this service type
+ (BOOL) useXPCServiceWhenPresent
{
    return YES;
}

+ (void) load {
    @autoreleasepool {
        [IMBParserController registerParserMessengerClass:self forMediaType:[self mediaType]];
    }
}


+ (NSString*) mediaType {
	return kIMBMediaTypeImage;
}


+ (NSString*) parserClassName {
	return @"IMBFacebookParser";
}


+ (NSString*) identifier {
	return @"com.karelia.imedia.Facebook";
}


+ (NSString*) xpcServiceIdentifierPostfix
{
	return @"Facebook";
}


//----------------------------------------------------------------------------------------------------------------------
// Returns the cache of parsers this messenger instantiated

+ (NSMutableArray *)parsers
{
    static NSMutableArray *parsers = nil;
    
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        parsers = [[NSMutableArray alloc] init];
    });
    return parsers;
}


//----------------------------------------------------------------------------------------------------------------------
// Returns the dispatch-once token

+ (dispatch_once_t *)onceTokenRef
{
    static dispatch_once_t onceToken = 0;
    
    return &onceToken;
}


#pragma mark - IMBRequestAccessDelegate Delegate

//----------------------------------------------------------------------------------------------------------------------
// Returns an access requesting controller that will take care of requesting access to Facebook

+ (id <IMBNodeAccessDelegate>) nodeAccessDelegate
{
    return [IMBFacebookAccessController sharedInstance];
}

#pragma mark - Object Lifecycle

#pragma mark - XPC Methods

//----------------------------------------------------------------------------------------------------------------------
// A single facebook parser is created and cached per facebook parser messenger

- (NSArray *)parserInstancesWithError:(NSError **)outError
{
    Class messengerClass = [self class];
    NSMutableArray *parsers = [messengerClass parsers];
    dispatch_once([messengerClass onceTokenRef],
                  ^{
                      IMBFacebookParser *parser = (IMBFacebookParser *)[self newParser];
                      parser.identifier = [messengerClass identifier];
                      parser.mediaType = self.mediaType;
                      parser.mediaSource = self.mediaSource;
                      
                      [parsers addObject:parser];
                      [parser release];
                  });
	return parsers;
}

//----------------------------------------------------------------------------------------------------------------------
// Set Facebook accessor object on parser for subsequent use
// Always returns nil (must match signature required by XPCKit)

- (id) setFacebookAccessor:(PhFacebook *)facebook error:(NSError **)outError
{
    // There is supposed to be only _one_ parser. If that condition no longer holds true
    // we must find other ways to identify the correct parser here.
    
    IMBFacebookParser *parser = [[[self class] parsers] lastObject];
    parser.facebook = facebook;
    
	if (outError) *outError = nil;

//    NSLog(@"Cookies left: %@", [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]);
    
    return nil;
}


//----------------------------------------------------------------------------------------------------------------------
// Always returns nil (must match signature required by XPCKit)

- (id) revokeAccessToNode:(IMBNode *)node error:(NSError **)pError
{
    IMBFacebookParser *parser = (IMBFacebookParser *)[self parserWithIdentifier:node.parserIdentifier];

    return [parser revokeAccessToNode:node error:pError];
}


#pragma mark - Object Description

- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata
{
	return [NSImage imb_imageMetadataDescriptionForMetadata:inMetadata];
}


@end
