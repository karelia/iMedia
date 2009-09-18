/*
     File: IMBComboTextCell.h 
  
*/

#import <Cocoa/Cocoa.h>

@interface IMBComboTextCell : NSTextFieldCell {
@private
    // Our cell delegates some drawing and other operations to subcells
    NSImageCell *_imageCell;
}

@property(retain) NSImage *image;

@end
