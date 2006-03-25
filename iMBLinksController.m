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
 
 In the case of iMediaBrowse, in addition to the terms noted above, in any 
 application that uses iMediaBrowse, we ask that you give a small attribution to 
 the members of CocoaDev.com who had a part in developing the project. Including, 
 but not limited to, Jason Terhorst, Greg Hulands and Ben Dunton.
 
 Greg doesn't really want acknowledgement he just want bug fixes as he has rewritten
 practically everything but the xml parsing stuff. Please send fixes to 
	<ghulands@framedphotographics.com>
	<ben@scriptsoftware.com>
 */


#import "iMBLinksController.h"
#import "iMBLibraryNode.h"

@interface iMBLinksController (Private)

- (void)setPlaylistController:(NSTreeController *)value;
- (NSTreeController *)playlistController;

@end

@implementation iMBLinksController


- (id)initWithPlaylistController:(NSTreeController *)ctrl
{
	if (self = [super init]) {
		[self setPlaylistController:ctrl];
		//[NSBundle loadNibNamed:@"Links" owner:self];
	}
	return self;
}

- (NSString *)mediaType
{
	return @"links";
}

static NSImage *_toolbarIcon = nil;

- (NSImage*)toolbarIcon
{
	if(_toolbarIcon == nil)
	{
		NSBundle *b = [NSBundle bundleForClass:[self class]];
		NSString *p = [b pathForResource:@"safari" ofType:@"png"];
		_toolbarIcon = [[NSImage alloc] initWithContentsOfFile:p];
		[_toolbarIcon setScalesWhenResized:YES];
		[_toolbarIcon setSize:NSMakeSize(32,32)];
	}
	return _toolbarIcon;
}


- (NSString *)name
{
	return NSLocalizedString(@"Links", @"Browser Name");
}

- (NSView *)browserView
{
	return oView;
}

- (void)didDeactivate
{
	
}

- (void)writePlaylistsToPasteboard:(NSPasteboard *)pboard
{
	
}

- (void)refresh
{
	
}

- (NSTreeController *)playlistController 
{
    return [[playlistController retain] autorelease];
}

- (void)setPlaylistController:(NSTreeController *)value 
{
    if (playlistController != value) 
	{
        [playlistController release];
        playlistController = [value retain];
    }
}

@end
