//
//  IMBFacebookParser.h
//  iMedia
//
//  Created by Jörg Jacobsen on 12.03.13.
//
//

#import <iMedia/iMedia.h>
#import "IMBParser.h"

@class ACAccountStore;

@interface IMBFacebookParser : IMBParser
{
    ACAccountStore *_accountStore;
}

@end
