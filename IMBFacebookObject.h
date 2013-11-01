//
//  IMBFacebookObject.h
//  iMedia
//
//  Created by Jörg Jacobsen on 12.06.13.
//
//

#import <iMedia/iMedia.h>

@interface IMBFacebookObject : IMBObject
{
    NSArray *_alternateImageLocations;
}

// We've come accross cases where the official thumbnail URL that Facebook returned to us just wouldn't do it.
// But FB also provides a list of URLs pointing to images at different resolutions. This is the property where
// we store this list and try for an alternate thumbnail image (may have much higher resolution)
//
@property (retain) NSArray *alternateImageLocations;

@end
