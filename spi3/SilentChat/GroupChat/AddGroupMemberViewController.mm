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
//  AddGroupMemberViewController.m
//  SPi3
//
//  Created by Gints Osis on 31/10/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//
#import "AddGroupMemberViewController.h"

#import "AddGroupMemberView.h"
#import "ChatViewController.h"
#import "GroupChatManager.h"
#import "GroupChatManager+UI.h"
#import "GroupChatManager+AvatarUpdate.h"
#import "SCPCallbackInterface.h"
#import "SCSChatSectionObject.h"
#import "Silent_Phone-Swift.h"
#import "UIColor+ApplicationColors.h"
#import "UIImage+ApplicationImages.h"
#import "SCSConstants.h"
#import "SCSEnums.h"

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelError;
//#endif

static NSInteger const kAddGroupMemberViewHeight = 60;
static NSInteger const kSearchBarHeight = 52;
@implementation AddGroupMemberViewController
{
    UIButton *groupCreateButton;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"Add members", nil);
    
    self.tableVM = [[scsContactTypeSearchVM alloc] initWithTableView:self.tableView];
    [self.tableVM setIsMultiSelectEnabled:YES];
    self.tableVM.shouldDisableNumbers = YES;
    self.tableVM.actionDelegate = self;
    self.tableVM.isSwipeEnabled = NO;
    
    _searchBar = [[[NSBundle mainBundle] loadNibNamed:@"SCSSearchBarView" owner:self options:nil] objectAtIndex:0];
    _addedGroupMemberView.delegate = self;
    _searchBar.delegate = self;
    [self.tableView setTableHeaderView:_searchBar];
    _searchBar.searchTextField.placeholder = kSearchName;
    [_searchBar.searchTextField becomeFirstResponder];
    
}
-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.title = kNewGroupConversation;
    if (!groupCreateButton)
    {
        self.navigationItem.leftBarButtonItem = [self getLeftBarButtonItem];
        self.navigationItem.rightBarButtonItem = [self getRightBarButtonItem];
    }
    
    self.tableVM.alreadyAddedContacts = self.alreadyAddedContacts;
    
    
    if (!self.tableVM.isSearchActive)
    {
        [self.tableVM activateSearchforTypes:scsContactTypeSearch|scsContactTypeAddressBookSilentCircle | scsContactTypeDirectory
              andDisplayFullListsOfTypes:scsContactTypeAddressBookSilentCircle];
    }
    
    [self updateNavigationTitleWithParticipants];
    
    if (![Switchboard.networkManager hasNetworkConnection])
    {
        [self showNetworkError];
    } else
    {
        [self updateGroupCreationViews];
    }
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if (self.tableVM.isSearchActive)
    {
        [self.tableVM deactivateSearchAndShowContactTypes:0];
    }
}

-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    _searchBar.frame = CGRectMake(0, 0, self.view.frame.size.width, kSearchBarHeight);
    [_addedGroupMemberView updateFrames];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark accept selection

- (void)dimissController:(id)sender {
    if (_transitionToConversations)
    {
        [self.transitionDelegate transitionToConversationsFromVC:self];
    } else
    {
        if (![self isBeingPresented])
        {
            [self.navigationController popViewControllerAnimated:YES];
        } else
        {
            [self dismissViewControllerAnimated:NO
                                     completion:nil];
        }
    }
}

/*
 Tap on right bar button item
 Send delegate the selected RecentObject Array and pop this viewcontroller
 */
-(void) acceptSelection
{
    if (![Switchboard.networkManager hasNetworkConnection])
    {
        [self showNetworkError];
        return;
    } else
    {
        [_addedGroupMemberView hideNetworkError];
    }
    if ([self.delegate respondsToSelector:@selector(didfinishSelectinggroupMembers:)])
    {
        [self.delegate didfinishSelectinggroupMembers:[ _addedGroupMemberView getAllMembers]];
        [self.navigationController popViewControllerAnimated:YES];
    } else
    {
        [self createNewGroup];
    }
}

#pragma mark searchActionsDelegate
-(void)searchTextDidChange:(NSString *)searchText
{
    [self.tableVM searchText:searchText];
}

-(void)didTapClearSearchButton
{
    [self.tableVM searchText:@""];
}

#pragma mark GroupMemberViewDelegate
-(void)didRemoveMemberName:(NSString *)contactName
{
    [self updateGroupCreationViews];
    [self.tableVM shouldRemoveContactNameFromSelection:contactName];
    [self updateNavigationTitleWithParticipants];
}
-(void)didAddMemberName:(NSString *)contactName
{
    [_searchBar clearSearch];
    [self updateNavigationTitleWithParticipants];
}

