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
//
//  AddGroupMemberViewController.h
//  SPi3
//
//  Created by Gints Osis on 31/10/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "AddGroupMemberView.h"
#import "SCSSearchVM.h"
#import "SCSTransitionDelegate.h"
#import "SCSSearchBarView.h"

/*
 Protocol to tell the delegate that this viewcontroller has finished picking RecentObjects
 */
@protocol GroupMemberSelectionDelegate<NSObject>

/*
 @param array - Array of Selected RecentObject's
 */
-(void) didfinishSelectinggroupMembers:(NSArray *) array;
@end
/*
 User picking viewcontroller to collect RecentObject's and pass them to delegate
 Contains AddGroupMemberView with selected RecentObject contactNames in scrollview
 A textfield to search for contact and a Tableview with search results or all conversation and contact results to select or deselct RecentObject's from by tapping on cell
 */
@interface AddGroupMemberViewController : UIViewController<UITextFieldDelegate,GroupMemberViewDelegate,SCSSearchVMActionDelegate,SCSSearchBarViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;

// Scrollview with contactname bubbles
@property (weak, nonatomic) IBOutlet AddGroupMemberView *addedGroupMemberView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *addGroupMemberViewHeightConstraint;

// delegate for finish selection
@property (nonatomic, assign) id <GroupMemberSelectionDelegate> delegate;

// array of RecentObject's to skip from displaying in search results
// Usually these are already added with previos selection or are already participants in the group that we are selecting for
@property (nonatomic) NSMutableArray *alreadyAddedContacts;


@property (nonatomic, strong) scsContactTypeSearchVM *tableVM;

@property (weak, nonatomic) id<SCSTransitionDelegate> transitionDelegate;


@property (strong, nonatomic) SCSSearchBarView *searchBar;

// if set to YES tapping back button will transition to conversations
@property BOOL transitionToConversations;

@end
