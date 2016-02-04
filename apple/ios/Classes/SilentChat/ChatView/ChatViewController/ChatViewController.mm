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
#define kActionSheetHeight 50
#define kAudioPlayerFrameHeight 40
#define kBackButtonSize 30
#define kChatRowVerticalSpacing 8

#define kChatBubbleGrayimage [UIImage imageNamed:@"ChatViewGreyBar.png"]
#define kChatBubbleEmptyLocationView [UIImage imageNamed:@"internet_earth.png"]
#define kEmptyContactImage [UIImage imageNamed:@"defaultContact2.png"]


#define kSentMessageBullet [UIImage imageNamed:@"sentArrow.png"]
#define kReceivedMessageBullet [UIImage imageNamed:@"recivedArrow.png"]

#define kReadStatusImage [UIImage imageNamed:@"MessageReadImage.png"]

#define kBurnImageSent [UIImage imageNamed:@"BurnIconSent.png"]
#define kBurnImageReceived [UIImage imageNamed:@"BurnIconReceived.png"]

#define kLocatioImageSent [UIImage imageNamed:@"locationSent.png"]
#define kLocationImageReceived [UIImage imageNamed:@"locationReceived.png"]

#define kClockIcon [UIImage imageNamed:@"ClockIcon.png"]


#define kReceivedMessageTextSpacingFromLeft 8
#define kReceivedMessageSpacingFromLeft 10
#define kSentMessageSpacingFromRight 15
#define kMinCellHeight 40

#define kChatBubbleBottomIconHeight 15


#define kRedColor [UIColor colorWithRed:217/255.0f green:50/255.0f blue:50/255.0f alpha:1.0f]
#define kGrayColor  [UIColor colorWithRed:216/255.0f green:216/255.0f blue:216/255.0f alpha:1.0f]

#define kSentMessageBackgroundColor [UIColor colorWithRed:93/255.0f green:95/255.0f blue:102/255.0f alpha:1.0f]
#define kReceivedMessageBackgroundColor [UIColor colorWithRed:246/255.0f green:243/255.0f blue:235/255.0f alpha:1.0f]

#define kSentMessageFontColor [UIColor colorWithRed:237/255.0f green:233/255.0f blue:227/255.0f alpha:1.0f]
#define kReceivedMessageFontColor [UIColor colorWithRed:54/255.0f green:55/255.0f blue:59/255.0f alpha:1.0f]

#define kTextFieldBackgroundColor [UIColor colorWithRed:255/255.0f green:246/255.0f blue:236/255.0f alpha:1.0f]
#define kTextFontColor [UIColor colorWithRed:14/255.0f green:19/255.0f blue:35/255.0f alpha:1.0f]
#define kActionSheetBackgroundColor [UIColor colorWithRed:55/255.0f green:55/255.0f blue:55/255.0f alpha:1.0f]

#define kTimeStampTextcolor [UIColor whiteColor]

#define kCellTopOffset 9
#define kTimeStampLabelFontSize 9.0f

extern UIImage *image1;

#import <QuartzCore/QuartzCore.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "ChatViewController.h"
#import "BurnButton.h"
#import "ChatBubbleCell.h"
#import "ChatObject.h"
#import "ContactInfoViewController.h"
#import "DAKeyboardControl.h"
#import "DBManager.h"
#import "DBManager+MessageReceiving.h"
#import "AttachmentManager.h"
#import "ChatManager.h"
#import "AttachmentPreviewController.h"
#import "AudioPlaybackManager.h"
#import "FullScreenImageViewController.h"
#import "LocationButton.h"
#import "MapViewController.h"
#import "SP_FastContactFinder.h"
#import "UserContact.h"
#import "Utilities.h"
#import "NSNumber+Filesize.h"
#import "SendButton.h"
#import "NavigationBarTitleView.h"
#import "LocationManager.h"
#import "SilentContactsViewController.h"

#import "axolotl_glue.h"

@interface ChatViewController () <SilentContactsViewControllerDelegate>
{
    // chat actionSheet opened state
    // -1 closed
    // 1 open
    int savedAttachmentsDirection;
    
    // initialize chatTableView in viewdidLoad so it's frame can be changed afterwards
    UITableView *chatTableView;
    NSIndexPath *lastClickedIndexPath;
    
    NSString *lastOpenedUserNameForChat;
    CGPoint lastTableScrollViewScrollOffset;
    
    // 1 - down,  -1 up, 0 not scrolling
    int scrollDirection;
    
    
    // true if table reload should happen with tableviewcell animation in willdisplay cell
    // turns false when table gets reloaded without user scrolling the table
    BOOL shouldReloadTableWithAnimation;
    
    UILabel *backButtonAlertLabel;
    
    BurnButton *savedBurnNowButton;
    RecentObject *openedRecent;
    
    UILongPressGestureRecognizer *longPressRecognizer;
    UILongPressGestureRecognizer *navigationTitlelongPressRecognizer;
    
    UILongPressGestureRecognizer *navigationImageViewLongPressRecognizer;
	
//	NSDictionary *_pendingPickerInfo;
	
    BOOL dismissedWithMessageClick;
    
    ChatObject *chatObjectInMenuController;
    
    BOOL dismissedViewWithAttachment;
    
    BOOL dismissedViewWithDevicesView;
    
    UserContact *_pendingContactAttachment;
}
@end


@implementation ChatViewController



