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
#define kEmptyContactImage [UIImage imageNamed:@"EmptyContactPicture.png"]
#define kSelectedRowBackgroundColor [UIColor colorWithRed:244/255.0 green:240/255.0 blue:230/255.0 alpha:1.0]
#define kEmptyDark [UIImage imageNamed:@"EmptyCircle.png"]
#define kEmptyBright [UIImage imageNamed:@"EmptyCircleBright.png"]
#define kBrightBackground [UIColor colorWithRed:58/255.0f green:59/255.0f blue:63/255.0f alpha:1.0f]


#import <AddressBook/AddressBook.h>

#import "SearchViewController.h"
#import "CTListBase.h"
#import "CTEditBase.h"
#import "CTRecentsItem.h"
#import "DAKeyboardControl.h"
#import "DBManager.h"
#import "DirectorySearcher.h"
#import "SearchTableViewCell.h"
#import "SP_FastContactFinder.h"
#import "UserContact.h"
#import "Utilities.h"
#import "ActionSheetButton.h"
#import "SilentContactCell.h"

#import "NSURL+SCUtilities.h"

#define _T_WO_GUI
/*
#include "../../../baseclasses/CTListBase.h"
#include "../../../baseclasses/CTEditBase.h"
#include "../../../tiviengine/CTRecentsItem.h"
*/
@interface SearchViewController ()
{
    UILabel *toLabel;
    ActionSheetButton *chatBubbleButton;
    NSMutableArray *resultsData;
    NSMutableArray *searchResultsData;
    UITextField *searchTextField;
    UserContact *selectedUserContact;
    CTRecentsList *recentsList;
    CTRecentsList *favouritesList;
    DirectorySearcher *directorySearcher;
    ChatObject *chatObjectForForwardIng;
    
    BOOL addRecentObjectsToResults;
    
    NSOperationQueue *contactCheckQueue;
    
    BOOL _isBeingAnimated;
}
@end

@implementation SearchViewController

