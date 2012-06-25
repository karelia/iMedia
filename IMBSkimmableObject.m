/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2012 by Karelia Software et al.
 
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


// Author: Jörg Jacobsen


//----------------------------------------------------------------------------------------------------------------------


#import "IMBSkimmableObject.h"
#import "NSObject+iMedia.h"
#import "IMBiPhotoEventNodeObject.h"
#import "IMBParserMessenger.h"
#import "SBUtilities.h"


@implementation IMBSkimmableObject

@synthesize currentSkimmingIndex = _currentSkimmingIndex;


//----------------------------------------------------------------------------------------------------------------------
// Makes sure that currentSkimmingIndex is reset

- (id)init
{
    self = [super init];
    if (self) {
        [self resetCurrentSkimmingIndex];
    }
    return self;
}


//----------------------------------------------------------------------------------------------------------------------
// We don't want no shared image representations like default behavior in super class (we are not folders)

- (NSImage *) sharedImageRepresentation
{
	return nil;
}


// Can't use object's identifier here, since it will be the Key image's URL which might be same for different faces

- (NSString *)imageUID
{
    return [self representedNodeIdentifier];
}


- (NSString*) imageRepresentationType
{
	return [[_imageRepresentationType retain] autorelease];
}


// Need to set this flag from skimmable controller while skimming

- (void) setIsLoadingThumbnail:(BOOL)inIsLoadingThumbnail
{
    _isLoadingThumbnail = inIsLoadingThumbnail;
}


//----------------------------------------------------------------------------------------------------------------------

#pragma mark - NSCoding

//----------------------------------------------------------------------------------------------------------------------


- (id) initWithCoder:(NSCoder*)inCoder
{
	if (self = [super initWithCoder:inCoder])
	{
		_currentSkimmingIndex = [inCoder decodeIntegerForKey:@"currentSkimmingIndex"];
	}
	
	return self;
}


- (void) encodeWithCoder:(NSCoder*)inCoder
{
	[super encodeWithCoder:inCoder];
	
	[inCoder encodeInteger:_currentSkimmingIndex forKey:@"currentSkimmingIndex"];
}


// Returns a sparse copy of self that carrys just enough data to load its thumbnail. Must be subclassed.
// This is for performance reasons.
//
- (IMBSkimmableObject *)thumbnailProvider
{
    [self imb_throwAbstractBaseClassExceptionForSelector:_cmd];
    return nil;
}


// If the image representation isn't available yet, then trigger asynchronous loading based on a sparse copy
// of self (only vital ivars for thumbnail loading are set - this should be much faster). When the results come in,
// copy the thumbnail from the incoming object. Do not replace the old object here, as that would unecessarily
// upset the NSArrayController. Redrawing of the view will be triggered automatically...
// 
- (void) fastLoadThumbnail
{
	if (self.needsImageRepresentation && !self.isLoadingThumbnail)
	{
		_isLoadingThumbnail = YES;
		
        IMBParserMessenger* messenger = self.parserMessenger;
        
        // Use more lightweight copy of self to load thumbnail to save CPU cycles when archiving/unarchiving
        IMBSkimmableObject *copy = [self thumbnailProvider];
        
        SBPerformSelectorAsync(messenger.connection,messenger,@selector(loadThumbnailForObject:error:),copy,
                               
                               ^(IMBObject* inPopulatedObject,NSError* inError)
                               {
                                   if (inError)
                                   {
                                       NSLog(@"%s Error trying to load thumbnail of IMBObject %@ (%@)",__FUNCTION__,self.name,inError);
                                   }
                                   else
                                   {
                                       [self storeReceivedImageRepresentation:inPopulatedObject.atomic_imageRepresentation];
                                       _isLoadingThumbnail = NO;
                                   }
                               });
	}
}


//----------------------------------------------------------------------------------------------------------------------

#pragma mark - Skimming 

//----------------------------------------------------------------------------------------------------------------------
// Returns the number of images to be skimmed through. Must be subclassed.

- (NSUInteger) imageCount
{
    NSString *errorMessage = [NSString stringWithFormat:@"-[%@ %s] must be subclassed", [self className], (char *)_cmd];
	NSLog(@"%@", errorMessage);
	[[NSException exceptionWithName:@"IMBProgrammerError" reason:errorMessage userInfo:nil] raise];
	
	return NSNotFound;
}


//----------------------------------------------------------------------------------------------------------------------
// Sets the current skimming index to NSNotFound and restores the key image in imageLocation

- (void) resetCurrentSkimmingIndex
{
    self.currentSkimmingIndex = NSNotFound;
}


//----------------------------------------------------------------------------------------------------------------------

#pragma mark - Helper

//----------------------------------------------------------------------------------------------------------------------
// Returns the image location that corresponds to the objects current skimming index. Must be subclassed.
// Note: This method must only be invoked in an XPC service (because implementations will most likely
//       take advantage of the parser associated with this object).

- (id) imageLocationForCurrentSkimmingIndex
{
    NSString *errorMessage = [NSString stringWithFormat:@"-[%@ %s] must be subclassed", [self className], (char *)_cmd];
	NSLog(@"%@", errorMessage);
	[[NSException exceptionWithName:@"IMBProgrammerError" reason:errorMessage userInfo:nil] raise];
	
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------
// Returns the image location that corresponds to the skimming index provided. Must be subclassed.
// Note: This method must only be invoked in an XPC service (because implementations will most likely
//       take advantage of the parser associated with this object).

- (id) imageLocationAtSkimmingIndex:(NSUInteger)skimmingIndex
{
    NSString *errorMessage = [NSString stringWithFormat:@"-[%@ %s] must be subclassed", [self className], (char *)_cmd];
	NSLog(@"%@", errorMessage);
	[[NSException exceptionWithName:@"IMBProgrammerError" reason:errorMessage userInfo:nil] raise];
	
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------
// Returns the image location of the key image. Must be subclassed.

- (id) keyImageLocation
{
    NSString *errorMessage = [NSString stringWithFormat:@"-[%@ %s] must be subclassed", [self className], (char *)_cmd];
	NSLog(@"%@", errorMessage);
	[[NSException exceptionWithName:@"IMBProgrammerError" reason:errorMessage userInfo:nil] raise];
	
	return nil;
}


@end