// save chat history whenever window dissapears
-(void)viewWillDisappear:(BOOL)animated
{
    if(messageTextView.text.length > 0)
    {
        [[Utilities utilitiesInstance] setSavedMessageText:messageTextView.text forContactName:[[Utilities utilitiesInstance] addPeerInfo:lastOpenedUserNameForChat lowerCase:NO]];
    }
    // if there are no chatmessages, remove this recent
    if(chatHistory.count <= 0){
        [[DBManager dBManagerInstance] removeChatWithContact:[Utilities utilitiesInstance].selectedRecentObject];
        [[Utilities utilitiesInstance] removeBadgesForConversation:[Utilities utilitiesInstance].selectedRecentObject];
        [[Utilities utilitiesInstance].recents removeObjectForKey:lastOpenedUserNameForChat];
        //[Utilities utilitiesInstance].selectedRecentObject = nil;
        
    }
    [messageTextView resignFirstResponder];
    [navigationTitlelongPressRecognizer removeTarget:self action:@selector(navigationTitlePressAction:)];
    [self.view removeKeyboardControl];
	
// EA: FIXME: we cannot remove the progress observers because progress may continue if the user taps to preview an attachment
	
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    /*
    if(dismissedWithMessageClick)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:@"receiveMessage"];
        [[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:AttachmentManagerReceiveAttachmentNotification];
        [[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:@"removeMessage"];
        [[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:@"receiveMessageState"];
    }*/
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadVisibleRowBurnTimers) object:nil];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[LocationManager locationManagerInstance].locationManager stopUpdatingLocation];
        [[LocationManager locationManagerInstance].locationManager stopMonitoringSignificantLocationChanges];
    });
    
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    

    
    [[Utilities utilitiesInstance] setTimeStampHeight];

    dismissedViewWithDevicesView = NO;
    [[Utilities utilitiesInstance] setTabBarHidden:YES];
    dismissedWithMessageClick = NO;
    scrollDirection = 0;
    shouldReloadTableWithAnimation = false;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receiveMessage:)
                                                 name:@"receiveMessage" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(receiveAttachment:)
												 name:AttachmentManagerReceiveAttachmentNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(removeMessage:)
                                                 name:@"removeMessage" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receiveMessageState:)
                                                 name:@"receiveMessageState" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(onChatObjectCreated:)
												 name:ChatObjectCreatedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(onChatObjectUpdated:)
												 name:ChatObjectUpdatedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(attachmentProgressNotification:)
												 name:AttachmentManagerEncryptProgressNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(attachmentProgressNotification:)
												 name:AttachmentManagerUploadProgressNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(attachmentProgressNotification:)
												 name:AttachmentManagerVerifyProgressNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(audioFinishedNotification:)
												 name:AudioPlayerDidFinishPlayingAttachmentNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audioPausedNotification:)
                                                 name:AudioPlayerDidPausePlayingAttachmentNotification object:nil];
	
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.backgroundColor = [Utilities utilitiesInstance].kNavigationBarColor;
    self.navigationController.navigationBar.translucent = NO;
    
    // add custum image for back button
    UIButton *backButtonWithImage = [UIButton buttonWithType:UIButtonTypeCustom];
    [backButtonWithImage setFrame:CGRectMake(0,0,kBackButtonSize,kBackButtonSize)];
    backButtonWithImage.userInteractionEnabled = YES;
    [backButtonWithImage setImage:[UIImage imageNamed:@"BackButton.png"] forState:UIControlStateNormal];
    backButtonWithImage.accessibilityLabel = @"Back";
    [backButtonWithImage addTarget:self.navigationController action:@selector(popViewControllerAnimated:) forControlEvents:UIControlEventTouchUpInside];
	
    // GO - Use only selectedRecentObject
    lastOpenedUserNameForChat = [Utilities utilitiesInstance].selectedRecentObject.contactName;
    
    // if location sending for this contact is on start updating location here
    if([Utilities utilitiesInstance].selectedRecentObject.shareLocationTime > time(NULL))
    {
        [[LocationManager locationManagerInstance].locationManager startUpdatingLocation];
    }
    /*
	if (!lastOpenedUserNameForChat)
		lastOpenedUserNameForChat = [Utilities utilitiesInstance].selectedRecentObject ? [Utilities utilitiesInstance].selectedRecentObject.contactName : [Utilities utilitiesInstance].lastOpenedUserNameForChat;
	if (!lastOpenedUserNameForChat) {
		NSLog(@"Error! lastOpenedUserNameForChat is nil!!!");		
	}
	*/
    int receivedOtherMessageCount = [[Utilities utilitiesInstance] getBadgeValueWithoutUser:lastOpenedUserNameForChat];
    backButtonAlertLabel = [[UILabel alloc] init];
    [backButtonAlertLabel setBackgroundColor:[Utilities utilitiesInstance].kAlertPointBackgroundColor];
    [backButtonAlertLabel setFont:[[Utilities utilitiesInstance] getFontWithSize:12]];
    [backButtonAlertLabel setTextColor:[UIColor whiteColor]];
    backButtonAlertLabel.text = [NSString stringWithFormat:@"%i",receivedOtherMessageCount];
    [backButtonAlertLabel sizeToFit];
    [backButtonAlertLabel setTextAlignment:NSTextAlignmentCenter];
    [backButtonAlertLabel setFrame:CGRectMake(backButtonWithImage.frame.size.width - backButtonAlertLabel.frame.size.width - 6, -6, backButtonAlertLabel.frame.size.width + 10, backButtonAlertLabel.frame.size.height)];
    backButtonAlertLabel.layer.cornerRadius = backButtonAlertLabel.frame.size.width/2;
    backButtonAlertLabel.layer.masksToBounds = YES;
    [backButtonWithImage addSubview:backButtonAlertLabel];
    
    if(receivedOtherMessageCount <= 0)
    {
        [backButtonAlertLabel setHidden:YES];
    }
    
    NSString *displayName = [[Utilities utilitiesInstance] removePeerInfo:[Utilities utilitiesInstance].selectedRecentObject.displayName lowerCase:NO];

    int idx;
    NSString *ns = [SP_FastContactFinder findPerson:lastOpenedUserNameForChat idx:&idx];
    dstImage = kEmptyContactImage;
    if(idx>=0)
    {
        dstImage = [SP_FastContactFinder getPersonImage:idx];
    }
    
    if(!dstImage)
    {
        dstImage = kEmptyContactImage;
    }
    
    navigationImageViewLongPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(navigationTitlePressAction:)];
    navigationImageViewLongPressRecognizer.minimumPressDuration = 0.25;
    
    UIView *titleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kBackButtonSize, kBackButtonSize)];
    UIImageView *titleImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, kBackButtonSize, kBackButtonSize)];
    [titleImageView setContentMode:UIViewContentModeScaleAspectFit];
    [titleImageView setImage:dstImage];
    [titleView addSubview:titleImageView];
    
    UIImageView *emptyCircleImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, kBackButtonSize, kBackButtonSize)];
    [emptyCircleImageView setContentMode:UIViewContentModeScaleAspectFit];
    [emptyCircleImageView setImage:[UIImage imageNamed:@"EmptyCircle.png"]];
    [titleView addSubview:emptyCircleImageView];
    
    UILabel *textlabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, kBackButtonSize, kBackButtonSize)];
    textlabel.text = ns.length < 1 ? displayName  : ns;
    [textlabel setTextColor:[UIColor clearColor]];
    [titleView addSubview:textlabel];
    [titleView addGestureRecognizer:navigationImageViewLongPressRecognizer];
    
    navigationTitlelongPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(navigationTitlePressAction:)];
    navigationTitlelongPressRecognizer.minimumPressDuration = 0.25;

    UILabel *usernameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, [Utilities utilitiesInstance].screenWidth / 2., kBackButtonSize)];
    [usernameLabel setText:(ns.length < 1 ? displayName  : ns)];
    [usernameLabel setTextColor:[UIColor whiteColor]];
    [usernameLabel setFont:[[Utilities utilitiesInstance] getFontWithSize:16]];
    [usernameLabel setTextAlignment:NSTextAlignmentLeft];
    [usernameLabel setUserInteractionEnabled:YES];
    [usernameLabel addGestureRecognizer:navigationTitlelongPressRecognizer];
    
    UIBarButtonItem *backBarButton      = [[UIBarButtonItem alloc] initWithCustomView:backButtonWithImage];
    UIBarButtonItem *userAvatarButton   = [[UIBarButtonItem alloc] initWithCustomView:titleView];
    UIBarButtonItem *usernameButton     = [[UIBarButtonItem alloc] initWithCustomView:usernameLabel];
    
    self.navigationItem.leftBarButtonItems = @[backBarButton, userAvatarButton, usernameButton];
    
    // add custum image for rightbarbuttonItem
    UIButton *rightButtonWithImage = [UIButton buttonWithType:UIButtonTypeCustom];
    [rightButtonWithImage setFrame:CGRectMake(0,0,kBackButtonSize,kBackButtonSize)];
    [rightButtonWithImage setUserInteractionEnabled:YES];
    [rightButtonWithImage setImage:[UIImage imageNamed:@"CallButton.png"] forState:UIControlStateNormal];
    
    [rightButtonWithImage addTarget:self action:@selector(callUser) forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *rightBarButton = [[UIBarButtonItem alloc] initWithCustomView:rightButtonWithImage];
    self.navigationItem.rightBarButtonItem = rightBarButton;
    
    // if we come from Recents tab, create new temporary recent, but dont add it to array of conversations
    if(![Utilities utilitiesInstance].selectedRecentObject)
    {
        openedRecent = [[RecentObject alloc] init];
        [[Utilities utilitiesInstance].recents setValue:openedRecent forKey:lastOpenedUserNameForChat];
        openedRecent.contactName = lastOpenedUserNameForChat;
        openedRecent.hasBurnBeenSet = 0;
        openedRecent.burnDelayDuration = [Utilities utilitiesInstance].kDefaultBurnTime;
        openedRecent.displayName = [Utilities utilitiesInstance].selectedRecentObject.displayName;
    } else
    {
        openedRecent = [Utilities utilitiesInstance].selectedRecentObject;
    }
    
    [self.navigationController.navigationBar setTitleTextAttributes:
     @{NSForegroundColorAttributeName: [UIColor colorWithRed:226/255.0f green:226/255.0f blue:226/255.0f alpha:1.0f],
       NSFontAttributeName:[[Utilities utilitiesInstance] getFontWithSize:16]}];
    
    // get chat history, or init new whenever window appears
    chatHistory = [[Utilities utilitiesInstance].chatHistory objectForKey:lastOpenedUserNameForChat];
    if(!chatHistory)
    {
        chatHistory = [[NSMutableArray alloc] init];
        [[Utilities utilitiesInstance].chatHistory setValue:chatHistory forKey:lastOpenedUserNameForChat];
    }

    [Utilities utilitiesInstance].selectedRecentObject = openedRecent;
    
    [actionSheetView updateButtonImages];
    [chatTableView reloadData];
    
    if(!dismissedViewWithAttachment)
    {
        [self reloadTableAndScrollToBottom:YES animated:NO];
    } else
    {
        // if view appears after closing attachment, restart burn timers
        [self reloadVisibleRowBurnTimers];
    }
    dismissedViewWithAttachment = NO;
    //[self performSelector:@selector(reloadRows) withObject:nil afterDelay:.01f];
    
    // add observers if view is already loaded
    if(actionSheetView !=nil)
    {
        [self addKeyboardPanning];
    }

	if ([[AudioPlaybackManager sharedManager] isPlaying]) {
		[[AudioPlaybackManager sharedManager] showPlayerInView:audioPlaybackHolderView];
		NSString *messageID = [AudioPlaybackManager sharedManager].chatObject.msgId;
		if ([self findChatObjectWithMessageID:messageID] != nil) {
			// it's one of our messages playing
			[self animateAudioPlayerViewWithDirection:[NSNumber numberWithInt:1]];
		}
	}
    
    [self.navigationController.navigationBar setShadowImage:[UIImage new]];
    
    [self checkForForwardedMessage];
    
    if(_pendingContactAttachment) {
        
        [[ChatManager sharedManager] sendMessageWithContact:_pendingContactAttachment];
        _pendingContactAttachment = nil;
    }
}
-(void)viewDidAppear:(BOOL)animated
{
     [super viewDidAppear:animated];
    // if conversation with this contact is opened for the first time,  bring up keyboard automatically
    if(![[DBManager dBManagerInstance] existsConversation:[[Utilities utilitiesInstance] addPeerInfo:lastOpenedUserNameForChat lowerCase:YES]])
    {
        if (messageTextView && chatHistory.count <= 0) {
            [messageTextView becomeFirstResponder];
        }
    }

    int idx;
    NSString *ns = [SP_FastContactFinder findPerson:lastOpenedUserNameForChat idx:&idx];

    NSString *displayName = [[Utilities utilitiesInstance] removePeerInfo:[Utilities utilitiesInstance].selectedRecentObject.displayName lowerCase:NO];
    
    // if both doesnt exist, take lastopenedusername which always exists
    if(!displayName && !ns)
    {
        displayName = [[Utilities utilitiesInstance] removePeerInfo:[Utilities utilitiesInstance].selectedRecentObject.contactName lowerCase:NO];
    }
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
     //[self checkForForwardedMessage];

    if(chatTableView)
    {
        [chatTableView reloadData];
    }
}