-(void)viewWillAppear:(BOOL)animated
{
    if([Utilities utilitiesInstance].deepLinkUrl.absoluteString.length > 0)
    {
        [_deepLinkview setHidden:NO];
        self.navigationItem.title = @"Send file";
        _deepLinkUsername.text = [[Utilities utilitiesInstance] getOwnUserName];
        [self animateDeepLinkView];
        NSURL *url = [Utilities utilitiesInstance].deepLinkUrl;
        NSString* extension = url.pathExtension;
        NSArray* importableExtensions = @[@"pdf", @"Image"];
        
        _deepLinkThumbnail.image = [url thumbNail];
        NSString *localizedName = nil;
        [url getResourceValue:&localizedName forKey:NSURLLocalizedNameKey error:NULL];
        _deepLinkFileNameLabel.text = localizedName;
        if ( [importableExtensions containsObject:extension])
        {
            NSURLRequest *request = [NSURLRequest requestWithURL:[Utilities utilitiesInstance].deepLinkUrl];
            
            [NSURLConnection sendAsynchronousRequest:request
                                               queue:[NSOperationQueue mainQueue]
                                   completionHandler:^(NSURLResponse * response, NSData *responseData, NSError *error) {
                                       
                                       if (responseData) {
                                           // TODO create SCAttachment from received data
                                       }
                                       
                                   }];
        }
        [Utilities utilitiesInstance].deepLinkUrl = [NSURL URLWithString:@""];
    } else
    {
        [_deepLinkview setHidden:YES];

        _deepLinkViewHeightConstraint.constant = 0;
        [_deepLinkview setNeedsUpdateConstraints];
        
        self.navigationItem.title = @"Search contact";
    }
    [[Utilities utilitiesInstance] setTabBarHidden:YES];
    // add custum image for back button
    UIButton *backButtonWithImage = [UIButton buttonWithType:UIButtonTypeCustom];
    [backButtonWithImage setFrame:CGRectMake(0,0,kBackButtonSize,kBackButtonSize)];
    backButtonWithImage.userInteractionEnabled = YES;
    [backButtonWithImage setImage:[UIImage imageNamed:@"BackButton.png"] forState:UIControlStateNormal];
    [backButtonWithImage addTarget:self.navigationController action:@selector(popViewControllerAnimated:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *backBarButton = [[UIBarButtonItem alloc] initWithCustomView:backButtonWithImage];
    self.navigationItem.leftBarButtonItem = backBarButton;
    [self addKeyboardPanning];
    
    // add conversation contacts to resultlist
    [self addResultsFromRecents];
    
    // set stored chatobject for forwarding to nil
    // if user clicks on search button reset it back
    chatObjectForForwardIng = [[Utilities utilitiesInstance].forwardedMessageData objectForKey:@"forwardedChatObject"];
    if(chatObjectForForwardIng)
    {
        [[Utilities utilitiesInstance].forwardedMessageData removeObjectForKey:@"forwardedChatObject"];
    }
}
-(void)viewWillDisappear:(BOOL)animated
{
    // BUG - should be done, but crashes app after closing and reopening
    //[self.view removeKeyboardControl];§
    [self.view removeKeyboardControl];
    [searchTextField resignFirstResponder];
    [directorySearcher dismissAllOperations];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    contactCheckQueue = [[NSOperationQueue alloc] init];
    
    resultsData = [[NSMutableArray alloc] init];
    
    searchResultsData = [[NSMutableArray alloc] init];
    
    // transparent black background view for status bar
    //UIView *darkTopView = [[UIView alloc] initWithFrame:CGRectMake(0, 5, [Utilities utilitiesInstance].screenWidth, [Utilities utilitiesInstance].kStatusBarHeight)];
    //[darkTopView setBackgroundColor:[Utilities utilitiesInstance].kStatusBarColor];
    //[self.view addSubview:darkTopView];
    
    /*
    UIView *darkSearchTextFieldBackground = [[UIView alloc] initWithFrame:CGRectMake(0, 65, [Utilities utilitiesInstance].screenWidth, 40)];
    [darkSearchTextFieldBackground setBackgroundColor:[Utilities utilitiesInstance].kNavigationBarColor];
    [self.view addSubview:darkSearchTextFieldBackground];
     */
    
    searchTextField = [[UITextField alloc] initWithFrame:CGRectMake(40, 5, [Utilities utilitiesInstance].screenWidth - 80, 30)];
    //[searchTextField setReturnKeyType:UIReturnKeySearch];
    searchTextField.delegate = self;
    [searchTextField setTextAlignment:NSTextAlignmentCenter];
    searchTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    searchTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    [searchTextField setBorderStyle:UITextBorderStyleRoundedRect];
    [searchTextField addTarget:self
                  action:@selector(textFieldDidChange:)
        forControlEvents:UIControlEventEditingChanged];
    searchTextField.placeholder = @"Type a contact name";
    [self.view addSubview:searchTextField];
    [searchTextField becomeFirstResponder];
    directorySearcher = [[DirectorySearcher alloc] init];
    directorySearcher.delegate = self;
    [searchTextField setReturnKeyType:UIReturnKeyGo];
    searchTextField.keyboardAppearance = UIKeyboardAppearanceDark;
    
   chatBubbleButton = [[ActionSheetButton alloc] initWithFrame:CGRectMake([Utilities utilitiesInstance].screenWidth - 30 - 5, 5, 30, 30)];
    [chatBubbleButton setImage:[UIImage imageNamed:@"ChatBubbleButton.png"] forState:UIControlStateNormal];
    [chatBubbleButton addTarget:self action:@selector(openChatWithUser:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:chatBubbleButton];
    
    toLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 0, 30, 30)];
    [toLabel setTextColor:[UIColor whiteColor]];
    toLabel.text = @"To:";
    [self.view addSubview:toLabel];
    [self loadContactsFromAddressBook];
}

-(void) animateDeepLinkView
{
    float yOffset = 80;
    [UIView animateWithDuration:0.5f animations:^(void) {
        CGRect searchRect = searchTextField.frame;
        CGRect toRect = toLabel.frame;
        CGRect chatButtonRect = chatBubbleButton.frame;
   
        searchRect.origin.y +=yOffset;
        toRect.origin.y +=yOffset;
        chatButtonRect.origin.y +=yOffset;
        
        [searchTextField setFrame:searchRect];
        [toLabel setFrame:toRect];
        [chatBubbleButton setFrame:chatButtonRect];
    }];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string{
   
   NSString *nextString = [textField.text stringByReplacingCharactersInRange:range withString:string];
   
   if(nextString.UTF8String[0] && !isalpha(nextString.UTF8String[0]))return NO;
   
   return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if(textField.text.length > 2)
    {
        [textField resignFirstResponder];
        [self openChatWithUser:nil];
    }
    return NO;
}


-(void) checkIfUserExists
{
    NSBlockOperation *blockOperation = [[NSBlockOperation alloc] init];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [blockOperation addExecutionBlock:^{
        
    // asks API for users info
        NSString * url = [NSString stringWithFormat:@"/v1/user/%@/?api_key=%@",searchTextField.text,[[Utilities utilitiesInstance] getAPIKey]];
        NSString *returnString = [[Utilities utilitiesInstance] getHttpWithUrl:url method:@"GET" requestData:@""];
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        
        NSData *data = [returnString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *resultJSON = [NSJSONSerialization JSONObjectWithData:data
                                                                   options:kNilOptions
                                                                     error:nil];
        
        if([[resultJSON objectForKey:@"result"] isEqualToString:@"error"])
        {
            NSString *errorMSg = [resultJSON objectForKey:@"error_msg"];
            if(!errorMSg)
            {
                errorMSg = [NSString stringWithFormat:@"Unable to send messages to user %@ Check whether entered username is correct",searchTextField.text];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Unable to send messages" message:errorMSg delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                [alert show];
            });
        } else if (resultJSON)
        {
            [self startChatWithUSer:searchTextField.text];
        } else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Unable to send messages" message:@"Cannot validate user name without network connection" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                [alert show];
            });
        }
    }];
    [contactCheckQueue cancelAllOperations];
    [contactCheckQueue addOperation:blockOperation];
}
-(void) openChatWithUser:(UIButton*) button
{
    NSString *thisContactName;
    NSString *thisContactUN;
    if(selectedUserContact)
    {
        thisContactName = selectedUserContact.contactFullName;
        thisContactUN = selectedUserContact.contactUserName;
        [self startChatWithUSer:thisContactUN];
    }
    else // if contact is not found assign contactName as searchTextfield.text
    {
        if(searchTextField.text.length <= 0)
        {
            return;
        }
        [self checkIfUserExists];
        //thisContactName = searchTextField.text;
        //thisContactUN = thisContactName;
    }
}