#pragma mark ScrollViewDelegate

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [_searchBar.searchTextField resignFirstResponder];
}

#pragma mark - SCSSearchVMActionDelegate

-(void)didAddRecentObjectToSelection:(RecentObject *)recentObject ofType:(scsContactType)contactType {

    if(!recentObject)
        return;
    
    if (![Switchboard.networkManager hasNetworkConnection])
    {
        [self.tableVM shouldRemoveContactNameFromSelection:recentObject.contactName];
        [self showNetworkError];
        return;
    } else
    {
        [_addedGroupMemberView hideNetworkError];
    }

    // TODO: Replace that after RecentObject refactor with a .uuid check
    if(!recentObject.contactName)
        return;
    
    if(contactType == scsContactTypeDirectory || contactType == scsContactTypeAddressBookSilentCircle || contactType == scsContactTypeSearch)
    {
        [self addRecentToMembers:recentObject];
        [self updateGroupCreationViews];
        return;
    }

    if(recentObject.isNumber) {
        
        [self showAlertControllerWithError:NSLocalizedString(@"Not a valid user", nil)];
        [self.tableVM shouldRemoveContactNameFromSelection:recentObject.contactName];
        return;
    }
    
    DDLogError(@"%s Recent object shouldn't be added! %@", __PRETTY_FUNCTION__, recentObject);
}

- (void)addRecentToMembers:(RecentObject *)recentObject {
    [_addedGroupMemberView addMember:recentObject];
}


-(void)didRemoveRecentObjectFromSelection:(RecentObject *)recentObject
{
    if (![Switchboard.networkManager hasNetworkConnection])
    {
        [self showNetworkError];
        return;
    }else
    {
        [_addedGroupMemberView hideNetworkError];
    }
    [_addedGroupMemberView removeMember:recentObject];
    [self updateGroupCreationViews];
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [_addedGroupMemberView transitionScrollViewToSize:size];
}


-(void) updateGroupCreationViews
{
    BOOL shouldOpen = NO;
    if ([_addedGroupMemberView getAllMembers].count > 0)
    {
        shouldOpen = YES;
    }
    
    if (shouldOpen)
    {
        _addGroupMemberViewHeightConstraint.constant = kAddGroupMemberViewHeight;
        [groupCreateButton setImage:[UIImage groupCreateEnabledIcon] forState:UIControlStateNormal];
        [groupCreateButton.layer addAnimation:[CATransition animation] forKey:kCATransition];
    } else
    {
        _addGroupMemberViewHeightConstraint.constant = 0;
        [groupCreateButton setImage:[UIImage groupCreateDisabledIcon] forState:UIControlStateNormal];
        [groupCreateButton.layer addAnimation:[CATransition animation] forKey:kCATransition];
    }
    [UIView animateWithDuration:0.2f animations:^{
        [self.view layoutIfNeeded];
    }];
}

-(void) showNetworkError
{
    NSArray *addedMembers = [[_addedGroupMemberView getAllMembers] copy];
    for (RecentObject *member in addedMembers)
    {
        [self.tableVM shouldRemoveContactNameFromSelection:member.contactName];
        [_addedGroupMemberView removeMember:member];
    }
    [_addedGroupMemberView showNetworkError];
    _addGroupMemberViewHeightConstraint.constant = kAddGroupMemberViewHeight;
    [groupCreateButton setImage:[UIImage groupCreateDisabledIcon] forState:UIControlStateNormal];
    [groupCreateButton.layer addAnimation:[CATransition animation] forKey:kCATransition];
}

#pragma mark group creation