-(void) callUser
{
    [messageTextView resignFirstResponder];
    void callToApp(const char *);
    callToApp(lastOpenedUserNameForChat.UTF8String);
    //void endCallToApp(const char *dst);
    //endCallToApp(lastOpenedUserNameForChat.UTF8String);
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    savedAttachmentsDirection = -1;
    
    float viewHeight = CGRectGetHeight(self.view.frame) - [Utilities utilitiesInstance].kStatusBarHeight - CGRectGetHeight(self.navigationController.navigationBar.frame);

    // yoffset is the height of title label in navigationbarTitleView
    chatTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, [Utilities utilitiesInstance].screenWidth, viewHeight - kActionSheetHeight)];
    chatTableView.delegate = self;
    chatTableView.dataSource = self;
    chatTableView.layer.shouldRasterize = YES;
    chatTableView.layer.rasterizationScale = [[UIScreen mainScreen] scale];
    [chatTableView setBackgroundColor:[UIColor clearColor]];
    [self.view addSubview:chatTableView];
    
    longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPressRecognizer.minimumPressDuration = 0.25;
    [chatTableView addGestureRecognizer:longPressRecognizer];

    
    [chatTableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    // transparent black background view for status bar
    //UIView *darkTopView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [Utilities utilitiesInstance].screenWidth, [Utilities utilitiesInstance].kStatusBarHeight)];
    //[darkTopView setBackgroundColor:[Utilities utilitiesInstance].kStatusBarColor];
    //[self.view addSubview:darkTopView];
    
    //background container for message insertion and send button
    containerView = [[UIView alloc] initWithFrame:CGRectMake(0, viewHeight - kActionSheetHeight, [Utilities utilitiesInstance].screenWidth, kActionSheetHeight)];
    [containerView setBackgroundColor:kActionSheetBackgroundColor];
    
    // chat message action sheet
    actionSheetView = [[ActionSheetView alloc] initWithFrame:CGRectMake(0, viewHeight - kActionSheetHeight, [Utilities utilitiesInstance].screenWidth, kActionSheetHeight) forViewController:self];
    actionSheetView.delegate = self;
    [actionSheetView setHidden:YES];
    [self.view addSubview:actionSheetView];
 
	audioPlaybackHolderView = [[UIView alloc] initWithFrame:CGRectMake(0, viewHeight - kAudioPlayerFrameHeight, [Utilities utilitiesInstance].screenWidth, kAudioPlayerFrameHeight)];
	audioPlaybackHolderView.hidden = YES;
	[self.view insertSubview:audioPlaybackHolderView belowSubview:actionSheetView];
	
    // HPGrowingTextView for message text
    messageTextView = [[HPGrowingTextView alloc] initWithFrame:CGRectMake(kActionSheetHeight, 8, [Utilities utilitiesInstance].screenWidth - 90, kActionSheetHeight)];
    messageTextView.isScrollable = NO;
    [messageTextView setNeedsDisplay];
    messageTextView.contentInset = UIEdgeInsetsMake(0, 5, 0, 5);
    messageTextView.minNumberOfLines = 1;
    messageTextView.maxNumberOfLines = 6;
    messageTextView.returnKeyType = UIReturnKeyDefault;
    messageTextView.font = [UIFont systemFontOfSize:15.0f];
    messageTextView.delegate = self;
	messageTextView.internalTextView.autocorrectionType = UITextAutocorrectionTypeYes;//No;
    messageTextView.internalTextView.scrollIndicatorInsets = UIEdgeInsetsMake(5, 0, 5, 0);
    messageTextView.backgroundColor = kTextFieldBackgroundColor;
    messageTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    messageTextView.layer.cornerRadius = 1;
    messageTextView.clipsToBounds = YES;
    messageTextView.delegate = self;
    messageTextView.internalTextView.keyboardAppearance = UIKeyboardAppearanceDark;
    messageTextView.internalTextView.font = [[Utilities utilitiesInstance] getFontWithSize: messageTextView.internalTextView.font.pointSize];
    messageTextView.internalTextView.accessibilityLabel = @"Message text field";

    [containerView addSubview:messageTextView];
    // Send button and entry background images
    UIImage *rawEntryBackground = [UIImage imageNamed:@"MessageEntryInputField.png"];
    UIImage *entryBackground = [rawEntryBackground stretchableImageWithLeftCapWidth:13 topCapHeight:22];
    UIImageView *entryImageView = [[UIImageView alloc] initWithImage:entryBackground];
    entryImageView.frame = CGRectMake(5, 0, 248, 80);
    entryImageView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    UIImage *rawBackground = [UIImage imageNamed:@"MessageEntryBackground.png"];
    UIImage *background = [rawBackground stretchableImageWithLeftCapWidth:13 topCapHeight:22];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:background];
    imageView.frame = CGRectMake(0, 0, containerView.frame.size.width, containerView.frame.size.height);
    imageView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
    // SendButton
    // shuld reposition frame to fit for ipad
    SendButton *doneBtn = [SendButton buttonWithType:UIButtonTypeCustom];
    doneBtn.accessibilityLabel = @"Send";
    //[doneBtn setBackgroundImage:[UIImage imageNamed:@"chatSendIcon.png"] forState:0];
    
    
    doneBtn.frame = CGRectMake(containerView.frame.size.width - 45, 3, 45, kActionSheetHeight - 6);
    
    //[doneBtn setTitleShadowColor:[UIColor colorWithWhite:0 alpha:0.4] forState:UIControlStateNormal];
    //doneBtn.titleLabel.shadowOffset = CGSizeMake (0.0, -1.0);
    doneBtn.titleLabel.font = [[Utilities utilitiesInstance] getFontWithSize: 18];
    [doneBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [doneBtn addTarget:self action:@selector(sendMessage:) forControlEvents:UIControlEventTouchUpInside];
    //[doneBtn setBackgroundColor:kRedColor];
    doneBtn.layer.cornerRadius = 1;
    doneBtn.layer.masksToBounds = YES;
    [containerView addSubview:doneBtn];
    
    //actionSheet Button
    UIButton *attachmentsButton = [[UIButton alloc] initWithFrame:CGRectMake(3, 0, kActionSheetHeight, kActionSheetHeight)];
     attachmentsButton.accessibilityLabel = @"Chat options";
    //attachmentsButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
    
    [attachmentsButton setImage:[UIImage imageNamed:@"chatFunctions.png"] forState:UIControlStateNormal];
    [attachmentsButton setContentEdgeInsets:UIEdgeInsetsMake(15, 10, 15, 10)];
    [attachmentsButton addTarget:self action:@selector(attachmentsButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [containerView addSubview:attachmentsButton];
    [self.view addSubview:containerView];
    
    [self addKeyboardPanning];
}

-(void) checkForForwardedMessage
{
    ChatObject *forwardedChatObject = [[Utilities utilitiesInstance].forwardedMessageData objectForKey:@"forwardedChatObject"];
    if(forwardedChatObject)
    {
        if(forwardedChatObject.attachment)
        {
            [[ChatManager sharedManager] sendMessageWithAttachment:forwardedChatObject.attachment upload:NO];
        } else if(forwardedChatObject.messageText.length  > 0)
        {
            messageTextView.text = forwardedChatObject.messageText;
            messageTextView.placeholder = nil;
        }
        
        NSMutableArray *viewControllerStack = [[NSMutableArray alloc] initWithArray:
                                               self.navigationController.viewControllers];
        [viewControllerStack removeObjectAtIndex:[viewControllerStack count] - 3];
        [viewControllerStack removeObjectAtIndex:[viewControllerStack count] - 2];
        self.navigationController.viewControllers = viewControllerStack;
    } else
    {
        NSString *savedMessageText = [[Utilities utilitiesInstance].savedMessageTexts objectForKey:[[Utilities utilitiesInstance] addPeerInfo:lastOpenedUserNameForChat lowerCase:NO]];
        if(savedMessageText)
        {
            messageTextView.placeholder = nil;
            messageTextView.text = savedMessageText;
            [[Utilities utilitiesInstance] removeSavedMessageTextForContactName:[[Utilities utilitiesInstance] addPeerInfo:lastOpenedUserNameForChat lowerCase:NO]];
        } else
        {
            messageTextView.placeholder = @"Say something...";
            messageTextView.text = @"";
        }
    }
    
    [[Utilities utilitiesInstance].forwardedMessageData removeObjectForKey:@"forwardedChatObject"];
}


-(void) addKeyboardPanning
{
    //DaKeyBoardControl block
    self.view.keyboardTriggerOffset = 40;
    [self.view addKeyboardPanningWithFrameBasedActionHandler:^(CGRect keyboardFrameInView, BOOL opening, BOOL closing) {
        /*
         Try not to call "self" inside this block (retain cycle).
         But if you do, make sure to remove DAKeyboardControl
         when you are done with the view controller by calling:
         [self.view removeKeyboardControl];
         */
        
        // possible retain cycle
        // adjust frames of containerView table and actionSheet
        CGRect toolBarFrame = containerView.frame;
        toolBarFrame.origin.y = keyboardFrameInView.origin.y - toolBarFrame.size.height;
        containerView.frame = toolBarFrame;
        
        CGRect tableViewFrame = chatTableView.frame;
        
        // titleview height
        tableViewFrame.size.height = toolBarFrame.origin.y;// - 24;
        chatTableView.frame = tableViewFrame;
        
        CGRect actionSheetViewFrame = containerView.frame;
        actionSheetViewFrame.size.height = toolBarFrame.origin.y;
        //if actionsheet is open
        if(savedAttachmentsDirection == 1)
        {
            actionSheetViewFrame.origin.y -= kActionSheetHeight;
        }
        actionSheetView.frame = actionSheetViewFrame;
		
		CGRect audioPlayerFrame = containerView.frame;
		audioPlayerFrame.size.height = kAudioPlayerFrameHeight;
		//if (!audioPlaybackHolderView.hidden) {
        audioPlayerFrame.origin.y = containerView.frame.origin.y - kAudioPlayerFrameHeight;//actionSheetViewFrame.origin.y - audioPlayerFrame.size.height;
        audioPlaybackHolderView.frame = audioPlayerFrame;
		//}
        
    } constraintBasedActionHandler:nil];
}

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
    
    // get a rect for the textView frame
    CGRect containerFrame = containerView.frame;
    containerFrame.origin.y = self.view.bounds.size.height - (keyboardBounds.size.height + containerFrame.size.height);
    
    CGRect attachmentsFrame = actionSheetView.frame;
    float actionSheetOffsetFromContainerView = 0;
    
    //if actionsheet is open
    if(savedAttachmentsDirection == 1)
    {
        actionSheetOffsetFromContainerView = kActionSheetHeight;
    }
    
    attachmentsFrame.origin.y = self.view.bounds.size.height - (keyboardBounds.size.height + containerFrame.size.height) - actionSheetOffsetFromContainerView;
	
	CGRect audioPlayerFrame = audioPlaybackHolderView.frame;
    
    if (!actionSheetView.hidden)
        audioPlayerFrame.origin.y = attachmentsFrame.origin.y + attachmentsFrame.size.height + audioPlayerFrame.size.height;
    else
        audioPlayerFrame.origin.y = attachmentsFrame.origin.y +audioPlayerFrame.size.height;
	
    // animations settings
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDuration:[duration doubleValue]];
    [UIView setAnimationCurve:[curve intValue]];
    
    // set views with new info
    containerView.frame = containerFrame;
    actionSheetView.frame = attachmentsFrame;
	//audioPlaybackHolderView.frame = audioPlayerFrame;
    // chatTableView.frame = chatTableViewOffsetFrame;
    
    
    // commit animations
    [UIView commitAnimations];
    [self scrollToBottom:YES forced:YES];
}

-(void) keyboardWillHide:(NSNotification *)note{
    NSNumber *duration = [note.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSNumber *curve = [note.userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey];
    
    // get a rect for the textView frame
    CGRect containerFrame = containerView.frame;
    containerFrame.origin.y = self.view.bounds.size.height - containerFrame.size.height;
    
    CGRect attachmentsFrame = actionSheetView.frame;
    float actionSheetOffsetFromContainerView = 0;
    if(savedAttachmentsDirection == 1) //if actionsheet is open
    {
        actionSheetOffsetFromContainerView = kActionSheetHeight;
    }
    attachmentsFrame.origin.y = self.view.bounds.size.height - containerFrame.size.height - actionSheetOffsetFromContainerView;
	
	CGRect audioPlayerFrame = audioPlaybackHolderView.frame;
	//if (!audioPlaybackHolderView.hidden)
		audioPlayerFrame.origin.y = attachmentsFrame.origin.y - audioPlayerFrame.size.height;
	
    // animations settings
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDuration:[duration doubleValue]];
    [UIView setAnimationCurve:[curve intValue]];
    
    // set views with new info
    containerView.frame = containerFrame;
    actionSheetView.frame = attachmentsFrame;
	audioPlaybackHolderView.frame = audioPlayerFrame;
    //chatTableView.frame = chatTableViewOffsetFrame;
    
    
    // commit animations
    [UIView commitAnimations];
    //[self scrollToBottom:NO];
}

#pragma mark HPGrowingTextViewDelegate
- (void)growingTextView:(HPGrowingTextView *)growingTextView willChangeHeight:(float)height
{
    // change frames of actionSheet, containerView and chatTable
    // according to textview changed height
    float diff = (growingTextView.frame.size.height - height);
    
    CGRect r = containerView.frame;
    r.size.height -= diff;
    r.origin.y += diff;
    containerView.frame = r;
    
    CGRect a = actionSheetView.frame;
    a.size.height -= diff;
    a.origin.y += diff;
    actionSheetView.frame = a;
	
	a = audioPlaybackHolderView.frame;
	a.size.height -= diff;
	a.origin.y += diff;
	audioPlaybackHolderView.frame = a;
	
    CGRect t = chatTableView.frame;
    t.size.height += diff;
    chatTableView.frame = t;
    [self scrollToBottom:YES forced:YES];
}

// replace 2 rowbreaks with 1
-(BOOL)growingTextView:(HPGrowingTextView *)growingTextView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
   // NSString *resultStr = [growingTextView.text stringByReplacingOccurrencesOfString:@"\n\n" withString:@"\n"];
   // growingTextView.text = resultStr;
    return YES;
}

#pragma mark UITableViewDelegate
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    ChatObject *chatObjectToRemove = (ChatObject*) [chatHistory objectAtIndex:indexPath.row];
    [[DBManager dBManagerInstance] sendForceBurn:chatObjectToRemove];//TODO wait for burn notification
    [self deleteRowAtIndexPath:indexPath];
    
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    [savedBurnNowButton removeFromSuperview];
}