-(void) startChatWithUSer:(NSString *) thisContactUN
{
    if(_isBeingAnimated)
        return;
    
    _isBeingAnimated = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[Utilities utilitiesInstance] assignSelectedRecentWithContactName:thisContactUN];
        [searchTextField resignFirstResponder];
        
        if(chatObjectForForwardIng)
        {
            [[Utilities utilitiesInstance].forwardedMessageData setValue:chatObjectForForwardIng forKey:@"forwardedChatObject"];
        }
        // to show keyboard in chatview
        [self performSegueWithIdentifier:@"startChatsegue" sender:nil];
        
        // remove this viewcontroller from stack before opening chat
        // so back button would lead to contactsView, instead of back to search
        
        NSMutableArray *viewControllerStack = [[NSMutableArray alloc] initWithArray:
                                               self.navigationController.viewControllers];
        [viewControllerStack removeObjectAtIndex:[viewControllerStack count] - 2];
        self.navigationController.viewControllers = viewControllerStack;
        
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
        
    } constraintBasedActionHandler:nil];
}

/**
 * Gets called when value in searchTextField changes
 * Can pass textfield.text without add or remove calculation
 **/
-(void) textFieldDidChange:(UITextField*) textField
{
    NSString *textFieldText = textField.text;
    [self resultsForSearchString:textFieldText];
}

