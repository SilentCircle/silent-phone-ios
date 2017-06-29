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
//  SCSMainTVC.m
//  SPi3
//
//  Created by Eric Turner on 11/8/15.
//  Modified original source by Gints Osis.
//
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//
#import "SCSMainTVC.h"

#import "AttachmentManager.h"
#import "ChatUtilities.h"
#import "ChatViewController.h"
#import "DBManager.h"
#import "SCDRWarningView.h"
#import "SCPCallbackInterface.h"
#import "SCPNotificationKeys.h"
#import "SCSContactsManager.h"
#import "SCSFeatures.h"

#import "UIColor+ApplicationColors.h"

#pragma mark Logging

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelAll;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelWarning;
//#endif

static NSString *const kDRPolicy = @"organization has a policy of retaining data about your communication, however you have blocked Silent Phone from retaining this data. Communication is now prohibited. To restore communication either unset \"Block data retention\" in Silent Phone settings or ask your organization's administrator to remove your data retention policy.";

@interface SCSMainTVC () <SCSContactTVCellDelegate, UITextFieldDelegate, CNContactViewControllerDelegate, CNContactPickerDelegate, SCSSearchVMActionDelegate> {
    
    UILongPressGestureRecognizer *_longPressRecognizer;
    
    UIButton *_burgerButton;
}

@property (strong, nonatomic) RecentObject *recentObjectToSave;

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIView *emptyConversationsView;
@property (weak, nonatomic) IBOutlet UILabel *emptyConversationHeader;
@property (weak, nonatomic) IBOutlet UILabel *emptyConversationMessage;
@property (weak, nonatomic) IBOutlet SCDRWarningView *dataRetentionWarningView;

@end

@implementation SCSMainTVC

#pragma mark - Lifecycle

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    [_emptyConversationHeader setText:NSLocalizedString(@"Start a conversation", nil)];
    [_emptyConversationMessage setText:NSLocalizedString(@"Tap the plus icon to call or text", nil)];

    // Side menu button
    [self.navigationItem.leftBarButtonItem setAccessibilityLabel:NSLocalizedString(@"side menu", nil)];
    
    _burgerButton = (UIButton *)self.navigationItem.leftBarButtonItem.customView;
    [_burgerButton setAdjustsImageWhenHighlighted:NO];
    [_burgerButton setImage:[_burgerButton.imageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                   forState:UIControlStateNormal];
    [_burgerButton addTarget:self
                      action:@selector(showSideMenu:)
            forControlEvents:UIControlEventTouchUpInside];
    
    // listen for online status changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(engineStateDidUpdate:)
                                                 name:kSCPEngineStateDidChangeNotification
                                               object:nil];

    self.navigationItem.rightBarButtonItem = [self newConversationButton];
    
#if HAS_DATA_RETENTION
    _dataRetentionWarningView.infoHolderVC = self;
    [_dataRetentionWarningView positionWarningAboveConstraint:_tableViewTopOffset];
#else
    _dataRetentionWarningView.hidden = YES;
    _dataRetentionWarningView.drButton.hidden = YES;
#endif // HAS_DATA_RETENTION
    
    if (([SCSFeatures logRecents])) {
        
        _longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        _longPressRecognizer.minimumPressDuration = 0.5f;
        _longPressRecognizer.cancelsTouchesInView = YES;
        
        [_tableView addGestureRecognizer:_longPressRecognizer];
    }
    
    self.tableVM = [[scsContactTypeSearchVM alloc] initWithTableView:self.tableView];
    [self.tableVM setActionDelegate:self];
    [self.tableVM setIsSwipeEnabled:YES];
    [self.tableVM setIsMultiSelectEnabled:NO];
    [self.tableVM setHiddenHeaders:scsContactTypeAllConversations];
    [self.tableVM showFullListsOfContactType:scsContactTypeAllConversations];
}

-(void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    [self registerNotifications];
    
    [self updateEmptyConversationsLabel];
    
    [self updateOnlineStatus];
}

- (void)viewWillLayoutSubviews {
    
    [super viewWillLayoutSubviews];
    
#if HAS_DATA_RETENTION
    // data retention
    _dataRetentionWarningView.enabled = [UserService currentUser].drEnabled;
#endif // HAS_DATA_RETENTION
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Private

- (void)showSideMenu:(id)sender {
    
    [self performSegueWithIdentifier:@"showSideMenu"
                              sender:nil];
}

#pragma mark - Notifications

-(void) registerNotifications {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self selector:@selector(updateEmptyConversationsLabel) name:kSCSContactTypeSearchTableUpdated object:nil];    
    [nc addObserver:self selector:@selector(userDidUpdate:) name:kSCSUserServiceUserDidUpdateNotification object:nil];
}

- (void)userDidUpdate:(NSNotification*)notification {
#if HAS_DATA_RETENTION
    _dataRetentionWarningView.enabled = [UserService currentUser].drEnabled;
#endif // HAS_DATA_RETENTION
}

- (void)engineStateDidUpdate:(NSNotification*)notification {
    [self updateOnlineStatus];
}

