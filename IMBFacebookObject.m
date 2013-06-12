//
//  IMBFacebookObject.m
//  iMedia
//
//  Created by Jörg Jacobsen on 12.06.13.
//
//

#import "IMBFacebookObject.h"

@implementation IMBFacebookObject

- (void) dealloc
{
    IMBRelease(_alternateImageLocations);
    
    [super dealloc];
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        self.alternateImageLocations = [aDecoder decodeObjectForKey:@"alternateImageLocations"];
    }
    return self;
}

- (void) encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    
	[aCoder encodeObject:self.alternateImageLocations forKey:@"alternateImageLocations"];
}

- (id) copyWithZone:(NSZone *)zone
{
    IMBFacebookObject *copy = [super copyWithZone:zone];
    
    copy.alternateImageLocations = self.alternateImageLocations;
    
    return copy;
}

@end