-(void) deleteRowAtIndexPath:(NSIndexPath*) indexPath
{
    //--TODO could be moved to dbmanager deleteEvent
    // remove ChatObject from local chatHisory
    
   // dispatch_async(dispatch_get_main_queue(), ^{
    if(!(chatHistory.count>indexPath.row))
    {
        NSLog(@"indexpath %li   %lu",(long)indexPath.row,(unsigned long)chatHistory.count);
        return;
    }
        ChatObject *chatObjectToRemove = (ChatObject*) [chatHistory objectAtIndex:indexPath.row];
        if(![chatHistory containsObject:chatObjectToRemove])return;
        
        [chatHistory removeObjectIdenticalTo:chatObjectToRemove];
        
        // remove message from database
        [[DBManager dBManagerInstance] removeChatMessage:chatObjectToRemove];
        
        [chatTableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        shouldReloadTableWithAnimation = NO;
   // });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3f * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [chatTableView reloadData];
    });
    
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return [Utilities utilitiesInstance].kStatusBarHeight;// + self.navigationController.navigationBar.frame.size.height;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(!chatHistory)
    {
        return 0;
    }
    return chatHistory.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.row > chatHistory.count - 1)
        return 0;
    ChatObject *thisChatObject = (ChatObject*)chatHistory[indexPath.row];
    CGFloat height = [thisChatObject.contentRectValue CGSizeValue].height + [Utilities utilitiesInstance].timeStampHeight + kChatRowVerticalSpacing;// + kChatRowVerticalSpacing;
	return height;
}

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *emptyHeaderView = [[UIView alloc] init];
    [emptyHeaderView setBackgroundColor:[UIColor clearColor]];
    return emptyHeaderView;
}


-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	lastClickedIndexPath = indexPath;
	
	ChatObject *thisChatObject = (ChatObject*)chatHistory[indexPath.row];
	BOOL bIsAudio = NO;
	if (thisChatObject.attachment) {
		NSString *mediaType = [thisChatObject.attachment.metadata objectForKey:kSCloudMetaData_MediaType];
		bIsAudio = ([(__bridge NSString *)kUTTypeAudio isEqualToString:mediaType]);
	}
	
	if (thisChatObject.isFailed) {
		UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Message Options" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:nil];
		[actionSheet addButtonWithTitle:@"Try Again"];
		if ( (thisChatObject.attachment)
					&& ([thisChatObject.attachment.cloudKey length] > 0)
					&& ([thisChatObject.attachment.cloudLocator length] > 0) ) {
			[actionSheet addButtonWithTitle:(bIsAudio) ? @"Play Audio" : @"View"];
		}
		[actionSheet showInView:self.view];
		return;
	}
	
    // to detect if willdissapear gets called from click on message
    dismissedWithMessageClick = YES;
	
	if (thisChatObject.attachment)
		[self _presentAttachment:thisChatObject];
	
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
}

#pragma mark - UIActionSheetDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if (buttonIndex == actionSheet.cancelButtonIndex) {
		// don't follow through sending the message
		return;
	}
	
	if (lastClickedIndexPath) {
		ChatObject *thisChatObject = (ChatObject *)chatHistory[lastClickedIndexPath.row];
		switch (buttonIndex) {
			case 1: // resend
				thisChatObject.iSendingNow = 1;
				thisChatObject.messageStatus = 0;
				if (thisChatObject.attachment)
					[[ChatManager sharedManager] uploadAttachmentForChatObject:thisChatObject];
				else
					[[ChatManager sharedManager] sendChatObjectAsync:thisChatObject];
				[chatTableView reloadRowsAtIndexPaths:@[lastClickedIndexPath] withRowAnimation:UITableViewRowAnimationNone];
				break;
			case 2: // view or play attachment
				if (thisChatObject.attachment)
					[self _presentAttachment:thisChatObject];
				break;
			default:
				break;
		}
	}
}

-(void) scrollViewDidScroll:(UIScrollView *)scrollView
{
    [savedBurnNowButton removeFromSuperview];
    [self willHideMenuController:nil];
    shouldReloadTableWithAnimation = YES;
    CGPoint currentOffset = scrollView.contentOffset;
    
    //down
    if (currentOffset.y > lastTableScrollViewScrollOffset.y)
    {
        scrollDirection = -1;
    }else
    {
        scrollDirection = 1;
    }
    lastTableScrollViewScrollOffset = currentOffset;
}

/**
 * animate row displaying
 * push each cell 50 points down or up depending on scroll direction
 **/
