//
//  IMBFacebookAccessViewController.m
//  iMedia
//
//  Created by Jörg Jacobsen on 08.04.13.
//
//

#import "IMBFacebookAccessController.h"
#import "IMBFacebookParserMessenger.h"
#import "SBUtilities.h"
#import "NSObject+iMedia.h"

@interface IMBFacebookAccessController ()

@end

@implementation IMBFacebookAccessController

@synthesize loginDialogPending=_loginDialogPending;

// Returns a singleton instance of the class

+ (IMBFacebookAccessController *)sharedInstance
{
	static IMBFacebookAccessController  *sSharedInstance = nil;
	static dispatch_once_t sOnceToken = 0;
    
    dispatch_once(&sOnceToken,
                  ^{
                      sSharedInstance = [[IMBFacebookAccessController alloc] init];
                  });
    
 	return sSharedInstance;
}


- (id)init
{
    self = [super init];
    if (self) {
    }
    return self;
}

#pragma mark
#pragma mark IMBNodeAccessDelegate Protocol

// Note that completion block will only be called if currently no other request to access node is pending
//
- (void) nodeViewController:(IMBNodeViewController *)nodeViewController
        requestAccessToNode:(IMBNode *)node
                 completion:(IMBRequestAccessCompletionHandler)completion
{
    if (self.isLoginDialogPending && completion) {
        completion(YES, nil, nil);
    } else {
        @synchronized(self)
        {
            self.loginDialogPending = YES;
            node.badgeTypeNormal = kIMBBadgeTypeLoading;
            
            NSString *facebookAppId = nil;
            if ([nodeViewController.delegate respondsToSelector:@selector(facebookAppId)]) {
                facebookAppId = [nodeViewController.delegate facebookAppId];
            }
            // Fallback only for development convenience! (Get if from key chain)
            if (facebookAppId == nil) {
                facebookAppId = [self facebookAppId];
            }
            if (facebookAppId == nil) {
                [self imb_throwProgrammerErrorExceptionWithReason:@"No Facebook app id provided. Should be provided by node view controller delegate."];
            }
            
            PhFacebook *facebook = [[PhFacebook alloc] initWithApplicationID:facebookAppId delegate:self];
            
            NSRect rect = NSMakeRect(0.0, 0.0, 0.0, 0.0);
            NSView *rectParentView = nil;
            
            if (nodeViewController)
            {
                IMBOutlineView *outlineView = nodeViewController.nodeOutlineView;
                NSInteger row = [outlineView rowForItem:node];
                rect = [outlineView badgeRectForRow:row];
                rectParentView = outlineView;
            }
            
            // JJ/TODO: Do we need all these permisstions?
            [facebook getAccessTokenForPermissions: [NSArray arrayWithObjects: @"read_stream", @"export_stream", @"user_photos", @"friends_photos", nil]
                                            cached: NO
                                    relativeToRect:rect
                                            ofView:rectParentView
                                        completion:^(NSDictionary *result)
            {
				node.badgeTypeNormal = [node badgeTypeNormalNonLoading];
                self.loginDialogPending = NO;
                if ([[result valueForKey: @"valid"] boolValue])
                {
//                    node.badgeTypeNormal = kIMBBadgeTypeLoading;
                    node.accessibility = kIMBResourceIsAccessible; // Temporarily, so that loading wheel shows again
                    IMBFacebookParserMessenger *messenger = (IMBFacebookParserMessenger *)node.parserMessenger;
                    
                    SBPerformSelectorAsync(messenger.connection,
                                           messenger,
                                           @selector(setFacebookAccessor:error:),
                                           facebook,
                                           dispatch_get_main_queue(),
                                           
                                           ^(id nothing,NSError *error)
                                           {
                                               if (completion) {
                                                   completion(NO, [NSArray arrayWithObject:node], error);
                                               }
                                           });
                }
                else
                {
                    if (completion) {
                        BOOL canceled = [result valueForKey: @"error"] == nil;
                        completion(canceled, nil, [result valueForKey: @"error"]);
                    }
                }
            }];
        }
    }
}

- (void) requestAccessToNode:(IMBNode *)inNode completion:(IMBRequestAccessCompletionHandler)inCompletion
{
    [self nodeViewController:nil requestAccessToNode:inNode completion:inCompletion];
}

// Log out from Facebook
// (will also delete Facebook cookies to enable different login id while auth token is not expired)
//
- (void) revokeAccessToNode:(IMBNode *)node completion:(IMBRevokeAccessCompletionHandler) completion
{
    node.badgeTypeNormal = kIMBBadgeTypeLoading;

    // Delete Facebook cookies so user can later login with a different id
    [self deleteFacebookCookies];
    
    IMBFacebookParserMessenger *messenger = (IMBFacebookParserMessenger *)node.parserMessenger;
    
    SBPerformSelectorAsync(messenger.connection,
                           messenger,
                           @selector(revokeAccessToNode:error:),
                           node,
                           dispatch_get_main_queue(),
                           ^(id nothing, NSError *error)
                           {
                               if (completion) {
                                   completion(error == nil, error);
                               }
                               node.badgeTypeNormal = [node badgeTypeNormalNonLoading];
                           });
}

#pragma mark
#pragma mark Utility

// Get Facebook app id from key chain (use key chain item type "password". Set "account" to "imb_facebook_app_id"
// and set password to facebook app id)
// NOTE: Use this method for development purposes only! Implement -facebookAppId on node view controller delegate
// before deploying app to store or customer)
//
- (NSString *)facebookAppId
{
    NSString *facebookAppId = nil;
    SecKeychainItemRef item = nil;
    UInt32 stringLength;
    char* buffer;
    OSStatus err = SecKeychainFindGenericPassword (NULL, 19, "imb_facebook_app_id", 0, nil, &stringLength, (void**)&buffer, &item);
    if (noErr == err) {
        if (stringLength > 0) {
            facebookAppId = [[[NSString alloc] initWithBytes:buffer length:stringLength encoding:NSUTF8StringEncoding] autorelease];
            NSLog(@"Warning! You are utilizing key chain entry 'imb_facebook_app_id' for providing a facebook app id. Provide through -facebookAppId on node view controller delegate before deploying app!");
        } else {
            NSLog (@"%s Empty password for 'imb_facebook_app_id' account in keychain: status %ld", __FUNCTION__, (long)err);
        }
        SecKeychainItemFreeContent (NULL, buffer);
    } else {
        NSLog(@"%s Couldn't find 'imb_facebook_app_id' account in keychain: status %ld", __FUNCTION__, (long)err);
    }
    
    return facebookAppId;
}

// Delete all Facebook cookies (http and https) except facebook locale
//
- (void) deleteFacebookCookies
{
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    [cookieStorage setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain];
    NSArray *domains = [NSArray arrayWithObjects:@"http://facebook.com/", @"https://facebook.com/", nil];
    for (NSString *domain in domains) {
        NSArray *cookies = [cookieStorage cookiesForURL:[NSURL URLWithString:domain]];
        for (NSHTTPCookie *cookie in cookies) {
            if (![cookie.name isEqualToString:@"locale"]
                //&& ![cookie.name isEqualToString:@"c_user"]
                )
            {
                //                NSLog(@"Deleting cookie: %@", cookie);
                [cookieStorage deleteCookie:cookie];
            }
        }
    }
    //    NSLog(@"Cookies left: %@", [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]);
}


#pragma mark
#pragma mark PhFacebookDelegate Protocol

//
-(void)requestResult:(NSDictionary *)result
{
    
}

@end
