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
#import "SilentContactInfoViewController.h"
#import "ContactInfoCell.h"
#import "axolotl_glue.h"
#import "Utilities.h"

#include "CSCContactDiscoveryBase.h"

#include "Recents.h"
#define _T_WO_GUI
#include "../../../../baseclasses/CTListBase.h"
#include "../../../../baseclasses/CTEditBase.h"
#include "../../../../tiviengine/CTRecentsItem.h"

#define kBackButtonSize 30
#define kChatIcon [UIImage imageNamed:@"ContactChatButton.png"]
#define kCallIcon [UIImage imageNamed:@"ContactCallButton.png"]
#define kFavoritesIcon [UIImage imageNamed:@"ContactFavoritesButton.png"]
//#include "interfaceApp/AppInterfaceImpl.h"
@implementation SilentContactInfoViewController
{
    NSMutableArray *_nonFavedContacts;
    UIButton *_favoritesButton;
}
#pragma mark UITableViewDelegate

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [[Utilities utilitiesInstance] setTabBarHidden:NO];
    
    _contactUsername.text = _selectedUserContact.contactFullName;
    // add custum image for back button
    UIButton *backButtonWithImage = [UIButton buttonWithType:UIButtonTypeCustom];
    [backButtonWithImage setFrame:CGRectMake(0,0,kBackButtonSize,kBackButtonSize)];
    backButtonWithImage.userInteractionEnabled = YES;
    [backButtonWithImage setImage:[UIImage imageNamed:@"BackButton.png"] forState:UIControlStateNormal];
    backButtonWithImage.accessibilityLabel = @"Back";
    [backButtonWithImage addTarget:self.navigationController action:@selector(popViewControllerAnimated:) forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *backBarButton = [[UIBarButtonItem alloc] initWithCustomView:backButtonWithImage];
    self.navigationItem.leftBarButtonItem = backBarButton;
    
    [self.navigationController.navigationBar setBackgroundImage:[[UIImage alloc] init] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = [[UIImage alloc] init];
    
    if(_selectedUserContact.contactImage)
    {
        _contactImageView.image = _selectedUserContact.contactImage;
        _initialsLabel.text = @"";
    } else
    {
        _initialsLabel.text = [[Utilities utilitiesInstance] getInitialsForUserName:_selectedUserContact.contactFullName];
        _contactImageView.image = nil;
    }
    [self findPhoneNumber];
    
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(favoriteAdded:)
                                                 name:@"kSilentPhoneFavoriteAddedNotification"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(favoriteRemoved:)
                                                 name:@"kSilentPhoneFavoriteRemovedNotification"
                                               object:nil];
    
}
- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)favoriteAdded:(NSNotification*)notification {
    
    [self refreshFavorites];
}

- (void)favoriteRemoved:(NSNotification*)notification {
    
    [self refreshFavorites];
}

- (void)refreshFavorites {

    _nonFavedContacts = [NSMutableArray array];
    
    for (NSDictionary * contactInfoArray in _selectedUserContact.contactInfoArray) {
        
        NSString *formattedPhoneNumber = [contactInfoArray objectForKey:@"phoneNumber"];
        
        CTRecentsItem *n = [self getRecentItemWithPhoneCallNumber:formattedPhoneNumber];
        
        int addToFavorites(CTRecentsItem *i, void *fav, int iFind);
        BOOL isFavorited = (addToFavorites(n,NULL,1) == 1);
        
        if(!isFavorited)
            [_nonFavedContacts addObject:contactInfoArray];
    }
    
    [_favoritesButton setEnabled:([_nonFavedContacts count] > 0)];
}

