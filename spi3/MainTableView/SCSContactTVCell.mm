/*
Copyright (C) 2016-2017, Silent Circle, LLC.  All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Any redistribution, use, or modification is done solely for personal
      benefit and not for any commercial purpose or for monetary gain
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name Silent Circle nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL SILENT CIRCLE, LLC BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
#import "SCSContactTVCell.h"
#import "UIImage+ApplicationImages.h"
#import "ChatUtilities.h"
#import "UIColor+ApplicationColors.h"
NSString * const kSCSContactTVCell_ID = @"SCSContactTVCell_ID";

@implementation SCSContactTVCell

@dynamic delegate;

+ (NSString *)reuseId { 
    return kSCSContactTVCell_ID; 
}

- (void)setContactName:(NSString *)contactName highlighted:(BOOL)highlighted
{
    UIFont *font = nil;
    if (highlighted)
    {
        font = [[ChatUtilities utilitiesInstance] getBoldFontWithSize:self.contactNameLabel.font.pointSize];
    } else
    {
        font = [[ChatUtilities utilitiesInstance] getMediumFontWithSize:self.contactNameLabel.font.pointSize];
    }

    [self.contactNameLabel setText:contactName];
    [self.contactNameLabel setFont:font];
}

-(void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    if(highlighted)
        [self setBackgroundColor:[UIColor selectedCellBackgroundColor]];
    else
        [self setBackgroundColor:[UIColor clearColor]];

}

/*
 * UIAccessibilityCustomAction method set by 
 * [SCSMaintTVC tableView:willDisplayCell:forRowAtIndexPath:]
 */
- (BOOL)accessibilityCall {
    
    if ([self.delegate respondsToSelector:@selector(accessibilityCall:)])
        [self.delegate accessibilityCall:self];
    
    return YES;
}

/*
 * UIAccessibilityCustomAction method set by 
 * [SCSMaintTVC tableView:willDisplayCell:forRowAtIndexPath:]
 */
- (BOOL)accessibilitySaveToContacts {
    
    if ([self.delegate respondsToSelector:@selector(accessibilitySaveToContacts:)])
        [self.delegate accessibilitySaveToContacts:self];
    
    return YES;
}

/*
 * UIAccessibilityCustomAction method set by 
 * [SCSMaintTVC tableView:willDisplayCell:forRowAtIndexPath:]
 */
- (BOOL)accessibilityDelete {
    
    if ([self.delegate respondsToSelector:@selector(accessibilityDelete:)])
        [self.delegate accessibilityDelete:self];
    
    return YES;
}


-(void) setSelectedCheckmarkImage
{
    self.addGroupMemberImageView.image = [UIImage selectedCheckmark];
}

-(void) setUnSelectedCheckmarkImage
{
    self.addGroupMemberImageView.image = [UIImage unselectedCheckmark];
}


@end