-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath{
    
    if(indexPath.row > chatHistory.count - 1)
        return;
     ChatObject *thisChatObject = (ChatObject*) chatHistory[indexPath.row];
    ChatBubbleCell *chatBubbleCell = (ChatBubbleCell *) cell;
    chatBubbleCell.thisChatObject = thisChatObject;
    [chatBubbleCell.burnImageButton addTarget:self action:@selector(burnButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    chatBubbleCell.burnImageButton.indexPathForCell = indexPath;
    
    chatBubbleCell.messageTextLabel.thisChatObject = thisChatObject;
    CGSize thisRowSize = [thisChatObject.contentRectValue CGSizeValue];
    [chatBubbleCell.containerView setFrame:CGRectMake(0, 0, [Utilities utilitiesInstance].screenWidth, thisRowSize.height)];
    [chatBubbleCell.messageTextLabel sizeThatFits:thisRowSize];
    int locationCompensation = 0;
    if(!thisChatObject.location)
    {
        [chatBubbleCell.locationButton setHidden:YES];
    } else
    {
        locationCompensation = 30;
        [chatBubbleCell.locationButton setHidden:NO];
        [chatBubbleCell.locationButton setImage:[UIImage imageNamed:@"LocationOnWithCircle.png"] forState:UIControlStateNormal];
        chatBubbleCell.locationButton.thisChatObject = thisChatObject;
    }
    
    if(thisChatObject.isReceived != 1){
        // if status is delevered, read or sent, set iSendingNow to 0, meaning we are not sending this message anymore
        // FIX for cases where status gets set to 200 and iSendingNow gets set to 1 afterwards
        switch (thisChatObject.messageStatus) {
            case 200:
            {
                thisChatObject.iSendingNow = 0;
                [chatBubbleCell.timeStampLabel setTextColor:kTimeStampTextcolor];
                if(thisChatObject.isRead)
                {
                    chatBubbleCell.timeStampLabel.text = [NSString stringWithFormat:@"Read, %@",[[Utilities utilitiesInstance] takeTimeFromDateStamp:(int)thisChatObject.unixTimeStamp] ];
                } else
                {
                    thisChatObject.iSendingNow = 0;
                    chatBubbleCell.timeStampLabel.text = [NSString stringWithFormat:@"Delivered, %@",[[Utilities utilitiesInstance] takeTimeFromDateStamp:(int)thisChatObject.unixTimeStamp] ];
                }
            }
                break;
            case 202:
            {
                thisChatObject.iSendingNow = 0;
                [chatBubbleCell.progressView setHidden:YES];
                [chatBubbleCell.timeStampLabel setTextColor:kTimeStampTextcolor];
                chatBubbleCell.timeStampLabel.text = @"Sent";
            }
                break; 
            default:
            {
                if(thisChatObject.isSynced)
                {
                    [chatBubbleCell.timeStampLabel setTextColor:kTimeStampTextcolor];
                    chatBubbleCell.timeStampLabel.text = @"Synced";
                    break;
                }
                if(thisChatObject.iSendingNow == 1){
                    [chatBubbleCell.timeStampLabel setTextColor:kTimeStampTextcolor];
                    chatBubbleCell.timeStampLabel.text = @"Preparing...";
                }
                else if(thisChatObject.isFailed){
                    [chatBubbleCell.timeStampLabel setTextColor:[UIColor redColor]];
                    chatBubbleCell.timeStampLabel.text = @"Failed";
                }
                else if(thisChatObject.messageIdentifier != 0 && thisChatObject.messageStatus != 200)
                {
                    [chatBubbleCell.timeStampLabel setTextColor:kTimeStampTextcolor];
                    chatBubbleCell.timeStampLabel.text = @"Sending";
                }
                else if(thisChatObject.messageStatus>=0 && (thisChatObject.messageIdentifier==0 && (thisChatObject.iSendingNow == 1 || thisChatObject.iSendingNow == 0))){//do not show prep if thisChatObject.messageIdentifier
                    [chatBubbleCell.timeStampLabel setTextColor:kTimeStampTextcolor];
                    chatBubbleCell.timeStampLabel.text = @"Preparing...";
                    
                }else
                {
                    [chatBubbleCell.timeStampLabel setTextColor:[UIColor redColor]];
                    chatBubbleCell.timeStampLabel.text = @"Failed";
                }
            }
                break;
        }
    }
    else
    {
        [chatBubbleCell.timeStampLabel setTextColor:kTimeStampTextcolor];
        chatBubbleCell.timeStampLabel.text = [[Utilities utilitiesInstance] takeTimeFromDateStamp:(int)thisChatObject.unixTimeStamp];
    }
    int burnCompensation  = 0;
    if(thisChatObject.burnTime > 0)
    {
        burnCompensation = 30;
        NSString *burnTime = [[Utilities utilitiesInstance] getBurnNoticeRemainingTime:thisChatObject];
        chatBubbleCell.burnTimeLabel.text = burnTime;
        [chatBubbleCell.burnTimeLabel sizeToFit];
        [chatBubbleCell.burnImageButton setHidden:NO];
        
        
    } else
    {
        [chatBubbleCell.burnImageButton setHidden:YES];
        chatBubbleCell.burnTimeLabel.text = @"";
        //[chatBubbleCell.burnTimeLabel sizeToFit];
    }
    /*
    CGRect timeStampTextRect = [chatBubbleCell.timeStampLabel.text boundingRectWithSize:CGSizeMake([Utilities utilitiesInstance].screenWidth, 9999)
                                                                      options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading)
                                                                   attributes:@{NSFontAttributeName:[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]}
                                                                      context:nil
                                ];
    CGSize timeStampTextSize = CGSizeMake(ceil(timeStampTextRect.size.width), ceil(timeStampTextRect.size.height));*/

    
    if(thisChatObject.isReceived == 1)
    {
        chatBubbleCell.tag = -1;
        //[chatBubbleCell.messageContactImageView setHidden:NO];
        //CGRect avatarR = chatBubbleCell.messageContactImageView.frame;
       // avatarR.origin.y = thisRowSize.height/2 - avatarR.size.height/2;
        //[chatBubbleCell.messageContactImageView setFrame:avatarR];
        
        [chatBubbleCell.messageTextLabel.layer setBackgroundColor:kReceivedMessageBackgroundColor.CGColor];
        [chatBubbleCell.messageTextLabel setFrame:CGRectMake(kReceivedMessageTextSpacingFromLeft + kReceivedMessageSpacingFromLeft, kCellTopOffset, thisRowSize.width, thisRowSize.height)];
        
        
        [chatBubbleCell.timeStampLabel setFrame:CGRectMake(kReceivedMessageTextSpacingFromLeft + kReceivedMessageSpacingFromLeft,thisRowSize.height+ 5 /* + kCellTopOffset*/,[Utilities utilitiesInstance].screenWidth,[Utilities utilitiesInstance].timeStampHeight)];
        [chatBubbleCell.timeStampLabel setTextAlignment:NSTextAlignmentLeft];
        
        
        [chatBubbleCell.locationButton setFrame:CGRectMake(thisRowSize.width + kReceivedMessageTextSpacingFromLeft + +kReceivedMessageSpacingFromLeft - 3 + burnCompensation, /*thisRowSize.height/2 - 10*/0, 33, 33)];
        [chatBubbleCell.burnImageButton setFrame:CGRectMake(thisRowSize.width + kReceivedMessageTextSpacingFromLeft + +kReceivedMessageSpacingFromLeft - 3 , /*thisRowSize.height/2 - 10*/0, 33, 33)];
        [chatBubbleCell.burnTimeLabel setFrame:CGRectMake(chatBubbleCell.burnImageButton.frame.origin.x + 3, /*thisRowSize.height/2 - 10 +*/ 30, 30, chatBubbleCell.burnTimeLabel.frame.size.height)];
        [chatBubbleCell.sentBulletImageView setHidden:YES];
        [chatBubbleCell.receivedBulletImageView setHidden:NO];
        [chatBubbleCell.receivedBulletImageView setFrame:CGRectMake(5, thisRowSize.height / 2 - 9, 20, 46/2)];
        [chatBubbleCell.burnImageButton setImage:kBurnImageReceived forState:0];
        [chatBubbleCell.locationButton setImage:kLocationImageReceived forState:0];
        //[chatBubbleCell.readStatusImageView setHidden:YES];
    }
    else
    {
        chatBubbleCell.tag = 1;
        //[chatBubbleCell.messageContactImageView setHidden:YES];
        [chatBubbleCell.messageTextLabel.layer setBackgroundColor:kSentMessageBackgroundColor.CGColor];
        [chatBubbleCell.messageTextLabel setFrame:CGRectMake([Utilities utilitiesInstance].screenWidth - thisRowSize.width
                                                   - kSentMessageSpacingFromRight, kCellTopOffset, thisRowSize.width, thisRowSize.height)];
        [chatBubbleCell.locationButton setFrame:CGRectMake([Utilities utilitiesInstance].screenWidth - thisRowSize.width - kSentMessageSpacingFromRight - 20 - kReceivedMessageSpacingFromLeft - burnCompensation, /*thisRowSize.height/2 - 10*/0, 33, 33)];
        [chatBubbleCell.burnImageButton setFrame:CGRectMake([Utilities utilitiesInstance].screenWidth - thisRowSize.width - kSentMessageSpacingFromRight - 20 - kReceivedMessageSpacingFromLeft, /*thisRowSize.height/2 - 10*/0, 33, 33)];
        [chatBubbleCell.burnTimeLabel setFrame:CGRectMake(chatBubbleCell.burnImageButton.frame.origin.x, /*thisRowSize.height/2 - 10 +*/ 30, 30, chatBubbleCell.burnTimeLabel.frame.size.height)];
        [chatBubbleCell.receivedBulletImageView setHidden:YES];
        [chatBubbleCell.sentBulletImageView setHidden:NO];
        [chatBubbleCell.sentBulletImageView setFrame:CGRectMake([Utilities utilitiesInstance].screenWidth - 25, thisRowSize.height / 2 - 9, 20, 46/2)];
        
        
        
        
        [chatBubbleCell.timeStampLabel setTextAlignment:NSTextAlignmentRight];
        [chatBubbleCell.timeStampLabel setFrame:CGRectMake(0 ,thisRowSize.height + 5/* + kCellTopOffset*/,[Utilities utilitiesInstance].screenWidth - kSentMessageSpacingFromRight,[Utilities utilitiesInstance].timeStampHeight)];
       
        
        
        [chatBubbleCell.burnImageButton setImage:kBurnImageSent forState:0];
        [chatBubbleCell.locationButton setImage:kLocatioImageSent forState:0];
    }
    
    if(thisChatObject.errorString.length > 0)
    {
        [chatBubbleCell.containerView setHidden:YES];
        [chatBubbleCell.errorContainerView setHidden:NO];
        chatBubbleCell.errorLabel.text = thisChatObject.messageText;
        [chatBubbleCell.errorLabel setFrame:CGRectMake([Utilities utilitiesInstance].screenWidth/2 - thisRowSize.width/2, 0, thisRowSize.width, thisRowSize.height)];
        [chatBubbleCell.errorImageView setFrame:CGRectMake(chatBubbleCell.errorLabel.frame.origin.x - 33, thisRowSize.height/2 - 15, 30, 30)];
    } else
    {
        [chatBubbleCell.errorContainerView setHidden:YES];
        [chatBubbleCell.containerView setHidden:NO];
    }
    
    if(thisChatObject.messageText.length > 0) // text message cell
    {
        // remove link detection, set text, set link detection
        chatBubbleCell.messageTextLabel.dataDetectorTypes = UIDataDetectorTypeNone;
        
        // FIX ios 8 datadectortype bug
        chatBubbleCell.messageTextLabel.text = nil;
        chatBubbleCell.messageTextLabel.text = thisChatObject.messageText;
        chatBubbleCell.messageTextLabel.dataDetectorTypes = UIDataDetectorTypeLink;
        [chatBubbleCell.messageTextLabel setNeedsLayout];
        [chatBubbleCell.messageImageView setHidden:YES];
        [chatBubbleCell.timeStampLabel setHidden:NO];
        chatBubbleCell.messageTextLabel.userInteractionEnabled = YES;
        
        
        //must be reset after setting text to nil
        if(thisChatObject.isReceived == 1)
        {
            [chatBubbleCell.messageTextLabel setTextColor:kReceivedMessageFontColor];
        }
        else
        {
            [chatBubbleCell.messageTextLabel setTextColor:kSentMessageFontColor];
        }
        [chatBubbleCell.progressView setHidden:YES];
    }
    else if(thisChatObject.imageThumbnail) // image message cell
    {
		[chatBubbleCell.messageImageView setFrame:CGRectMake(3, 3, thisRowSize.width - 6, thisRowSize.height - 6)];
		chatBubbleCell.messageImageView.image = thisChatObject.imageThumbnail;
		[chatBubbleCell.messageImageView setHidden:NO];
       
       NSString *mediaType = [thisChatObject.attachment.metadata objectForKey:kSCloudMetaData_MediaType];

       chatBubbleCell.accessibilityLabel = [NSString stringWithFormat:@"%@ file %@",mediaType,chatBubbleCell.timeStampLabel.text];
       chatBubbleCell.accessibilityTraits =  UIAccessibilityTraitStaticText;
       chatBubbleCell.contentView.accessibilityElementsHidden = YES;
       chatBubbleCell.messageImageView.accessibilityElementsHidden = YES;
       

		CGRect progressR = CGRectMake(0, 0, 100, chatBubbleCell.progressView.frame.size.height); // progress view heights are fixed in iOS
        progressR.origin.x = chatBubbleCell.messageTextLabel.frame.origin.x + (thisRowSize.width - progressR.size.width)/2;
        progressR.origin.y = chatBubbleCell.messageTextLabel.frame.origin.y + 3 + (chatBubbleCell.messageImageView.frame.size.height - progressR.size.height)/2;
        [chatBubbleCell.progressView setFrame:progressR];
        
		chatBubbleCell.progressView.hidden = !thisChatObject.iSendingNow;
		
        // thumbnails have a border around them and need room on the bottom for timestamp
        chatBubbleCell.messageTextLabel.text = @"";
        chatBubbleCell.messageTextLabel.userInteractionEnabled = NO; // tap through

    }
    else if ((thisChatObject.attachment && !thisChatObject.attachment.metadata) && (thisChatObject.isReceived==1 || thisChatObject.isSynced) && (thisChatObject.hasFailedAttachment == 0))
    {
        [chatBubbleCell.progressView setHidden:YES];
        chatBubbleCell.messageImageView.image = nil;
        chatBubbleCell.messageTextLabel.text = @"";
        
		// if we've received an attachment but don't yet have the TOC, try downloading it again here (for the thumbnail)
       if(!thisChatObject.didTryDownloadTOC){
           [[ChatManager sharedManager] downloadChatObjectTOC:thisChatObject];
       }
    }

    if(shouldReloadTableWithAnimation)
    {
        //setup state before animation
        // depending on cell tag change x direction for sent or received messages
        CATransform3D translation;
        translation = CATransform3DMakeTranslation(5 * cell.tag, -25 * scrollDirection, 0);
        cell.layer.transform = translation;
        
        // state after completition
        [UIView beginAnimations:@"translation" context:NULL];
        [UIView setAnimationDuration:0.8];
        cell.layer.transform = CATransform3DIdentity;
        [UIView commitAnimations];
    }
    
    // if message is not read set it to already read
    if(thisChatObject.isRead == -1 && thisChatObject.isReceived == 1)
    {
        //GO - do this only when app is open
        UIApplicationState state = [[UIApplication sharedApplication] applicationState];
        if (state != UIApplicationStateBackground && state != UIApplicationStateInactive)
        {
            //Do checking here.
            [[Utilities utilitiesInstance] removeBadgeNumberForChatObject:thisChatObject];
            thisChatObject.isRead = 1;
            [[DBManager dBManagerInstance] saveMessage:thisChatObject];
            [[DBManager dBManagerInstance] setOffBurnTimerForBurnTime:thisChatObject.burnTime andChatObject:thisChatObject checkForRemoveal:NO];
            
            // if received message gets read for first time send delivery notification
            [[DBManager dBManagerInstance] sendDeliveryNotification:thisChatObject];
        }
        
    }
 
}


-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"SCContactChatCell";
    ChatBubbleCell *cell = (ChatBubbleCell *)[chatTableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    // TODO: move this code to ChatBubbleCell
	// adds check for out of bounds chatobject, can happen when burning multiple messages
    if(chatHistory.count <= indexPath.row)
    {
        return cell;
    }
    ChatObject *thisChatObject = (ChatObject*) chatHistory[indexPath.row];
	
    // check if row contains messageLabel
    if(!cell)
    {
        cell = [[ChatBubbleCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier: CellIdentifier];
        cell.messageTextLabel.delegate = self;
        [cell.locationButton addTarget:self action:@selector(locationButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    }
   // cell.messageContactImageView.image = dstImage;
	
    CGSize thisRowSize = [thisChatObject.contentRectValue CGSizeValue];
	if (thisChatObject.imageThumbnail) {
		thisRowSize.width += 6;
        thisRowSize.height += 6 ;//+ kChatBubbleBottomIconHeight;
	}
   
    
    if(thisChatObject.iDidBurnAnimation == 0)
    {
        cell.containerView.alpha = 1.0f;
    }
    else
        cell.containerView.alpha = 0.0f;
    
    
    
    return cell;
}

/**
 * insert row when sending or receiving new message
 * dont reload chatTableView
 */
-(void) reloadTableAndScrollToBottom:(BOOL)scrollToBottom animated:(BOOL) animated
{
    shouldReloadTableWithAnimation = NO;
    [self scrollToBottom:YES forced:scrollToBottom];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadVisibleRowBurnTimers) object:nil];
    [self reloadVisibleRowBurnTimers];
    shouldReloadTableWithAnimation = NO;
}

/**
 scrolls chatTableView to bottom
 @param animated - should scroll with animation
 */
-(void) scrollToBottom:(BOOL) animated forced:(BOOL) forced
{
	// EA: do not rely on chatHistory.count - it's possible chatHistory has 1 more item than tableview
	// This can happen when adding a new chat message -- this method gets called before the tableview is reloaded
	
	NSInteger numRows = [chatTableView numberOfRowsInSection:0];
	if (numRows < 2)
		return;
//    if(chatHistory.count <=2)
//    {
//        return;
//    }
//    NSIndexPath *prev = [NSIndexPath indexPathForRow:chatHistory.count - 2 inSection:0];
	NSIndexPath *prev = [NSIndexPath indexPathForRow:numRows-2 inSection:0];
	
    if ([chatTableView.indexPathsForVisibleRows containsObject:prev] || forced)
    {
        shouldReloadTableWithAnimation = NO;
//        NSIndexPath *indexPathToScroll = [NSIndexPath indexPathForRow:chatHistory.count - 1 inSection:0];
		NSIndexPath *indexPathToScroll = [NSIndexPath indexPathForRow:numRows-1 inSection:0];
        [chatTableView scrollToRowAtIndexPath:indexPathToScroll atScrollPosition:UITableViewScrollPositionBottom animated:animated];
        shouldReloadTableWithAnimation = NO;
    }
}

#pragma mark sendReceiveMessages
/**
 *Take content from messageTextView and send message
 @param messageContext - context to create message with, can be image or button which got clicked on for send
 */
-(void) sendMessage:(NSObject*) messageContext
{
	SendButton *sender;
	if([messageContext isKindOfClass:[SendButton class]])
	{
		sender = (SendButton *) messageContext;
	}
	NSString *messageViewText = messageTextView.text;
	messageViewText = [messageViewText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (messageViewText.length>0)// || [messageContext isKindOfClass:[UIImage class]])
	{
		if(sender)
			[sender clickAnimation];
//		messageViewText = [messageViewText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		// if message text > 1000 characters send as text file attachment
		if ([messageViewText length] > 1000) {
			SCAttachment *attachment = [SCAttachment attachmentFromText:messageViewText];
			[[ChatManager sharedManager] sendMessageWithAttachment:attachment upload:YES];
		} else
			[[ChatManager sharedManager] sendTextMessage:messageViewText];
		
		messageTextView.text = @"";
        messageTextView.placeholder = @"Say something ..";
		
		[chatTableView reloadData];
		[self reloadTableAndScrollToBottom:YES animated:YES];
	}
}

-(void)receiveMessage:(NSNotification*)notification
{
    ChatObject *receivedChatObject = (ChatObject*) notification.object;
    int receivedMessagesInOtherThreads = [[Utilities utilitiesInstance] getBadgeValueWithoutUser:lastOpenedUserNameForChat];
    if(receivedMessagesInOtherThreads > 0)
    {
        [backButtonAlertLabel setHidden:NO];
        backButtonAlertLabel.text = [NSString stringWithFormat:@"%i",receivedMessagesInOtherThreads];
    }

	if(![receivedChatObject.contactName isEqualToString:lastOpenedUserNameForChat])
    {
        // this message is not for this conversation
        // show received message in other conversation
        return;
    }
	
	// finds first indexPath with smaller timestamp than the received chatobject starting from the bottom
    // in cases message received is not the last one
    
    NSIndexPath *indexPathToInsert;
    long indexToInsert = 0;

    if(chatHistory.count > 0)
    {
        for (int i = (int)chatHistory.count - 1 ; i>=0; i--) {
            ChatObject *thisChatObject = (ChatObject *) chatHistory[i];
            
            indexToInsert = i;
            
            if(receivedChatObject == thisChatObject)break;
        }
    }
    
    indexPathToInsert = [NSIndexPath indexPathForRow:indexToInsert inSection:0];
    
    [chatTableView beginUpdates];
    [chatTableView insertRowsAtIndexPaths:@[indexPathToInsert] withRowAnimation:UITableViewRowAnimationNone];
    [chatTableView endUpdates];
    
    [self reloadTableAndScrollToBottom:YES animated:YES];
}

- (void)receiveAttachment:(NSNotification *)notification {
	NSString *receivedMessageID = [notification object];
    // walk this array backwards as the one we're looking for is most likely at the end
    // GO - reversed array, added scrolling to bottom	
    for (long i = chatHistory.count-1; i>=0; i--) {
        ChatObject *thisChatObject = (ChatObject *)chatHistory[i];
        if ([receivedMessageID isEqualToString:thisChatObject.msgId]) {
			NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
			UITableViewCell *existingCell = [chatTableView cellForRowAtIndexPath:indexPath];
			// does this row exist yet in the tableview?
			if (existingCell) {
				[chatTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
				[self scrollToBottom:YES forced:NO];
			}
            break;
        }
    }
}

-(void) removeMessage:(NSNotification*) notification
{
    
    int f =0;
    ChatObject *chatObjectToRemove = (ChatObject*) notification.object;
    for (ChatBubbleCell *cell in [chatTableView visibleCells]) {
        if([cell.thisChatObject isEqual:chatObjectToRemove])
        {
            NSIndexPath *i = [chatTableView indexPathForCell:cell];
            if(!i)break;
            [self deleteRowAtIndexPath:i];
            f=1;
            break;
        }
    }
    if(!f){
        if([chatHistory containsObject:chatObjectToRemove]){
            [chatHistory removeObjectIdenticalTo:chatObjectToRemove];
            shouldReloadTableWithAnimation = NO;
            [chatTableView reloadData];
        }
    }
}

-(void) receiveMessageState:(NSNotification *) notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL reload = NO;
        ChatObject *chatObjectToRefresh = (ChatObject*) notification.object;
        for (ChatBubbleCell *cell in [chatTableView visibleCells]) {
            if([cell.thisChatObject.msgId isEqualToString:chatObjectToRefresh.msgId])
            {
                reload = YES;
            }
        }
        if(reload)
        {
            shouldReloadTableWithAnimation = NO;
            [chatTableView reloadData];
            if(chatObjectToRefresh.didTryDownloadTOC)
            {
                [self scrollToBottom:YES forced:NO];
            }
            /*
             [chatTableView beginUpdates];
             [chatTableView reloadRowsAtIndexPaths:[chatTableView indexPathsForVisibleRows] withRowAnimation:UITableViewRowAnimationNone];
             [chatTableView endUpdates];*/
            
        }
    });
}

- (void)onChatObjectCreated:(NSNotification *)note {
	// update on main thread
	dispatch_async(dispatch_get_main_queue(), ^{
		ChatObject *chatObject = [note object];
		if ([chatObject.contactName isEqualToString:lastOpenedUserNameForChat]) {
			[chatTableView reloadData];
			[self reloadTableAndScrollToBottom:YES animated:YES];
		}
	});
}

// TODO: replace receiveMessageState with this
- (void)onChatObjectUpdated:(NSNotification *)note {
	// update on main thread
	dispatch_async(dispatch_get_main_queue(), ^{
		ChatObject *chatObject = [note object];
		if ([chatObject.contactName isEqualToString:lastOpenedUserNameForChat]) {
			NSIndexPath *indexPath = [self findChatObjectWithMessageID:chatObject.msgId];
			if (indexPath) {
				shouldReloadTableWithAnimation = NO;
                [chatTableView beginUpdates];
				[chatTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                [chatTableView endUpdates];
            }
		}
	});
}

- (void)_presentAttachment:(ChatObject *)chatObject {
	NSString *mediaType = [chatObject.attachment.metadata objectForKey:kSCloudMetaData_MediaType];
	if ([(__bridge NSString *)kUTTypeAudio isEqualToString:mediaType]) {
		// cancel closing of audioplaybackview
		[NSObject cancelPreviousPerformRequestsWithTarget:self];
		[self animateAudioPlayerViewWithDirection:[NSNumber numberWithInt:1]];
		[[AudioPlaybackManager sharedManager] playAttachment:chatObject inView:audioPlaybackHolderView];
	} else {
		dismissedViewWithAttachment = YES;
		AttachmentPreviewController *attachmentVC = [[AttachmentPreviewController alloc] initWithChatObject:chatObject];
		
		// because I can't set background color or PreviewController I'm using this:
		[self presentViewController:attachmentVC animated:YES completion:nil];
		// instead of this:
		//[self.navigationController pushViewController:attachmentVC animated:YES];
	}
}

#pragma mark prepareForSegue
-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([segue.identifier isEqualToString:@"showMapView"])
    {
        LocationButton *clickedLocationButton = (LocationButton *) sender;
        
        MapViewController *destViewC = (MapViewController*)segue.destinationViewController;
        
        if(clickedLocationButton.thisChatObject.location)
        {
            // assign Mapview variables from ChatObject
            destViewC.pinLocation = clickedLocationButton.thisChatObject.location;
            destViewC.chatItemIndexPath = lastClickedIndexPath;
            destViewC.locationUnixTimeStamp = clickedLocationButton.thisChatObject.unixTimeStamp;
            
            // get my username
            if(clickedLocationButton.thisChatObject.isReceived==0){
                void *getCurrentDOut(void);
                const char* sendEngMsg(void *pEng, const char *p);
                const char *p=sendEngMsg(getCurrentDOut(),"cfg.un");
                destViewC.locationUserName = [NSString stringWithUTF8String:p];
                
            }
            else destViewC.locationUserName = [[Utilities utilitiesInstance] removePeerInfo:lastOpenedUserNameForChat lowerCase:NO];
        }
    }
    else if([segue.identifier isEqualToString:@"showSingleImageView"])
    {
        ChatObject *thisChatObject = (ChatObject*)chatHistory[lastClickedIndexPath.row];
        FullScreenImageViewController *destViewC = (FullScreenImageViewController*) segue.destinationViewController;
        destViewC.imageToDisplay = thisChatObject.image;
    } else if([segue.identifier isEqualToString:@"deviceSegue"])
    {
        UIViewController *destViewC = segue.destinationViewController;
	}
}

#pragma mark actionSheetViewAnimation
/**
 Click on ActionSheet open / close button
 */
-(void) attachmentsButtonClick:(UIButton*)button
{
    //close
    if(savedAttachmentsDirection == 1)
    {
        savedAttachmentsDirection = -1;
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(attachmentsButtonClick:) object:nil];
        
        // store last chatobject when burn slider gets closed
        // to save new burnsliderdelay value
        if(chatHistory.count > 0)
        {
            [[DBManager dBManagerInstance] insertOrUpdateConversation:chatHistory.lastObject];
        }
    }
    else //open
    {
        savedAttachmentsDirection = 1;
        [self performSelector:@selector(attachmentsButtonClick:) withObject:nil afterDelay:5.0];
    }
    [self animateAttachmentViewWithDirection:savedAttachmentsDirection];
}

/**
 Open or close ActionSheet animation
 @param direction - 1 animate up or open.  -1 animate down or close
 */
-(void) animateAttachmentViewWithDirection:(int) direction
{
    //if open unhide actionSheet
    if(direction == 1)
    {
        [actionSheetView setHidden:NO];
    }
    [UIView animateWithDuration:0.3 animations:^{
        CGRect attachmentsRect = actionSheetView.frame;
        [actionSheetView setFrame:CGRectMake(attachmentsRect.origin.x, attachmentsRect.origin.y - kActionSheetHeight*direction, attachmentsRect.size.width, attachmentsRect.size.height)];
		if (!audioPlaybackHolderView.hidden) {
			CGRect audioPlayerFrame = audioPlaybackHolderView.frame;
			audioPlayerFrame.origin.y = actionSheetView.frame.origin.y - kAudioPlayerFrameHeight;
			audioPlaybackHolderView.frame = audioPlayerFrame;
		}
    } completion:^ (BOOL finished)
     {
         // hide burn slider when animation finishes
         [actionSheetView.sliderView setHidden:YES];
         
         // if closed, hide actionsheet
         if(direction == -1)
         {
             [actionSheetView setHidden:YES];
         }
     }];
}

-(void) animateAudioPlayerViewWithDirection:(NSNumber *) directionNumber
{
    int direction = [directionNumber intValue];
	//if open unhide player
	if(direction == 1)
	{
        if (!audioPlaybackHolderView.hidden)
            return; // already showing
        
        // FIX:audio players y origin is 40 points above actionsheet
        // set audioplayers view to actionsheetview if player is about to open audioplayer
        audioPlaybackHolderView.frame = actionSheetView.frame;

        [audioPlaybackHolderView setHidden:NO];
	} else if (direction == -1) {
		if (audioPlaybackHolderView.hidden)
			return; // already hidden
	}
	[UIView animateWithDuration:0.3 animations:^{
		CGRect audioPlayerFrame = audioPlaybackHolderView.frame;
		audioPlayerFrame.origin.y -= kAudioPlayerFrameHeight*direction;
		audioPlaybackHolderView.frame = audioPlayerFrame;
	} completion:^ (BOOL finished)
	 {
		 // if closed, hide actionsheet
		 if(direction == -1)
		 {
			 [audioPlaybackHolderView setHidden:YES];
		 }
	 }];
}

#pragma mark MessageBurnSliderTouchDelegate
/**
 * When user touches burn slider, stop actionsheetview from closing
 **/
-(void)touchHappened
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(attachmentsButtonClick:) object:nil];
    [self performSelector:@selector(attachmentsButtonClick:) withObject:nil afterDelay:5.0];
}