#pragma mark UITableViewDelegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    selectedUserContact = (UserContact*)searchResultsData[searchResultsData.count - 1 - indexPath.row];
    searchTextField.text = [[Utilities utilitiesInstance] removePeerInfo:selectedUserContact.contactFullName lowerCase:NO];
    [_resultsTableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return searchResultsData.count;
}
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 63;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellIdentifier = @"contactCell";
    SilentContactCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    UserContact *thisContact = (UserContact*)searchResultsData[searchResultsData.count - 1 - indexPath.row];
    
    if(thisContact == selectedUserContact)
    {
        //[cell.contentView setBackgroundColor:kSelectedRowBackgroundColor];
        [cell.redBackgroundView setHidden:NO];
    }
    else
    {
        if(indexPath.row %2 == 0)
        {
            [cell.whiteBorderImage setImage:kEmptyDark];
            [cell.cellBackgroundView setBackgroundColor:[Utilities utilitiesInstance].kChatViewBackgroundColor];
        } else
        {
            [cell.whiteBorderImage setImage:kEmptyBright];
            [cell.cellBackgroundView setBackgroundColor:kBrightBackground];
        }
        [cell.redBackgroundView setHidden:YES];
    }
    cell.contactNameLabel.text = [[Utilities utilitiesInstance] removePeerInfo:thisContact.contactFullName lowerCase:NO];
    cell.contactPhoneLabel.text = [[Utilities utilitiesInstance] removePeerInfo:thisContact.contactPhone lowerCase:NO];
    
    
    //TODO add real contact image if available
    
    int idx;
    //NSString *ns =
    [SP_FastContactFinder findPerson:thisContact.contactUserName  idx:&idx];
    
    UIImage *im = idx>= 0 ? [SP_FastContactFinder getPersonImage:idx] : nil;
    if(!im)
    {
        im = kEmptyContactImage;
        cell.contactInitialsLabel.text = [[Utilities utilitiesInstance] getInitialsForUser:[[Utilities utilitiesInstance].recents objectForKey:thisContact.contactUserName]];
        if(cell.contactInitialsLabel.text.length <=0)
        {
            cell.contactInitialsLabel.text = [[Utilities utilitiesInstance] getInitialsForUserName:thisContact.contactFullName];
        }
            
    } else
    {
        cell.contactInitialsLabel.text = @"";
    }
    cell.contactImageView.image = im;
    
    return cell;
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
            // create new UserContact
           //
           // UserContact *user = [[UserContact alloc] init];
            ABRecordRef contactPerson = (__bridge ABRecordRef)allContacts[i];
            NSString *firstName = (__bridge_transfer NSString *)ABRecordCopyValue(contactPerson,
                                                                                  kABPersonFirstNameProperty);
            NSString *lastName = (__bridge_transfer NSString *)ABRecordCopyValue(contactPerson, kABPersonLastNameProperty);
            
            NSString *companyName = (__bridge_transfer NSString *)ABRecordCopyValue(contactPerson, kABPersonOrganizationProperty);
            
            NSString *fullName;
            if(lastName.length<=0)
                lastName = @"";
            if(firstName.length<=0)
                firstName = @"";
            if(firstName.length<=0 && lastName.length<=0)
            {
                fullName = companyName;
            }
            fullName = [NSString stringWithFormat:@"%@ %@", firstName, lastName];
            
            ABMultiValueRef phones =(__bridge ABMultiValueRef)((__bridge NSString*)ABRecordCopyValue(contactPerson, kABPersonPhoneProperty));
            
            ABMultiValueRef urls = (__bridge ABMultiValueRef)((__bridge NSString*)ABRecordCopyValue(contactPerson, kABPersonURLProperty));
            
            // get url strings
            for(CFIndex i = 0; i < ABMultiValueGetCount(urls); i++) {
                
                NSString *contactURL = (__bridge NSString*)ABMultiValueCopyValueAtIndex(urls, i);
                // if url contains :sip part
                if([contactURL rangeOfString : @"sip:"].location!=NSNotFound)
                {
                    // remove :sip to get username
                    
                    //UserContact *userToAdd = [[UserContact alloc] init];
                    NSArray *contactURLArr = [contactURL componentsSeparatedByString:@"sip:"];

                    [self insertObjectWithoutSip:contactURLArr[1] displayName:fullName contactPhone:contactURL];


                }
            }
            
            // get phone strings
            for(CFIndex i = 0; i < ABMultiValueGetCount(phones); i++) {
                
                NSString *contactPhone = (__bridge NSString*)ABMultiValueCopyValueAtIndex(phones, i);
                // if url contains :sip part
                if([contactPhone rangeOfString : @"sip:"].location!=NSNotFound)
                {
                    // remove :sip to get username
                   // UserContact *userToAdd = [[UserContact alloc] init];
                    NSArray *contactPhoneArr = [contactPhone componentsSeparatedByString:@"sip:"];
                    [self insertObjectWithoutSip:contactPhoneArr[1] displayName:fullName contactPhone:contactPhone];
                } else
                {
                    [self insertObjectWithoutSip:contactPhone displayName:fullName contactPhone:contactPhone];
                }
            }
        }
        CFRelease(addressBook);
    }
    
    // initialize recents and favourites list From Recents and Favourites
    
    if(!recentsList)
    {
        recentsList = CTRecentsList::sharedRecents();
        favouritesList = CTRecentsList::sharedFavorites();
        
        // must be called in main
        dispatch_async(dispatch_get_main_queue(), ^{
            recentsList->load();
            recentsList->countItemsGrouped();
            
            favouritesList->load();
            //favouritesList->countItemsGrouped();
            
            
            // take CTRecentsItems from Recents, add to resultsData;
            for (int i = 0; i<recentsList->countVisItems(); i ++) {
                CTRecentsItem *item = recentsList->getByIndex(i);
                [self checkAndAddRecentsItem:item];
                
            }
            
            // take CTRecentsItems from Favourites, add to resultsData;
            for (int i = 0; i<favouritesList->countVisItems(); i ++) {
                CTRecentsItem *item = favouritesList->getByIndex(i);
                [self checkAndAddRecentsItem:item];
                
            }
        });
    }
    
    //[resultsTableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
    
}


