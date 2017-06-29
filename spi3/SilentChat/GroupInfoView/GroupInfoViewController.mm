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
//  GroupInfoViewController.m
//  SPi3
//
//  Created by Gints Osis on 09/12/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "GroupInfoViewController.h"
#import "SCSContactTVCell.h"
#import "RecentObject.h"
#import "DBManager.h"
#import "ChatUtilities.h"
#import "NSDate+SCDate.h"
#import "UIImage+ApplicationImages.h"
#import "SCSContactsManager.h"
#import "SCSTransitionDelegate.h"
#import "GroupChatManager.h"
#import "GroupChatManager+Members.h"
#import "GroupChatManager+AvatarUpdate.h"
#import "GroupChatManager+UI.h"
#import "SCSGroupSectionObject.h"
#import "SCSConstants.h"
#import "SCSGroupInfoObject.h"
#import "SCSContactTVCell.h"
#import "GroupInfoTableViewCell.h"
#import "GroupActionTableViewCell.h"
#import "SCSSearchVMHeaderFooterView.h"
#import "GroupInfoTextField.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "SCCImageUtilities.h"
#import "ChatViewController.h"
#import "SCPCallbackInterface.h"
#import "SCSAvatarManager.h"

static CGFloat const kContactCellHeight = 80.;

@interface GroupInfoViewController () < SCSContactTVCellDelegate,
                                        CNContactPickerDelegate,
                                        CNContactViewControllerDelegate,
                                        GroupActionDelegate > {
                                            
    NSArray *dataSource;
    float _scrollViewLastOffset;
    
    RecentObject *groupRecent;
    
    RecentObject *recentToSave;
                                           
    UITextField *_groupNameTextfield;
}
@end

@implementation GroupInfoViewController

#pragma mark - Lifecycle

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    
    if(self = [super initWithCoder:aDecoder])
    {
        [self registerNotifications];
    }
    
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];

    [self registerNotifications];

    [_activityView startAnimating];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [self formatDataSource];
    });
    
    self.navigationItem.leftBarButtonItem = [self getLeftBarButtonItem];
    
}

- (void)viewDidLoad {

    [super viewDidLoad];
    
    UINib *cell = [UINib nibWithNibName:@"SCSContactTVCell" bundle:nil];
    [self.tableView registerNib:cell forCellReuseIdentifier:[SCSContactTVCell reuseId]];
    
    UINib *headerfooter = [UINib nibWithNibName:@"SCSSearchVMHeaderFooterView" bundle:nil];
    [self.tableView registerNib:headerfooter forHeaderFooterViewReuseIdentifier:[SCSSearchVMHeaderFooterView reusedId]];
    
    self.title = NSLocalizedString(kGroupMembers, nil);
}

#pragma mark - Private

-(void) registerNotifications {
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(recentObjectUpdated:)
                                                 name:kSCSRecentObjectUpdatedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(recentObjectRemoved:)
                                                 name:kSCSRecentObjectRemovedNotification
                                               object:nil];
}

-(void) updateGroupAvatar
{
    UIImage *avatarImage = [AvatarManager avatarImageForConversationObject:groupRecent size:eAvatarSizeFull];
    [_headerContactView setImage:avatarImage];
}

-(void) formatDataSource {
    
    NSArray *members = [GroupChatManager getAllGroupMemberInfo:_groupUUID];
    
    groupRecent = [[DBManager dBManagerInstance] getRecentByName:_groupUUID];
    [self performSelectorOnMainThread:@selector(updateGroupAvatar) withObject:nil waitUntilDone:NO];
    
    NSMutableArray *recentArray = [[NSMutableArray alloc] initWithCapacity:members.count];
    
    for (NSDictionary *info in members) {
        
        NSString *name = [info objectForKey:@"contactName"];
        double joinTime = ((NSNumber *)[info objectForKey:@"joinTime"]).doubleValue;
        
        if(!name)
            continue;
        
        RecentObject *recent = [Switchboard.userResolver cachedRecentWithUUID:name];
        
        if(!recent) {

            recent = [RecentObject new];
            recent.contactName          = name;
            recent.isPartiallyLoaded    = YES;
            
            // FIXME: We do this temporarily until we also
            // save the member's RecentObjects instances in
            // the database (with the RecentObject refactor).
            [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectShouldResolveNotification
                                                                object:self
                                                              userInfo:@{ kSCPRecentObjectDictionaryKey : recent }];
        }
        
        recent.unixTimeStamp = joinTime;
        [recentArray addObject:recent];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        dataSource = [self getInfoSectionsForMembers:recentArray];
        
        [self.tableView reloadData];
        [_activityView stopAnimating];
    });
}

