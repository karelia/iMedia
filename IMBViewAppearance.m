//
//  IMBViewAppearance.m
//  iMedia
//
//  Created by Jörg Jacobsen on 30.09.12.
//
//

#import "IMBViewAppearance+iMediaPrivate.h"
#import "NSObject+iMedia.h"

@implementation IMBViewAppearance

@synthesize view = _view;


// Do not send -init. Use designated initializer instead.

- (id) init
{
    NSString *error = [NSString stringWithFormat:@"Must not send -init to instance of class %@. Send -initWithView: instead.", [self className]];
    [self imb_throwProgrammerErrorExceptionWithReason:error];
    
    return nil;
}


// Designated initializer

- (id) initWithView:(NSView *)inView
{
    self = [super init];
    if (self) {
        SEL setterOnView = @selector(setImb_Appearance:);
        
        if (inView && [inView respondsToSelector:setterOnView]) {
            [inView performSelector:setterOnView withObject:self];
        } else {
            NSString *error = [NSString stringWithFormat:@"Cannnot -setImb_Appearance: on view %@. View must implement this property.", [inView className]];
            [self imb_throwProgrammerErrorExceptionWithReason:error];
        }
        _view = inView;
    }
    return self;
}


- (void) unsetView
{
    _view = nil;
}


- (void) invalidateAppearance
{
    if (self.view)
    {
        [self.view setNeedsDisplay:YES];
    }
}


// Returns the background color of its view if the view itself supports -backgroundColor

- (NSColor *)backgroundColor
{
    SEL getter = @selector(backgroundColor:);
    if (self.view && [self.view respondsToSelector:getter])
    {
        return [self.view performSelector:getter];
    }
    return nil;
}


// Sets the background color on its view if the view itself supports -setBackgroundColor:

- (void) setBackgroundColor:(NSColor *)inColor
{
    SEL setter = @selector(setBackgroundColor:);
    if (self.view && [self.view respondsToSelector:setter])
    {
        [self.view performSelector:setter withObject:inColor];
        
        if (inColor && [self.view isKindOfClass:[NSTableView class]]) {
            ((NSTableView *)self.view).usesAlternatingRowBackgroundColors = NO;
        }
    }
    [self invalidateAppearance];
}


@end
