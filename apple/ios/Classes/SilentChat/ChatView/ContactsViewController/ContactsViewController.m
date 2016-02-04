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
#define kBackButtonSize 30
#define kSelectedRowBackgroundColor [UIColor colorWithRed:244/255.0 green:240/255.0 blue:230/255.0 alpha:1.0]
#define kEmptyContactImage [UIImage imageNamed:@"EmptyContactPicture.png"]

#define kSendButton [UIImage imageNamed:@"sendUserContact.png"]
#define kAddContactIimageSize 30

#import <AddressBook/AddressBook.h>

#import "ContactsViewController.h"
#import "ChatObject.h"
#import "ChatManager.h"
#import "SCContactBookPickerCell.h"
#import "SilentContactCell.h"
#import "UserContact.h"
#import "Utilities.h"

// enum for Apple contacts or SilentCircle contacts choice
typedef enum {
    segment_addressbook = 0,
    segment_stuser = 1
} SegmentIndex;

@interface ContactsViewController ()
{
    UIBarButtonItem *sendButton;
    UIBarButtonItem *cancelButton;
    UISegmentedControl *segmentControl;
    SegmentIndex selectedSegment;
    NSArray *addressBookData;
    NSArray *partitionedData;
    BOOL useSectionsForAB;
    
    NSMutableArray *contactData;
    NSMutableArray *searchContactData;
    NSIndexPath *lastSelectedContactIndexPath;
    
    NSString *lastSearchedText;
}
@end

@implementation ContactsViewController

