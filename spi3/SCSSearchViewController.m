//
//  SCSSearchViewController.m
//  SPi3
//
//  Created by Stelios Petrakis on 21/02/2017.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import <ContactsUI/ContactsUI.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "SCSSearchViewController.h"
#import "SCSSearchVM.h"

#import "AddressBookContact.h"
#import "AttachmentManager.h"
#import "ChatViewController.h"
#import "ChatUtilities.h"
#import "DBManager.h"
#import "RecentObject.h"
#import "SCPCall.h"
#import "SCPCallbackInterface.h"
#import "SCPCallManager.h"
#import "SCPNotificationKeys.h"
#import "SCSChatSectionObject.h"
#import "SCSContactsManager.h"
#import "SCSContactTVCell.h"
#import "SCSEnums.h"
#import "SCSPhoneHelper.h"
#import "SCSTransitionDelegate.h"
#import "UserService.h"
#import "SCSConstants.h"

#import "NSDate+SCDate.h"
#import "NSDictionaryExtras.h"
#import "NSURL+SCUtilities.h"
#import "UIButton+SCButtons.h"
#import "UIColor+ApplicationColors.h"
#import "UIImage+ApplicationImages.h"

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelError;
//#endif


@interface SCSSearchViewController () <SCSContactTVCellDelegate,
CNContactViewControllerDelegate, CNContactPickerDelegate, SCSSearchVMActionDelegate,SCSSearchBarViewDelegate, SCSNewGroupChatViewDelegate>
{    
    RecentObject *_recentObjectToSave;    
    BOOL _hasSearchText;
    
    scsContactType _fullTypes;
    
    UIButton *_keyboardModeButton;
    
}

@property (nonatomic, strong) scsContactTypeSearchVM *tableVM;

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end


static NSInteger const kSearchBarHeight = 52;
@implementation SCSSearchViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    
    [super viewDidLoad];
    _searchBar = [[[NSBundle mainBundle] loadNibNamed:@"SCSSearchBarView" owner:self options:nil] objectAtIndex:0];
    [self.view addSubview:_searchBar];
    _searchBar.searchTextField.placeholder = kSearchNameNumber;
    [_searchBar.searchTextField becomeFirstResponder];
    
    self.tableVM = [[scsContactTypeSearchVM alloc] initWithTableView:self.tableView];
    self.tableVM.shouldDisableNumbers = _disablePhoneNumberResults;
    self.tableVM.actionDelegate = self;
    self.tableVM.isSwipeEnabled = !_disableSwipe;
    self.tableVM.isMultiSelectEnabled = NO;

    _fullTypes    = scsContactTypeAddressBookSilentCircle;
    
    scsContactType searchTypes  = scsContactTypeAddressBookSilentCircle;
    
    if(!_disableDirectorySearch)
        searchTypes |= scsContactTypeDirectory;
    
    if(!_disableAutocompleteSearch)
        searchTypes |= scsContactTypeSearch;
    
    if(!_disableAddressBook) {
        
        searchTypes |= scsContactTypeAddressBook;
        _fullTypes |= scsContactTypeAddressBook;
    }
    
    if(_enableGroupConversations) {
        
        searchTypes |= scsContactTypeGroupConversations;
        _fullTypes |= scsContactTypeGroupConversations;
    }
    
    [self.tableVM activateSearchforTypes:searchTypes
              andDisplayFullListsOfTypes:_fullTypes];

    self.tableView.tableFooterView = [UIView new];

    [self updateHeaderView];

    [self configureStartingAccessibility];
    
    [self registerNotifications];
    _searchBar.delegate = self;
    
    _groupChatButtonView.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.navigationItem.leftBarButtonItem = [self getLeftBarButtonItem];
    if (!self.disablePhoneNumberResults)
        self.navigationItem.rightBarButtonItem = [self getRightBarButtonItem];
    [self showStartNetworkError];
    
    if (_searchBar)
    {
        if (![_searchBar isFirstResponder])
        {
            [_searchBar.searchTextField becomeFirstResponder];
        }
        _searchBar.searchTextField.keyboardType = UIKeyboardTypeEmailAddress;
         [self updateKeyboardModeButton];
    }
    
    [self updateHeaderView];
}

-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    if (_searchBar)
    {
        [_searchBar setFrame:CGRectMake(0, 0, self.view.frame.size.width, kSearchBarHeight)];
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void) showStartNetworkError
{
    if(![Switchboard.networkManager hasNetworkConnection])
    {
        UIAlertController *noNetworkAlert = [UIAlertController alertControllerWithTitle:kNoNetwork message:NSLocalizedString(@"Creating a new conversation requires network access so we can search for the other party. Try connecting to a network or disabling airplane mode", nil) preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* okAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"OK", nil)
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction * action)
                                   {
                                       [noNetworkAlert dismissViewControllerAnimated:YES completion:nil];
                                   }];
        
        [noNetworkAlert addAction:okAction];
        
        [self presentViewController:noNetworkAlert animated:YES completion:nil];
    }
}

