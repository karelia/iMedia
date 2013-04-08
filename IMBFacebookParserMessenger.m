//
//  IMBFacebookParserMessenger.m
//  iMedia
//
//  Created by Jörg Jacobsen on 12.03.13.
//
//

#import "IMBFacebookParserMessenger.h"
#import "IMBFacebookParser.h"

@implementation IMBFacebookParserMessenger

// Use this switch if you want to turn off XPC service usage for this service type
+ (BOOL) useXPCServiceWhenPresent
{
    return NO;
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

#pragma mark - Object Lifecycle

#pragma mark - XPC Methods

//----------------------------------------------------------------------------------------------------------------------
// A single facebook parser is created and cached per facebook parser messenger

- (NSArray *) parserInstancesWithError: (NSError **) outError
{
    Class messengerClass = [self class];
    NSMutableArray *parsers = [messengerClass parsers];
    dispatch_once([messengerClass onceTokenRef],
                  ^{
                      IMBFacebookParser *parser = (IMBFacebookParser *)[self newParser];
                      parser.identifier = [[self class] identifier];
                      parser.mediaType = self.mediaType;
                      parser.mediaSource = self.mediaSource;
                      
                      [parsers addObject:parser];
                      [parser release];
                  });
	return parsers;
}




@end
