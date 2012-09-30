//
//  IMBViewAppearance.h
//  iMedia
//
//  Created by Jörg Jacobsen on 30.09.12.
//
//

#import <Foundation/Foundation.h>

@interface IMBViewAppearance : NSObject
{
    NSView *_view;
}

@property (assign, readonly) NSView *view;

// Designated initializer

- (id) initWithView:(NSView *)inView;

// Returns the background color of its view if the view itself supports -backgroundColor

- (NSColor *)backgroundColor;

// Sets the background color on its view if the view itself supports -setBackgroundColor:

- (void) setBackgroundColor:(NSColor *)inColor;

@end