#pragma mark - Notifications

-(void)registerNotifications {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(willPresentCallScreen:)
               name:kSCPWillPresentCallScreenNotification
             object:nil];
}

-(void)willPresentCallScreen:(NSNotification *)notification {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissSearch];
    });
}

-(void) dismissSearch
{
    [self.navigationController popViewControllerAnimated:YES];
}


#pragma mark - Accessibility Methods

- (void)configureStartingAccessibility {
    // Call to set _keyboardModeButton accessibility label
    [self updateKeyboardModeButton];
}


#pragma mark - SwipeCell Action Methods

-(void)placeCallWithRecentObject:(RecentObject *) recentObject
{
    
    if(!recentObject)
        return;
    
    if(![Switchboard allAccountsOnline])
    {
        [[ChatUtilities utilitiesInstance] showNoNetworkErrorForConversation:recentObject actionType:eCall];
        return;
    }
    NSString *contactName = recentObject.contactName;
    
    [[ChatUtilities utilitiesInstance] 
     checkIfDRIsBlockingCommunicationWithContactName:contactName
     completion:^(BOOL exists, BOOL blocked, SCSDRStatus drStatus) {
         
         dispatch_async(dispatch_get_main_queue(), ^{
             if (blocked) {
                 
                 [_transitionDelegate displayDRProhibitionAlert];                                                                                    
             }                                                                        
             else {
                 [_transitionDelegate placeCallFromVC:self
                                           withNumber:contactName];
             }
         });
     }];
}


#pragma mark - SearchVMActionDelegate

-(void)didTapRecentObject:(RecentObject *)recentObject {
    
    if(_doneBlock) {
        
        _doneBlock(recentObject);
        return;
    }
    
    [self presentChatWithRecentObject:recentObject];
}

-(void)didTapCallButtonOnRecentObject:(RecentObject *)recentObject
{
    [_searchBar.searchTextField resignFirstResponder];
    [self placeCallWithRecentObject:recentObject];
}

-(void)didTapSaveContactsButtonOnRecentObject:(RecentObject *)recentObject
{
    [_searchBar.searchTextField resignFirstResponder];
    [self showSaveChoices:recentObject];
}

#pragma mark - UIScrollViewDelegate

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    
    // Resign the keyboard when user starts scrolling
    [_searchBar.searchTextField resignFirstResponder];
}

#pragma mark - Present New Group Chat 

- (void)presentNewGroupChatController:(id)sender {

    UIStoryboard *chatStoryboard = [UIStoryboard storyboardWithName:@"Chat" bundle:nil];
    
    AddGroupMemberViewController *addGroupMemberViewC = (AddGroupMemberViewController*)[chatStoryboard instantiateViewControllerWithIdentifier:@"AddGroupMemberViewController"];
    
    if ([addGroupMemberViewC respondsToSelector:@selector(transitionDelegate)])
        addGroupMemberViewC.transitionDelegate = self.transitionDelegate;

    [self.navigationController setViewControllers:@[addGroupMemberViewC]];
}

#pragma mark - Present Chat

-(void)presentChatWithRecentObject:(RecentObject *) selectedRecent {
    
    if(!selectedRecent)
        return;
    
    if(!selectedRecent.contactName)
        return;
    
    if(![Switchboard allAccountsOnline])
    {
        [[ChatUtilities utilitiesInstance] showNoNetworkErrorForConversation:selectedRecent actionType:eWrite];
        return;
    }
    
    if(selectedRecent.isNumber)
    {
        [self placeCallWithRecentObject:selectedRecent];
        return;
    }
    
    [[ChatUtilities utilitiesInstance] checkIfContactNameExists:selectedRecent.contactName
                                                     completion:^(RecentObject *updatedRecent) {
                                                     
                                                         BOOL exists = (updatedRecent != nil);
                                                         
                                                         [[ChatUtilities utilitiesInstance] donateInteractionWithRecent:selectedRecent
                                                                                                   doesExistInDirectory:exists];
                                                        
                                                         if(!exists) {
                                                             
                                                             // If this is not an SC user, or the conversation doesn't already exist
                                                             // then check if user has interacted with a number. If this is the case
                                                             // make the call (Outbound PSTN permssion is checked inside SCPCallHelper).
                                                             BOOL isNumber = [[ChatUtilities utilitiesInstance] isNumber:selectedRecent.contactName];
                                                             
                                                             if(isNumber) {
                                                                 
                                                                 [self placeCallWithRecentObject:selectedRecent];
                                                                 return;
                                                             }
                                                             
                                                             UIAlertController *errorController = [UIAlertController
                                                                                                   alertControllerWithTitle:NSLocalizedString(@"Unable to send messages", nil)
                                                                                                   message:NSLocalizedString(@"User not found", nil)
                                                                                                   preferredStyle:UIAlertControllerStyleAlert];
                                                             UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                                                                                style:UIAlertActionStyleDefault
                                                                                                              handler:nil];
                                                             [errorController addAction:okAction];
                                                             
                                                             [self presentViewController:errorController
                                                                                animated:YES
                                                                              completion:nil];
                                                         }
                                                         else {
                                                             
                                                             if (selectedRecent.contactName)
                                                                 [[NSNotificationCenter defaultCenter] postNotificationName:kSCPNeedsTransitionToChatWithContactNameNotification 
                                                                                                                     object:self 
                                                                                                                   userInfo:@{kSCPContactNameDictionaryKey:selectedRecent.contactName}];
                                                         }
                                                     }];
}


