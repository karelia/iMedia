//
//  IMBFacebookParser.h
//  iMedia
//
//  Created by Jörg Jacobsen on 12.03.13.
//
//

#import <iMedia/iMedia.h>
#import <PhFacebook/PhFacebook.h>
#import "IMBParser.h"

@class ACAccountStore;

@interface IMBFacebookParser : IMBParser
{
    ACAccountStore *_accountStore;
    PhFacebook *_facebook;
}

// OAuth authentication enabled Facebook accessor object
@property (retain) PhFacebook *atomic_facebook;
@property (retain) PhFacebook *facebook;    // Also sets myself as delegate

- (id) revokeAccessToNode:(IMBNode *)node error:(NSError **)pError;
@end
