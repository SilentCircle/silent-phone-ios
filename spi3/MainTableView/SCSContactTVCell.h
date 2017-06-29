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

#import <UIKit/UIKit.h>

#import "SCSContactViewSwipeCell.h"
#import "SCSEnums.h"

extern NSString * const kSCSContactTVCell_ID;

@class SCSContactTVCell;

/**
 * This protocol extends the MGSwipeTableCellDelegate protocol for
 * specific accessibility functionality for placing call, saving to
 * contacts, and deleting conversation, for MGSwipeTableCell swipe
 * gesture actions.
 */
@protocol SCSContactTVCellDelegate <MGSwipeTableCellDelegate>
@optional
-(void) accessibilityCall:(SCSContactTVCell*)contactCell;
-(void) accessibilitySaveToContacts:(SCSContactTVCell*)contactCell;
-(void) accessibilityDelete:(SCSContactTVCell*)contactCell;

@end

/**
 * This tableCell class implements a number of properties, but no
 * specific functionality of its own.
 *
 * The SCSContactViewSwipeCell class combines features of the 
 * SCSContactViewCell and MGSwipeTableCell, which are inherited by this
 * subclass. 
 *
 * Used in SCSMainTVC
 *
 * @see SCSContactViewSwipeCell
 */
@interface SCSContactTVCell : SCSContactViewSwipeCell

@property (weak, nonatomic) IBOutlet id<SCSContactTVCellDelegate>delegate;

@property (weak, nonatomic) IBOutlet UILabel *contactNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *messageAlertView;
@property (weak, nonatomic) IBOutlet UIImageView *failedBadgeImageView;
@property (weak, nonatomic) IBOutlet UIImageView *dataRetentionImageView;
@property (weak, nonatomic) IBOutlet UILabel *lastMessageTextLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *lastMessageTextTopConstraint;
@property (weak, nonatomic) IBOutlet UILabel *lastMessageTimeLabel;
@property (weak, nonatomic) IBOutlet UIView *separatorView;
@property (weak, nonatomic) IBOutlet UILabel *contactInfoLabel;
@property (weak, nonatomic) IBOutlet UIImageView *addGroupMemberImageView;
@property (weak, nonatomic) IBOutlet UIImageView *callIconView;
@property (weak, nonatomic) IBOutlet UIImageView *externaImageView;

@property (assign, nonatomic) scsContactType contactType;

/**
 Sets the text of the contact name label 
 and makes it bold or not.

 @param contactName The contact name
 @param highlighted YES if we want to make it bold, NO otherwise
 */
- (void)setContactName:(NSString *)contactName highlighted:(BOOL)highlighted;

/**
 * UIAccessibilityCustomAction methods set by 
 * [SCSMaintTVC tableView:willDisplayCell:forRowAtIndexPath:]
 */
- (BOOL)accessibilityCall;
- (BOOL)accessibilitySaveToContacts;
- (BOOL)accessibilityDelete;

// functions for setting multiselection checkmark image
-(void) setSelectedCheckmarkImage;
-(void) setUnSelectedCheckmarkImage;
@end