#pragma mark - Save Contact

- (void)showSaveChoices:(RecentObject *)recentObject {
    
    _recentObjectToSave = recentObject;
    
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
    
    [viewController.navigationController dismissViewControllerAnimated:YES
                                                            completion:nil];
}

#pragma mark - CNContactPickerDelegate

- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContact:(CNContact *)contact {
    
    [picker dismissViewControllerAnimated:NO
                               completion:^{
                                   
                                   CNContact *updatedContact = [[SCSContactsManager sharedManager] updateContact:contact
                                                                                                withRecentObject:_recentObjectToSave];
                                   
                                   if(updatedContact)
                                       [self showNewContactControllerForContact:updatedContact
                                                                          isNew:NO];
                               }];
}

#pragma mark - IB actions
- (IBAction)keyboardModeButtonTapped:(id)sender
{
    if (![_searchBar.searchTextField isFirstResponder])
    {
        [_searchBar.searchTextField becomeFirstResponder];
    }
    if(_searchBar.searchTextField.keyboardType == UIKeyboardTypeEmailAddress)
        [_searchBar.searchTextField setKeyboardType:UIKeyboardTypePhonePad];
    else
        [_searchBar.searchTextField setKeyboardType:UIKeyboardTypeEmailAddress];

    [_searchBar.searchTextField reloadInputViews];
    [self updateKeyboardModeButton];
}

- (void)updateKeyboardModeButton
{
    if(_searchBar.searchTextField.keyboardType == UIKeyboardTypeEmailAddress)
    {
        [_keyboardModeButton setImage:[UIImage kbModeDialpad_white]
                             forState:UIControlStateNormal];
        _keyboardModeButton.accessibilityLabel = NSLocalizedString(@"dial pad", nil);
    }
    else
    {
        [_keyboardModeButton setImage:[UIImage kbModeKeyboard_white]
                             forState:UIControlStateNormal];
        _keyboardModeButton.accessibilityLabel = NSLocalizedString(@"keyboard", nil);
    }
}

- (void)updateHeaderView
{
    BOOL shouldHideNewGroupChatButton = _disableNewGroupChatButton;
    
    if (!shouldHideNewGroupChatButton)
        shouldHideNewGroupChatButton = _hasSearchText;
    
    if (shouldHideNewGroupChatButton)
    {
        [self.tableView setTableHeaderView:nil];
    } else
    {
        [self.tableView setTableHeaderView:_groupChatButtonView];
    }
}

#pragma mark UINavigationBarButtons

-(UIBarButtonItem *) getRightBarButtonItem
{
    int buttonSize = [ChatUtilities getNavigationBarButtonSize];
    _keyboardModeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_keyboardModeButton setFrame:CGRectMake(0,0,buttonSize,buttonSize)];
    [_keyboardModeButton addTarget:self action:@selector(keyboardModeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *rightBarButton = [[UIBarButtonItem alloc] initWithCustomView:_keyboardModeButton];
    return rightBarButton;
}

-(UIBarButtonItem *) getLeftBarButtonItem
{
    UIButton *backButton = [ChatUtilities getNavigationBarBackButton];
     [backButton addTarget:self action:@selector(dismissSearch) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *leftBarButton = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    return leftBarButton;
}

#pragma Search Bar delegates

-(void)didTapNewGroupChatButton
{
    UIStoryboard *chatStoryBoard = [UIStoryboard storyboardWithName:@"GroupChat" bundle:nil];
    AddGroupMemberViewController *viewC = [chatStoryBoard instantiateViewControllerWithIdentifier:@"AddGroupMemberViewController"];
    viewC.transitionDelegate = self.transitionDelegate;
    viewC.transitionToConversations = YES;
    [self.navigationController pushViewController:viewC animated:YES];
}

-(void)searchTextDidChange:(NSString *)searchText
{
    [self.tableVM searchText:searchText];
    _hasSearchText = ![searchText isEqualToString:@""];
    [self updateKeyboardModeButton];
    [self updateHeaderView];
}

-(void)didTapClearSearchButton
{
    [self.tableVM searchText:@""];
    _hasSearchText = NO;
    [self updateHeaderView];
}
@end