/**
 * Set side-menu barbutton tint color to reflect account online status.
 *
 * Called by engineStateDidUpdate notification listener.
 */
- (void)updateOnlineStatus {
    NSString *state = [Switchboard currentDOutState:NULL];    

    if([state isEqualToString:@"yes"]) {
        _burgerButton.tintColor = [UIColor connectivityOnlineColor];
    } else if([state isEqualToString:@"connecting"]) {
        _burgerButton.tintColor = [UIColor connectivityConnectingColor];
    } else {
        _burgerButton.tintColor = [UIColor connectivityOfflineColor];
    }
}

#pragma mark - Accessibility Methods

- (void)updateEmptyMessageAccessibility {
    
    _emptyConversationHeader.isAccessibilityElement = !_emptyConversationsView.hidden;
    
    _emptyConversationMessage.isAccessibilityElement = !_emptyConversationsView.hidden;
}

#pragma mark - EmptyConversations Message

-(void) updateEmptyConversationsLabel {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if([self.tableVM isTableViewEmpty])
            [self showEmptyConversationMessage];
        else
            [self hideEmptyConversationMessage];
    });
}

-(void)showEmptyConversationMessage {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        _emptyConversationsView.hidden = NO;
        
        [self updateEmptyMessageAccessibility];
    });
}

- (void)hideEmptyConversationMessage {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        _emptyConversationsView.hidden = YES;
        
        [self updateEmptyMessageAccessibility];
    });
}

#pragma mark - SwipeCell Action Methods

-(void)placeCallWithRecentObject:(RecentObject *) recentObject
{
    if(![Switchboard allAccountsOnline])
    {
        [[ChatUtilities utilitiesInstance] showNoNetworkErrorForConversation:recentObject actionType:eCall];
        return;
    }
    NSDictionary *userInfo = @{kSCPOutgoingCallNumber: recentObject.contactName};
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSCPOutgoingCallRequestNotification
                                                        object:self
                                                      userInfo:userInfo];
}

-(void)saveContactWithRecentObject:(RecentObject *) recentObject {
    
    _recentObjectToSave = recentObject;
    
    if(!_recentObjectToSave)
        return;
    
    [self showSaveChoices:recentObject];
}

#pragma mark - SearchVMActionDelegate

-(void)didTapRecentObject:(RecentObject *)recentObject {
    
    [self presentChatWithRecentObject:recentObject];
}

-(void)didTapCallButtonOnRecentObject:(RecentObject *)recentObject {
    
    [self placeCallWithRecentObject:recentObject];
}

-(void)didTapSaveContactsButtonOnRecentObject:(RecentObject *)recentObject {
    
    [self saveContactWithRecentObject:recentObject];
}

-(void)didTapDeleteButtonOnRecentObject:(RecentObject *)recentObject {
    
    if (!recentObject.isGroupRecent) {
        [[DBManager dBManagerInstance] removeChatWithContact:recentObject];
    }
}

-(void) didTapDeleteButtonOnGroupRecent:(RecentObject *) recentObj {
    if (recentObj.isGroupRecent) {
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
                                                                 [[DBManager dBManagerInstance] removeChatWithContact:recentObj];
                                                                 
                                                                 [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectRemovedNotification object:self userInfo:@{kSCPRecentObjectDictionaryKey:recentObj}];
                                                             }];
        [warningController addAction:acceptAction];
        
        [self presentViewController:warningController animated:YES completion:nil];
        
    }    
}

#pragma mark - Present Chat - Cell Tapped

-(void)presentChatWithRecentObject:(RecentObject *) selectedRecent {
    
    NSString *contactName = selectedRecent.contactName;
    
#if HAS_DATA_RETENTION
    if ([UserService isDRBlockedForContact:selectedRecent]) {
        
        // if data retention is enabled for either me or this contact, throw an alert and exit
        BOOL allowViewConv = [[DBManager dBManagerInstance] existsRecentByName:contactName];
        NSString *title = (allowViewConv) ? @"Communication Prohibited" : @"Unable to start conversation";

        NSString *org = ([UserService currentUser].drEnabled) ? @"Your " : @"Recipient's ";
        NSString *msg = [org stringByAppendingString:kDRPolicy];

        UIAlertController *errorController = [UIAlertController alertControllerWithTitle:NSLocalizedString(title, nil)
                                                                                 message:NSLocalizedString(msg, @"Data retention settings conflict")
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {

                                                             if (allowViewConv) {

                                                                 // they can still view the conversation
                                                                 [[ChatUtilities utilitiesInstance] assignSelectedRecent:contactName
                                                                                                               withProps:nil];

                                                                 if(_transitionDelegate  && [_transitionDelegate respondsToSelector:@selector(transitionToChatWithContactName:)])
                                                                     [_transitionDelegate transitionToChatWithContactName:contactName];
                                                             }
                                                         }];
        [errorController addAction:okAction];
        
        [self presentViewController:errorController
                           animated:YES
                         completion:nil];
        
        return;
    }
#endif // HAS_DATA_RETENTION

    [[ChatUtilities utilitiesInstance] assignSelectedRecent:contactName
                                                  withProps:nil];
    
    if(_transitionDelegate  && [_transitionDelegate respondsToSelector:@selector(transitionToChatWithContactName:)])
        [_transitionDelegate transitionToChatWithContactName:contactName];
}