#pragma mark CTHelperFunctions
/**
 * Takes data from CTrecentsItem converts to NSString
 * Checks CTRecentsItem whether it is already added to resultsData
 * Checks name field for user, if empty takes username with domain
 **/
-(void)checkAndAddRecentsItem:(CTRecentsItem*) item
{
    NSString *thisRecentFullName = [self toNSFromTB:&item->name];
    NSString *thisRecentPeerAddr = [self toNSFromTB:&item->peerAddr];
    
    if([thisRecentPeerAddr rangeOfString : @"sip:"].location != NSNotFound)
    {
        thisRecentPeerAddr = [NSString stringWithFormat:@"%s",thisRecentPeerAddr.UTF8String+4];
    }
    
    NSString *thisRecentPeerAddrWithoutDomain = [[Utilities utilitiesInstance] removePeerInfo:thisRecentPeerAddr lowerCase:YES];
    
    // check if contact already exists in resultsData
    BOOL contactExists = false;
    for (UserContact * contact in resultsData) {
        // compare full name and nickname without domain name
        if(([contact.contactFullName isEqualToString:thisRecentFullName] || [contact.contactFullName isEqualToString:thisRecentPeerAddrWithoutDomain] || [contact.contactUserName isEqualToString:thisRecentPeerAddrWithoutDomain]) &&
           (thisRecentFullName.length > 0 || thisRecentPeerAddr.length > 0))
        {
            contactExists = true;
            break;
        }
    }
    if(!contactExists)
    {
        [self insertObjectWithoutSip:thisRecentPeerAddr displayName:thisRecentFullName contactPhone:thisRecentPeerAddr];
    }

}

-(BOOL) checkIfContactIsAlreadyAdded:(UserContact *)thisContact
{
    BOOL contactExists = false;
    for (UserContact * contact in resultsData) {
        
        // compare full name and nickname without domain name
        if([[[Utilities utilitiesInstance] removePeerInfo:thisContact.contactUserName lowerCase:YES] isEqualToString:[[Utilities utilitiesInstance] removePeerInfo:contact.contactUserName lowerCase:YES]])
        {
            contactExists = true;
            break;
        }
    }
    return contactExists;
}

//if we do not have DID support we have disable DID
-(BOOL)isNumber:(NSString *)nr{
   const char *pN = nr.UTF8String;
   
   //do not insert numbers into results
   if(strncmp(pN, "sip:",4)==0)pN+=4;
   while(pN[0]=='+' || pN[0]=='(' || pN[0]==' '|| pN[0]=='-' || pN[0]=='*')pN++;
   if(isdigit(pN[0]))return YES;
   
   return NO;
}

