//
//  IMBFacebookAccessViewController.h
//  iMedia
//
//  Created by Jörg Jacobsen on 08.04.13.
//
//

#import <iMedia/iMedia.h>
#import <PhFacebook/PhFacebook.h>
#import "IMBParserMessenger.h"

@interface IMBFacebookAccessController : NSObject <IMBNodeAccessDelegate, PhFacebookDelegate>
{
    IMBNode *_node;
    BOOL _loginDialogPending;
}

// The node this access controller provides access to
@property (retain) IMBNode *node;

// Says whether the user already started a login dialog but did not complete it yet
@property (getter = isLoginDialogPending) BOOL loginDialogPending;

// Returns a singleton instance of the class
+ (IMBFacebookAccessController *)sharedInstance;
@end
