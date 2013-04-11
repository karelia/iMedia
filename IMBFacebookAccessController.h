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

@interface IMBFacebookAccessController : NSObject <IMBAccessRequester, PhFacebookDelegate>
{
    PhFacebook *facebook;
}

@property (retain) PhFacebook *facebook;

@end
