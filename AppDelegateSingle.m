/*
 iMedia Browser <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2007 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 iMedia Browser is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2007 by Karelia Software et al.
 
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


#import "AppDelegateSingle.h"
#import <iMediaBrowser/iMedia.h>
#import <iMediaBrowser/iMBPhotosView.h>
#import <iMediaBrowser/iMBMusicView.h>

@implementation AppDelegateSingle

- (void)dealloc
{
    [photosView release];
    [musicView release];

    [super dealloc];
}

- (void)awakeFromNib
{
    photosView = [[iMBPhotosView alloc] initWithFrame:[photosContainerView bounds]];
    musicView = [[iMBMusicView alloc] initWithFrame:[musicContainerView bounds]];

    [photosContainerView addSubview:(NSView *)photosView];
    [musicContainerView addSubview:(NSView *)musicView];
    
    [(NSView *)photosView setAutoresizingMask:(NSViewHeightSizable|NSViewWidthSizable)];
    [(NSView *)musicView setAutoresizingMask:(NSViewHeightSizable|NSViewWidthSizable)];
    
    [photosView willActivate];
    [musicView willActivate];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[iMediaConfiguration sharedConfigurationWithDelegate:self];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
    // TODO: Saving the defaults should be handled in didDeactivate rather than here.

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"iMB-%@", [[iMediaConfiguration sharedConfiguration] identifier]]]];
    
    // save current selection in photo view to user defaults
    NSIndexPath *photosSelection = [[photosView controller] selectionIndexPath];
    NSData *archivedPhotosSelection = [NSKeyedArchiver archivedDataWithRootObject:photosSelection];

    [dictionary setObject:archivedPhotosSelection forKey:[NSString stringWithFormat:@"%@Selection", NSStringFromClass([photosView class])]];
    
    [[NSUserDefaults standardUserDefaults] setObject:dictionary forKey:[NSString stringWithFormat:@"iMB-%@", [[iMediaConfiguration sharedConfiguration] identifier]]];
    
    // save current selection in music view to user defaults
    NSIndexPath *musicSelection = [[musicView controller] selectionIndexPath];
    NSData *archivedMusicSelection = [NSKeyedArchiver archivedDataWithRootObject:musicSelection];

    [dictionary setObject:archivedMusicSelection forKey:[NSString stringWithFormat:@"%@Selection", NSStringFromClass([musicView class])]];

    [[NSUserDefaults standardUserDefaults] setObject:dictionary forKey:[NSString stringWithFormat:@"iMB-%@", [[iMediaConfiguration sharedConfiguration] identifier]]];
    
    [[NSUserDefaults standardUserDefaults] synchronize];

    [photosView didDeactivate];
    [musicView didDeactivate];
}

- (BOOL)iMediaConfiguration:(iMediaConfiguration *)configuration willUseMediaParser:(NSString *)parserClassname forMediaType:(NSString *)media;
{
	return YES;
}

@end
