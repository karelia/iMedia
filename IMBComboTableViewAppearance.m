//
//  IMBComboTableViewAppearance.m
//  iMedia
//
//  Created by Jörg Jacobsen on 29.09.12.
//
//

#import "IMBComboTableViewAppearance.h"
#import "NSCell+iMedia.h"
#import "IMBComboTextCell.h"

@implementation IMBComboTableViewAppearance

@synthesize subRowTextAttributes = _subRowTextAttributes;
@synthesize subRowTextHighlightAttributes = _subRowTextHighlightAttributes;


- (void)dealloc
{
    IMBRelease(_subRowTextAttributes);
    IMBRelease(_subRowTextHighlightAttributes);
    
    [super dealloc];
}


// Customizes appearance of cell according to this object's appearance properties

- (void) prepareCell:(NSCell *)inCell atColumn:(NSInteger)inColumn row:(NSInteger)inRow
{
    [super prepareCell:inCell atColumn:inColumn row:inRow];
    
	if ([inCell isKindOfClass:[IMBComboTextCell class]])
	{
        IMBComboTextCell *theCell = (IMBComboTextCell *) inCell;
        
        theCell.textColor = [NSColor controlTextColor];
        if ([theCell isHighlighted])
        {
            if (self.subRowTextHighlightAttributes) {
                [theCell setSubtitleTextAttributes:self.subRowTextHighlightAttributes];
            } else if (self.subRowTextAttributes){
                [theCell setSubtitleTextAttributes:self.subRowTextAttributes];
            }
        } else {    // Non-highlighted cell
            if (self.subRowTextAttributes) {
                [theCell setSubtitleTextAttributes:self.subRowTextAttributes];
            }
        }
	}
}


// Draws background colors for rows according to -backgroundColors (re-iterating colors).
@end