-(void) recentObjectUpdated:(NSNotification *) note {
    
    RecentObject *updatedRecent = [note.userInfo objectForKey:kSCPRecentObjectDictionaryKey];
    
    if(!updatedRecent)
        return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self updateGroupAvatar];
        [self reloadCellWithRecentObject:updatedRecent];
    });
}

-(void) recentObjectRemoved:(NSNotification *) note
{
    RecentObject *removedRecent = [note.userInfo objectForKey:kSCPRecentObjectDictionaryKey];
    if ([removedRecent isEqual:groupRecent] || groupRecent == nil)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.transitionDelegate transitionToConversationsFromVC:self];
        });
    }
}

-(void) reloadCellWithRecentObject:(RecentObject *) updatedRecent {
    
    NSString *updatedContactName = [[ChatUtilities utilitiesInstance] removePeerInfo:updatedRecent.contactName lowerCase:YES];
    
    for (int i = 0; i<dataSource.count; i++)
    {
        SCSGroupSectionObject *groupSection = dataSource[i];
        
        if (groupSection.sectionType != eGroupMembers)
            continue;
        
        for (int j = 0; j < groupSection.objectsArray.count; j++) {
            
            RecentObject *recent = groupSection.objectsArray[j];
            
            NSString *strippedContactName = [[ChatUtilities utilitiesInstance] removePeerInfo:recent.contactName lowerCase:YES];
            
            if ([strippedContactName isEqualToString:updatedContactName])
            {
                [recent setIsPartiallyLoaded:NO];
                [recent updateWithRecent:updatedRecent];
                
                NSIndexPath *indexPathToReload = [NSIndexPath indexPathForRow:j inSection:i];
                [self.tableView reloadRowsAtIndexPaths:@[indexPathToReload] withRowAnimation:UITableViewRowAnimationNone];
            }
        }
    }
}

#pragma mark - UIScrollViewDelegate

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    
    // Resign the keyboard when user starts scrolling
    
    if(_groupNameTextfield)
        [_groupNameTextfield resignFirstResponder];
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    if(scrollView.contentOffset.y <0) {
        
        CGPoint currentOffset = scrollView.contentOffset;
        _headerHeightConstraint.constant -=currentOffset.y - _scrollViewLastOffset;
        _scrollViewLastOffset = currentOffset.y;
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    [self.tableView deselectRowAtIndexPath:indexPath
                                  animated:YES];

    SCSGroupSectionObject *sectionObject = dataSource[indexPath.section];
    
    if (sectionObject.sectionType != eGroupMembers)
        return;
    
    RecentObject *recent = (RecentObject *)sectionObject.objectsArray[indexPath.row];

    if(!recent)
        return;
    
    // Don't allow to create new chat threads
    // until the full info for that user
    // has been fetched.
    if(recent.isPartiallyLoaded)
        return;
    
    NSString *ownUserName = [[ChatUtilities utilitiesInstance] getOwnUserName];
    NSString *userNameWithoutPeerInfo = [[ChatUtilities utilitiesInstance] removePeerInfo:recent.contactName lowerCase:NO];
    
    if ([ownUserName isEqualToString:userNameWithoutPeerInfo])
        return;
    
    UIStoryboard *chatStoryBoard = [UIStoryboard storyboardWithName:@"Chat" bundle:nil];
        
    ChatViewController *chatViewController = (ChatViewController *)[chatStoryBoard instantiateViewControllerWithIdentifier:@"ChatViewController"];
    chatViewController.displayTitle = recent.displayName;
        
    [ChatUtilities utilitiesInstance].selectedRecentObject = [[DBManager dBManagerInstance] getOrCreateRecentObjectWithContactName:recent.contactName];
        
    if ([chatViewController respondsToSelector:@selector(transitionDelegate)])
        [chatViewController setValue:self.transitionDelegate forKey:@"transitionDelegate"];
        
    // Replace nav stack and animate "Back" navigation
    NSMutableArray *vcs = [@[] mutableCopy];
    [vcs addObject:self.navigationController.viewControllers[0]]; // mainTVC
    [vcs addObject:chatViewController];
    [vcs addObject:self];
    
    [self.navigationController setViewControllers:vcs];
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - UITableViewDelegate

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    SCSGroupSectionObject *sectionObject = dataSource[indexPath.section];
    
    if (sectionObject.sectionType == eGroupMembers)
        return kContactCellHeight;
    else
        return 50;
}

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    
    SCSGroupSectionObject *sectionObject = (SCSGroupSectionObject *)dataSource[section];
    
    SCSSearchVMHeaderFooterView *headerFooterView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:[SCSSearchVMHeaderFooterView reusedId]];
    headerFooterView.mainTitle.text = sectionObject.headerTitle;
    headerFooterView.subtitle.text = @"";
    return headerFooterView;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {

    SCSGroupSectionObject *sectionObject = dataSource[section];

    if(!sectionObject)
        return 0;
    
    if(sectionObject.sectionType == eGroupActions)
        return 0;
    
    return 25;
}

