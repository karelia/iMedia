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
    BOOL _loginDialogPending;
}

// Says whether the user already started a login dialog but did not complete it yet
@property (getter = isLoginDialogPending) BOOL loginDialogPending;

// Returns a singleton instance of the class
+ (IMBFacebookAccessController *)sharedInstance;
@end