#pragma mark actionSheetDelegate
- (void)sendMessageWithAssetInfo:(NSDictionary *)assetInfo {
	[[ChatManager sharedManager] sendMessageWithAssetInfo:assetInfo inView:self.view];
//	[chatTableView reloadData];
//	[self reloadTableAndScrollToBottom:YES animated:YES];
}

- (void)sendMessageWithAttachment:(SCAttachment *)attachment {
	[[ChatManager sharedManager] sendMessageWithAttachment:attachment upload:YES];
//	[chatTableView reloadData];
//	[self reloadTableAndScrollToBottom:YES animated:YES];
}

-(void)resignFirstResponderForAction
{
    [messageTextView resignFirstResponder];
}
/*
-(int)getImgSize:(NSDictionary *)pickerInfo scale:(CGFloat)scale{
   UIImage *image = [pickerInfo objectForKey:UIImagePickerControllerOriginalImage];
   //+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize
   UIImage *scaledImage = [SCAttachment imageWithImage:image scaledToSize:CGSizeMake(image.size.width*scale, image.size.height*scale)];
   NSData *mediaData = UIImageJPEGRepresentation(scaledImage, .8f);
   return (int)mediaData.length;
   
}
*/
-(void) locationButtonClick:(LocationButton *) button
{
    if(button.thisChatObject.location)
    {
        [self performSegueWithIdentifier:@"showMapView" sender:button];
    }
}