#pragma mark - UITableViewDataSource

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    return dataSource.count;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    SCSGroupSectionObject *sectionObject = dataSource[section];
    
    if(!sectionObject)
        return 0;
    
    if(!sectionObject.objectsArray)
        return 0;
    
    return sectionObject.objectsArray.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    SCSGroupSectionObject *sectionObject = dataSource[indexPath.section];
    
    if (sectionObject.sectionType == eGroupMembers) {
        
        RecentObject *recent = (RecentObject *)sectionObject.objectsArray[indexPath.row];
        SCSContactTVCell *cell = [tableView dequeueReusableCellWithIdentifier:[SCSContactTVCell reuseId]];
    
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        [cell.messageAlertView setHidden:YES];
        [cell.addGroupMemberImageView setHidden:YES];
        [cell.callIconView setHidden:YES];
        cell.delegate = self;
        
        UIImage *image = [AvatarManager avatarImageForConversationObject:recent size:eAvatarSizeSmall];
        
        [cell.contactView setImage:image];

        // FIXME: We are doing this temporarily until we
        // make the RecentObject refactor
        if([[ChatUtilities utilitiesInstance] isUUID:recent.displayAlias])
            cell.lastMessageTextLabel.text = @"...";
        else
            cell.lastMessageTextLabel.text = recent.displayAlias;
        
        NSString *displayName = recent.displayName;
        
        cell.contactNameLabel.text = displayName;
        
        NSDate *lastDate = [NSDate dateWithTimeIntervalSince1970:(int)recent.unixTimeStamp];
        
        NSString *timeLabelString = [[ChatUtilities utilitiesInstance] chatListDateFromDateStamp:recent.unixTimeStamp];
        
        if([lastDate isToday])
            timeLabelString = [[ChatUtilities utilitiesInstance] takeTimeFromDateStamp:(int)recent.unixTimeStamp];
        else if([lastDate isYesterday])
            timeLabelString = NSLocalizedString(kYesterday, nil);
        
        timeLabelString = [NSString stringWithFormat:@"%@\n %@",NSLocalizedString(kJoined, nil),timeLabelString];
        [cell.lastMessageTimeLabel setText:timeLabelString];
        [cell.lastMessageTimeLabel setAccessibilityLabel:timeLabelString];
        return cell;
    }
    else if(sectionObject.sectionType == eGroupName) {
        
        GroupInfoTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[GroupInfoTableViewCell reuseIdentifier]];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.valueTextField.userInteractionEnabled = YES;
        cell.valueTextField.sectionType = sectionObject.sectionType;
        
        SCSGroupInfoObject * infoObject = (SCSGroupInfoObject *)sectionObject.objectsArray[indexPath.row];
        cell.valueTextField.text = infoObject.value;
        
        return cell;
    }
    else {
        
        GroupActionTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[GroupActionTableViewCell reuseIdentifier]];
        cell.delegate = self;
        
        return cell;
    }
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    
    _groupNameTextfield = textField;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    
    _groupNameTextfield = nil;
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (!groupRecent)
        return YES;
    NSString *lastDisplayName = groupRecent.displayName;
    NSString *textFieldText = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([textFieldText isEqualToString:lastDisplayName])
    {
        [textField resignFirstResponder];
        return YES;
    }
    
    if (textFieldText.length == 0)
    {
        textField.text = groupRecent.displayName;
        [self showAlertControllerWithErrorString:kErrorEmptyDisplayName];
        return NO;
    }
    if (textFieldText.length > 50)
    {
        textField.text = groupRecent.displayName;
        [self showAlertControllerWithErrorString:kErrorTooLongDisplayName];
        return NO;
    }
    GroupInfoTextField *infoTextField = (GroupInfoTextField *) textField;
    switch (infoTextField.sectionType)
    {
        case eGroupName:
        {
            groupRecent.displayName = textFieldText;
            groupRecent.hasGroupNameBeenSetExplicitly = YES;
            [[DBManager dBManagerInstance] saveRecentObject:groupRecent];
            [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectUpdatedNotification object:self userInfo:@{kSCPRecentObjectDictionaryKey:groupRecent}];
            
            NSString *message = [NSString stringWithFormat:@"%@ %@",kUserGroupNameChange,textFieldText];
            [GroupChatManager createGroupStatusMessageWithDict:@{@"grpId":groupRecent.contactName,@"name":groupRecent.displayName} message:message showAlert:NO];
            
            [[GroupChatManager sharedInstance] setName:textFieldText inGroup:groupRecent.contactName];
            [[GroupChatManager sharedInstance] applyGroupChanges:groupRecent.contactName];
        }
            break;
            
        default:
            break;
    }
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - MGSwipeTableCellDelegate