#pragma mark - Present ChatVC

-(void)openChatViewWithSelectedUserAndFileURL:(NSURL*)fileURL title:(NSString *)dtitle animated:(BOOL)animated {
    
    if([self.navigationController.topViewController isKindOfClass:[ChatViewController class]])
        return;
    
    ChatViewController *chatVC = [self chatViewControllerWithTitle:dtitle
                                                           fileURL:fileURL];
    
    [self.navigationController pushViewController:chatVC
                                         animated:animated];
}

- (ChatViewController *)chatViewControllerWithTitle:(NSString *)title fileURL:(NSURL *)fileURL {
    
    UIStoryboard *sbChat = [UIStoryboard storyboardWithName:@"Chat" bundle:nil];
    ChatViewController *chatVC = [sbChat instantiateInitialViewController];
    chatVC.transitionDelegate = self.transitionDelegate;
    chatVC.displayTitle = title;
    
    if(fileURL)
        chatVC.pendingOpenInAttachmentURL = fileURL;
    
    return chatVC;
}

#pragma mark - Save Contact

- (void)showSaveChoices:(RecentObject *)recentObject {
    
    UIAlertController *chooseContactSaveType = [UIAlertController alertControllerWithTitle:nil
                                                                                   message:nil
                                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *contactSaveTypeNewAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Create New Contact", nil)
                                                                       style:UIAlertActionStyleDefault
                                                                     handler:^(UIAlertAction * _Nonnull action) {
                                                                         
                                                                         CNContact *contact = [[SCSContactsManager sharedManager] addressBookContactWithRecentObject:_recentObjectToSave];
                                                                         [self showNewContactControllerForContact:contact
                                                                                                            isNew:YES];
                                                                     }];
    [chooseContactSaveType addAction:contactSaveTypeNewAction];
    
    UIAlertAction *contactSaveTypeExistingAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Add to Existing Contact", nil)
                                                                            style:UIAlertActionStyleDefault
                                                                          handler:^(UIAlertAction * _Nonnull action) {
                                                                              
                                                                              [self showContactPicker];
                                                                          }];
    [chooseContactSaveType addAction:contactSaveTypeExistingAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [chooseContactSaveType addAction:cancelAction];
    
    
    if([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        
        SCSContactTVCell *cell = [self.tableVM getCellFromRecentObject:recentObject];
        
        if (!cell)
            return;
        
        UIPopoverPresentationController *popPresenter = [chooseContactSaveType popoverPresentationController];
        popPresenter.sourceView = cell;
        popPresenter.sourceRect = [cell bounds];
    }
    
    [self presentViewController:chooseContactSaveType
                       animated:YES
                     completion:nil];
}

- (void)handleLongPress:(UIGestureRecognizer *)gestureRecognizer {
    
    if (gestureRecognizer.state != UIGestureRecognizerStateBegan)
        return;
    
    CGPoint tableViewTouchPoint = [gestureRecognizer locationInView:_tableView];
    
    NSIndexPath *indexPath = [_tableView indexPathForRowAtPoint:tableViewTouchPoint];
    
    SCSContactTVCell *cell = (SCSContactTVCell *)[_tableView cellForRowAtIndexPath:indexPath];
    
    if (!cell)
        return;
    
    RecentObject *cellRecent = [self.tableVM getRecentObjectFromCell:cell];
    NSString *message = [NSString stringWithFormat:@"%@", [cellRecent dictionaryRepresentation]];
    UIAlertController *recentAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Conversation Data", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* okAction = [UIAlertAction
                               actionWithTitle:NSLocalizedString(@"OK", nil)
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction * action)
                               {
                                   [recentAlert dismissViewControllerAnimated:YES completion:nil];
                               }];
    
    [recentAlert addAction:okAction];
    [self presentViewController:recentAlert animated:YES completion:nil];
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
    
    [picker dismissViewControllerAnimated:NO
                               completion:nil];
    
    CNContact *updatedContact = [[SCSContactsManager sharedManager] updateContact:contact
                                                                 withRecentObject:_recentObjectToSave];
    
    if(updatedContact)
        [self showNewContactControllerForContact:updatedContact
                                           isNew:NO];
}


#pragma mark - UIViewController Methods

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

#pragma mark - Search Controller

- (void)presentSearchController {
    
    if(_transitionDelegate  && [_transitionDelegate respondsToSelector:@selector(presentSearchController:)])
        [_transitionDelegate presentSearchController:nil];
}

#pragma mark - New Conversation Button

- (UIBarButtonItem *)newConversationButton {
    
    UIBarButtonItem *bbtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                          target:self
                                                                          action:@selector(presentSearchController)];
    bbtn.tintColor = [UIColor whiteColor];
    bbtn.accessibilityLabel = NSLocalizedString(@"New Conversation", nil);
    
    return bbtn;
}

@end