-(void) insertObjectWithoutSip:(NSString*) userName displayName:(NSString*) displayName  contactPhone:(NSString *) contactPhone
{
    if([self isNumber:contactPhone])return;
    UserContact *thisContact = [[UserContact alloc] init];
    NSString *thisContactTitle;
    if(displayName.length > 0)
    {
        thisContactTitle = displayName;
    }  else if(userName.length > 0)
    {
        thisContactTitle = userName;
    }
    thisContact.contactFullName = [[Utilities utilitiesInstance] removePeerInfo:thisContactTitle lowerCase:NO];
    
    if([userName rangeOfString : @"sip:"].location != NSNotFound)
    {
        userName = [NSString stringWithFormat:@"%s",userName.UTF8String+4];
    }
    for (UserContact *thisContact in resultsData)
    {
        if([[[Utilities utilitiesInstance] removePeerInfo:thisContact.contactUserName lowerCase:NO] isEqualToString:[[Utilities utilitiesInstance] removePeerInfo:userName lowerCase:NO]])
        {
            return;
        }
    }
    thisContact.contactUserName = userName;
    thisContact.contactPhone = contactPhone;
    [resultsData addObject:thisContact];
}

/**
 * Convert RecentItem string to NSString
 **/
-(NSString *) toNSFromTB:(CTStrBase*) b
{
    NSString *r=[NSString stringWithCharacters:(const unichar*)b->getText() length:b->getLen()];
    return r;
}

/**
 * gets called each time user changes text in search textfield
 * searches resultsData array for searchTexfield.text
 * adds results in searchResultsData for displaying in tableview
 **/
-(void) resultsForSearchString:(NSString*) searchString
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
    for (int i = 0 ; i < searchResultsData.count; i++) {
       NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
        [indexPaths addObject:indexPath];
    }
    
    [searchResultsData removeAllObjects];
    [_resultsTableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
    
    NSMutableArray *indexPathForAddition = [[NSMutableArray alloc] init];
    [directorySearcher searchForUsersWithTextFieldText:searchString];
    for (UserContact *contact in resultsData)
    {
        if ([contact.contactFullName rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound || [contact.contactUserName rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound)
        {
            [searchResultsData addObject:contact];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:searchResultsData.count - 1 inSection:0];
            [indexPathForAddition addObject:indexPath];
        }
    }
    [self insertRowsForIndexPaths:indexPathForAddition];
    if (searchResultsData.count <= 0) {
        selectedUserContact = nil;
    }
}

#pragma mark DirectorySearch Delegate
-(void)addItemsFromNetworkDictionary:(NSArray *)userContactsToAdd
{
    NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
    for (int idx = 0, i = 0; i<userContactsToAdd.count; i++) {
        UserContact *contact = (UserContact*) userContactsToAdd[i];
       
        if([self isNumber:contact.contactPhone]  || [self isNumber:contact.contactUserName])continue;
       
        [searchResultsData addObject:contact];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:idx inSection:0];
        [indexPaths addObject:indexPath];
        idx++;
        
    }
   
    [self insertRowsForIndexPaths:indexPaths];
}

-(void) addResultsFromRecents
{
    for (RecentObject *thisRecent in [Utilities utilitiesInstance].recents.allValues) {
        UserContact *contact = [[UserContact alloc] init];
        contact.contactFullName = [[Utilities utilitiesInstance] removePeerInfo:thisRecent.displayName lowerCase:NO];
        contact.contactUserName = thisRecent.contactName;
        contact.contactPhone = thisRecent.contactName;
        if(!contact.contactFullName)
        {
            contact.contactFullName = contact.contactUserName;
        }
        if(![self checkIfContactIsAlreadyAdded:contact])
        {
            [resultsData addObject:contact];
        }
    }
}
-(void) insertRowsForIndexPaths:(NSArray*) indexPaths
{
    dispatch_async (dispatch_get_main_queue(), ^{
        [_resultsTableView beginUpdates];
        [_resultsTableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
        [_resultsTableView endUpdates];
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
@end
