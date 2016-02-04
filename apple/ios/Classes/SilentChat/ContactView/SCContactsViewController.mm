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
#define kContactCellHeight 80
#define kContactCellOffsetFromSides 40
#define kContactCellSpacing 10
#define kContactimageHeight 80


#define kBackgroundImage [UIImage imageNamed:@"chatBackground.png"]
#define kEmptyContactImage [UIImage imageNamed:@"EmptyContactPicture.png"]//defaultContact2Selected.png
#define kEmptyContactImageSelected [UIImage imageNamed:@"defaultContact2.png"]
#define kWhiteClockIcon [UIImage imageNamed:@"clockIcon.png"]
#define kBlackClockIcon [UIImage imageNamed:@"clockIconBlack.png"]

#define kAddContactIimageSize 30

#define kFirstRowBackgroundColor [UIColor colorWithRed:36/255.0 green:38/255.0 blue:39/255.0 alpha:1.0]
#define kSecondRowBackgroundColor [UIColor colorWithRed:41/255.0 green:41/255.0 blue:45/255.0 alpha:1.0]
#define kReceivedMessageLabelColor [UIColor colorWithRed:91/255.0f green:91/255.0f blue:91/255.0f alpha:1.0f]
#define kReceivedMessageBackgroundColor [UIColor colorWithRed:225/255.0f green:225/255.0f blue:225/255.0f alpha:1.0f]

#define kActiveReceivedArrow [UIImage imageNamed:@"ActiveRecivedArrow.png"]
#define kActiveSentArrow [UIImage imageNamed:@"ActiveSentArrow.png"]

#define kNotActiveRecivedArrow [UIImage imageNamed:@"NotActiveRecivedArrow.png"]
#define kNotActiveSentArrow [UIImage imageNamed:@"NotActiveSentArrow.png"]

#import "SCContactsViewController.h"
#import "ChatBubbleLabel.h"
#import "ChatViewController.h"
#import "ContactTableViewCell.h"
//#import "DAKeyboardControl.h"
#import "DBManager.h"
#import "RecentObject.h"
#import "SP_FastContactFinder.h"
#import "Utilities.h"

#import <MobileCoreServices/MobileCoreServices.h>

@interface SCContactsViewController ()
{
    //UITextField *searchContactTextField;x
    
    NSMutableArray *recentsArray;
    RecentObject *lastSelectedRecent;
    
    UILongPressGestureRecognizer *navigationTitlelongPressRecognizer;
    
    // navigation bar title
    UILabel *titleLabel;
}

@end

@implementation SCContactsViewController
-(void)viewWillDisappear:(BOOL)animated
{
    //[searchContactTextField resignFirstResponder];
    //[self.view removeKeyboardControl];
    [navigationTitlelongPressRecognizer removeTarget:self action:@selector(navigationTitlePressAction:)];
}

