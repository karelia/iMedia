//
//  IMBFacebookParserMessenger.h
//  iMedia
//
//  Created by Jörg Jacobsen on 12.03.13.
//
//

#import <iMedia/iMedia.h>

@class PhFacebook;

@interface IMBFacebookParserMessenger : IMBParserMessenger
{
    PhFacebook *_facebook;
}

/**
 OAuth authentication enabled Facebook accessor object.
 
 Since XPC services may terminate at any given time (especially on 10.7!) we cannot expect a parser to stay around.
 Thus we store the facebook accessor object in the parser messenger because it will outlive any parsers (because it lives
 in the application's main process). Whenever the parser messenger accesses a parser in an XPC service
 (-parserWithIdentifier) we will set the parser's facebook property to it's messenger's facebook object.
 */
@property (retain) PhFacebook *facebook;


@end
