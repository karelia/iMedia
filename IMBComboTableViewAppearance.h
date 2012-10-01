//
//  IMBComboTableViewAppearance.h
//  iMedia
//
//  Created by Jörg Jacobsen on 29.09.12.
//
//

#import "IMBTableViewAppearance.h"

@interface IMBComboTableViewAppearance : IMBTableViewAppearance
{
    NSDictionary *_subRowTextAttributes;
    NSDictionary *_subRowTextHighlightAttributes;
}

@property (retain) NSDictionary *subRowTextAttributes;
@property (retain) NSDictionary *subRowTextHighlightAttributes;

@end
