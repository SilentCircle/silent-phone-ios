/*
Copyright (C) 2016, Silent Circle, LLC.  All rights reserved.

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
#import "SilentContactsViewController.h"
#import "SilentContactCell.h"
#import <AddressBook/AddressBook.h>
#import "Utilities.h"
#import "DAKeyboardControl.h"
#import "SilentContactInfoViewController.h"
#import "ChatManager.h"

#include "CSCContactDiscoveryBase.h"

#if defined __IPHONE_9_0
#import <Contacts/Contacts.h>
#endif

#define kSelectedColor [UIColor colorWithRed:244/255.0 green:240/255.0 blue:230/255.0 alpha:1.0]
#define kEmptyDark [UIImage imageNamed:@"EmptyCircle.png"]
#define kEmptyBright [UIImage imageNamed:@"EmptyCircleBright.png"]
#define kRefreshButton [UIImage imageNamed:@"ContactRefreshButton.png"]
#define kBackButtonSize 30
#define kBrightBackground [UIColor colorWithRed:58/255.0f green:59/255.0f blue:63/255.0f alpha:1.0f]

@interface SilentContactsViewController () <UISearchBarDelegate, UISearchControllerDelegate, UISearchResultsUpdating>

@property (nonatomic, strong) UISearchController *searchController;
@property BOOL searchControllerWasActive;
@property BOOL searchControllerSearchFieldWasFirstResponder;

@end

@implementation SilentContactsViewController {
    
    NSMutableArray *contactData;
    NSMutableDictionary *searchContactData;
    NSMutableArray *searchContactDataSimple;
    UserContact *selectedUserContact;
    
    NSString *lastSearchedText;
    
    SilentContactCell *selectedCell;
    
    CSCContactDiscoveryBase *cd;
    
    NSMutableCharacterSet *_badPhoneCharacters;
    NSCharacterSet *_englishCharacters;
    NSArray *_sortedContactDataKeys;
    
    BOOL _isKeyboardResigning;
    BOOL _isKeyboardShowing;
}

#pragma mark - View Lifecycle

-(void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    if(selectedCell) {
        selectedCell.redBackgroundView.alpha = 1.0f;
        [UIView animateWithDuration:0.5f animations:^(void){
            selectedCell.redBackgroundView.alpha = 0.0f;
        } completion:^(BOOL finished){
            [selectedCell.redBackgroundView setHidden:YES];
            selectedCell.redBackgroundView.alpha = 1.0f;
            selectedCell = nil;
            selectedUserContact = nil;
        }];
    }
    
    [self setExtendedLayoutIncludesOpaqueBars:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onKeyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onKeyboardDidHide:) name:UIKeyboardDidHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onKeyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onKeyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
}

-(void)viewWillDisappear:(BOOL)animated {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if(_presentModally)
        [self.searchController setActive:NO];
    
    [super viewWillDisappear:animated];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    
    return UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

-(void)viewDidLoad {
    
    [super viewDidLoad];
    
    _badPhoneCharacters = [NSMutableCharacterSet characterSetWithCharactersInString:@"-_(),"];
    [_badPhoneCharacters formUnionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    _englishCharacters = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ"];
    cd = g_CSCContactDiscoveryObject();
    contactData = [NSMutableArray new];
    searchContactData = [NSMutableDictionary new];
    searchContactDataSimple = [NSMutableArray new];
    lastSearchedText = @"";
    
    UITapGestureRecognizer *tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    [_backgroundView addGestureRecognizer:tapGR];
    [_backgroundView setBackgroundColor:[Utilities utilitiesInstance].kNavigationBarColor];
    
    [self.contactsTableView setBackgroundView:_backgroundView];
    [self.contactsTableView setSectionIndexBackgroundColor:[UIColor clearColor]];
    [self.contactsTableView setSectionIndexColor:[UIColor whiteColor]];

    [self.navigationController.navigationBar setTintColor:[UIColor whiteColor]];
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.backgroundColor = [Utilities utilitiesInstance].kNavigationBarColor;
    self.navigationController.navigationBar.translucent = NO;
    [self.navigationController.navigationBar setShadowImage:[UIImage new]];

    _searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    [self.searchController.searchBar setTintColor:[UIColor whiteColor]];
    [self.searchController.searchBar.layer setBorderWidth:1.];
    [self.searchController.searchBar setTranslucent:NO];
    [self.searchController.searchBar.layer setBorderColor:[Utilities utilitiesInstance].kChatViewBackgroundColor.CGColor];
    [self.searchController.searchBar setBarTintColor:[Utilities utilitiesInstance].kChatViewBackgroundColor];
    
    self.searchController.searchResultsUpdater = self;
    [self.searchController.searchBar sizeToFit];
    
    [self.tableViewTopConstraint setConstant:CGRectGetHeight(self.searchController.searchBar.frame)];
    [self.contactsTableView setNeedsUpdateConstraints];
    
    [self.view addSubview:self.searchController.searchBar];
    
    self.searchController.delegate = self;
    self.searchController.dimsBackgroundDuringPresentation = NO;
    self.searchController.searchBar.delegate = self;

    [[Utilities utilitiesInstance] setTabBarHidden:NO];

    if(!_presentModally) {
        
        UIButton *backButtonWithImage = [UIButton buttonWithType:UIButtonTypeCustom];
        [backButtonWithImage setFrame:CGRectMake(0,0,kBackButtonSize,kBackButtonSize)];
        backButtonWithImage.userInteractionEnabled = YES;
        [backButtonWithImage setImage:kRefreshButton forState:UIControlStateNormal];
        [backButtonWithImage addTarget:self action:@selector(reloadContactsAndSearch) forControlEvents:UIControlEventTouchUpInside];
        
        UIBarButtonItem *backBarButton = [[UIBarButtonItem alloc] initWithCustomView:backButtonWithImage];
        self.navigationItem.leftBarButtonItem = backBarButton;
    }
    else {
        
        [self setTitle:@"Send a contact"];

        [self.navigationController.navigationBar setBackgroundImage:[UIImage new]
                                                     forBarPosition:UIBarPositionAny
                                                         barMetrics:UIBarMetricsDefault];
        [self.navigationController.navigationBar setTintColor:[UIColor whiteColor]];
        
        [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
        self.navigationController.navigationBar.backgroundColor = [Utilities utilitiesInstance].kNavigationBarColor;
        self.navigationController.navigationBar.translucent = NO;
    }
    
    self.definesPresentationContext = YES;
    
    [self reloadContactsAndSearch];
}

#pragma mark - UITableViewDelegate

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    
    if([self willCreateSectionsForSearchResults])
        return ([_sortedContactDataKeys count] <= 1 ? nil : _sortedContactDataKeys);
    else
        return nil;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    view.tintColor = [Utilities utilitiesInstance].kNavigationBarColor;
    
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    [header.textLabel setTextColor:[UIColor whiteColor]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)sender {
    
    if([self willCreateSectionsForSearchResults])
        return [_sortedContactDataKeys count];
    else
        return 1;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    
    if([self willCreateSectionsForSearchResults])
        return [_sortedContactDataKeys objectAtIndex:section];
    else
        return nil;
}

- (NSInteger)tableView:(UITableView *)sender numberOfRowsInSection:(NSInteger)section
{
    if([self willCreateSectionsForSearchResults])
        return [[searchContactData objectForKey:[_sortedContactDataKeys objectAtIndex:section]] count];
    else
        return [searchContactDataSimple count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellIdentifier = @"contactCell";
    SilentContactCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    return cell;
}

-(void)tableView:(UITableView *)tableView willDisplayCell:(SilentContactCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UserContact *thisContact;
    
    if([self willCreateSectionsForSearchResults])
        thisContact = [[searchContactData objectForKey:[_sortedContactDataKeys objectAtIndex:indexPath.section]] objectAtIndex:indexPath.row];
    else
        thisContact = [searchContactDataSimple objectAtIndex:indexPath.row];
    
    if(thisContact.contactImage)
    {
        cell.contactImageView.image = thisContact.contactImage;
        [cell.contactInitialsLabel setHidden:YES];
    } else
    {
        [cell.contactInitialsLabel setHidden:NO];
        cell.contactImageView.image = nil;
        cell.contactInitialsLabel.text = [[Utilities utilitiesInstance] getInitialsForUserName:thisContact.contactFullName];
    }
    
    if(thisContact == selectedUserContact)
    {
        [cell.redBackgroundView setHidden:NO];
    } else
    {
        [cell.redBackgroundView setHidden:YES];
    }
    
    if(indexPath.row %2 == 0)
    {
        [cell.whiteBorderImage setImage:kEmptyBright];
        [cell.cellBackgroundView setBackgroundColor:kBrightBackground];
    } else
    {
        [cell.whiteBorderImage setImage:kEmptyDark];
        [cell.cellBackgroundView setBackgroundColor:[Utilities utilitiesInstance].kChatViewBackgroundColor];
    }
    cell.contactNameLabel.text = thisContact.contactFullName;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    selectedCell = (SilentContactCell *)[_contactsTableView cellForRowAtIndexPath:indexPath];
    
    if([self willCreateSectionsForSearchResults])
        selectedUserContact = (UserContact*)[[searchContactData objectForKey:[_sortedContactDataKeys objectAtIndex:indexPath.section]] objectAtIndex:indexPath.row];
    else
        selectedUserContact = (UserContact*)[searchContactDataSimple objectAtIndex:indexPath.row];
    
    if(!_presentModally)
    {
        [_contactsTableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
        [self performSegueWithIdentifier:@"contactInfoSegue" sender:nil];
    }
    else
    {
        if(self.silentContactsDelegate) {
            
            [self.silentContactsDelegate silentContactsViewControllerWillDismissWithContact:selectedUserContact];
        }
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {

    [self dismissKeyboard];
}

#pragma mark - UISearchControllerDelegate

- (void)willPresentSearchController:(UISearchController *)searchController {
    
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)didPresentSearchController:(UISearchController *)searchController {
    
    [self setNeedsStatusBarAppearanceUpdate];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    
    NSString *searchText = [self.searchController.searchBar text];

    if(![lastSearchedText isEqualToString:searchText]) {
        
        [self searchContactsWithText:searchText];
        lastSearchedText = searchText;
    }
}

#pragma mark - Custom

- (void)dismissKeyboard {
    
    if(self.searchController.isActive && !_isKeyboardResigning && !_isKeyboardShowing) {
        [self.searchController.searchBar resignFirstResponder];
    }
}

- (BOOL)willCreateSectionsForSearchResults {
    
    return YES; //!_presentModally;
}

- (NSString*)formatPhoneNumber:(NSString*)phoneNumber {
    
    NSArray* words = [phoneNumber componentsSeparatedByCharactersInSet:_badPhoneCharacters];
    return [words componentsJoinedByString:@""];
}

-(void) reloadContactsAndSearch {
    
    [contactData removeAllObjects];
    [searchContactData removeAllObjects];
    [searchContactDataSimple removeAllObjects];
    
    [self loadContactsFromAddressBook];
    [self searchContactsWithText:lastSearchedText];
}

-(void) searchContactsWithText:(NSString *) searchText {
    
    dispatch_async (dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        [searchContactData removeAllObjects];
        [searchContactDataSimple removeAllObjects];

        for (int i = 0; i<contactData.count; i++) {
            
            UserContact *contact = contactData[i];
            
            BOOL match = NO;
            
            if(searchText.length == 0)
                match = YES;
            else if([contact.contactFullName rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound)
                match = YES;
            else if([contact.contactPhoneNumberString rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound)
                match = YES;
            
            if (match) {
                
                if([self willCreateSectionsForSearchResults]) {

                    NSString *firstLetter = [self sectionStringForContactName:contact.contactSortByName];
                    
                    if(![searchContactData objectForKey:firstLetter])
                        [searchContactData setObject:[NSMutableArray arrayWithObject:contact] forKey:firstLetter];
                    else {
                        [[searchContactData objectForKey:firstLetter] addObject:contact];
                    }
                    
                } else {
                    [searchContactDataSimple addObject:contact];
                }
            }
        }
        
        if([self willCreateSectionsForSearchResults]) {
            
            _sortedContactDataKeys = [[searchContactData allKeys] sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
                
                // Section with special characters (#) goes to the bottom
                if([(NSString*)a isEqualToString:@"#"])
                    return NSOrderedDescending;
                else if([(NSString*)b isEqualToString:@"#"])
                    return NSOrderedAscending;
                
                // Sort everything else by name
                return [a compare:b options:NSCaseInsensitiveSearch];
            }];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            BOOL showNoResults = NO;
            
            if([self willCreateSectionsForSearchResults] && [searchContactData count] == 0)
                showNoResults = YES;
            else if(![self willCreateSectionsForSearchResults] && [searchContactDataSimple count] == 0)
                showNoResults = YES;
            else
                showNoResults = NO;
            
            if(showNoResults) {
                [_noResultsLabel setHidden:NO];
                [_contactsTableView setScrollEnabled:NO];
            }
            else {
                [_noResultsLabel setHidden:YES];
                [_contactsTableView setScrollEnabled:YES];
            }

            [_contactsTableView reloadData];
        });
    });
}

- (NSString*)sectionStringForContactName:(NSString*)contactFullName {

    // Populate the letter map
    NSString *firstLetter = [[contactFullName substringToIndex:1] uppercaseString];
    
    // Group every non english character under the # section
    BOOL isEnglishLetter  = !([firstLetter rangeOfCharacterFromSet:_englishCharacters].location == NSNotFound);
    
    if(!isEnglishLetter)
        firstLetter = @"#";

    return firstLetter;
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([segue.identifier isEqualToString:@"contactInfoSegue"])
    {
        SilentContactInfoViewController *destViewC = (SilentContactInfoViewController *) segue.destinationViewController;
        destViewC.selectedUserContact = selectedUserContact;
    }
}

- (void)loadContactsFromAddressBook
{
    // Note:
    // We cannot use the new framework when we are about to send a contact as an attachment
    // due to the fact that ChatManager class uses the old AddressBook API to identify the contact sent via
    // its abRecordID. We might need to switch to the new CNContactStore API in ChatManager as well as soon
    // as we make SPi an iOS9 only app.
    if([[[UIDevice currentDevice] systemVersion] floatValue] >=9.0 && !_presentModally)
    {
        #if defined __IPHONE_9_0
        [self requestAccessToContactsFramework];
        #endif
        return;
    }
   
   //CSCContactDiscoveryBase *cd = g_CSCContactDiscoveryObject();
   
    CFErrorRef error = NULL;
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, &error);
    __block BOOL accessGranted = NO;
    if (&ABAddressBookRequestAccessWithCompletion != NULL) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
            accessGranted = granted;
            dispatch_semaphore_signal(semaphore);
        });
    }
    if (addressBook != nil) {
        NSArray *allContacts = (NSArray *)CFBridgingRelease(ABAddressBookCopyArrayOfAllPeople(addressBook));
        NSUInteger i = 0; for (i = 0; i < [allContacts count]; i++)
        {
            ABRecordRef contactPerson = (__bridge ABRecordRef)allContacts[i];
            
            // create new UserContact
            UserContact *user = [[UserContact alloc] init];
            
            user.abRecordID = ABRecordGetRecordID(contactPerson);
            
            NSString *firstName = (__bridge_transfer NSString *)ABRecordCopyValue(contactPerson, kABPersonFirstNameProperty);
            NSString *lastName = (__bridge_transfer NSString *)ABRecordCopyValue(contactPerson, kABPersonLastNameProperty);
            NSString *nickName = (__bridge_transfer NSString *)ABRecordCopyValue(contactPerson, kABPersonNicknameProperty);
            NSString *organizationName = (__bridge_transfer NSString *)ABRecordCopyValue(contactPerson, kABPersonOrganizationProperty);
            
            NSString *displayName = nil;
            NSString *sortByName = nil;
            
            if([firstName length] > 0 && [lastName length] > 0) {
                displayName = [NSString stringWithFormat:@"%@ %@", firstName, lastName];
                sortByName = lastName;
            }
            else if([firstName length] > 0)
                displayName = firstName;
            else if([lastName length] > 0)
                displayName = lastName;
            else if([nickName length] > 0)
                displayName = nickName;
            else if([organizationName length] > 0)
                displayName = organizationName;
            else
                displayName = @"No name";
            
            if(!sortByName)
                sortByName = displayName;
        
            // add the contact to the list
            user.contactFullName = displayName;
            user.contactSortByName = sortByName;
            
            NSData  *imgData = (__bridge NSData *)ABPersonCopyImageData(contactPerson);
            user.contactImage = [UIImage imageWithData:imgData];
            [contactData addObject:user];
            
            NSString *contactPhoneNumberString = @"";
            user.contactInfoArray = [[NSMutableArray alloc] init];
            
            [self loadContactsDataForPerson:contactPerson WithProperty:kABPersonInstantMessageProperty inArray:user.contactInfoArray phoneNumberString:&contactPhoneNumberString];
            [self loadContactsDataForPerson:contactPerson WithProperty:kABPersonURLProperty inArray:user.contactInfoArray phoneNumberString:&contactPhoneNumberString];
            [self loadContactsDataForPerson:contactPerson WithProperty:kABPersonPhoneProperty inArray:user.contactInfoArray phoneNumberString:&contactPhoneNumberString];
            
            user.contactPhoneNumberString = contactPhoneNumberString;
        }
        
        CFRelease(addressBook);
        [self doJob];
    }
    
    NSArray *sortedContactList = [contactData sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        UserContact *c1 = (UserContact *)obj1;
        UserContact *c2 = (UserContact *)obj2;
        return [c1.contactSortByName compare:c2.contactSortByName options:NSCaseInsensitiveSearch];
    }];
    contactData = [NSMutableArray arrayWithArray:sortedContactList];
}


-(void) loadContactsDataForPerson:(ABRecordRef)person WithProperty:(ABRecordID)property inArray:(NSMutableArray *) contactDataArray phoneNumberString:(NSString **)phoneNumberString
{
    ABMultiValueRef phones = ABRecordCopyValue(person, property);
    
    for(CFIndex j = 0; j < ABMultiValueGetCount(phones); j++) {

        NSString *phoneLabel = (NSString*)CFBridgingRelease(ABMultiValueCopyLabelAtIndex(phones, j));
        phoneLabel = (NSString *)CFBridgingRelease(ABAddressBookCopyLocalizedLabel((__bridge CFStringRef)phoneLabel));
        
        NSString *phoneNumber;
        
        // In IM properties the value is a NSDictionary
        if(property == kABPersonInstantMessageProperty)
            phoneNumber = [(NSDictionary*)CFBridgingRelease(ABMultiValueCopyValueAtIndex(phones, j)) objectForKey:@"username"];
        else // otherwise it is a NSString
            phoneNumber = (NSString*)CFBridgingRelease(ABMultiValueCopyValueAtIndex(phones, j));
        
        // Exclude every value that is not a phone number and does not start with the "sip:" prefix
        if ((property == kABPersonInstantMessageProperty || property == kABPersonURLProperty) && [phoneNumber rangeOfString:@"sip:"].location == NSNotFound)
            continue;
        
        NSDictionary * phoneNumberDict = [NSDictionary dictionaryWithObjectsAndKeys:phoneLabel, @"phoneLabel", phoneNumber,@"phoneNumber", nil];
        [contactDataArray addObject:phoneNumberDict];
        
        cd->addNumber(phoneNumber.UTF8String);
        
        *phoneNumberString = [(*phoneNumberString) stringByAppendingString:[self formatPhoneNumber:phoneNumber]];
    }
    
    CFRelease(phones);
}

#pragma mark contactLoading from ContactsFrameWork
#if defined __IPHONE_9_0
-(void) requestAccessToContactsFramework
{
    CNEntityType entityType = CNEntityTypeContacts;
    if( [CNContactStore authorizationStatusForEntityType:entityType] == CNAuthorizationStatusNotDetermined)
    {
        CNContactStore * contactStore = [[CNContactStore alloc] init];
        [contactStore requestAccessForEntityType:entityType completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if(granted){
                [self fetchContactsFromContactsFrameWork];
            }
        }];
    }
    else if( [CNContactStore authorizationStatusForEntityType:entityType]== CNAuthorizationStatusAuthorized)
    {
        [self fetchContactsFromContactsFrameWork];
    }
    else if( [CNContactStore authorizationStatusForEntityType:entityType]== CNAuthorizationStatusDenied)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Access denied" message:@"Please enable access to contacts" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
        [alert show];
    }
}

-(void)fetchContactsFromContactsFrameWork
{
    NSError* contactError;
    CNContactStore* addressBook = [[CNContactStore alloc] init];
    
    [addressBook containersMatchingPredicate:[CNContainer predicateForContainersWithIdentifiers: @[addressBook.defaultContainerIdentifier]] error:&contactError];
    
    NSArray * keysToFetch =@[CNContactPhoneNumbersKey,
                             CNContactFamilyNameKey,
                             CNContactGivenNameKey,
                             CNContactNicknameKey,
                             CNContactOrganizationNameKey,
                             CNContactImageDataKey,
                             CNContactUrlAddressesKey];
    
    CNContactFetchRequest * request = [[CNContactFetchRequest alloc]initWithKeysToFetch:keysToFetch];
    
    [addressBook enumerateContactsWithFetchRequest:request error:&contactError usingBlock:^(CNContact * __nonnull contact, BOOL * __nonnull stop){
        [self parseContactWithCNContact:contact];
    }];
    [self doJob];
}

-(void) parseContactWithCNContact:(CNContact *)contact
{
    UserContact *userContact = [[UserContact alloc] init];
    
    NSString *displayName = nil;
    NSString *sortByName = nil;
    
    if([contact.givenName length] > 0 && [contact.familyName length] > 0) {
        displayName = [NSString stringWithFormat:@"%@ %@", contact.givenName, contact.familyName];
        sortByName = contact.familyName;
    }
    else if([contact.givenName length] > 0)
        displayName = contact.givenName;
    else if([contact.familyName length] > 0)
        displayName = contact.familyName;
    else if([contact.nickname length] > 0)
        displayName = contact.nickname;
    else if([contact.organizationName length] > 0)
        displayName = contact.organizationName;
    else
        displayName = @"No name";
    
    if(!sortByName)
        sortByName = displayName;
    
    // add the contact to the list
    userContact.contactFullName = displayName;
    userContact.contactSortByName = sortByName;
    
    userContact.contactImage = [UIImage imageWithData:contact.imageData];
    userContact.contactInfoArray = [[NSMutableArray alloc] initWithCapacity:contact.phoneNumbers.count + contact.urlAddresses.count];

    userContact.contactPhoneNumberString = @"";
    
    for (CNLabeledValue *phoneNumber in contact.phoneNumbers)
    {
        NSString *phoneLabel = [CNLabeledValue localizedStringForLabel:phoneNumber.label];
        CNPhoneNumber *contactPhoneNumber = (CNPhoneNumber *)phoneNumber.value;
        
        cd->addNumber(contactPhoneNumber.stringValue.UTF8String);
        NSDictionary * phoneNumberDict = [NSDictionary dictionaryWithObjectsAndKeys:phoneLabel, @"phoneLabel", contactPhoneNumber.stringValue,@"phoneNumber", nil];
        [userContact.contactInfoArray addObject:phoneNumberDict];
        
        userContact.contactPhoneNumberString = [userContact.contactPhoneNumberString stringByAppendingString:[self formatPhoneNumber:contactPhoneNumber.stringValue]];
    }
    
    for (CNLabeledValue *phoneNumber in contact.urlAddresses)
    {
        NSString *urlValueString = [NSString stringWithFormat:@"%@",phoneNumber.value];

        if ([urlValueString rangeOfString:@"sip:"].location == NSNotFound)
            continue;

        NSString *phoneLabel = [CNLabeledValue localizedStringForLabel:phoneNumber.label];
        
        NSDictionary * phoneNumberDict = [NSDictionary dictionaryWithObjectsAndKeys:phoneLabel, @"phoneLabel", phoneNumber.value,@"phoneNumber", nil];
        [userContact.contactInfoArray addObject:phoneNumberDict];
        cd->addNumber(urlValueString.UTF8String);
        
        userContact.contactPhoneNumberString = [userContact.contactPhoneNumberString stringByAppendingString:[self formatPhoneNumber:(NSString*)phoneNumber.value ]];
    }
    
    [contactData addObject:userContact];
}
#endif

-(void) doJob
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        cd->doJob();
    });
}

-(void) addKeyboardPanning
{
    [self.view addKeyboardPanningWithFrameBasedActionHandler:^(CGRect keyboardFrameInView, BOOL opening, BOOL closing) {
        /*
         Try not to call "self" inside this block (retain cycle).
         But if you do, make sure to remove DAKeyboardControl
         when you are done with the view controller by calling:
         [self.view removeKeyboardControl];
         */
        
        // possible retain cycle
        // adjust frames of containerView table and actionSheet
        
        //CGRect tableViewFrame = resultsTableView.frame;
        //tableViewFrame.size.height = keyboardFrameInView.origin.y - 110;
       // resultsTableView.frame = tableViewFrame;
        
    } constraintBasedActionHandler:nil];
}

#pragma mark - Notifications

-(void)onKeyboardWillShow:(NSNotification*)notification {

    _isKeyboardShowing = YES;
}

-(void)onKeyboardDidShow:(NSNotification*)notification {
    
    _isKeyboardShowing = NO;
}

- (void)onKeyboardWillHide:(NSNotification*)notification {

    _isKeyboardResigning = YES;
}

- (void)onKeyboardDidHide:(NSNotification*)notification {
    
    _isKeyboardResigning = NO;
}

@end