-(BOOL)swipeTableCell:(MGSwipeTableCell *)cell canSwipe:(MGSwipeDirection)direction fromPoint:(CGPoint)point {

    if(direction == MGSwipeDirectionRightToLeft)
        return NO;

    return YES;
}

-(NSArray*) swipeTableCell:(SCSContactTVCell*) cell swipeButtonsForDirection:(MGSwipeDirection)direction
             swipeSettings:(MGSwipeSettings*) swipeSettings expansionSettings:(MGSwipeExpansionSettings*) expansionSettings
{
    swipeSettings.transition = MGSwipeTransitionDrag;
    
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    
    SCSGroupSectionObject *sectionObject = dataSource[indexPath.section];
    RecentObject *recentObjectFromCell = sectionObject.objectsArray[indexPath.row];

    if(recentObjectFromCell.isPartiallyLoaded)
        return @[];
    
    NSMutableArray *actions = [NSMutableArray new];
    
    // Place Call
    MGSwipeButton *callButton = [MGSwipeButton buttonWithTitle:@""
                                                          icon:[UIImage swipeCallIcon]
                                               backgroundColor:[UIColor clearColor]
                                                      callback:^BOOL(MGSwipeTableCell *sender) {
                                                          
                                                          [self placeCallWithSwipeCell:cell];
                                                          return YES;
                                                      }];
    [callButton setTag:25];
    
    [actions addObject:callButton];
    
    // Save to Contacts
    if (!recentObjectFromCell.abContact) {
        
        MGSwipeButton *saveToContactsButton = [MGSwipeButton buttonWithTitle:@""
                                                                        icon:[UIImage swipeSaveContactsIcon]
                                                             backgroundColor:[UIColor clearColor]
                                                                    callback:^BOOL(MGSwipeTableCell *sender) {
                                                                        
                                                                        [self saveContactWithSwipeCell:cell];
                                                                        return YES;
                                                                    }];
        [saveToContactsButton setTag:26];
        
        [actions addObject:saveToContactsButton];
    }
    
    return actions;
}

#pragma mark - SwipeCell Action Methods
/*
 * TODO: abstract an accessor for the common code used to get the
 * recentObject in the call/chatButtonClicked: methods.
 */