-(void)viewWillAppear:(BOOL)animated
{
    [[Utilities utilitiesInstance] setTabBarHidden:NO];
    // add subtitle to navigation title
    titleLabel = [[UILabel alloc] init];
    [self setNavigationBarTitle];
    [titleLabel setFont:[[Utilities utilitiesInstance] getFontWithSize:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline].pointSize]];
    [titleLabel setTextColor:[UIColor whiteColor]];
    [titleLabel setTextAlignment:NSTextAlignmentCenter];
    
    // set label size to fit this text
    titleLabel.text = @"10 UNREAD MESSAGES";
    [titleLabel sizeToFit];
    
    
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = [[Utilities utilitiesInstance] getOwnUserName];
    [subtitleLabel setTextColor:[UIColor whiteColor]];
     [subtitleLabel setFont:[[Utilities utilitiesInstance] getFontWithSize:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote].pointSize]];
    [subtitleLabel sizeToFit];
     

    UIView *navigationItemTitleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0,MAX(subtitleLabel.frame.size.width, titleLabel.frame.size.width), titleLabel.frame.size.height + subtitleLabel.frame.size.height)];
    [navigationItemTitleView addSubview:titleLabel];
    [navigationItemTitleView addSubview:subtitleLabel];
    
    navigationTitlelongPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(navigationTitlePressAction:)];
    navigationTitlelongPressRecognizer.minimumPressDuration = 0.25;
    [navigationItemTitleView addGestureRecognizer:navigationTitlelongPressRecognizer];
    
    
    float widthDiff = subtitleLabel.frame.size.width - titleLabel.frame.size.width;
    
    if (widthDiff > 0) {
        CGRect frame = titleLabel.frame;
        frame.origin.x = widthDiff / 2;
        titleLabel.frame = CGRectIntegral(frame);
    }else{
        CGRect frame = subtitleLabel.frame;
        frame.origin.x = fabs(widthDiff) / 2;
        subtitleLabel.frame = CGRectIntegral(frame);
    }
    
    [subtitleLabel setFrame:CGRectMake(subtitleLabel.frame.origin.x, titleLabel.frame.size.height, subtitleLabel.frame.size.width, subtitleLabel.frame.size.height)];
     
    self.navigationItem.titleView = navigationItemTitleView;
    
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.backgroundColor = [Utilities utilitiesInstance].kNavigationBarColor;
    [self.navigationController.navigationBar setBarTintColor:[Utilities utilitiesInstance].kNavigationBarColor];
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor colorWithRed:226/255.0f green:226/255.0f blue:226/255.0f alpha:1.0f],
                                                                    NSFontAttributeName:[[Utilities utilitiesInstance] getFontWithSize:16]};
    
    /*
    self.navigationController.navigationBar.layer.shadowColor = [[UIColor blackColor] CGColor];
    self.navigationController.navigationBar.layer.shadowOffset = CGSizeMake(0,3);
    self.navigationController.navigationBar.layer.shadowRadius = 1.0f;
    self.navigationController.navigationBar.layer.shadowOpacity = 0.3f;
     */
    
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    
    // add custum image for rightbarbuttonItem
    UIButton *rightButtonWithImage = [UIButton buttonWithType:UIButtonTypeCustom];
    [rightButtonWithImage setFrame:CGRectMake(0,0,kAddContactIimageSize,kAddContactIimageSize)];
    rightButtonWithImage.userInteractionEnabled = YES;
    [rightButtonWithImage.imageView setContentMode:UIViewContentModeScaleAspectFit];
    [rightButtonWithImage setImage:[UIImage imageNamed:@"plussButton.png"] forState:UIControlStateNormal];
    [rightButtonWithImage addTarget:self action:@selector(addContactClick) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *rightBarButton = [[UIBarButtonItem alloc] initWithCustomView:rightButtonWithImage];
    self.navigationItem.rightBarButtonItem = rightBarButton;
    
    
    [self resetBadgeNumber];
    [self sortAndRefreshRecentsTableView];
    
     [self.navigationController.navigationBar setShadowImage:[UIImage new]];
    
}

-(void) sortAndRefreshRecentsTableView
{
    // sort utilities.recents dictionary.allvalues to descending by timestamp
    // assign to local recentsArray
    NSSortDescriptor *sortDescriptor;
    sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"unixTimeStamp"
                                                 ascending:NO];
    
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    recentsArray = [[[Utilities utilitiesInstance].recents.allValues sortedArrayUsingDescriptors:sortDescriptors] mutableCopy];
    
    [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
}

-(void) resetBadgeNumber
{
    NSString *badgeValue = [[Utilities utilitiesInstance] getBadgeValueForChatTabBar];
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        if([badgeValue intValue] <= 0)
        {
            [self.navigationController.tabBarItem setBadgeValue:nil];
        } else
        {
            [self.navigationController.tabBarItem setBadgeValue:badgeValue];
        }
    });
    [self setNavigationBarTitle];
}

