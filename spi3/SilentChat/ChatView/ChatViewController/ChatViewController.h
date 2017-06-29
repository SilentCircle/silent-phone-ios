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
/**
 * Chat Messages UITableView
 **/

#import "Silent_Phone-Swift.h"
#import "AddGroupMemberViewController.h"
#import "SCCNavigationTitleView.h"

@protocol SCSTransitionDelegate;

@class ActionSheetViewRed;
@class SCDRWarningView;


@interface ChatViewController : UIViewController<GroupMemberSelectionDelegate>

// Array of sectionobjects
@property (nonatomic, strong) NSMutableArray *chatHistory;

// array of all chatobject's
@property (nonatomic, strong) NSMutableArray *chatObjectsHistory;

@property (weak, nonatomic) id<SCSTransitionDelegate> transitionDelegate;
@property (nonatomic) BOOL isKeyboardOpen;
@property (nonatomic, strong) NSURL *pendingOpenInAttachmentURL;
@property (weak, nonatomic) IBOutlet UITableView *chatTableView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *chatTableViewBottomConstant;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *chatTableViewTopConstant;

// data retention
@property (weak, nonatomic) IBOutlet SCDRWarningView *dataRetentionWarningView;

@property (weak, nonatomic) IBOutlet UIView *emptyChatBackgroundView;
@property (weak, nonatomic) IBOutlet SCSContactView *emptyChatContactView;
@property (weak, nonatomic) IBOutlet UILabel *emptyChatUserName;
@property (strong, nonatomic) IBOutlet SCCNavigationTitleView *navigationTitleView;
@property (strong, nonatomic) IBOutlet ActionSheetViewRed *actionsheetViewRed;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *headerViewTopConstant;
@property (weak, nonatomic) IBOutlet UILabel *contactNameLabel;
// Used in title and empty
@property (strong, nonatomic) NSString *displayTitle;

@property (weak, nonatomic) IBOutlet UIButton *addGroupChatMemberButton;

- (IBAction)addGroupChatMember:(id)sender;

- (void)presentContactSelection;

@end