-(void)placeCallWithSwipeCell:(SCSContactTVCell *)cell
{
    
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    NSString *contactName = nil;
    SCSGroupSectionObject *sectionObject = dataSource[indexPath.section];
    RecentObject *selectedRecent = sectionObject.objectsArray[indexPath.row];
    contactName = selectedRecent.contactName;

    if ([_transitionDelegate respondsToSelector:@selector(placeCallFromVC:withNumber:)])
    {
        [_transitionDelegate placeCallFromVC:self withNumber:contactName];
    }
    
}

-(void)saveContactWithSwipeCell:(SCSContactTVCell *)cell {
    
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    SCSGroupSectionObject *sectionObject = dataSource[indexPath.section];
    recentToSave = sectionObject.objectsArray[indexPath.row];
    
    if(!recentToSave)
        return;
    
    
    [self showSaveChoices:cell];
}

#pragma mark - Save Contact

- (void)showSaveChoices:(MGSwipeTableCell *)cell {
    
    UIAlertController *chooseContactSaveType = [UIAlertController alertControllerWithTitle:nil
                                                                                   message:nil
                                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *contactSaveTypeNewAction = [UIAlertAction actionWithTitle:NSLocalizedString(kCreateNewContact, nil)
                                                                       style:UIAlertActionStyleDefault
                                                                     handler:^(UIAlertAction * _Nonnull action) {
                                                                         
                                                                         CNContact *contact = [[SCSContactsManager sharedManager] addressBookContactWithRecentObject:recentToSave];
                                                                         
                                                                         [self showNewContactControllerForContact:contact
                                                                                                            isNew:YES];
                                                                     }];
    [chooseContactSaveType addAction:contactSaveTypeNewAction];
    
    UIAlertAction *contactSaveTypeExistingAction = [UIAlertAction actionWithTitle:NSLocalizedString(kAddToExisting, nil)
                                                                            style:UIAlertActionStyleDefault
                                                                          handler:^(UIAlertAction * _Nonnull action) {
                                                                              
                                                                              [self showContactPicker];
                                                                          }];
    [chooseContactSaveType addAction:contactSaveTypeExistingAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(kCancel, nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [chooseContactSaveType addAction:cancelAction];
    
    if([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        
        UIPopoverPresentationController *popPresenter = [chooseContactSaveType popoverPresentationController];
        popPresenter.sourceView = cell;
        popPresenter.sourceRect = [cell bounds];
    }
    
    [self presentViewController:chooseContactSaveType
                       animated:YES
                     completion:nil];
}

- (void)showNewContactControllerForContact:(CNContact *)contact isNew:(BOOL)isNew {
    
    CNContactStore *contactStore = [CNContactStore new];
    
    CNContactViewController *contactVC = [CNContactViewController viewControllerForNewContact:contact];
    [contactVC setContactStore:contactStore];
    [contactVC setTitle:(isNew ? NSLocalizedString(@"New Contact", nil) : NSLocalizedString(@"Update Contact", nil))];
    [contactVC setDelegate:self];
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:contactVC];
    [navigationController.navigationBar setTintColor:[UIColor whiteColor]];
    [navigationController.navigationBar setBarStyle:UIBarStyleBlack];

    [self presentViewController:navigationController
                       animated:YES
                     completion:nil];
}

- (void)showContactPicker {
    
    CNContactPickerViewController *contactPickerVC = [CNContactPickerViewController new];
    [contactPickerVC setDelegate:self];
    
    [self presentViewController:contactPickerVC
                       animated:YES
                     completion:nil];
}

#pragma mark - CNContactViewControllerDelegate

- (void)contactViewController:(CNContactViewController *)viewController didCompleteWithContact:(CNContact *)contact {
    
    [viewController.navigationController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - CNContactPickerDelegate

- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContact:(CNContact *)contact {
    
    [picker dismissViewControllerAnimated:NO completion:nil];
    
    CNContact *updatedContact = [[SCSContactsManager sharedManager] updateContact:contact
                                                                 withRecentObject:recentToSave];
    
    if(updatedContact)
        [self showNewContactControllerForContact:updatedContact
                                           isNew:NO];
}


#pragma mark Group Section Getter
-(NSArray *) getInfoSectionsForMembers:(NSArray *) membersArray
{
    SCSGroupSectionObject *groupNameSection = [[SCSGroupSectionObject alloc] init];
    groupNameSection.sectionType = eGroupName;
    groupNameSection.headerTitle = NSLocalizedString(kGroupName, nil);
    
    SCSGroupInfoObject *groupNameInfoObject = [[SCSGroupInfoObject alloc] init];
    groupNameInfoObject.value = groupRecent.displayName;
    groupNameSection.objectsArray = @[groupNameInfoObject];
    
    SCSGroupSectionObject *groupMembersSection = [[SCSGroupSectionObject alloc] init];
    groupMembersSection.sectionType = eGroupMembers;
    groupMembersSection.headerTitle = NSLocalizedString(kPeople, nil);
    groupMembersSection.objectsArray = membersArray;
    
    SCSGroupSectionObject *groupActionsSection = [[SCSGroupSectionObject alloc] init];
    groupActionsSection.sectionType = eGroupActions;
    groupActionsSection.headerTitle = NSLocalizedString(kActions, nil);
    groupActionsSection.objectsArray = @[groupRecent];
    
    NSArray *sectionArray = [[NSArray alloc] initWithObjects:groupNameSection,groupMembersSection,groupActionsSection, nil];
    return sectionArray;
}

-(void) showAlertControllerWithErrorString:(NSString *) string
{
    UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"Error" message:string preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* okAction = [UIAlertAction
                               actionWithTitle:NSLocalizedString(@"OK", nil)
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction * action)
                               {
                                   [errorAlert dismissViewControllerAnimated:YES completion:nil];
                               }];
    
    [errorAlert addAction:okAction];
    
    [self presentViewController:errorAlert animated:YES completion:nil];
}

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    __block UIImage *pickedImage = [info objectForKey:UIImagePickerControllerEditedImage];
    __block NSMutableDictionary *blockInfo = [info mutableCopy];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    
        // Selected image has to be scaled down to 512 width before assigning and sending
        if (pickedImage.size.width > [AvatarManager fullSizeAvatarWidth])
        {
            CGSize maxImageSize = CGSizeMake([AvatarManager fullSizeAvatarWidth],pickedImage.size.height * [AvatarManager fullSizeAvatarWidth] / pickedImage.size.width);
            UIImage *scaledImage = [SCCImageUtilities scaleImage:pickedImage ToSize:maxImageSize];
            [AvatarManager setExplicitAvatar:scaledImage forGroup:groupRecent];
            [blockInfo setObject:scaledImage forKey:UIImagePickerControllerOriginalImage];
            [[GroupChatManager sharedInstance] setExplicitAvatar:blockInfo forGroup:groupRecent.contactName];
        } else
        {
            [AvatarManager setExplicitAvatar:pickedImage forGroup:groupRecent];
            [[GroupChatManager sharedInstance] setExplicitAvatar:info forGroup:groupRecent.contactName];
        }
        [self performSelectorOnMainThread:@selector(updateGroupAvatar) withObject:nil waitUntilDone:NO];
    });
}

- (IBAction)changeAvatarTap:(id)sender
{
    
    UIButton *senderButton = (UIButton *)sender;
    
    // Based on profileViewController avatar change options
    UIAlertController *avatarChangeChoices = [UIAlertController alertControllerWithTitle:nil
                                                                            message:nil
                                                                     preferredStyle:UIAlertControllerStyleActionSheet];
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        
        UIAlertAction *cameraUpload = [UIAlertAction actionWithTitle:NSLocalizedString(@"Take Photo", nil)
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * _Nonnull action) {
                                                                 [self presentImagePicker:UIImagePickerControllerSourceTypeCamera];
                                                             }];
        [avatarChangeChoices addAction:cameraUpload];
    }
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        
        UIAlertAction *photoUpload = [UIAlertAction actionWithTitle:NSLocalizedString(@"Choose Existing Photo", nil)
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * _Nonnull action) {
                                                                [self presentImagePicker:UIImagePickerControllerSourceTypePhotoLibrary];
                                                            }];
        [avatarChangeChoices addAction:photoUpload];
    }
    
    if(groupRecent.hasGroupAvatarBeenSetExplicitly) {
        
        UIAlertAction *removeProfile = [UIAlertAction actionWithTitle:NSLocalizedString(@"Remove Avatar Picture", nil)
                                                                style:UIAlertActionStyleDestructive
                                                              handler:^(UIAlertAction * _Nonnull action) {
                                                                  [self removeExplicitlyAvatarImage];
                                                              }];
        [avatarChangeChoices addAction:removeProfile];
    }
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [avatarChangeChoices addAction:cancelAction];
    
    if([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        
        UIPopoverPresentationController *popPresenter = [avatarChangeChoices
                                                         popoverPresentationController];
        popPresenter.sourceView = senderButton;
        popPresenter.sourceRect = senderButton.bounds;
    }
    
    [self presentViewController:avatarChangeChoices animated:YES completion:nil];
}