-(void) setNavigationBarTitle
{
    NSString *badgeValue = [[Utilities utilitiesInstance] getBadgeValueForChatTabBar];
    
    NSString *pluralSuffix = @"";
    if([badgeValue intValue] > 1)
    {
        pluralSuffix = @"S";
    }
    titleLabel.text = [NSString stringWithFormat:@"%@ UNREAD MESSAGE%@",badgeValue,pluralSuffix];
    if([badgeValue intValue] <=0)
    {
        titleLabel.text = @"TEXT";
    } else
    {
        titleLabel.text = [NSString stringWithFormat:@"%@ UNREAD MESSAGE%@",badgeValue,pluralSuffix];
    }
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    [self.view setBackgroundColor:[Utilities utilitiesInstance].kChatViewBackgroundColor];
    [self resetBadgeNumber];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(resetBadgeNumber)
                                                 name:@"resetBadgeNumberForChatView"
                                               object:nil];
    recentsArray = [[NSMutableArray alloc] init];
    //[self addKeyboardPanning];
    // transparent black background view for status bar
    //UIView *darkTopView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [Utilities utilitiesInstance].screenWidth, [Utilities utilitiesInstance].kStatusBarHeight)];
    //[darkTopView setBackgroundColor:[Utilities utilitiesInstance].kStatusBarColor];
    //[self.view addSubview:darkTopView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateRecentsTableView)
                                                 name:@"updateRecents"
                                               object:nil];
    /*
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];*/
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receiveMessage:)
                                                 name:@"receiveMessage" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(receiveMessage:) // same handler
												 name:AttachmentManagerReceiveAttachmentNotification object:nil];
	
    // add tap gesture to tableview background to deselect contact when clicked outside row
    UITapGestureRecognizer *tapOutsideTableViewRow = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapOnTableViewBackgroundView:)];
    if(!self.tableView.backgroundView)
    {
        UIView *tableViewBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [Utilities utilitiesInstance].screenWidth, [Utilities utilitiesInstance].screenHeight)];
        UIImageView *tableBackgroundImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, [Utilities utilitiesInstance].screenWidth, [Utilities utilitiesInstance].screenHeight)];
        tableBackgroundImageView.image = nil;
        [tableBackgroundImageView setBackgroundColor:[Utilities utilitiesInstance].kNavigationBarColor];
        [tableBackgroundImageView setContentMode:UIViewContentModeScaleToFill];
        [tableViewBackgroundView addSubview:tableBackgroundImageView];
        self.tableView.backgroundView = tableViewBackgroundView;
    }
    [self.tableView.backgroundView addGestureRecognizer:tapOutsideTableViewRow];
    self.tableView.layer.shouldRasterize = YES;
    self.tableView.layer.rasterizationScale = [[UIScreen mainScreen] scale];
}


-(void) receiveMessage:(NSDictionary*) data
{
    [self sortAndRefreshRecentsTableView];
}