-(void) findPhoneNumber
{
    if(!_silentPhoneCallNumber)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            _nonFavedContacts = [NSMutableArray array];
            
            for (NSDictionary * contactInfoArray in _selectedUserContact.contactInfoArray) {
                
                NSString *formattedPhoneNumber = [contactInfoArray objectForKey:@"phoneNumber"];
                
                CTRecentsItem *n = [self getRecentItemWithPhoneCallNumber:formattedPhoneNumber];
                
                int addToFavorites(CTRecentsItem *i, void *fav, int iFind);
                BOOL isFavorited = (addToFavorites(n,NULL,1) == 1);

                if(!isFavorited)
                    [_nonFavedContacts addObject:contactInfoArray];
                
                int r = 0;
                
                if(formattedPhoneNumber)
                    r = g_CSCContactDiscoveryObject()->isMatching(formattedPhoneNumber.UTF8String);
                
                if(r == 1)
                {
                    NSString *cleanNr = [[Utilities utilitiesInstance] removePeerInfo:formattedPhoneNumber lowerCase:NO];
                    
                    NSString *un = [[Utilities utilitiesInstance] getUserNameFromAlias:cleanNr];
                    
                    if(un && un.length>0)
                        formattedPhoneNumber = un;
                    
                    _silentPhoneCallNumber = formattedPhoneNumber;
                }
            }

            [self performSelectorOnMainThread:@selector(showTableViewHeader) withObject:nil waitUntilDone:NO];
        });
    }
}
#define kButtonWidth 100
-(void) showTableViewHeader
{
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [Utilities utilitiesInstance].screenWidth, 55)];
    [headerView setBackgroundColor:[UIColor clearColor]];
    headerView.clipsToBounds = YES;
    
    UIButton * callButton = [[UIButton alloc] initWithFrame:CGRectMake(([Utilities utilitiesInstance].screenWidth / 2) - kButtonWidth/2, 0, kButtonWidth, 50)];
    [callButton setImage:kCallIcon forState:UIControlStateNormal];
    [callButton.imageView setContentMode:UIViewContentModeScaleAspectFit];
    [callButton addTarget:self action:@selector(callToSilentPhone) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:callButton];
    
    UIButton * chatButton = [[UIButton alloc] initWithFrame:CGRectMake(([Utilities utilitiesInstance].screenWidth / 2) - kButtonWidth/2 - kButtonWidth - 10, 0, kButtonWidth, 50)];
    [chatButton setImage:kChatIcon forState:UIControlStateNormal];
    [chatButton.imageView setContentMode:UIViewContentModeScaleAspectFit];
    [chatButton addTarget:self action:@selector(startChatWithContact) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:chatButton];
    
    _favoritesButton = [[UIButton alloc] initWithFrame:CGRectMake(([Utilities utilitiesInstance].screenWidth / 2) - kButtonWidth/2 + kButtonWidth + 10, 0, kButtonWidth, 50)];
    [_favoritesButton setImage:kFavoritesIcon forState:UIControlStateNormal];
    [_favoritesButton.imageView setContentMode:UIViewContentModeScaleAspectFit];
    [_favoritesButton addTarget:self action:@selector(presentFavorites) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:_favoritesButton];
    
    if(!_silentPhoneCallNumber) {
        
        [callButton setEnabled:NO];
        [chatButton setEnabled:NO];
    }
    
    if([_nonFavedContacts count] == 0)
        [_favoritesButton setEnabled:NO];
    
    [UIView animateWithDuration:.1f animations:^{
        [_tableView beginUpdates];
        [_tableView setTableHeaderView:headerView];
        [_tableView endUpdates];
    }];
    
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)sender
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)sender numberOfRowsInSection:(NSInteger)section
{
    return _selectedUserContact.contactInfoArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellIdentifier = @"callCell";
    ContactInfoCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    NSDictionary *contactPhones = _selectedUserContact.contactInfoArray[indexPath.row];
    
    cell.phoneLabel.text = [contactPhones objectForKey:@"phoneLabel"];
    NSString *formattedPhoneNumber = [[Utilities utilitiesInstance] removePeerInfo:[contactPhones objectForKey:@"phoneNumber"] lowerCase:NO];
    formattedPhoneNumber = [[Utilities utilitiesInstance] formatPhoneNumber:formattedPhoneNumber];
    cell.phoneNumberLabel.text = formattedPhoneNumber;
    cell.callButton.tag = indexPath.row;
    [cell.callButton addTarget:self action:@selector(callToPhone:) forControlEvents:UIControlEventTouchUpInside];
    return cell;
}

-(void) startChatWithContact
{
    [[Utilities utilitiesInstance] assignSelectedRecentWithContactName:_silentPhoneCallNumber];
    UIStoryboard *chatStoryBoard = [UIStoryboard storyboardWithName:@"Chat" bundle:nil];
    UIViewController *chatViewController = [chatStoryBoard instantiateViewControllerWithIdentifier:@"ChatViewController"];
    
    [self.navigationController pushViewController:chatViewController animated:YES];
}

- (CTRecentsItem*)getRecentItemWithPhoneCallNumber:(NSString *)phoneCallNumber {
    
    CTRecentsItem *n = new CTRecentsItem();
    
    if(!n)
        return NULL;
    
    n->name.setText(_selectedUserContact.contactFullName.UTF8String);
    n->peerAddr.setText(phoneCallNumber.UTF8String);
    
    return n;
}

-(void) presentFavorites
{
    if([_nonFavedContacts count] == 1) {
        
        [self addToFavorites:[_nonFavedContacts objectAtIndex:0]];
        return;
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Add to Favorites"
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (NSDictionary *contactInfo in _nonFavedContacts) {
        
        NSString *phoneNumber   = [contactInfo objectForKey:@"phoneNumber"];
        NSString *phoneLabel    = [contactInfo objectForKey:@"phoneLabel"];
        
        NSString *formattedPhoneNumber = [[Utilities utilitiesInstance] removePeerInfo:phoneNumber lowerCase:NO];
        formattedPhoneNumber = [[Utilities utilitiesInstance] formatPhoneNumber:formattedPhoneNumber];

        UIAlertAction *addFavAction = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@\t%@", phoneLabel, formattedPhoneNumber]
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * _Nonnull action) {
                                                                 [self addToFavorites:contactInfo];
                                                             }];
        [alertController addAction:addFavAction];
    }
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alertController addAction:cancelAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)addToFavorites:(NSDictionary*)contactInfo {
    
    NSString *phoneNumber = [contactInfo objectForKey:@"phoneNumber"];

    CTRecentsItem *n = [self getRecentItemWithPhoneCallNumber:phoneNumber];
    
    int addToFavorites(CTRecentsItem *i, void *fav, int iFind);
        addToFavorites(n,NULL,0);
    
    [_nonFavedContacts removeObject:contactInfo];

    if([_nonFavedContacts count] == 0)
        [_favoritesButton setEnabled:NO];
}

-(void) callToSilentPhone
{
    void callToApp(const char *);
    callToApp(_silentPhoneCallNumber.UTF8String);
}
-(void) callToPhone:(UIButton *) sender
{
    ContactInfoCell *cell = (ContactInfoCell*)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:sender.tag inSection:0]];
    if(cell.phoneNumberLabel.text.length > 0)
    {
        void callToApp(const char *);
        callToApp(cell.phoneNumberLabel.text.UTF8String);
    }
}
@end