- (void)presentImagePicker:(UIImagePickerControllerSourceType)sourceType {
    
    UIImagePickerController *ipController = [UIImagePickerController new];
    [ipController setDelegate:self];
    [ipController setAllowsEditing:YES];
    [ipController setSourceType:sourceType];
    
    [self presentViewController:ipController animated:YES completion:nil];
}

-(void) removeExplicitlyAvatarImage
{
    if (groupRecent)
    {
        NSString *contactName = [[ChatUtilities utilitiesInstance] removePeerInfo:groupRecent.contactName lowerCase:YES].uppercaseString;
        
        [[GroupChatManager sharedInstance] resetGeneratedAvatarForGroup:contactName showAlert:NO showMessage:YES];
        [[GroupChatManager sharedInstance] resetAvatarInGroup:contactName];
        [[GroupChatManager sharedInstance] applyGroupChanges:contactName];
    }
}

#pragma mark groupActions
-(void)leaveGroupTapped
{
    UIAlertController *warningController = [UIAlertController 
                                            alertControllerWithTitle:NSLocalizedString(@"Are you sure?", nil) 
                                            message:NSLocalizedString(@"Leaving the group will destroy all its data on this device.  To join the group again, you'll need to be added by another member.", nil)
                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", ni)
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [warningController addAction:cancelAction];
    
    UIAlertAction *acceptAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", ni)
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
                                                             
                                                             [[DBManager dBManagerInstance] removeChatWithContact:groupRecent];                                                                                                                          
                                                             
                                                             [[NSNotificationCenter defaultCenter] 
                                                              postNotificationName:kSCSRecentObjectRemovedNotification 
                                                              object:self 
                                                              userInfo:@{kSCPRecentObjectDictionaryKey:groupRecent}];
                                                             
                                                             dispatch_async(dispatch_get_main_queue(), ^{
                                                                 [self.transitionDelegate transitionToConversationsFromVC:self];
                                                             });                                                             
                                                         }];
    [warningController addAction:acceptAction];
    
    [self presentViewController:warningController animated:YES completion:nil];
}

#pragma mark - Helpers

-(SCSContactTVCell *)getCellFromRecentObject:(RecentObject *)recent
{
    for (NSInteger i = 0; i<dataSource.count; i++) {
        
        SCSGroupSectionObject *sectionObject = dataSource[i];

        if(sectionObject.sectionType != eGroupMembers)
            continue;
        
        for (NSInteger j = 0; j<sectionObject.objectsArray.count; j++) {
            
            RecentObject *recentObject = sectionObject.objectsArray[j];
            
            if ([recentObject isEqual:recent]) {
                
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:j
                                                            inSection:i];
                
                if(!indexPath)
                    return nil;
                
                return [self.tableView cellForRowAtIndexPath:indexPath];
            }
        }
    }
    
    return nil;
}

-(UIBarButtonItem *) getLeftBarButtonItem
{
    UIButton *backButton = [ChatUtilities getNavigationBarBackButton];
    [backButton addTarget:self action:@selector(dismissController) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *leftBarButton = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    return leftBarButton;
}

-(void) dismissController
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
@end