-(void) updateRecentsTableView
{
    [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
}

-(void) openChatViewWithUser
{
    // Rest of chatting interface resides in Chat.storyboard
    // Instantiate the storyboard and open first viewcontroller
    UIStoryboard *chatStoryBoard = [UIStoryboard storyboardWithName:@"Chat" bundle:nil];
    UIViewController *chatViewController = [chatStoryBoard instantiateViewControllerWithIdentifier:@"ChatViewController"];
    [self.navigationController pushViewController:chatViewController animated:YES];
}

#pragma mark UITableViewDelegate
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
   // ContactTableViewCell *cell = (ContactTableViewCell*)[tableView cellForRowAtIndexPath:indexPath];
    
    RecentObject *selectedRecent = (RecentObject*)[recentsArray objectAtIndex:indexPath.row];
    
    // little wierd but still better than assigning selectedRecent variables
    [[Utilities utilitiesInstance] assignSelectedRecentWithContactName:selectedRecent.contactName];
    
    // local reference to last selected recent
    lastSelectedRecent = selectedRecent;
    
    /*
    // set chat contact name and ID
    // TODO remove nsstrings for last object
    [Utilities utilitiesInstance].lastOpenedUserNameForChat = cell.contactName;
    
    // assign info about last selected contact
    [Utilities utilitiesInstance].selectedRecentObject = selectedRecent;
    [Utilities utilitiesInstance].selectedRecentObject.contactName = cell.contactName;
    [Utilities utilitiesInstance].selectedRecentObject.displayName =[[Utilities utilitiesInstance] removePeerInfo:cell.contactName lowerCase:NO];
    [Utilities utilitiesInstance].selectedRecentObject.shareLocationTime = selectedRecent.shareLocationTime;*/
    
    // reload before closing, so user could see selected contact to turn red
    [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
    [self openChatViewWithUser];
    
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [self deleteConversationForRow:indexPath];
}

-(void) deleteConversationForRow:(NSIndexPath *) indexPath
{
    // Remove RecentObject from utiliies
    RecentObject *recentToRemove = [recentsArray objectAtIndex:indexPath.row];
    [[DBManager dBManagerInstance] removeChatWithContact:recentToRemove];
    [[Utilities utilitiesInstance].recents removeObjectForKey:recentToRemove.contactName];
    
    // remove from selected
    if ([[Utilities utilitiesInstance].selectedRecentObject isEqual:recentToRemove])
    {
        [Utilities utilitiesInstance].selectedRecentObject = nil;
    }
    
    // Remove from local array
    [recentsArray removeObject:recentToRemove];
    [[Utilities utilitiesInstance] removeBadgesForConversation:recentToRemove];
    [_tableView reloadSections: [NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
    [self resetBadgeNumber];
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return recentsArray.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return kContactCellHeight;
}





-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"SCContactCell";
    
    // use local recentsArray
    RecentObject *thisRecent = (RecentObject*)recentsArray[indexPath.row];
    NSArray *messagesForThisContact = [[Utilities utilitiesInstance].chatHistory objectForKey:thisRecent.contactName];
    
    ChatObject *lastChatObject = messagesForThisContact.lastObject;
    
    ContactTableViewCell *cell = (ContactTableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    ChatBubbleLabel *lastMessageLabel;
    
    UILabel *dateLabel;
    UIImageView *sentArrow;
    UIImageView *receivedArrow;
    
    UILabel *unreadMessageCounterLabel;
    
    if(cell == nil)
    {
        [tableView registerNib:[UINib nibWithNibName:@"contactCell" bundle:nil] forCellReuseIdentifier:@"SCContactCell"];
        cell = [tableView dequeueReusableCellWithIdentifier:@"SCContactCell"];
    }
    // if cell doesnt have text label
    if(![cell.contentView viewWithTag:7])
    {
        lastMessageLabel = [[ChatBubbleLabel alloc] init];
        [lastMessageLabel setFont:[[Utilities utilitiesInstance] getFontWithSize:[UIFont preferredFontForTextStyle:UIFontTextStyleBody].pointSize]];
        [lastMessageLabel setTextColor:[UIColor whiteColor]];
        [lastMessageLabel setBackgroundColor:kReceivedMessageLabelColor];
        lastMessageLabel.tag = 7;
        lastMessageLabel.numberOfLines = 1;
        [cell.contentView addSubview:lastMessageLabel];
        
        dateLabel = [[UILabel alloc] init];
        [dateLabel setFont:[[Utilities utilitiesInstance] getFontWithSize:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote].pointSize]];
        [dateLabel setTextColor:[UIColor whiteColor]];
        dateLabel.tag = 8;
        [cell.contentView addSubview:dateLabel];
        
        sentArrow = [[UIImageView alloc] init];
        sentArrow.tag = 9;
        [cell.contentView addSubview:sentArrow];
        
        receivedArrow = [[UIImageView alloc] init];
        receivedArrow.tag = 10;
        [cell.contentView addSubview:receivedArrow];
        
        cell.initialsLabel.numberOfLines = 1;
        cell.initialsLabel.adjustsFontSizeToFitWidth = YES;
        cell.initialsLabel.edgeInsets = UIEdgeInsetsMake(0, 3, 0, 3);
        
    }
    else
    {
        lastMessageLabel = (ChatBubbleLabel*)[cell.contentView viewWithTag:7];
        dateLabel = (UILabel*)[cell.contentView viewWithTag:8];
        sentArrow = (UIImageView*)[cell.contentView viewWithTag:9];
        receivedArrow = (UIImageView*)[cell.contentView viewWithTag:10];
    }
    [cell.failedBadgeImageView setHidden:YES];
    [cell.backgroundPlaceHoler setBackgroundColor:[Utilities utilitiesInstance].kChatViewBackgroundColor];
    /*
    if(indexPath.row % 2 == 0)
    {
        [cell.backgroundPlaceHoler setBackgroundColor:kFirstRowBackgroundColor];
    } else
    {
        [cell.backgroundPlaceHoler setBackgroundColor:[Utilities utilitiesInstance].kChatViewBackgroundColor];
    }
                                                                             */
    //UIImageView *contactImageView = (UIImageView*)[cell.contentView viewWithTag:1];
    //UILabel *contactNameLabel = (UILabel*)[cell.contentView viewWithTag:2];
    //UILabel *timeLabel = (UILabel*)[cell.contentView viewWithTag:8];
   // UIView *receivedAlertView = [cell.contentView viewWithTag:10];
    //UIImageView *clockIconImageView = (UIImageView *)[cell.contentView viewWithTag:11];
    
    //TODO add real contact image if available
    
    int idx;
    NSString *ns = [SP_FastContactFinder findPerson:thisRecent.contactName idx:&idx];

    //UIImage *emptyContactImage = kEmptyContactImage;
    // change color of selected cell
    if(lastSelectedRecent == thisRecent)
    {
        [sentArrow setImage:kActiveSentArrow];
        [receivedArrow setImage:kActiveReceivedArrow];
        
        //emptyContactImage = kEmptyContactImageSelected;
        //[clockIconImageView setImage:kBlackClockIcon];
        //[[cell.contentView viewWithTag:6] setBackgroundColor:kReceivedMessageBackgroundColor];
        [lastMessageLabel setTextColor:[UIColor blackColor]];
        [lastMessageLabel setBackgroundColor:kReceivedMessageBackgroundColor];
        //[cell.contactNameLabel setTextColor:[UIColor blackColor]];
       // [cell.lastDateLabel setTextColor:[UIColor blackColor]];
        
    } else
    {
        [sentArrow setImage:kNotActiveSentArrow];
        [receivedArrow setImage:kNotActiveRecivedArrow];
        
        //emptyContactImage = kEmptyContactImage;
        [lastMessageLabel setBackgroundColor:kReceivedMessageLabelColor];
       // [clockIconImageView setImage:kWhiteClockIcon];
        [lastMessageLabel setTextColor:[UIColor whiteColor]];
       // [cell.contactNameLabel setTextColor:[UIColor whiteColor]];
        //[cell.lastDateLabel setTextColor:[UIColor whiteColor]];
    }
    UIImage *im = [SP_FastContactFinder getPersonImage:idx];
    if(im)
    {
        [cell.initialsLabel setHidden:YES];
    }else
    {
        [cell.initialsLabel setHidden:NO];
        cell.initialsLabel.text = [[Utilities utilitiesInstance] getInitialsForUser:thisRecent];
    }
    cell.contactImageLabel.image = im ? im : kEmptyContactImage;
    
    if(lastChatObject)
    {
        NSString *lastMessageLabelText = @"";
        if(lastChatObject.attachment)
        {
            // detect last message content
            NSString *mediaType = [lastChatObject.attachment.metadata objectForKey:kSCloudMetaData_MediaType];
            if(lastChatObject.hasFailedAttachment)
            {
                lastMessageLabelText = @"Failed attachment";
                [cell.failedBadgeImageView setHidden:NO];
                lastMessageLabel.textColor = [UIColor colorWithRed:231/255.0 green:58/255.0 blue:39/255.0 alpha:1.0f];
            } else
            if ([(__bridge NSString *)kUTTypeAudio isEqualToString:mediaType])
            {
                lastMessageLabelText = @"Audio";
            } else if ([(__bridge NSString *)kUTTypeImage isEqualToString:mediaType])
            {
                lastMessageLabelText = @"Image";
            } else if([(__bridge NSString *)kUTTypeMovie isEqualToString:mediaType])
            {
                lastMessageLabelText = @"Movie";
            }
            else if([(__bridge NSString *)kUTTypePDF isEqualToString:mediaType])
            {
                lastMessageLabelText = @"PDF";
            }
            else
            {
                lastMessageLabelText = @"File";
            }
            if(!lastChatObject.hasFailedAttachment)
            {
                if(lastChatObject.isReceived == 1)
                {
                    lastMessageLabelText = [NSString stringWithFormat:@"%@ %@",lastMessageLabelText,@"received"];
                } else
                {
                    lastMessageLabelText = [NSString stringWithFormat:@"%@ %@",lastMessageLabelText,@"sent"];
                }
            }
            if(lastChatObject.audioLength)
            {
                lastMessageLabelText = [NSString stringWithFormat:@"%@ : %@",lastMessageLabelText, lastChatObject.audioLength];
            }
            
        } else
        {
            lastMessageLabelText = lastChatObject.messageText;
        }
        lastMessageLabel.text = lastMessageLabelText;
        dateLabel.text = [[Utilities utilitiesInstance] getTimeDifferenceSinceNowForTimeString:(int)lastChatObject.unixTimeStamp];
        
       // [clockIconImageView setHidden:NO];
    } else
    {
        dateLabel.text = @"";
        lastMessageLabel.text = @" No messages";
        [lastMessageLabel setTextColor:[UIColor lightGrayColor]];
        //[clockIconImageView setHidden:YES];
    }
     cell.contactNameLabel.text = ns && ns.length>0 ? ns : [[Utilities utilitiesInstance] removePeerInfo:thisRecent.contactName lowerCase:NO];
    
    
    // position last message label right below contact name label
    // position datelabel at the bottom right of last message label
    [lastMessageLabel sizeToFit];
    [dateLabel sizeToFit];
    [lastMessageLabel setFrame:CGRectMake(cell.contactNameLabel.frame.origin.x, cell.contactNameLabel.frame.origin.y + cell.contactNameLabel.frame.size.height + 2 , [Utilities utilitiesInstance].screenWidth - cell.contactNameLabel.frame.origin.x - 15 , lastMessageLabel.frame.size.height+10)];
    
    [dateLabel setFrame:CGRectMake(lastMessageLabel.frame.origin.x + lastMessageLabel.frame.size.width - dateLabel.frame.size.width, lastMessageLabel.frame.origin.y + lastMessageLabel.frame.size.height, dateLabel.frame.size.width, dateLabel.frame.size.height)];
    
    //[cell.messageAlertView sizeToFit];
    
    int receivedMessageCount = [[Utilities utilitiesInstance] getBadgeValueForUser:thisRecent.contactName];
    if(receivedMessageCount <= 0)
    {
       [cell.messageAlertView setHidden:YES];
        [unreadMessageCounterLabel setHidden:YES];
    }
    else if(cell.failedBadgeImageView.hidden)
    {
        [cell.messageAlertView setHidden:NO];
        cell.messageAlertView.text = [NSString stringWithFormat:@"%i",receivedMessageCount];
        /*
        [unreadMessageCounterLabel setHidden:NO];
        NSString *receivedMessageCountString = [NSString stringWithFormat:@"%i",receivedMessageCount];
        unreadMessageCounterLabel.text = receivedMessageCountString;
        CGRect unreadLabelRect = [receivedMessageCountString boundingRectWithSize:CGSizeMake(9999, 9999)
                                                                               options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading)
                                                                            attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12]}
                                                                               context:nil
                                  ];
        CGSize unreadLabelSize = CGSizeMake(ceil(unreadLabelRect.size.width), ceil(unreadLabelRect.size.height));
        [cell.messageAlertView setFrame:CGRectMake(cell.contactImageLabel.frame.size.width,0,unreadLabelSize.width + 10,unreadLabelSize.width + 10)];
        cell.messageAlertView.layer.cornerRadius = cell.messageAlertView.frame.size.width/2;
         */
    }
    const int arrowSize = 15;
    if(lastChatObject && lastMessageLabel.text.length > 0)
    {
        float yPos = (lastMessageLabel.frame.origin.y + lastMessageLabel.frame.size.height) - (lastMessageLabel.frame.size.height/2) - arrowSize/2;
        if(lastChatObject.isReceived == 1)
        {
            [receivedArrow setHidden:NO];
            [receivedArrow setTintColor:kReceivedMessageBackgroundColor];
            [receivedArrow setFrame:CGRectMake(lastMessageLabel.frame.origin.x - arrowSize + 5, yPos, arrowSize, arrowSize)];
            [sentArrow setHidden:YES];
        } else
        {
            [sentArrow setHidden:NO];
            [sentArrow setTintColor:kReceivedMessageBackgroundColor];
            [sentArrow setFrame:CGRectMake([Utilities utilitiesInstance].screenWidth - arrowSize - 5, yPos, arrowSize, arrowSize)];
            [receivedArrow setHidden:YES];
        }
    } else
    {
        [sentArrow setHidden:YES];
        [receivedArrow setHidden:YES];
    }
    
    cell.contactName = thisRecent.contactName;
    return cell;
}





/**
 *tap on tableView background
 * to deselct selected row
 **/
#pragma mark tapGestureRecognizer
- (void)tapOnTableViewBackgroundView:(UITapGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateEnded)
    {
        lastSelectedRecent = nil;
        [self updateRecentsTableView];
    }
}

/**
 * click on search for contact button in top right
 * ad's bottom textfield similar in ChatViewController
 * animate textfield up and down in keyboardWillShow and keyboardWillHide
 **/
-(void) addContactClick
{
    UIStoryboard *chatStoryBoard = [UIStoryboard storyboardWithName:@"Chat" bundle:nil];
    UIViewController *chatViewController = [chatStoryBoard instantiateViewControllerWithIdentifier:@"SearchViewController"];
    [self.navigationController pushViewController:chatViewController animated:YES];
}
/*

#pragma mark keyboardDelegate
//Code from Brett Schumann
-(void) keyboardWillShow:(NSNotification *)note
{
    // get keyboard size and location
    CGRect keyboardBounds;
    [[note.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &keyboardBounds];
    NSNumber *duration = [note.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSNumber *curve = [note.userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey];
    
    // Need to translate the bounds to account for rotation.
    keyboardBounds = [self.view convertRect:keyboardBounds toView:nil];
    
    // get a rect for the search texfield frame
    CGRect contactSearchTextFieldframe = searchContactTextField.frame;
    contactSearchTextFieldframe.origin.y = self.view.bounds.size.height - (keyboardBounds.size.height + contactSearchTextFieldframe.size.height);
    
    // animations settings
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDuration:[duration doubleValue]];
    [UIView setAnimationCurve:[curve intValue]];
    
    // set views with new info
    searchContactTextField.frame = contactSearchTextFieldframe;
    
    
    // commit animations
    [UIView commitAnimations];
}

-(void) keyboardWillHide:(NSNotification *)note{
    NSNumber *duration = [note.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSNumber *curve = [note.userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey];
    
    CGRect contactSearchTextFieldframe = searchContactTextField.frame;
    contactSearchTextFieldframe.origin.y = self.view.bounds.size.height - contactSearchTextFieldframe.size.height;
    
    // animations settings
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDuration:[duration doubleValue]];
    [UIView setAnimationCurve:[curve intValue]];
    
    // set views with new info
    searchContactTextField.frame = contactSearchTextFieldframe;
    // commit animations
    [UIView commitAnimations];
}

-(void) addKeyboardPanning
{
    //DaKeyBoardControl block
    self.view.keyboardTriggerOffset = 40;
    [self.view addKeyboardPanningWithFrameBasedActionHandler:^(CGRect keyboardFrameInView, BOOL opening, BOOL closing) {

        CGRect searchContactTextFieldFrame = searchContactTextField.frame;
        searchContactTextFieldFrame.origin.y = keyboardFrameInView.origin.y - searchContactTextFieldFrame.size.height;
        searchContactTextField.frame = searchContactTextFieldFrame;
        
    } constraintBasedActionHandler:nil];
}
*/
- (void)navigationTitlePressAction:(UIGestureRecognizer *)gestureRecognizer
{
    [Utilities utilitiesInstance].selectedRecentObject = nil;
    //[self performSegueWithIdentifier:@"deviceSegue" sender:nil];
    UIStoryboard *chatStoryBoard = [UIStoryboard storyboardWithName:@"Chat" bundle:nil];
    UIViewController *chatViewController = [chatStoryBoard instantiateViewControllerWithIdentifier:@"DevicesViewController"];
    [self.navigationController pushViewController:chatViewController animated:YES];
}

/**
 * If search textfield contains more than 3 characters, search or create new user by name
 *assign username to lastchattedusername for displaying in navigation bar
 * open chat.storyBoard
 **/
-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    return YES;
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
