/*
 
 Permission is hereby granted, free of charge, to any person obtaining a 
 copy of this software and associated documentation files (the "Software"), 
 to deal in the Software without restriction, including without limitation 
 the rights to use, copy, modify, merge, publish, distribute, sublicense, 
 and/or sell copies of the Software, and to permit persons to whom the Software 
 is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in 
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS 
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
 AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
Please send fixes to
	<ghulands@framedphotographics.com>
	<ben@scriptsoftware.com>
 
 */

#import "Library.h"

@implementation Library

static NSBundle *frameworkBundle = nil;

+ (void)initialize
{
	frameworkBundle = [NSBundle bundleForClass:[self class]];	
}

- (id)init
{
	if(self = [super init])
	{
		libraryItems = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[name release];
	[cachedNameWithImage release];
	[libraryImageName release];
	[libraryItems release];
	[super dealloc];
}

/**
Returns a boolean indicating if the library can "own" sub-libraries.  
 */

- (BOOL)allowsSubLibraries
{
	return NO;
}

/**
Returns the image for the type of library.
 */

- (NSString *)libraryImageName {
    return [[libraryImageName retain] autorelease];
}

- (void)setLibraryImageName:(NSString *)value {
    if (libraryImageName != value) {
        [libraryImageName release];
        libraryImageName = [value copy];
    }
}

/**
 Returns an attributed string with the library name, annotated with the image
 for the library at the beginning of the string using a text attachment.  We 
 cache the image per library so as to not reload the image each time.
*/

- (NSAttributedString *)nameWithImage {
	
    NSString *tmpValue;
    NSMutableAttributedString *result;
    NSImage *libraryImage = nil;
    
    // check the cache first... 
    if (cachedNameWithImage != nil) {
        return cachedNameWithImage;
    }
    
    // get the name part of the string
    tmpValue = [self name];
    tmpValue = (tmpValue == nil) ? @"" : tmpValue;
    
    // start with a mutablestring with the name (padding a space at beginning)
    result = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@",tmpValue]];

    libraryImage = [[[NSImage alloc] initWithContentsOfFile:[frameworkBundle pathForImageResource:[self libraryImageName]]] autorelease];
    [libraryImage setScalesWhenResized:YES];
    [libraryImage setSize:NSMakeSize(14, 14)];
    
    if (libraryImage != nil) {
		
        NSFileWrapper *wrapper = nil;
        NSTextAttachment *attachment = nil;
        NSAttributedString *icon = nil;
		
        // need a filewrapper to create an NSTextAttachment
        wrapper = [[NSFileWrapper alloc] init];
		
        // set the icon (this is what'll show up in attributed strings)
        [wrapper setIcon:libraryImage];
        
        // you need an attachment to create the attributed string as an RTFd
        attachment = [[NSTextAttachment alloc] initWithFileWrapper:wrapper];
        
        // finally, the attributed string for the icon
        icon = [NSAttributedString attributedStringWithAttachment:attachment];
        [result insertAttributedString:icon atIndex:0];
		
        // cleanup
        [wrapper release];
        [attachment release];	
    }
    
    // set and return the result
    cachedNameWithImage = result;    
    return result;
}

/**
Mutator to set the name of a group.  We remove the image when the name of 
 the group is being edited (since that cannot be changed by the user), so
 here we reset the cached image and name string.
 */

- (void)setNameWithImage:(NSString *)nameWithImage {
    [self setName:nameWithImage];
    [cachedNameWithImage release];
    cachedNameWithImage = nil;
}

/**
The summary string for the library.
 */

- (NSString *)summaryString {
    return nil;
}

- (BOOL)isLeaf {
    return YES;
}

#pragma mark ACCESSORS
- (NSString *)name {
    return [[name retain] autorelease];
}

- (void)setName:(NSString *)value {
    if (name != value) {
        [name release];
        name = [value copy];
    }
}

- (void)addLibraryItem:(id)value{    
	[libraryItems addObject:value];
}

- (void)setLibraryItems:(NSMutableArray*)value
{
	if(libraryItems != value)
	{
		[libraryItems release];
		libraryItems = [value copy];
	}
}

- (NSMutableArray*)libraryItems
{
	return [[libraryItems retain] autorelease];
}
@end