-(void) burnButtonClick:(BurnButton*) button
{
    BurnButton *burnNowButton = [[BurnButton alloc] initWithFrame:CGRectMake(0, 0, 100, 30)];
    [burnNowButton setTitle:@"Burn" forState:0];
    [burnNowButton.titleLabel setFont:[[Utilities utilitiesInstance] getFontWithSize:14]];
    [burnNowButton setBackgroundColor:[UIColor blackColor]];
    burnNowButton.indexPathForCell = button.indexPathForCell;
    [burnNowButton addTarget:self action:@selector(burnNowClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:burnNowButton];
    [savedBurnNowButton removeFromSuperview];
    savedBurnNowButton = burnNowButton;
    ChatBubbleCell *cell = (ChatBubbleCell*)[chatTableView cellForRowAtIndexPath:button.indexPathForCell];
    CGPoint buttoncenter = [self.view convertPoint:button.center fromView:cell];
    burnNowButton.center = buttoncenter;
}


/*
 * performs poof animation after timer for message runs out
 * no need to call deleterowatindexpath
 */
-(void) burnAfterTimer:(ChatBubbleCell *) cell
{
    [savedBurnNowButton removeFromSuperview];
    ChatObject *co =  cell.thisChatObject;
    [UIView animateWithDuration:0.5 animations:^{
        //cell.contentView.alpha = 0;
        cell.containerView.alpha = 0;
    }];
    UIImage *poof0 = [UIImage imageNamed:@"poof0"];
    UIImage *poof1 = [UIImage imageNamed:@"poof1"];
    UIImage *poof2 = [UIImage imageNamed:@"poof2"];
    UIImage *poof3 = [UIImage imageNamed:@"poof3"];
    UIImage *poof4 = [UIImage imageNamed:@"poof4"];
    UIImage *poof5 = [UIImage imageNamed:@"poof5"];
    
    NSArray	*poofImages = @[ poof5, poof4, poof3, poof2, poof1, poof0, poof1, poof2, poof3, poof4, poof5 ];
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    imageView.animationImages = poofImages;
    imageView.animationDuration = 0.5;
    imageView.animationRepeatCount = 1;
    imageView.image = [poofImages objectAtIndex:0];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    
    CGSize imageSize = imageView.image.size;
    UIView *bubbleView = [cell.contentView viewWithTag:1];
    CGSize bubbleViewSize = bubbleView.frame.size;
    
    CGFloat width = MIN(imageSize.width, bubbleViewSize.width);
    CGFloat height = MIN(imageSize.height, bubbleViewSize.height);
    
    CGPoint bubbleCenter = [self.view convertPoint:bubbleView.center fromView:cell];
    
    imageView.frame = CGRectMake(0, 0, width, height);
    imageView.center = bubbleCenter;
    
    [self.view addSubview:imageView];
    [imageView startAnimating];
    [[Utilities utilitiesInstance] playSoundFile:@"poof" withExtension:@"aif"];
    __weak UIImageView *weakImageView = imageView;
    double delayInSeconds = 0.5;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        
        __strong UIImageView *strongImageView = weakImageView;
        if (strongImageView)
        {
            [strongImageView removeFromSuperview];
            [co.burnTimer fire];
        }
    });
    
}

-(void) burnNowClick:(BurnButton *) button

{
    [self burnNowClick:button indexPath:button.indexPathForCell];
}

/*
 * performs poof animation after burn now button click or UIMenuController burn click
 */
-(void) burnNowClick:(BurnButton *) button indexPath:(NSIndexPath*)indexPath
{
    ChatBubbleCell *cell = (ChatBubbleCell*)[chatTableView cellForRowAtIndexPath:indexPath];
    cell.thisChatObject.iDidBurnAnimation = 1;
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.5 animations:^{
            button.alpha = 0;
            cell.containerView.alpha = 0;
        }];
        [button setBackgroundColor:[UIColor grayColor]];
        [button setUserInteractionEnabled:NO];
        UIImage *poof0 = [UIImage imageNamed:@"poof0"];
        UIImage *poof1 = [UIImage imageNamed:@"poof1"];
        UIImage *poof2 = [UIImage imageNamed:@"poof2"];
        UIImage *poof3 = [UIImage imageNamed:@"poof3"];
        UIImage *poof4 = [UIImage imageNamed:@"poof4"];
        UIImage *poof5 = [UIImage imageNamed:@"poof5"];
        NSArray	*poofImages = @[ poof5, poof4, poof3, poof2, poof1, poof0, poof1, poof2, poof3, poof4, poof5 ];
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        [imageView setBackgroundColor:[UIColor clearColor]];
        imageView.animationImages = poofImages;
        imageView.animationDuration = 0.5;
        imageView.animationRepeatCount = 1;
        imageView.image = [poofImages objectAtIndex:0];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        CGSize imageSize = imageView.image.size;
        UIView *bubbleView = [cell.contentView viewWithTag:1];
        CGSize bubbleViewSize = bubbleView.frame.size;
        CGFloat width = MIN(imageSize.width, bubbleViewSize.width);
        CGFloat height = MIN(imageSize.height, bubbleViewSize.height);
        CGPoint bubbleCenter = [self.view convertPoint:bubbleView.center fromView:cell];
        imageView.frame = CGRectMake(0, 0, width, height);
        imageView.center = bubbleCenter;
        [self.view addSubview:imageView];
        [imageView startAnimating];
        __weak UIImageView *weakImageView = imageView;
        __weak BurnButton *weakButton = button;
        
        [[DBManager dBManagerInstance]sendForceBurn:cell.thisChatObject];
        
        [[Utilities utilitiesInstance] playSoundFile:@"poof" withExtension:@"aif"];
        double delayInSeconds = 0.5;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            __strong UIImageView *strongImageView = weakImageView;
            __strong BurnButton *strongButton = weakButton;
            if (strongImageView)
            {
                [savedBurnNowButton removeFromSuperview];
                [strongButton removeFromSuperview];
                [strongImageView removeFromSuperview];
                //cell.containerView.alpha = 1.0f;
                
                [self deleteRowAtIndexPath:indexPath];
            }
        });
    });
}

