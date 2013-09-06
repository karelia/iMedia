/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2013 by Karelia Software et al.
 
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

//----------------------------------------------------------------------------------------------------------------------

// Author: Jörg Jacobsen

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
            
            NSString *facebookAppId = nil;
            if ([nodeViewController.delegate respondsToSelector:@selector(facebookAppId)]) {
                facebookAppId = [nodeViewController.delegate facebookAppId];
            }
            // Fallback only for development convenience! (Get it from key chain)
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
            
            [facebook getAccessTokenForPermissions: [NSArray arrayWithObjects: @"user_photos", @"user_friends", @"friends_photos", nil]
                                            cached: NO
                                    relativeToRect:rect
                                            ofView:rectParentView
                                        completion:^(NSDictionary *result)
            {
                self.loginDialogPending = NO;
                
                BOOL success = [[result valueForKey: @"valid"] boolValue];
                if (success) {
                    IMBFacebookParserMessenger *messenger = (IMBFacebookParserMessenger *)node.parserMessenger;
                    
                    messenger.facebook = facebook;
                }
                if (completion) {
                    NSError *error = [result valueForKey: @"error"];
                    BOOL isLoginCanceled = !success && (error == nil);
                    completion(isLoginCanceled, success ? @[node] : nil, error);
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
                               messenger.facebook = nil;
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
