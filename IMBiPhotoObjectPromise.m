/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2011 by Karelia Software et al.
 
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
 following copyright notice: Copyright (c) 2005-2011 by Karelia Software et al.
 
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


// Author: Pierre Bernard, Mike Abdullah


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBiPhotoObjectPromise.h"
#import "IMBiPhotoParser.h"

#import "IMBParserController.h"

#import "NSString+iMedia.h"


// TODO: should subclassed methods be public?
@interface IMBObjectsPromise ()

- (void) _countObjects:(NSArray*)inObjects;
- (void) loadObjects:(NSArray*)inObjects;
- (void) _loadObject:(IMBObject*)inObject;
- (void) _didFinish;

@end


@interface IMBiPhotoObjectPromise ()

@end


// This subclass is used for pyramid files that need to be split. The split file is saved to the local file system,
// where it can then be accessed by the delegate... 

#pragma mark

@implementation IMBiPhotoObjectPromise

- (id) initWithIMBObjects:(NSArray*)inObjects
{
	if ((self = [super initWithIMBObjects:inObjects]) != nil)
	{
	}
	
	return self;
}

- (IMBParser *)parserForObject:(IMBObject *)object;
{
    IMBParser *result = [object parser];
    if (result) return result;
    
    
    // IMBObjectsPromise creates objects by unarchiving them. Unarchived objects do not contain a reference to their parser, only the parser type and media source. Thus, we have to guess at the parser here so clients can have access to it.
    NSString *parserMediaType = object.parserMediaType;
    NSString *parserMediaSource = object.parserMediaSource;
    
    if ((parserMediaType == nil) || (parserMediaSource == nil)) {
        return nil;
    }
    
    IMBParserController *parserController = [IMBParserController sharedParserController];
    NSArray *loadedParsers = [parserController parsersForMediaType:parserMediaType];
    
    for (IMBParser *parser in loadedParsers) {
        if ([parser.mediaSource isEqualToString:parserMediaSource])
        {
            [object setParser:parser];
            return parser;
        }
    }
    
    return nil;
}

- (void) _loadObject:(IMBObject*)inObject
{
    id parser = [self parserForObject:inObject];
    
    
    if ([parser isKindOfClass:[IMBiPhotoParser class]]) {
        NSMutableDictionary *metadata = [NSMutableDictionary dictionaryWithDictionary:[inObject metadata]];
        NSDictionary *plist = [parser plist];
        
        NSString *applicationVersionString = [plist objectForKey:@"Application Version"];
        if (applicationVersionString) [metadata setObject:applicationVersionString forKey:@"Application Version"];
        
        
        NSString *archivePathString = [plist objectForKey:@"Archive Path"];
        
        if (archivePathString != nil) {
            [metadata setObject:archivePathString forKey:@"Archive Path"];
            
            static NSArray *keysToFix = nil;
            
            if (keysToFix == nil) {
                keysToFix = [[NSArray alloc] initWithObjects:@"ImagePath", @"OriginalPath", nil];
            }
            
            for (NSString *keyToFix in keysToFix) {
                NSString *pathString = [metadata objectForKey:keyToFix];
                
                if ([pathString hasPrefix:@"Masters/"]) {
                    NSString *thumbPathString = [metadata objectForKey:@"ThumbPath"];
                    NSString *thumbnailsPathString = [archivePathString stringByAppendingPathComponent:@"Thumbnails"];
                    
                    if ([thumbPathString hasPrefix:thumbnailsPathString]) {
                        NSInteger thumbnailsPathStringLength = [thumbnailsPathString length];
                        NSString *mastersPathString = [archivePathString stringByAppendingPathComponent:@"Masters"];
                        NSString *suffix = [thumbPathString substringFromIndex:thumbnailsPathStringLength];
                        
                        pathString = [mastersPathString stringByAppendingPathComponent:suffix];
                        pathString = [pathString stringByIterativelyResolvingSymlinkOrAlias];
                    }
                    
                    if (pathString) [metadata setObject:pathString forKey:keyToFix];
                }
            }
        }
        
        if ([NSThread isMainThread])
        {
            inObject.metadata = metadata;
        }
        else
        {
            NSArray* modes = [NSArray arrayWithObject:NSRunLoopCommonModes];
            [inObject performSelectorOnMainThread:@selector(setMetadata:) withObject:metadata waitUntilDone:NO modes:modes];
        }
        
        
        // Resolve aliases before passing on to super. Issue #22
        NSString *location = [[inObject location] stringByIterativelyResolvingSymlinkOrAlias];
        [inObject setLocation:location];
	}
    
	[super _loadObject:inObject];
}

@end
