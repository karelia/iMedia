//
//  IMBFacebookAccessViewController.m
//  iMedia
//
//  Created by Jörg Jacobsen on 08.04.13.
//
//

#import "IMBFacebookAccessController.h"

#define FACEBOOK_APP_ID @"421570721265438"

@interface IMBFacebookAccessController ()

@end

@implementation IMBFacebookAccessController

@synthesize facebook;

- (id)init
{
    self = [super init];
    if (self) {
        self.facebook = [[PhFacebook alloc] initWithApplicationID:FACEBOOK_APP_ID delegate:self];
    }
    return self;
}


#pragma mark
#pragma mark IMBAccessRequester Protocol

//
- (void) requestAccessToNode:(IMBNode *)inNode completion:(IMBRequestAccessCompletionHandler)inCompletion
{
    [self.facebook getAccessTokenForPermissions: [NSArray arrayWithObjects: @"read_stream", @"export_stream", nil] cached: NO];
    
    // JJ/TODO: completion handler would be invoked to early since API is not block- but callback-based. What to do?
}


#pragma mark
#pragma mark PHFacebookdelegate Protocol

//
-(void)tokenResult:(NSDictionary *)result
{
    if ([[result valueForKey: @"valid"] boolValue])
    {
        // Send Token to associated XPC service
        
        // Reload node
    }
    else
    {
        // JJ/TODO: What to do with an error?
        [result valueForKey: @"error"];
    }
}


//
-(void)requestResult:(NSDictionary *)result
{
    
}

@end
