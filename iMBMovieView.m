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
 
 This file was Authored by Greg Hulands
 
 */

#import "iMBMovieView.h"
#import <QTKit/QTKit.h>

@interface iMBMovieView (PrivateAPI)
- (NSDictionary *)recordUnderPoint:(NSPoint)p;
@end


#warning TODO: It may be useful to convert all QTMovie constructors to use initWithDataReference so more types are properly loaded.

@implementation iMBMovieView

- (void)dealloc
{
	[myPreview release];
	[super dealloc];
}

- (void)previewMovie:(NSString *)path inRect:(NSRect)rect
{
	if (!myPreview)
	{
		myPreview = [[QTMovieView alloc] initWithFrame:rect];
		[myPreview setControllerVisible:NO];
		[myPreview setShowsResizeIndicator:NO];
		[myPreview setPreservesAspectRatio:YES];
	}
	[self addSubview:myPreview];
	[myPreview pause:self];
	NSError *error = nil;
	QTMovie *movie = [[[QTMovie alloc] initWithAttributes:
		[NSDictionary dictionaryWithObjectsAndKeys: 
			path, QTMovieFileNameAttribute,
			[NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute,
			nil] error:&error] autorelease];
	[myPreview setMovie:movie];
	[myPreview play:self];
}

- (IBAction)play:(id)sender
{
	
}

- (IBAction)stop:(id)sender
{
	[myPreview pause:self];
}

- (void)mouseDown:(NSEvent *)theEvent
{
	[super mouseDown:theEvent];
	
	if ([theEvent clickCount] == 2)
	{
		NSDictionary *rec = [self recordUnderPoint:[self convertPoint:[theEvent locationInWindow] fromView:nil]];
		[self previewMovie:[rec objectForKey:@"file"]
					inRect:NSRectFromString([rec objectForKey:@"rect"])];
	}
}

- (void)setImages:(NSArray *)imgs
{
	[myPreview pause:self];
	[myPreview retain];
	[myPreview removeFromSuperview];
	
	[super setImages:imgs];
}


@end