-(void) createNewGroup
{
    self.navigationItem.rightBarButtonItem = [self getActivityIndicatorBarButtonItem];
    NSArray *groupMembers = [_addedGroupMemberView getAllMembers];
    
    if (groupMembers.count == 0) {
        
        [self showAlertControllerWithError:NSLocalizedString(@"You must add at least one group member", nil)];
        self.navigationItem.rightBarButtonItem = [self getRightBarButtonItem];
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        NSString *groupName = [[GroupChatManager sharedInstance] getDisplayNameForGroupMembers:groupMembers];
        
        NSString *groupUUID = [[GroupChatManager sharedInstance] createGroup];
        
        if (!groupUUID) {
            
            dispatch_async(dispatch_get_main_queue(), ^{

                [self showAlertControllerWithError:NSLocalizedString(@"Error while creating group. Please try again.", nil)];
                self.navigationItem.rightBarButtonItem = [self getRightBarButtonItem];
            });
            
            return;
        }
        
        RecentObject *recent = [[DBManager dBManagerInstance] getOrCreateRecentObjectForReceivedMessage:groupUUID
                                                                                         andDisplayName:groupName
                                                                                                isGroup:YES];
        recent.isGroupRecent = 1;
        recent.displayName = groupName;
        // save recent object here because after saving group message recent is not resaved again
        [[DBManager dBManagerInstance] saveRecentObject:recent];
        
        [[ChatUtilities utilitiesInstance] assignSelectedRecent:groupUUID
                                                      withProps:nil];
        
        [GroupChatManager createGroupStatusMessageWithDict:@{@"grpId":groupUUID,@"name":groupName}
                                                   message:@"Group created"
                                                 showAlert:NO];
        
        [[GroupChatManager sharedInstance] setBurnTime:[ChatUtilities utilitiesInstance].kDefaultBurnTime
                                               inGroup:groupUUID];
        
        for (RecentObject *recent in groupMembers)
        {
            [[GroupChatManager sharedInstance] addUser:recent
                                               inGroup:groupUUID];
        }
        
        [[GroupChatManager sharedInstance] applyGroupChanges:groupUUID];
        [[GroupChatManager sharedInstance] resetGeneratedAvatarForGroup:groupUUID showAlert:NO showMessage:NO];
        dispatch_async(dispatch_get_main_queue(), ^{
            
            UIStoryboard *chatStoryBoard = [UIStoryboard storyboardWithName:@"Chat" bundle:nil];
            ChatViewController *chatViewController = (ChatViewController *)[chatStoryBoard instantiateViewControllerWithIdentifier:@"ChatViewController"];
            chatViewController.displayTitle = groupName;
            
            if ([chatViewController respondsToSelector:@selector(transitionDelegate)])
                [chatViewController setValue:self.transitionDelegate forKey:@"transitionDelegate"];
            
            [self.navigationController setViewControllers:@[self.navigationController.viewControllers[0], chatViewController]];
        });
    });
}

#pragma mark UINavigationBar

-(void) updateNavigationTitleWithParticipants
{
    long newMemberCount = [_addedGroupMemberView getAllMembers].count;
    NSString *title = @"";
    
    // we are adding people to group so put "Add" string at the begining of title
    // otherwise show number of added members and word participants after the number
    if (self.alreadyAddedContacts != 0)
    {
        if (newMemberCount > 0)
        {
            title = [NSString stringWithFormat:@"%@ %li %@",kAdd,newMemberCount,(newMemberCount == 1)?kParticipant:kParticipants];
        } else
        {
            title = [NSString stringWithFormat:@"%@ %@",kAdd,kParticipants];
        }
        
        title = [title capitalizedString];
    }
    else if(newMemberCount > 0)
    {
        title = [[NSString stringWithFormat:@"%li %@",newMemberCount,(newMemberCount == 1)?kParticipant:kParticipants] capitalizedString];
    }
    else
    {
        title = kNewGroupConversation;
    }
    
    self.title = title;
}


-(UIBarButtonItem *) getLeftBarButtonItem
{
    UIButton *backButton = [ChatUtilities getNavigationBarBackButton];
    [backButton addTarget:self action:@selector(dimissController:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *leftBarButton = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    return leftBarButton;
}

-(UIBarButtonItem *) getRightBarButtonItem
{
    groupCreateButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [groupCreateButton setFrame:CGRectMake(0,0,30,30)];
    [groupCreateButton setUserInteractionEnabled:YES];
    [groupCreateButton setAccessibilityLabel:NSLocalizedString(@"Done", nil)];
    [groupCreateButton setImage:[UIImage groupCreateDisabledIcon]
                       forState:UIControlStateNormal];
    [groupCreateButton addTarget:self action:@selector(acceptSelection) forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *rightBarButton = [[UIBarButtonItem alloc] initWithCustomView:groupCreateButton];
    return rightBarButton;
}

-(UIBarButtonItem *) getActivityIndicatorBarButtonItem
{
    UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [activityIndicator startAnimating];
    UIBarButtonItem *rightBarButton = [[UIBarButtonItem alloc] initWithCustomView:activityIndicator];
    return rightBarButton;
}

-(void) showAlertControllerWithError:(NSString *) errorMessage
{
    if (errorMessage)
    {
        UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"Error" message:errorMessage preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* okAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"OK", nil)
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction * action)
                                   {
                                       [errorAlert dismissViewControllerAnimated:YES completion:nil];
                                   }];
        
        [errorAlert addAction:okAction];
        
        [self presentViewController:errorAlert animated:YES completion:nil];
        return;
    }
}
@end