-(void) reloadVisibleRowBurnTimers
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        BOOL shouldReload = NO;
        NSArray *visibleCells = [chatTableView visibleCells];
        if(!visibleCells)return;
        
        long now = time(NULL);
        for (ChatBubbleCell *cell in visibleCells) {
            // if one row counts time less than 1min or has received burn from other party reload all visible cells
            // if any row is being deleted(poof animation is playing) cancel reload
            long dif = cell.thisChatObject.burnTime + cell.thisChatObject.unixReadTimeStamp - now;
            if((cell.thisChatObject.burnNow ||( cell.thisChatObject.unixReadTimeStamp && dif >= 0 && dif < 60)) && !chatObjectInMenuController)
            {
                // reload burn timers only if we are not scrolling tableview
                if (!chatTableView.isDragging && !chatTableView.isDecelerating)
                {
                    shouldReload = YES;
                    break;
                }
            }
            if(cell.thisChatObject.iDidBurnAnimation != 0)
                shouldReload = NO;
        }
        if(shouldReload)
        {
            shouldReloadTableWithAnimation = NO;
            
            //        [chatTableView reloadData];
            NSArray *ar = [chatTableView indexPathsForVisibleRows];
            // [chatTableView beginUpdates];
            //  [chatTableView reloadRowsAtIndexPaths:ar withRowAnimation:UITableViewRowAnimationNone];
            
            ar = [chatTableView indexPathsForVisibleRows];
            
            for (NSIndexPath *cellIndexPath in ar) {
                ChatBubbleCell *cell = (ChatBubbleCell*)[chatTableView cellForRowAtIndexPath:cellIndexPath];
                long dif = cell.thisChatObject.burnTime + cell.thisChatObject.unixReadTimeStamp - now;
                if(cell.thisChatObject.burnNow || ( cell.thisChatObject.unixReadTimeStamp && cell.thisChatObject.burnTime && dif >= 0 && dif < 60))
                {
                    if((cell.thisChatObject.burnNow || dif <= 0) && cell.thisChatObject.iDidBurnAnimation == 0){
                        cell.thisChatObject.iDidBurnAnimation = 1;
                        cell.thisChatObject.burnNow = 0;
                        [self burnAfterTimer: cell];
                    }
                }
            }
            for (NSIndexPath *cellIndexPath in ar) {
                ChatBubbleCell *cell = (ChatBubbleCell*)[chatTableView cellForRowAtIndexPath:cellIndexPath];
                if(cell.thisChatObject.iDidBurnAnimation == 1)
                {
                    cell.thisChatObject.iDidBurnAnimation = 2;
                }
            }
            [chatTableView reloadData];
            //  [chatTableView endUpdates];
            
        }
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadVisibleRowBurnTimers) object:nil];
        [self performSelector:@selector(reloadVisibleRowBurnTimers) withObject:nil afterDelay:1.0];
    });
}

#pragma mark - AttachmentManager notfications
- (NSIndexPath *)findChatObjectWithMessageID:(NSString *)messageID {
    //int row = 0;
    //GO - reverses search order
    //for (ChatObject *chatObject in chatHistory) {
    for (long i = chatHistory.count-1; i>=0; i--) {
        ChatObject *thisChatObject = (ChatObject *)chatHistory[i];
        if ([thisChatObject.msgId isEqualToString:messageID])
            return [NSIndexPath indexPathForRow:i inSection:0];
       // row++;
    }
    return nil;
}

- (void)attachmentProgressNotification:(NSNotification *)note {
	AttachmentProgress *progressObj = [note object];
    NSIndexPath *indexPath = [self findChatObjectWithMessageID:progressObj.messageID];
    if (!indexPath)
        return;
    ChatBubbleCell *cell = (ChatBubbleCell*)[chatTableView cellForRowAtIndexPath:indexPath];
    if (!cell || cell.thisChatObject.messageStatus >= 200)
        return;
    cell.progressView.progress = progressObj.progress;
    cell.progressView.hidden = ( (progressObj.progress <= 0) || (progressObj.progress >= 1.0) );
    [cell.timeStampLabel setTextColor:kTimeStampTextcolor];
	switch (progressObj.progressType) {
		case kProgressType_Encrypt:
			cell.timeStampLabel.text = @"Preparing...";
			break;
		case kProgressType_Upload:
			cell.timeStampLabel.text = @"Uploading...";
			break;
		case kProgressType_Verify:
			cell.timeStampLabel.text = @"Verifying...";
			break;
		case kProgressType_Download:
			cell.timeStampLabel.text = @"Downloading...";
			break;
	}
}

#pragma mark - AudioPlaybackManager notification
- (void)audioFinishedNotification:(NSNotification *)note {
	[self animateAudioPlayerViewWithDirection:[NSNumber numberWithInt:-1]];
}
- (void)audioPausedNotification:(NSNotification *)note {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self performSelector:@selector(animateAudioPlayerViewWithDirection:) withObject:[NSNumber numberWithInt:-1] afterDelay:5.0];
}

#pragma mark touches
- (void)handleLongPress:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan)
    {
        CGPoint tableViewTouchPoint = [gestureRecognizer locationInView:chatTableView];
        
        NSIndexPath *indexPath = [chatTableView indexPathForRowAtPoint:tableViewTouchPoint];
        ChatBubbleCell *cell = (ChatBubbleCell *)[chatTableView cellForRowAtIndexPath:indexPath];
        [self displayMenuControllerForCell:cell atIndexPath:indexPath];
    }
}

- (void)displayMenuControllerForCell:(ChatBubbleCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    chatObjectInMenuController = cell.thisChatObject;
    [[UIMenuController sharedMenuController] setMenuItems:nil];
    CGRect rowFrame = [chatTableView rectForRowAtIndexPath:indexPath];
    
    CGRect bubbleFrameInTableView;
    bubbleFrameInTableView = cell.messageTextLabel.frame;
    
    bubbleFrameInTableView.origin.x += rowFrame.origin.x;
    bubbleFrameInTableView.origin.y += rowFrame.origin.y;
    
    CGRect visibleTableFrame;
    visibleTableFrame.origin = chatTableView.contentOffset;
    visibleTableFrame.size = chatTableView.frame.size;
    
    CGRect menuFrame = CGRectIntersection(bubbleFrameInTableView, visibleTableFrame);
    
    
    UIMenuItem *burnItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Burn", @"Burn")
                                                      action:@selector(burn:)];
    
    UIMenuItem *forwardItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Forward", @"Forward")
                                                         action:@selector(forward:)];
    
    UIMenuItem *infoItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Info", @"Info")
                                                       action:@selector(info:)];
    
    UIMenuItem *resendItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Resend", @"Resend")
                                                      action:@selector(resend:)];
    
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    
    NSArray *menuItemsArray;
    
    // if message is failed, change last item to resend
    if(cell.thisChatObject.isFailed)
    {
        menuItemsArray = @[burnItem,infoItem, resendItem];
    } else
    {
        menuItemsArray = @[burnItem,infoItem, forwardItem];
    }
    
    [menuController setMenuItems:menuItemsArray];
    
    [chatTableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    [cell.messageTextLabel becomeFirstResponder];
    [menuController setTargetRect:menuFrame inView:chatTableView];
    [menuController setMenuVisible:YES animated:YES];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(willHideMenuController:)
                                               name:UIMenuControllerWillHideMenuNotification
                                             object:nil];
}

- (void)willHideMenuController:(NSNotification *)notification
{
    chatObjectInMenuController = nil;
    [self reloadVisibleRowBurnTimers];
    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:UIMenuControllerWillHideMenuNotification
                                                object:nil];
    
    // Remove the custom menu items from the shared menuController.
    // If we don't do this then these menu items will appear for the inputView.
    
    [[UIMenuController sharedMenuController] setMenuItems:nil];
    
    // Unselect the cell, and update the cell's UI
    
    //FIX: deselected cell gets passed to pasteboard when selecting copy in menucontroller
    /*
    NSIndexPath *indexPath = [chatTableView indexPathForSelectedRow];
    if (indexPath)
    {
        [chatTableView deselectRowAtIndexPath:indexPath animated:NO];
    }
     */
}

-(BOOL)textView:(ChatBubbleTextView *)sender canPerformAction:(SEL)action
{
    ChatBubbleCell *cell = (ChatBubbleCell *)[chatTableView cellForRowAtIndexPath:[chatTableView indexPathForSelectedRow]];
    if(!cell)return NO;
    if(action == @selector(copy:))
    {
        if(sender.thisChatObject.messageText.length > 0)
            return YES;
        else
            return NO;
    }
    
    if(action == @selector(more:) || action == @selector(info:)|| action == @selector(resend:))
    {
        return YES;
    }
    else if(action == @selector(burn:) || action == @selector(forward:))
    {
        if(sender.thisChatObject.errorString)
        {
            return NO;
        } else
        {
            return YES;
        }
    } else
    {
        return NO;
    }
}

-(void)textView:(UITextView *)textView menuActionCopy:(id)sender
{
    ChatBubbleCell *cell = (ChatBubbleCell *)[chatTableView cellForRowAtIndexPath:[chatTableView indexPathForSelectedRow]];
    if(!cell)return;
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    if(!cell.imageView.image)
    {
        pasteboard.string = cell.messageTextLabel.text;
    }
}

-(void)textView:(UITextView *)textView menuActionResend:(id)sender
{
	chatObjectInMenuController.iSendingNow = 1;
	if (chatObjectInMenuController.attachment)
    {
        // if message has failed, reset messagestatus
        if(chatObjectInMenuController.messageStatus < 0)
        {
            chatObjectInMenuController.messageStatus = 0;
        }
		[[ChatManager sharedManager] uploadAttachmentForChatObject:chatObjectInMenuController];
    }
	else
    [[ChatManager sharedManager] sendChatObjectAsync:chatObjectInMenuController];
}

-(void)textView:(UITextView *)textView menuActionBurn:(id)sender
{
    ChatBubbleCell *cell = (ChatBubbleCell *)[chatTableView cellForRowAtIndexPath:[chatTableView indexPathForSelectedRow]];
    [self burnNowClick:cell.burnInfoButton indexPath:[chatTableView indexPathForSelectedRow]];
}

-(void)textView:(UITextView *)textView menuActionForward:(id)sender
{
    ChatBubbleCell *cell = (ChatBubbleCell *)[chatTableView cellForRowAtIndexPath:[chatTableView indexPathForSelectedRow]];
    [[Utilities utilitiesInstance].forwardedMessageData setValue:cell.thisChatObject forKey:@"forwardedChatObject"];
    UIStoryboard *chatStoryBoard = [UIStoryboard storyboardWithName:@"Chat" bundle:nil];
    UIViewController *chatViewController = [chatStoryBoard instantiateViewControllerWithIdentifier:@"SearchViewController"];
    [self.navigationController pushViewController:chatViewController animated:YES];
}


-(void)textView:(UITextView *)textView menuActionInfo:(id)sender
{
    NSString *messageInfo;
    ChatObject *thisChatObject = (ChatObject*)chatHistory[[chatTableView indexPathForSelectedRow].row];
    if(thisChatObject.errorString)
    {
        NSData *data = [thisChatObject.errorString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *errorDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        messageInfo = [NSString stringWithFormat:@"%@",errorDict.allKeys];
        
        NSArray *keys = [errorDict allKeys];
        NSString *key;
        NSString *value;
        for (int i = 0; i < keys.count; i++)
        {
            key = [keys objectAtIndex: i];
            value = [errorDict objectForKey: key];
            messageInfo = [NSString stringWithFormat:@"%@\n%@ : %@",messageInfo, key, value];
        }
    } else
    {
        messageInfo = [[Utilities utilitiesInstance] formatInfoStringForChatObject:thisChatObject];
    }
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Message Info"
                                                    message:messageInfo
                                                   delegate:self
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

- (void)navigationTitlePressAction:(UIGestureRecognizer *)gestureRecognizer
{
    if(!dismissedViewWithDevicesView)
    {
        dismissedViewWithDevicesView = YES;
        [self performSegueWithIdentifier:@"deviceSegue" sender:nil];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - SilentContactsViewControllerDelegate 

- (void)silentContactsViewControllerWillDismissWithContact:(UserContact *)contact {
    
    _pendingContactAttachment = contact;

    [self.navigationController popViewControllerAnimated:YES];
}

@end