-(void)viewWillAppear:(BOOL)animated
{
    [[Utilities utilitiesInstance] setTabBarHidden:YES];
    [self searchContactsWithText:@""];
}
- (void)viewDidLoad {
    
    
    UIView *darkTopView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [Utilities utilitiesInstance].screenWidth, [Utilities utilitiesInstance].kStatusBarHeight)];
    [darkTopView setBackgroundColor:[Utilities utilitiesInstance].kStatusBarColor];
    [self.view addSubview:darkTopView];
    // array of loaded contacts
    contactData = [[NSMutableArray alloc] init];
    searchContactData = [[NSMutableArray alloc] init];
    
    [self loadContactsFromAddressBook];
    [super viewDidLoad];
    
    UIButton *rightButtonWithImage = [UIButton buttonWithType:UIButtonTypeCustom];
    [rightButtonWithImage setFrame:CGRectMake(0,0,kAddContactIimageSize,kAddContactIimageSize)];
    rightButtonWithImage.userInteractionEnabled = YES;
    [rightButtonWithImage.imageView setContentMode:UIViewContentModeScaleAspectFit];
    [rightButtonWithImage setImage:[UIImage imageNamed:@"sendUserContact.png"] forState:UIControlStateNormal];
    [rightButtonWithImage addTarget:self action:@selector(sendButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    sendButton = [[UIBarButtonItem alloc] initWithCustomView:rightButtonWithImage];
    self.navigationItem.rightBarButtonItem = sendButton;
    
    segmentControl = [[UISegmentedControl alloc] initWithItems:@[@"Apple Contacts"]];
    segmentControl.tintColor = [UIColor whiteColor];
    self.navigationItem.titleView = segmentControl;
    [segmentControl addTarget:self
                 action:@selector(segmentAction:)
       forControlEvents:UIControlEventValueChanged];
    segmentControl.selectedSegmentIndex = segment_addressbook;
    selectedSegment = segment_addressbook;
    
    UIButton *backButtonWithImage = [UIButton buttonWithType:UIButtonTypeCustom];
    [backButtonWithImage setFrame:CGRectMake(0,0,kBackButtonSize,kBackButtonSize)];
    backButtonWithImage.userInteractionEnabled = YES;
    [backButtonWithImage setImage:[UIImage imageNamed:@"BackButton.png"] forState:UIControlStateNormal];
    [backButtonWithImage addTarget:self.navigationController action:@selector(popViewControllerAnimated:) forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *backBarButton = [[UIBarButtonItem alloc] initWithCustomView:backButtonWithImage];
    self.navigationItem.leftBarButtonItem = backBarButton;
    
    [_tableView setBackgroundColor:[Utilities utilitiesInstance].kChatViewBackgroundColor];
}

// Send contact to chat
- (IBAction)sendButtonAction:(id)sender
{
    if(lastSelectedContactIndexPath)
    {
        UserContact *selectedContact = (UserContact *) contactData[lastSelectedContactIndexPath.row];
        [[ChatManager sharedManager] sendMessageWithContact:selectedContact];
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (IBAction)segmentAction:(id)sender
{
    // keep reference to selected segment and reload contacts UITableView
    UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
    selectedSegment = (SegmentIndex)(segmentedControl.selectedSegmentIndex);
    [_tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
}

#pragma mark UITableViewDelegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)sender
{
    // should add sections for alphabetical character headers
    return 1;
}
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    lastSelectedContactIndexPath = indexPath;
    float offset = tableView.contentOffset.y;
    [tableView reloadData];
    [tableView setContentOffset:CGPointMake(0, offset)];
}

- (NSInteger)tableView:(UITableView *)sender numberOfRowsInSection:(NSInteger)section
{
    NSInteger sectionCount;
    if (selectedSegment == segment_addressbook)
    {
        sectionCount = searchContactData.count;
    }
    else
    {
        sectionCount = 0;
    }
    return sectionCount;
}
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 63;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellIdentifier = @"contactCell";
    SilentContactCell *cell = (SilentContactCell *)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(SilentContactCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	UserContact *thisContact = (UserContact*)searchContactData[indexPath.row];
    cell.contactNameLabel.text = thisContact.contactFullName;
    if(!thisContact.contactImage)
    {
        cell.contactImageView.image = kEmptyContactImage;
        cell.contactInitialsLabel.text = [[Utilities utilitiesInstance] getInitialsForUser:[[Utilities utilitiesInstance].recents objectForKey:thisContact.contactUserName]];
        if(cell.contactInitialsLabel.text.length <=0)
        {
            cell.contactInitialsLabel.text = [[Utilities utilitiesInstance] getInitialsForUserName:thisContact.contactFullName];
        }
    } else
    {
        cell.contactImageView.image = thisContact.contactImage;
        cell.contactInitialsLabel.text = @"";
    }
    if(lastSelectedContactIndexPath && lastSelectedContactIndexPath.row == indexPath.row)
    {
        [cell.redBackgroundView setHidden:NO];
    } else
    {
        [cell.redBackgroundView setHidden:YES];
    }
	//cell.accessoryType = ([indexPath isEqual:lastSelectedContactIndexPath]) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

- (void)loadContactsFromAddressBook
{
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
        NSArray *allContacts = (__bridge  NSArray *)ABAddressBookCopyArrayOfAllPeople(addressBook);
        NSUInteger i = 0; for (i = 0; i < [allContacts count]; i++)
        {
			ABRecordRef contactPerson = (__bridge ABRecordRef)allContacts[i];
            
            // create new UserContact
            UserContact *user = [[UserContact alloc] init];
			user.abRecordID = ABRecordGetRecordID(contactPerson);
            NSString *firstName = (__bridge_transfer NSString *)ABRecordCopyValue(contactPerson, kABPersonFirstNameProperty);
            NSString *lastName = (__bridge_transfer NSString *)ABRecordCopyValue(contactPerson, kABPersonLastNameProperty);
			
			NSString *displayName = @"";
			NSString *sortByName = nil;
			if ([firstName length] > 0) {
				displayName = [displayName stringByAppendingString:firstName];
				sortByName = firstName;
			}
			if (lastName && [lastName length] > 0) {
				if ([displayName length] > 0)
					displayName = [displayName stringByAppendingString:@" "];
				displayName = [displayName stringByAppendingString:lastName];
				sortByName = lastName;
			}
            /*
			if ([displayName length] == 0) {
				NSString *organization = (__bridge_transfer NSString *)ABRecordCopyValue(contactPerson, kABPersonOrganizationProperty);
				if ([organization length] > 0) {
					displayName = [displayName stringByAppendingString:organization];
					sortByName = organization;
				}
			}
			if ([displayName length] == 0) {
				NSString *phone = (__bridge_transfer NSString *)ABRecordCopyValue(contactPerson, kABPersonPhoneProperty);
				if ([phone length] > 0) {
					displayName = [displayName stringByAppendingString:phone];
					sortByName = phone;
				}
			}*/
			if ([displayName length] > 0) {
				// add the contact to the list
				user.contactFullName = displayName;
				user.contactSortByName = sortByName;
				
				NSData  *imgData = (__bridge NSData *)ABPersonCopyImageData(contactPerson);
				user.contactImage = [UIImage imageWithData:imgData];
				[contactData addObject:user];
			}
        }
        CFRelease(addressBook);
    }
    
	NSArray *sortedContactList = [contactData sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
		UserContact *c1 = (UserContact *)obj1;
		UserContact *c2 = (UserContact *)obj2;
		return [c1.contactSortByName compare:c2.contactSortByName options:NSCaseInsensitiveSearch];
	}];
	contactData = [NSMutableArray arrayWithArray:sortedContactList];
	
    [_tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark searchBarDelegate
-(void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    if(![lastSearchedText isEqualToString:searchText])
    {
        [self searchContactsWithText:searchText];
        lastSearchedText = searchText;
    }
}

-(void) searchContactsWithText:(NSString *) searchText
{
    dispatch_async (dispatch_get_main_queue(), ^{
        
        if(searchContactData.count > 0)
        {
            NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
            for (int i = 0 ; i < searchContactData.count; i++) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
                [indexPaths addObject:indexPath];
            }
            [searchContactData removeAllObjects];
            [_tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
        }
        
        NSMutableArray *indexPathForAddition = [[NSMutableArray alloc] init];
        for (int i = 0; i<contactData.count; i++) {
            UserContact *contact = contactData[i];
            
            if ([contact.contactFullName rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound || searchText.length <=0)
            {
                [searchContactData addObject:contact];
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:searchContactData.count - 1 inSection:0];
                [indexPathForAddition addObject:indexPath];
            }
        }
        [self insertRowsForIndexPaths:indexPathForAddition];
    });
}

-(void) insertRowsForIndexPaths:(NSArray*) indexPaths
{
    dispatch_async (dispatch_get_main_queue(), ^{
        [_tableView beginUpdates];
        [_tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
        [_tableView endUpdates];
    });
}
@end
