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

//#import "Silent_Phone-Swift.h"
#import "axolotl_glue.h"

#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

#import "ChatViewController.h"

#import "ActionSheetWithKeyboardView.h"
#import "ActionSheetViewRed.h"
#import "AttachmentManager.h"
#import "AttachmentPreviewController.h"
#import "AudioPlayBackHolderView.h"
#import "AudioPlaybackManager.h"
#import "BurnButton.h"
#import "ChatBubbleCell.h"
#import "ChatBubbleTextView.h"
#import "ChatObject.h"
#import "ChatManager.h"
#import "ChatUtilities.h"
#import "DBManager.h"
#import "DBManager+MessageReceiving.h"
#import "DBManager+Sorting.h"
#import "DevicesViewController.h"
#import "LocationButton.h"
#import "LocationManager.h"
#import "MapViewController.h"
#import "RavenClient.h"
#import "SCDRWarningView.h"
#import "SCFileManager.h"
#import "SCPNotificationKeys.h"
#import "SCSChatSectionObject.h"
#import "SCSContactsManager.h"
#import "SCSEnums.h"
#import "SCSAudioManager.h"
#import "SendButton.h"
#import "UserService.h"
#import "SCSAvatarManager.h"
#import "SCPCallbackInterface.h"

//group chat
#import "AddGroupMemberViewController.h"
#import "GroupChatManager.h"
#import "GroupChatManager+AvatarUpdate.h"
#import "GroupChatManager+UI.h"
#import "SCSConstants.h"
#import "GroupChatManager+Members.h"
#import "GroupInfoViewController.h"

// Categories
#import "UIColor+ApplicationColors.h"
#import "UIImage+ApplicationImages.h"


static NSInteger const kActionSheetHeight           = 40;
static NSInteger const kAudioPlayerFrameHeight      = 40;
//static NSInteger const kChatRowVerticalSpacing      = 15;
static NSInteger const kMessageMaxLength            = 5000;
//static CGFloat const kActionSheetOpenSpeed          = 0.3f;

static NSInteger const kMaxMessageTextFontSize      = 25;
//static NSInteger const kMaxMessageInputTextFontSize = 20;

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelError;
//#endif


@interface ChatViewController ()
<ActionSheetDelegate, ChatBubbleCellDelegate,
//SilentContactsViewControllerDelegate,
KeyboardWithActionSheetDelegate,
//UIActionSheetDelegate,
UITableViewDelegate, UITableViewDataSource>
{    
    NSIndexPath *lastClickedIndexPath;
    
    NSString *lastOpenedUserNameForChat;
    
    // true if table reload should happen with tableviewcell animation in willdisplay cell
    // turns false when table gets reloaded without user scrolling the table
    BOOL shouldReloadTableWithAnimation;
    
    UILabel *backButtonAlertLabel;
    
    BurnButton *savedBurnNowButton;
    
    UILongPressGestureRecognizer *longPressRecognizer;
    AddressBookContact *_pendingContactAttachment;
    
    BOOL cancelReloadBeforeAppearing;    
    
    CGPoint lastTouchPositionInViewController;    
    
    
    AudioPlayBackHolderView *audioPlaybackHolderView;
    
    BOOL _supressFirstResponder;
    
    NSUInteger _chatHistoryCnt;
    
    
    BOOL shouldCheckForMoreMessages;
    
    
    int lastLoadedMessageCount;
    
    BOOL _allowScrollToLoad;
    
    int messageBubbleTextFontSize;
    
    
    BOOL _audioPlaybackHolderViewFrameObserverAdded;
    
    
    BOOL headerOpened;
    CGFloat lastContentOffset;
    
    BOOL isNumber;
    
    ActionSheetWithKeyboardView *actionSheetView;
    UIButton *burnButton;
    UIButton *plusButton;
        
    UIButton *backButtonWithImage;
    
    NSString *msgIDOfChatObjectInMenuController;
    
    
    NSTextContainer *sizingTextContainer;
    NSLayoutManager *sizingLayoutManager;
    NSTextStorage *sizingTextStorage;
    
    BOOL isScrolling;
    
    BOOL isGroupChat;
    NSMutableArray *groupMemberRecentObjects;

    //Moved from public .h
    SendButton *doneBtn;
    NSOperationQueue *chatHistoryQueue;
    int lastLoadedMsgNumber;
    
    RecentObject *openedRecent;
    
    BOOL isChatOpen;
    
    scsRightBarButtonType rightBarButtonType;
    
    BOOL isVerified;
}

@end


@implementation ChatViewController


#pragma mark - Lifecycle

dispatch_queue_t messageQueue() {
    static dispatch_once_t once;
    static dispatch_queue_t queue;
    dispatch_once(&once, ^{
        queue = dispatch_queue_create("com.something.myapp.backgroundQueue", 0);
    });
    return queue;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    sizingTextContainer = [[NSTextContainer alloc] init];
    sizingLayoutManager = [[NSLayoutManager alloc] init];
    [sizingLayoutManager addTextContainer:sizingTextContainer];
    
    sizingTextStorage = [[NSTextStorage alloc] init];
    [sizingTextStorage addLayoutManager:sizingLayoutManager];
    
    shouldCheckForMoreMessages = YES;
    isVerified = NO;
    
    lastLoadedMessageCount = 0;
    
    float viewHeight = CGRectGetHeight(self.view.frame) - [ChatUtilities utilitiesInstance].kStatusBarHeight - CGRectGetHeight(self.navigationController.navigationBar.frame);
    
    // long press recognizer on messages
    longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPressRecognizer.minimumPressDuration = 0.25;
    longPressRecognizer.cancelsTouchesInView = NO;
    
    [_chatTableView addGestureRecognizer:longPressRecognizer];
    _chatTableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [_chatTableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    
    
    // chat message action sheet
    audioPlaybackHolderView = [[AudioPlayBackHolderView alloc] initWithFrame:CGRectMake(0, viewHeight - kAudioPlayerFrameHeight, self.view.frame.size.width, kAudioPlayerFrameHeight)];
    audioPlaybackHolderView.hidden = YES;
    [audioPlaybackHolderView setBackgroundColor:[UIColor clearColor]];
    [self.view addSubview:audioPlaybackHolderView];
    
    _actionsheetViewRed.delegate = self;
    _actionsheetViewRed.parentViewController = self;
    
    
    // notify actionsheet that location permission has changed and button needs to be updated
    [[NSNotificationCenter defaultCenter] addObserver:_actionsheetViewRed selector:@selector(didChangeLocationAuthorizationStatus) name:kdidChangeLocationStatus object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willDismissWithActionSheet)       name:kActionSheetWillDismissItsSuperView object:nil];
    
    
    [self.view addObserver:self forKeyPath:@"frame" options:NSKeyValueObservingOptionNew context:nil];
    
    self.chatTableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
   // self.chatTableView.estimatedRowHeight = 100;
   // self.chatTableView.rowHeight = UITableViewAutomaticDimension;
#if HAS_DATA_RETENTION
    _dataRetentionWarningView.infoHolderVC = self;
    [_dataRetentionWarningView positionWarningAboveConstraint:_chatTableViewTopConstant];
#else
    _dataRetentionWarningView.hidden = YES;
    _dataRetentionWarningView.drButton.hidden = YES;
#endif // HAS_DATA_RETENTION
    
    rightBarButtonType = eRightBarButtonNone;
}

- (void)dealloc {
    
    [self removeAudioPlaybackHolderViewFrameObserver];
    
    // Remove Notification observers
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
}


-(void)viewDidLayoutSubviews
{
    if (!actionSheetView)
    {
        actionSheetView = [[ActionSheetWithKeyboardView alloc] initWithViewController:self];
        [actionSheetView setBackgroundColor:[UIColor whiteColor]];
        [self.view addSubview:actionSheetView];
        
        [actionSheetView setFontForTextField:[[ChatUtilities utilitiesInstance] getFontWithSize:18]];
        actionSheetView.delegate = self;
        [actionSheetView addActionSheetView:_actionsheetViewRed];
        
        SendButton *doneButton = [[SendButton alloc] init];
        [actionSheetView addDoneButton:doneButton];
        
        burnButton = [[UIButton alloc] init];
        [burnButton setBackgroundColor:[UIColor messageInputFieldBackgroundColor]];
        [burnButton setImage:[UIImage imageNamed:@"BurnOn.png"] forState:0];
        [actionSheetView addBurnButton:burnButton];
        
        plusButton = [[UIButton alloc] init];
        [plusButton setImage:[UIImage imageNamed:@"plusIcon.png"] forState:0];
        [plusButton setBackgroundColor:[UIColor messageInputFieldBackgroundColor]];
        [actionSheetView addAttachmentButton:plusButton];
        
        if ([[AudioPlaybackManager sharedManager] isPlaying]) {
            [[AudioPlaybackManager sharedManager] showPlayerInView:audioPlaybackHolderView];
            NSString *audioPlayingContactName = [AudioPlaybackManager sharedManager].chatObject.contactName;
            if ([audioPlayingContactName isEqualToString:lastOpenedUserNameForChat]) {
                // it's one of our messages playing
                [self animateAudioPlayerViewWithDirection:[NSNumber numberWithInt:1]];
            }
        }
        
        if ([[ChatUtilities utilitiesInstance] isNumber:lastOpenedUserNameForChat] && !isGroupChat)
        {
            [actionSheetView hideInputForNumberActionSheet];
        }

#if HAS_DATA_RETENTION
        // data retention
        [_dataRetentionWarningView enableWithRecipient:openedRecent];
        if ( (_dataRetentionWarningView.enabled) && ([UserService isDRBlockedForContact:openedRecent]) ) {
            doneButton.enabled = NO;
            doneButton.layer.opacity = 0.5; // doneButton does not have a disabled icon
            plusButton.enabled = NO;
            self.navigationItem.rightBarButtonItem.enabled = NO;
        }
#endif // HAS_DATA_RETENTION
    }
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    isChatOpen = YES;
    
    openedRecent = [ChatUtilities utilitiesInstance].selectedRecentObject;
    
    RecentObject *cachedRecent = [Switchboard.userResolver cachedRecentWithUUID:openedRecent.contactName];
    
    if (!cachedRecent)
    {
        //workaround to force resolve a RecentObject taken out of database or created after received message
        openedRecent.isPartiallyLoaded = YES;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectShouldResolveNotification object:self userInfo:@{kSCPRecentObjectDictionaryKey:openedRecent}];
    }
    [self requestAddressBookAvatar];
    
    if (openedRecent.isGroupRecent == 1)
    {
        isGroupChat = YES;
        [_addGroupChatMemberButton setHidden:NO];
    } else
    {
        isGroupChat = NO;
        [_addGroupChatMemberButton setHidden:YES];
    }
#ifdef randomSending
    [self sendTestMessage];
#endif
    if (!chatHistoryQueue) {
        chatHistoryQueue = [[NSOperationQueue alloc] init];
        chatHistoryQueue.maxConcurrentOperationCount = 1;
    }
    
    [self getMessageBubbleTextFontSize];
    [ChatUtilities utilitiesInstance].isChatThreadVisible = YES;
    [[ChatUtilities utilitiesInstance] setTimeStampHeight];
    
    shouldReloadTableWithAnimation = false;
    isScrolling = NO;
    
    
    if(!cancelReloadBeforeAppearing)
    {
        [self registerNotifications];
    }
    
    lastOpenedUserNameForChat = openedRecent.contactName;
    
    // when opening thread we mark all messages as read
    // for 1:1 conversation we iterate through all messages and set their isRead property to 1, launch burn timer and save the message
    // for conversations we do the same and send read receipts for sibling devices
    if (isGroupChat)
    {
        [[GroupChatManager sharedInstance] sendGroupReadReceiptsForGroup:openedRecent];
    }
    else
    {
        [[DBManager dBManagerInstance] markMessagesAsReadForConversation:openedRecent];
    }
    
    if ([[ChatUtilities utilitiesInstance] isNumber:lastOpenedUserNameForChat] && !isGroupChat) {
        // TODO, hide keyboard
        isNumber = YES;
    } else
    {
        isNumber = NO;
    }
    
    // if location sending for this contact is on, start updating location here
    if(openedRecent.shareLocationTime > time(NULL))
    {
        [[LocationManager sharedManager] startUpdatingLocation];
    }
    
    backButtonWithImage = [ChatUtilities getNavigationBarBackButton];
    [backButtonWithImage addTarget:self action:@selector(dismissChat:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *backBarButton = [[UIBarButtonItem alloc] initWithCustomView:backButtonWithImage];
    self.navigationItem.leftBarButtonItem = backBarButton;
    
    [self setUnreadMessageCountInOtherThreads];
    
    
    if (isGroupChat && rightBarButtonType != eRightBarButtonAddGroupMember)
    {
        [self performSelectorInBackground:@selector(addRightBarButtonForGroupChat) withObject:nil];
        rightBarButtonType = eRightBarButtonAddGroupMember;
    } else if (!isGroupChat && rightBarButtonType != eRightBarButtonCall)
    {
        // adds image for rightbarbuttonItem
        int navigationButtonSize = [ChatUtilities getNavigationBarButtonSize];
        UIButton *rightButtonWithImage = [UIButton buttonWithType:UIButtonTypeCustom];
        [rightButtonWithImage setTintColor:[UIColor whiteColor]];
        
        UIBarButtonItem *rightBarButton = [[UIBarButtonItem alloc] initWithCustomView:rightButtonWithImage];
        [rightButtonWithImage setFrame:CGRectMake(0,0,navigationButtonSize,navigationButtonSize)];
        [rightButtonWithImage addTarget:self action:@selector(callUser) forControlEvents:UIControlEventTouchUpInside];
        [rightButtonWithImage setAccessibilityLabel:NSLocalizedString(@"Call", nil)];
        [rightButtonWithImage setImage:[UIImage navigationBarCallButton]
                              forState:UIControlStateNormal];
        self.navigationItem.rightBarButtonItem = rightBarButton;
        rightBarButtonType = eRightBarButtonCall;
    }
    [self setNavigationBarTitle];
    
    if (![self.chatTableView numberOfSections])
    {
        lastLoadedMsgNumber = -1;
        
        // force hide the empty conversation view,
        // loadNextMessages will show again if it loads 0 messages
        [self updateEmptyConversationViews:YES];
        [self loadNextMessages];
    }
    
    // If view appears after closing attachment, restart burn timers
    //if(dismissedViewWithAttachment)
    [self reloadVisibleRowBurnTimers];
    
    _chatHistoryCnt = [_chatHistory count];
    
    
    if(_pendingContactAttachment) {
        
        [[ChatManager sharedManager] sendMessageWithContact:_pendingContactAttachment];
        _pendingContactAttachment = nil;
    }
    
    if(_pendingOpenInAttachmentURL) {
        
        // Copy URL for completion block cleanup
        NSURL *openInURL = _pendingOpenInAttachmentURL;
        [SCAttachment attachmentFromFileURL:openInURL
                                  withScale:1.
                                  thumbSize:CGSizeMake(300, 300)
                                   location:nil
                            completionBlock:^(NSError *error, SCAttachment *attachment) {
                                
                                // Delete original open-in copied file, 
                                // whether the attachment is good or not.
                                [SCFileManager deleteFileAtURL:openInURL];
                                
                                if(error) {
                                    NSLog(@"Error: %@", error);
                                    return;
                                }
                                
                                if(attachment)
                                    [[ChatManager sharedManager] sendMessageWithAttachment:attachment upload:YES forGroup:isGroupChat];
                            }];
        
        _pendingOpenInAttachmentURL = nil;
    }
    
    msgIDOfChatObjectInMenuController = nil;
    
    [[ChatUtilities utilitiesInstance] removeBadgesForConversation:openedRecent];
}

- (void)dismissChat:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self checkForwardedMSG];
    
    if(_chatHistory.count <= 0)
    {
        // GO - automatic keyboard opening is disabled, so the empty background welcoming screen could be presented to the user
        /*
         if (_messageTextView && _chatHistory.count <= 0 && !_supressFirstResponder) {
         [_messageTextView becomeFirstResponder];
         }
         */
        if(_supressFirstResponder)
            _supressFirstResponder = NO;
    }
    cancelReloadBeforeAppearing = NO;
}

// save chat history whenever window dissapears
-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear: animated];
    isChatOpen = NO;
    
    if(actionSheetView.messageTextView.text.length > 0)
    {
        [[ChatUtilities utilitiesInstance] setSavedMessageText:actionSheetView.messageTextView.text forContactName:[[ChatUtilities utilitiesInstance] addPeerInfo:lastOpenedUserNameForChat lowerCase:NO]];
    }
    [self resignFirstResponderForAction];
    
    // EA: FIXME: we cannot remove the progress observers because progress may continue if the user taps to preview an attachment
    
    // Do not unregister self from all notifications here. This will
    // unregister from all UIViewController callbacks, like this method.
    if (!cancelReloadBeforeAppearing)
    {
        [self deregisterNotifications];
    }
    
    if (!audioPlaybackHolderView.hidden) {
        [self removeAudioPlaybackHolderViewFrameObserver];
    }
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadVisibleRowBurnTimers) object:nil];
    
    [[LocationManager sharedManager] stopUpdatingLocation];
    
    if (openedRecent)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [[DBManager dBManagerInstance] saveRecentObject:openedRecent];
        });
    }
    
    [ChatUtilities utilitiesInstance].shouldOpenChatViewFromNotification = YES;
    [[ChatUtilities utilitiesInstance] removeBadgesForConversation:openedRecent];
    
}

-(void)viewDidDisappear:(BOOL)animated
{
    
    [ChatUtilities utilitiesInstance].isChatThreadVisible = NO;
}

#pragma mark - RecentObject notifications

-(void) recentObjectRemoved:(NSNotification *) note
{
    DDLogDebug(@"%s",__FUNCTION__);
    RecentObject *removedRecent = [note.userInfo objectForKey:kSCPRecentObjectDictionaryKey];
    if (removedRecent)
    {
        if ([removedRecent isEqual:openedRecent] || openedRecent == nil)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.transitionDelegate transitionToConversationsFromVC:self];
            });
        }
    }
}

-(void) recentObjectUpdated:(NSNotification *) note
{
    DDLogDebug(@"%s",__FUNCTION__);
    __block RecentObject *updatedRecent = (RecentObject *)[note.userInfo objectForKey:kSCPRecentObjectDictionaryKey];
    
    if (!updatedRecent || !openedRecent)
        return;
    
    __weak ChatViewController *weakSelf = self;
    
    // notification is called from background
    dispatch_async(dispatch_get_main_queue(), ^{
        
        __strong ChatViewController *strongSelf = weakSelf;
        
        if(!strongSelf)
            return;
        
        if(!updatedRecent || !openedRecent)
            return;
        
        if(![updatedRecent isEqual:openedRecent])
            return;
        
        [openedRecent updateWithRecent:updatedRecent];
        
        [self requestAddressBookAvatar];
        
        [strongSelf setNavigationBarTitle];
        [strongSelf scheduleTableReload];
        [strongSelf updateEmptyConversationViews:NO];
    });
}

#pragma mark - UIApplication notification

-(void) applicationDidBecomeActive
{
    [self scheduleTableReload];
}

-(void) applicationDidEnterBackground
{
    [self resignFirstResponderForAction];
}

#pragma mark - Accessibility

-(BOOL) accessibilityPerformEscape
{
    [self.navigationController popViewControllerAnimated:YES];
    
    return YES;
}

#pragma mark - Font Change
-(void) reloadChatBubbles:(NSNotification *) notification
{
    DDLogDebug(@"%s",__FUNCTION__);
    [self getMessageBubbleTextFontSize];

    [self scheduleTableReload];
    [self setNavigationBarTitle];
}

-(void) getMessageBubbleTextFontSize
{
    messageBubbleTextFontSize = [UIFont preferredFontForTextStyle:UIFontTextStyleBody].pointSize;
    if (messageBubbleTextFontSize > kMaxMessageTextFontSize) {
        messageBubbleTextFontSize = kMaxMessageTextFontSize;
    }
}
#pragma mark - Section sorting
-(NSMutableArray *) getChatSectionObjectsFromChatHistory:(NSMutableArray *) thisChatHistory
{
    //returns SCSChatSectionObject objects which contains chatObjects array of chatmessages for this section
    
    ChatObject *lastChatObject;
    SCSChatSectionObject *currentSectionObject;
    NSMutableArray * mutableConversation = [[NSMutableArray alloc] init];
    
    
    for (ChatObject *thisChatObject in thisChatHistory) {
        
        BOOL shouldAdd = YES;
        
        if(shouldAdd)
        {
            // if this is first object in array, add new SCSChatSectionObject
            //
            if(!lastChatObject)
            {
                currentSectionObject = [[SCSChatSectionObject alloc] init];
                currentSectionObject.headerTitle = [[ChatUtilities utilitiesInstance] takeHeaderTitleTimeFromDateStamp:thisChatObject.timeVal.tv_sec];
                //[mutableConversation addObject:lastSectionObject];
                
                BOOL added = NO;
                for (int i = 0; i<mutableConversation.count; i++)
                {
                    SCSChatSectionObject *previousSectionObject = (SCSChatSectionObject *)mutableConversation[i];
                    if (currentSectionObject.lastChatObjectTimeStamp > previousSectionObject.lastChatObjectTimeStamp)
                    {
                        [mutableConversation insertObject:currentSectionObject atIndex:i];
                        added = YES;
                        break;
                    }
                    
                }
                if (!added)
                {
                    [mutableConversation addObject:currentSectionObject];
                }
            }
            else
            {
                NSDate *lastChatObjectDate = [NSDate dateWithTimeIntervalSince1970:lastChatObject.timeVal.tv_sec];
                NSDate *thisChatObjectDate = [NSDate dateWithTimeIntervalSince1970:thisChatObject.timeVal.tv_sec];
                
                if(![[ChatUtilities utilitiesInstance] isDate:lastChatObjectDate sameDayAsDate:thisChatObjectDate])
                {
                    currentSectionObject = [[SCSChatSectionObject alloc] init];
                    currentSectionObject.headerTitle = [[ChatUtilities utilitiesInstance] takeHeaderTitleTimeFromDateStamp:thisChatObject.timeVal.tv_sec];
                    //[mutableConversation addObject:lastSectionObject];
                    
                    BOOL added = NO;
                    for (int i = 0; i<mutableConversation.count; i++)
                    {
                        SCSChatSectionObject *previousSectionObject = (SCSChatSectionObject *)mutableConversation[i];
                        if (currentSectionObject.lastChatObjectTimeStamp > previousSectionObject.lastChatObjectTimeStamp)
                        {
                            [mutableConversation insertObject:currentSectionObject atIndex:i];
                            added = YES;
                            break;
                        }
                    }
                    if (!added)
                    {
                        [mutableConversation addObject:currentSectionObject];
                    }
                }
            }
            currentSectionObject.lastChatObjectTimeStamp = thisChatObject.timeVal.tv_sec;
            
            [currentSectionObject.chatObjectsArray addObject:thisChatObject];
            lastChatObject = thisChatObject;
        }
    }
    return mutableConversation;
}

#pragma mark - NavBarTitle

-(void) setNavigationBarTitle
{
    if (!openedRecent)
        return;
    DDLogDebug(@"%s",__FUNCTION__);
    
    if(openedRecent.isGroupRecent)
    {
        [_contactNameLabel setHidden:YES];
    }
    else if ([[ChatUtilities utilitiesInstance] isNumber:lastOpenedUserNameForChat] && !openedRecent.abContact)
    {
        [_contactNameLabel setHidden:YES];
    }
    else
    {
        NSString *displayAlias = [[ChatUtilities utilitiesInstance] removePeerInfo:openedRecent.displayAlias
                                                                         lowerCase:NO];
        
        [_contactNameLabel setText:displayAlias];
        [_contactNameLabel setHidden:NO];
    }
    
    self.navigationItem.titleView = _navigationTitleView;
    
    _displayTitle = openedRecent.displayName;
    
    if(openedRecent.abContact && openedRecent.abContact.fullName)
        _displayTitle = openedRecent.abContact.fullName;
    
    NSString *peerLessContactName = [[ChatUtilities utilitiesInstance] removePeerInfo:openedRecent.contactName
      
                                                                            lowerCase:NO];
    if (!_displayTitle)
    {
        if(![[ChatUtilities utilitiesInstance] isUUID:peerLessContactName])
            _displayTitle = peerLessContactName;
        else
        {
            _displayTitle = [[ChatUtilities utilitiesInstance] getPrimaryAliasFromUser:peerLessContactName];
        }
    }

    _navigationTitleView.usernameLabel.text = _displayTitle;
    
    if(isNumber) {
        
        [_navigationTitleView.bottomStackView setHidden:YES];
        return;
    }
    
    if (!isVerified && !_navigationTitleView.verifiedLabel.hidden) {
        
        [UIView animateWithDuration:.25f
                         animations:^{
                             [_navigationTitleView.verifiedLabel setHidden:YES];
                         }];
    }
    
    if (!isGroupChat)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            isVerified = [[ChatUtilities utilitiesInstance] areAllDevicesVerifiedWithRecentObject:openedRecent];
            if (isVerified && _navigationTitleView.verifiedLabel.isHidden)
            {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

                    [UIView animateWithDuration:.25f
                                     animations:^{
                                         [_navigationTitleView.verifiedLabel setHidden:NO];
                                     }];
                });
            }
        });
    }
}

- (IBAction)navigationTitlePressAction:(UIGestureRecognizer *)gestureRecognizer
{
    [actionSheetView closeBurnSlider];
    
    if(isNumber)
        return;
    
    if(!cancelReloadBeforeAppearing)
    {
        cancelReloadBeforeAppearing = YES;
        
        if (isGroupChat)
        {
            [self performSegueWithIdentifier:@"groupInfoSegue" sender:nil];
        } else
        {
            [self performSegueWithIdentifier:@"deviceSegue" sender:nil];
        }
    }
}

#pragma mark - Call Peer

-(void) callUser
{
    if(![Switchboard allAccountsOnline])
    {
        [[ChatUtilities utilitiesInstance] showNoNetworkErrorForConversation:openedRecent actionType:eCall];
        return;
    }
    cancelReloadBeforeAppearing = YES;
    [self resignFirstResponderForAction];
    if ([_transitionDelegate respondsToSelector:@selector(placeCallFromVC:withNumber:)]) {
        [_transitionDelegate placeCallFromVC:self withNumber:lastOpenedUserNameForChat];
    }
}

#pragma mark - Section sorting

-(ChatObject *) getPreviousChatObject:(NSIndexPath *) indexPath
{
    ChatObject *previousChatObject = nil;
    
    // if we need to take it from the previous section
    if (indexPath.row - 1 < 0) {
        SCSChatSectionObject *previousSection = nil;
        
        // if previous section exists
        if (indexPath.section - 1 > 0)
        {
            previousSection = _chatHistory[indexPath.section - 1];
            previousChatObject = previousSection.chatObjectsArray.lastObject;
        }
    } else
    {
        SCSChatSectionObject *thisSectionObject = _chatHistory[indexPath.section];
        
        if([thisSectionObject.chatObjectsArray count] <= indexPath.row - 1)
            return 0;
        
        previousChatObject = thisSectionObject.chatObjectsArray[indexPath.row - 1];
    }
    
    return previousChatObject;
}


-(void) checkForwardedMSG
{
    [self checkForForwardedMessage];
}

-(void) checkForForwardedMessage
{
    
    ChatObject *forwardedChatObject = [[ChatUtilities utilitiesInstance].forwardedMessageData objectForKey:@"forwardedChatObject"];
    if(forwardedChatObject)
    {
        if(forwardedChatObject.attachment)
        {
            [[ChatManager sharedManager] sendMessageWithAttachment:forwardedChatObject.attachment upload:NO forGroup:isGroupChat];
        } else if(forwardedChatObject.messageText.length  > 0)
        {
            actionSheetView.messageTextView.text = forwardedChatObject.messageText;
            actionSheetView.messageTextView.placeholder = nil;
        }
        
    } else
    {
        NSString *savedMessageText = [[ChatUtilities utilitiesInstance].savedMessageTexts objectForKey:[[ChatUtilities utilitiesInstance] addPeerInfo:lastOpenedUserNameForChat lowerCase:NO]];
        if(savedMessageText)
        {
            actionSheetView.messageTextView.placeholder = nil;

            actionSheetView.messageTextView.text = savedMessageText;
            [[ChatUtilities utilitiesInstance] removeSavedMessageTextForContactName:[[ChatUtilities utilitiesInstance] addPeerInfo:lastOpenedUserNameForChat lowerCase:NO]];
            
            //remove it from savedUnsentNewConversationMessages
            [[ChatUtilities utilitiesInstance] removeSavedUnsentNewConversationMessageForContactName:[[ChatUtilities utilitiesInstance] addPeerInfo:lastOpenedUserNameForChat lowerCase:NO]];
            
            if (!_supressFirstResponder)
            {
                [actionSheetView.messageTextView becomeFirstResponder];
            }
        } else
        {
            actionSheetView.messageTextView.placeholder = NSLocalizedString(@"Say something...", nil);
        }
    }
    
    [[ChatUtilities utilitiesInstance].forwardedMessageData removeAllObjects];
}


#pragma mark UITableViewDelegate

-(BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    SCSChatSectionObject *thisSection = (SCSChatSectionObject*) [_chatHistory objectAtIndex:indexPath.section];
    
    if([thisSection.chatObjectsArray count] <= indexPath.row)
        return NO;
    
    ChatObject *chatObjectToRemove = (ChatObject*) [thisSection.chatObjectsArray objectAtIndex:indexPath.row];
    
    if(chatObjectToRemove.errorString.length > 0)
        return YES;
    else
        return NO;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    [savedBurnNowButton removeFromSuperview];
}


-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 40;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _chatHistory.count;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(_chatHistory.count <= 0)
    {
        return 0;
    }
    SCSChatSectionObject *thisSectionObject = (SCSChatSectionObject *)_chatHistory[section];
    if(!thisSectionObject)
    {
        return 0;
    }
    return thisSectionObject.chatObjectsArray.count;
}


-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    SCSChatSectionObject *sectionObject = (SCSChatSectionObject *)_chatHistory[section];
    
    UILabel *sectionTitleLabel = [UILabel new];
    [sectionTitleLabel setFont:[[ChatUtilities utilitiesInstance] getFontWithSize:13.]];
    [sectionTitleLabel setTextColor:[UIColor whiteColor]];
    sectionTitleLabel.text = sectionObject.headerTitle;
    [sectionTitleLabel sizeToFit];
    
    float headerHeight = 20.;
    
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(
                                                                  (self.view.frame.size.width - (CGRectGetWidth(sectionTitleLabel.frame) + 10.)) / 2.,
                                                                  (40. - headerHeight) / 2.,
                                                                  CGRectGetWidth(sectionTitleLabel.frame) + 20.,
                                                                  headerHeight
                                                                  )];
    [headerView setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:.6]];
    headerView.layer.cornerRadius = headerView.frame.size.height / 2;
    headerView.layer.masksToBounds = YES;
    
    sectionTitleLabel.center = headerView.center;
    
    UIView *backgroundView = [UIView new];
    [backgroundView addSubview:headerView];
    [backgroundView addSubview:sectionTitleLabel];
    
    return backgroundView;
}


-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    lastClickedIndexPath = indexPath;
    SCSChatSectionObject *sectionObject = _chatHistory[indexPath.section];
    
    if([sectionObject.chatObjectsArray count] <= indexPath.row)
        return;
    
    ChatObject *thisChatObject = (ChatObject*)sectionObject.chatObjectsArray[indexPath.row];
    
    if(thisChatObject.hasFailedAttachment){
        //TODO do something better, try to download TOC automaticaly if we have network
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:nil
                                                                    message:NSLocalizedString(@"Attachment failed", nil)
                                                             preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *tryAgain = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"Try Again", nil)
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *action) {
                                       [[ChatManager sharedManager] downloadChatObjectTOC:thisChatObject];
                                   }
                                   ];
        [ac addAction:tryAgain];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction * _Nonnull action) {
                                                                 
                                                             }];
        [ac addAction:cancelAction];
        
        [self presentViewController:ac animated:YES completion:nil];
        
        
        return;
    }
    
    BOOL bIsAudio = NO;
    if (thisChatObject.attachment) {
        NSString *mediaType = [thisChatObject.attachment.metadata objectForKey:kSCloudMetaData_MediaType];
        bIsAudio = ([(__bridge NSString *)kUTTypeAudio isEqualToString:mediaType]);
    }
    
    /*
    if (thisChatObject.isFailed && !thisChatObject.isCall) {
        if([_messageTextView isFirstResponder])
        {
            [_messageTextView resignFirstResponder];
        }
        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Message Options", nil)
                                                                 delegate:self
                                                        cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                   destructiveButtonTitle:nil
                                                        otherButtonTitles:nil];
        [actionSheet addButtonWithTitle:NSLocalizedString(@"Try Again", nil)];
        if ( (thisChatObject.attachment)
            && ([thisChatObject.attachment.cloudKey length] > 0)
            && ([thisChatObject.attachment.cloudLocator length] > 0) ) {
            [actionSheet addButtonWithTitle:(bIsAudio) ? NSLocalizedString(@"Play Audio", nil) : NSLocalizedString(@"View", nil)];
        }
        [actionSheet showInView:self.view];
        return;
    }*/
}

- (void)presentAttachmentForRow:(NSIndexPath*)indexPath {
    
    SCSChatSectionObject *sectionObject = (SCSChatSectionObject *)_chatHistory[indexPath.section];
    
    if(indexPath.row > sectionObject.chatObjectsArray.count - 1)
        return;
    
    ChatObject *thisChatObject = (ChatObject*) sectionObject.chatObjectsArray[indexPath.row];
    
    if (thisChatObject && thisChatObject.attachment)
        [self _presentAttachment:thisChatObject];
}

/* not used
#pragma mark - UIActionSheetDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        // don't follow through sending the message
        return;
    }
    
    if (lastClickedIndexPath) {
        
        SCSChatSectionObject *sectionObject = _chatHistory[lastClickedIndexPath.section];
        
        if([sectionObject.chatObjectsArray count] <= lastClickedIndexPath.row)
            return;
    
        ChatObject *thisChatObject = (ChatObject *)sectionObject.chatObjectsArray[lastClickedIndexPath.row];
        switch (buttonIndex) {
            case 1: // resend
                thisChatObject.iSendingNow = 1;
                thisChatObject.messageStatus = 0;
                if (thisChatObject.attachment)
                    [[ChatManager sharedManager] uploadAttachmentForChatObject:thisChatObject];
                else
                    [[ChatManager sharedManager] sendChatObjectAsync:thisChatObject];
                [_chatTableView reloadRowsAtIndexPaths:@[lastClickedIndexPath] withRowAnimation:UITableViewRowAnimationNone];
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
*/

-(void) scrollViewDidScroll:(UIScrollView *)scrollView
{
    [savedBurnNowButton removeFromSuperview];
    [self didHideMenuController:nil];
    shouldReloadTableWithAnimation = YES;
    
    if(_allowScrollToLoad && scrollView.contentOffset.y <= 100. && shouldCheckForMoreMessages)
    {
        _allowScrollToLoad = NO;
        
        shouldCheckForMoreMessages = NO;
        [self loadNextMessages];
    }
    
    CGPoint touchPositionInViewController = [scrollView.panGestureRecognizer locationInView:self.view];
    
    
    lastTouchPositionInViewController = touchPositionInViewController;
    if (scrollView.panGestureRecognizer.state != UIGestureRecognizerStatePossible) {
        
        float bottomEdge = scrollView.contentOffset.y + scrollView.frame.size.height;
        if ((!(bottomEdge >= scrollView.contentSize.height) && scrollView.contentOffset.y > 0) || (scrollView.contentSize.height < self.view.bounds.size.height)) {
            float scrollingDifference = scrollView.contentOffset.y - lastContentOffset;
            if (((scrollingDifference <5 && !headerOpened) || (scrollingDifference >5 && headerOpened)) && fabs(scrollingDifference) >=5)
            {
                [self animateHeader];
            }
        }
    }
    
    [actionSheetView scrollViewDidScroll:scrollView];
    lastContentOffset = scrollView.contentOffset.y;
}

-(void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [actionSheetView scrollViewDidEndDecelerating:scrollView];
}

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [actionSheetView closeBurnSlider];
    isScrolling = YES;
    _allowScrollToLoad = YES;
}

-(void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    isScrolling = NO;
    [actionSheetView scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
}


static const int headerViewHeight = 25;
-(void) animateHeader
{
    if (_contactNameLabel.hidden) {
        return;
    }
    [self.view layoutIfNeeded];
    
#if HAS_DATA_RETENTION
    CGRect drFrame = _dataRetentionWarningView.frame;
#endif // HAS_DATA_RETENTION
    if( !headerOpened )
    {
       // [self.chatTableView beginUpdates];
        //self.chatTableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 25)];
        //[self.chatTableView endUpdates];
        _chatTableViewTopConstant.constant = headerViewHeight;
#if HAS_DATA_RETENTION
        if (_dataRetentionWarningView.enabled)
            _chatTableViewTopConstant.constant += drFrame.size.height;
#endif // HAS_DATA_RETENTION
       
        [UIView animateWithDuration:0.15f animations:^(void){
#if HAS_DATA_RETENTION
            if (_dataRetentionWarningView.enabled)
                _dataRetentionWarningView.warningViewTopConstant.constant = headerViewHeight;
#endif // HAS_DATA_RETENTION
            _headerViewTopConstant.constant = 0;
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished){
            
        }];
    } else
    {
       // self.chatTableView.tableHeaderView = nil;
#if HAS_DATA_RETENTION
        if (_dataRetentionWarningView.enabled)
            _chatTableViewTopConstant.constant = drFrame.size.height;
        else
#endif // HAS_DATA_RETENTION
            _chatTableViewTopConstant.constant = 0;

        [UIView animateWithDuration:0.15f animations:^(void){
#if HAS_DATA_RETENTION
            if (_dataRetentionWarningView.enabled)
                _dataRetentionWarningView.warningViewTopConstant.constant = 0;
#endif // HAS_DATA_RETENTION
            _headerViewTopConstant.constant = -50;
            [self.view layoutIfNeeded];
        }];
    }
    headerOpened = !headerOpened;
}

/**
 * animate row displaying
 * push each cell 50 points down or up depending on scroll direction
 **/
-(void)tableView:(UITableView *)tableView willDisplayCell:(ChatBubbleCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath{
    
    SCSChatSectionObject *sectionObject = (SCSChatSectionObject *)_chatHistory[indexPath.section];
    
    if([sectionObject.chatObjectsArray count] <= indexPath.row)
        return;
    
    ChatObject *thisChatObject = (ChatObject*) sectionObject.chatObjectsArray[indexPath.row];
    
    // if message is not read set it to already read
    if(thisChatObject.isRead == -1 && (thisChatObject.isReceived == 1 || thisChatObject.isCall))
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            //GO - do this only when app is open
            UIApplicationState state = [[UIApplication sharedApplication] applicationState];
            if (state != UIApplicationStateBackground && state != UIApplicationStateInactive)
            {
                if (isGroupChat)
                {
                    [[GroupChatManager sharedInstance] sendGroupReadReceipts:@[thisChatObject]];
                } else
                {
                    [[DBManager dBManagerInstance] setOffBurnTimerForBurnTime:thisChatObject.burnTime andChatObject:thisChatObject checkForRemoveal:NO];
                    [[DBManager dBManagerInstance] sendReadNotification:thisChatObject];
                    thisChatObject.isRead = 1;
                    [[DBManager dBManagerInstance] saveMessage:thisChatObject];
                }
            }
        });
    }
}

const int kBurnButtonSpacing = 100;
const int kContactImageViewSize = 60;
const int kAttachmentMessageSpacingtoBottom = 51;
//const int kTextMessageSpacingtoBottom = 35 + 16;
const int defaultLoadingAttachmentRowHeight = 79;
const int kDefaultCallCellHeight = 55;
const int kGroupStatusMessageSpacing = 10;

const int kMinChatBubbleWidth = 100;

const int kSentMessageLeadingOffset = 110;
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    int messageStatusSpacing = [[ChatUtilities utilitiesInstance] getFontWithSize:messageBubbleTextFontSize].pointSize;
    int spacingToBottom = 35 + messageStatusSpacing;
    
    SCSChatSectionObject *sectionObject = (SCSChatSectionObject *)_chatHistory[indexPath.section];
    
    if([sectionObject.chatObjectsArray count] <= indexPath.row)
        return 0;
    
    ChatObject *thisChatObject = sectionObject.chatObjectsArray[indexPath.row];
    ChatObject *previousChatObject = [self getPreviousChatObject:indexPath];
    
    
    int senderNameSpacing = 0;
    if (![previousChatObject.senderId isEqualToString:thisChatObject.senderId] && isGroupChat && thisChatObject.isReceived == 1)
    {
        senderNameSpacing = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote].pointSize;
    }
    
    if (thisChatObject.errorString)
    {
        spacingToBottom = 5;
    }
    
    
    int widthSubstraction = kBurnButtonSpacing;
    if (thisChatObject.isReceived == 1)
    {
        widthSubstraction += kContactImageViewSize;
    } else
    {
        widthSubstraction = kSentMessageLeadingOffset;
    }
    if (thisChatObject.isCall)
    {
        return kDefaultCallCellHeight;
    }
    if (thisChatObject.isAttachment)
    {
        if (thisChatObject.imageThumbnail)
        {
            return thisChatObject.imageThumbnailFrameSize.height + spacingToBottom + senderNameSpacing;
        } else
        {
            return defaultLoadingAttachmentRowHeight + kAttachmentMessageSpacingtoBottom + senderNameSpacing;
        }
    }
        
        CGSize maximumLabelSize = CGSizeMake(CGRectGetWidth(self.view.frame) - widthSubstraction, CGFLOAT_MAX);
    
    NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:thisChatObject.messageText attributes:@{NSFontAttributeName:[[ChatUtilities utilitiesInstance] getFontWithSize:messageBubbleTextFontSize]}];
    
    [sizingTextContainer setSize:maximumLabelSize];
    [sizingTextStorage setAttributedString:attrString];
    
    
    CGFloat formattedStringHeight = ceilf([sizingLayoutManager usedRectForTextContainer:sizingTextContainer].size.height);
    
    CGFloat formattedStringWidth = ceilf([sizingLayoutManager usedRectForTextContainer:sizingTextContainer].size.width);
    if (formattedStringWidth < kMinChatBubbleWidth)
    {
        formattedStringWidth = kMinChatBubbleWidth;
    }
    
    thisChatObject.messageTextViewSize = CGSizeMake(formattedStringWidth, formattedStringHeight);
    if (thisChatObject.isInvitationChatObject == 1)
    {
        return roundf(formattedStringHeight + kGroupStatusMessageSpacing);
    }
    return roundf(formattedStringHeight + spacingToBottom + senderNameSpacing);
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *sentTextCellIdentifier = @"sentTextCell";
    static NSString *receivedTextCellIdentifier = @"receivedTextCell";
    static NSString *sentCellIdentifier = @"sentCell";
    static NSString *receivedCellIdentifier = @"receivedCell";
    static NSString *callCellIdentifier = @"callCell";
    static NSString *errorCellIdentifier = @"errorCell";
    static NSString *invitationCellIdentifier = @"invitationCell";
    ChatBubbleCell *cell = nil;
    
    SCSChatSectionObject *sectionObject = (SCSChatSectionObject *)_chatHistory[indexPath.section];
    
    
    // should return empty cell
    if (sectionObject.chatObjectsArray.count <= indexPath.row) {
        return (ChatBubbleCell *)[_chatTableView dequeueReusableCellWithIdentifier:receivedCellIdentifier];
    }
    ChatObject *thisChatObject = sectionObject.chatObjectsArray[indexPath.row];
    
    if (thisChatObject.isInvitationChatObject == 1)
    {
        cell = (ChatBubbleCell *)[_chatTableView dequeueReusableCellWithIdentifier:invitationCellIdentifier];
    } else
    {
        if(thisChatObject.isCall)
        {
            cell = (ChatBubbleCell *)[_chatTableView dequeueReusableCellWithIdentifier:callCellIdentifier];
        } else if(thisChatObject.isReceived == 0)
        {
            if (thisChatObject.attachment) {
                cell = (ChatBubbleCell *)[_chatTableView dequeueReusableCellWithIdentifier:sentCellIdentifier];
            } else
            {
                cell = (ChatBubbleCell *)[_chatTableView dequeueReusableCellWithIdentifier:sentTextCellIdentifier];
            }
        } else if(thisChatObject.isReceived == 1)
        {
            if (thisChatObject.attachment) {
                cell = (ChatBubbleCell *)[_chatTableView dequeueReusableCellWithIdentifier:receivedCellIdentifier];
            } else
            {
                cell = (ChatBubbleCell *)[_chatTableView dequeueReusableCellWithIdentifier:receivedTextCellIdentifier];
            }
        }
    }
    
    if (thisChatObject.errorString)
    {
        cell = (ChatBubbleCell *)[_chatTableView dequeueReusableCellWithIdentifier:errorCellIdentifier];
    }
    [cell setBubbleCellDelegate:self];
    
    
    if(thisChatObject.iDidBurnAnimation == 0)
    {
        cell.contentView.alpha = 1.0f;
    }
    else
    {
        cell.contentView.alpha = 0.0f;
    }
    
    ChatBubbleCell *chatBubbleCell = cell;
    
    NSDictionary *burnDictionary = [[ChatUtilities utilitiesInstance] getBurnNoticeRemainingTime:thisChatObject];
    NSString *accessibilityStatus;
    NSString *accessibilityContent;
    chatBubbleCell.bubbleCellDelegate = self;
    
    chatBubbleCell.thisChatObject = thisChatObject;
    
    if (thisChatObject.errorString) {
        chatBubbleCell.errorLabel.text = thisChatObject.messageText;
    }
    
    if (thisChatObject.isInvitationChatObject == 1)
    {
        chatBubbleCell.inviteLabel.text = thisChatObject.messageText;
        return chatBubbleCell;
    }
    
    if (thisChatObject.isShowingBurnButton)
    {
        if (thisChatObject.isCall) {
            chatBubbleCell.callBackgroundViewLeadingConstraint.constant = 50;
        }
        [chatBubbleCell.burnButton setHidden:NO];
    } else
    {
        
        if (thisChatObject.isCall) {
            chatBubbleCell.callBackgroundViewLeadingConstraint.constant = 0;
        }
        [chatBubbleCell.burnButton setHidden:YES];
    }
    
    chatBubbleCell.burnButton.thisChatobject = thisChatObject;
    
    chatBubbleCell.burnTimeLabel.font = [[ChatUtilities utilitiesInstance] getFontWithSize:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote].pointSize];
    
    NSString *accessibilityConent;
    if (thisChatObject.isCall)
    {
        
        UIColor *tintColor = [UIColor lightGrayColor];
        UIImage *arrowImage = [UIImage incomingCallEventArrow];
        
        if (!thisChatObject.isIncomingCall) {
            arrowImage = [UIImage outgoingCallEventArrow];
        }
        switch (thisChatObject.callState) {
            case eDialedEnded:
            case eDialedNoAnswer:
                tintColor = [UIColor recentsOutgoingCallColor];
                break;
            case eIncomingAnswered:
                tintColor = [UIColor recentsIncomingCallColor];
                break;
            case eIncomingMissed:
                tintColor = [UIColor recentsMissedCallColor];
                break;
            case eSipError:
                tintColor = [UIColor recentsMissedCallColor];
                break;
            case eIncomingDeclined:
                tintColor = [UIColor recentsMissedCallColor];
                break;
            default:
                break;
        }
        
        [chatBubbleCell.phoneIconImageView setImage:[arrowImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
        [chatBubbleCell.phoneIconImageView setTintColor:tintColor];
        
        
        [chatBubbleCell.callInfoLabel setText:thisChatObject.messageText];
        [chatBubbleCell.callInfoLabel setTextColor:tintColor];
        chatBubbleCell.callInfoLabel.font = [[ChatUtilities utilitiesInstance] getFontWithSize:messageBubbleTextFontSize];
        [chatBubbleCell.callTimeStampLabel setText:[[ChatUtilities utilitiesInstance] takeTimeFromDateStamp:thisChatObject.timeVal.tv_sec]];
        
        chatBubbleCell.callTimeStampLabel.font = [[ChatUtilities utilitiesInstance] getFontWithSize:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote].pointSize];
    } else
    {
        if(thisChatObject.isReceived != 1)
        {
            if (!isGroupChat)
            {
                chatBubbleCell.groupSenderLabel.text = nil;
                [chatBubbleCell.statusLabel setTextColor:[UIColor chatBubbleStatusFontColor]];
                if(thisChatObject.isSynced && thisChatObject.isRead == 0)
                {
                    chatBubbleCell.statusLabel.text = NSLocalizedString(@"Synced", nil);
                }
                else if(thisChatObject.isRead == 1){
                    thisChatObject.iSendingNow = 0;
                    [chatBubbleCell.progressView setHidden:YES];
                    chatBubbleCell.statusLabel.text = NSLocalizedString(@"Read", nil);
                }
                else if(thisChatObject.delivered){
                    thisChatObject.iSendingNow = 0;
                    [chatBubbleCell.progressView setHidden:YES];
                    chatBubbleCell.statusLabel.text = NSLocalizedString(@"Delivered", nil);
                }
                else if(thisChatObject.messageStatus == 202 || thisChatObject.messageStatus==200){
                    thisChatObject.iSendingNow = 0;
                    [chatBubbleCell.progressView setHidden:YES];

                    chatBubbleCell.statusLabel.text = NSLocalizedString(@"Sent", nil);
                }
                else if(thisChatObject.iSendingNow == 1){
                    chatBubbleCell.statusLabel.text = NSLocalizedString(@"Preparing...", nil);
                }
                else if(thisChatObject.isFailed){
                    [chatBubbleCell.statusLabel setTextColor:[UIColor redColor]];
                    chatBubbleCell.statusLabel.text = NSLocalizedString(@"Failed",nil);
                }
                else if(thisChatObject.messageIdentifier != 0 && thisChatObject.messageStatus != 200)
                {
                    if(thisChatObject.isSynced)
                    {
                        chatBubbleCell.statusLabel.text = NSLocalizedString(@"Synced", nil);
                    }
                    else if(thisChatObject.isRead){
                        thisChatObject.iSendingNow = 0;
                        [chatBubbleCell.progressView setHidden:YES];
                        chatBubbleCell.statusLabel.text = NSLocalizedString(@"Read", nil);
                    }
                    else if(thisChatObject.delivered){
                        thisChatObject.iSendingNow = 0;
                        [chatBubbleCell.progressView setHidden:YES];
                        chatBubbleCell.statusLabel.text = NSLocalizedString(@"Delivered", nil);
                    }
                    else if(thisChatObject.messageStatus == 202 || thisChatObject.messageStatus==200){
                        thisChatObject.iSendingNow = 0;
                        [chatBubbleCell.progressView setHidden:YES];
                        chatBubbleCell.statusLabel.text = NSLocalizedString(@"Sent", nil);
                    }
                    else if(thisChatObject.iSendingNow == 1){
                        chatBubbleCell.statusLabel.text = NSLocalizedString(@"Preparing...", nil);
                    }
                    else if(thisChatObject.isFailed){
                        [chatBubbleCell.statusLabel setTextColor:[UIColor redColor]];
                        chatBubbleCell.statusLabel.text = NSLocalizedString(@"Failed",nil);
                    }
                    else if(thisChatObject.messageIdentifier != 0 && thisChatObject.messageStatus != 200)
                    {
                        chatBubbleCell.statusLabel.text = NSLocalizedString(@"Sending", nil);
                    }
                    else if(thisChatObject.messageStatus>=0 && (thisChatObject.messageIdentifier==0 && (thisChatObject.iSendingNow == 1 || thisChatObject.iSendingNow == 0))){//do not show prep if thisChatObject.messageIdentifier
                        chatBubbleCell.statusLabel.text = NSLocalizedString(@"Preparing...", nil);
                        
                    }else
                    {
                        [chatBubbleCell.statusLabel setTextColor:[UIColor redColor]];
                        chatBubbleCell.statusLabel.text = NSLocalizedString(@"Failed", nil);
                    }
                }
                if( thisChatObject.errorStringExistingMsg && thisChatObject.errorStringExistingMsg.length>0){
                    if(chatBubbleCell.statusLabel.text && chatBubbleCell.statusLabel.text.length>0){
                        chatBubbleCell.statusLabel.text = [chatBubbleCell.statusLabel.text stringByAppendingString:@" !"];
                    }
                }
            } else
            {
                [chatBubbleCell.progressView setHidden:YES];
                chatBubbleCell.statusLabel.text = @"";
            }
        } else
        {
            chatBubbleCell.statusLabel.text = @"";
            NSString *contactName = nil;
            if (isGroupChat)
            {
                contactName = thisChatObject.senderId;
            } else
            {
                contactName = lastOpenedUserNameForChat;
            }
            
            ChatObject *previousChatObject = [self getPreviousChatObject:indexPath];
            
            if ([previousChatObject.senderId isEqualToString:thisChatObject.senderId] && isGroupChat)
            {
                chatBubbleCell.groupSenderLabel.text = nil;
                [chatBubbleCell.messageContactView setHidden:YES];
            } else
            {
                chatBubbleCell.groupSenderLabel.text = thisChatObject.senderDisplayName;
                [chatBubbleCell.groupSenderLabel setFont:[[ChatUtilities utilitiesInstance] getFontWithSize:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote].pointSize]];
                [chatBubbleCell.messageContactView setHidden:NO];
                
                if (openedRecent)
                {
                    UIImage *contactImage = [AvatarManager avatarImageForChatObject:thisChatObject size:eAvatarSizeSmall];
                    [chatBubbleCell.messageContactView setImage:contactImage];
                }
            }
        }
        
        
        chatBubbleCell.timeStampLabel.text = [[ChatUtilities utilitiesInstance] takeTimeFromDateStamp:(int)thisChatObject.unixTimeStamp];
        chatBubbleCell.timeStampLabel.font = [[ChatUtilities utilitiesInstance] getFontWithSize:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote].pointSize];
        chatBubbleCell.statusLabel.font = [[ChatUtilities utilitiesInstance] getFontWithSize:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote].pointSize];
        
        
        
        [chatBubbleCell.playVideoImage setHidden:YES];
        [chatBubbleCell.activityIndicator stopAnimating];
        // image message
        if(thisChatObject.imageThumbnail)
        {
            BOOL isVideo = NO;
            
            if(thisChatObject.attachment && thisChatObject.attachment.metadata)
            {
                NSString *attachmentMediaType = (NSString*)[thisChatObject.attachment.metadata objectForKey:@"MediaType"];
                
                if([attachmentMediaType isEqualToString:(NSString*)kUTTypeMovie])
                {
                    isVideo = YES;
                    
                    // TODO: We can show the video duration under the play button, fetching it as well from the metadata dictionary:
                    // [[thisChatObject.attachment.metadata objectForKey:@"Duration"] doubleValue];
                }
            }
            if (!thisChatObject.isAudioAttachment)
            {
                [chatBubbleCell.playVideoImage setHidden:!isVideo];
            } else
            {
                [chatBubbleCell.playVideoImage setHidden:thisChatObject.containsWaveForm];
            }
            
            [chatBubbleCell.messageImageView setHidden:NO];
            chatBubbleCell.messageImageView.image = thisChatObject.imageThumbnail;
            NSString *mediaType = [thisChatObject.attachment.metadata objectForKey:kSCloudMetaData_MediaType];
            
            accessibilityContent = mediaType;
            
            chatBubbleCell.accessibilityTraits =  UIAccessibilityTraitStaticText;
            chatBubbleCell.contentView.accessibilityElementsHidden = YES;
            chatBubbleCell.messageImageView.accessibilityElementsHidden = YES;
            if (!isGroupChat)
            {
                chatBubbleCell.progressView.hidden = !thisChatObject.iSendingNow;
            }
            
        } else if (thisChatObject.messageText.length > 0 && !thisChatObject.isAttachment)
        {
            [chatBubbleCell.progressView setHidden:YES];
            accessibilityContent = thisChatObject.messageText;
            chatBubbleCell.messageTextView.thisChatObject = thisChatObject;
            chatBubbleCell.messageImageView.image = nil;
            
            chatBubbleCell.messageTextView.text = thisChatObject.messageText;
            
            if (thisChatObject.messageTextViewSize.width < 100)
            {
                thisChatObject.messageTextViewSize = CGSizeMake(100, thisChatObject.messageTextViewSize.height);
            }
            chatBubbleCell.messageTextViewWidthConstant.constant = thisChatObject.messageTextViewSize.width;
            [chatBubbleCell.messageImageView setHidden:YES];
            [chatBubbleCell.timeStampLabel setHidden:NO];
            
            accessibilityConent = thisChatObject.messageText;
            if(thisChatObject.isReceived == 1)
            {
                [chatBubbleCell.messageTextView setTextColor:[UIColor receivedMessageFontColor]];
            }
            else
            {
                [chatBubbleCell.messageTextView setTextColor:[UIColor sentMessageFontColor]];
            }
            chatBubbleCell.messageTextView.font = [[ChatUtilities utilitiesInstance] getFontWithSize:messageBubbleTextFontSize];
            chatBubbleCell.messageTextView.font = [[ChatUtilities utilitiesInstance] getFontWithSize:messageBubbleTextFontSize];
        }
        else if ((thisChatObject.isAttachment && !thisChatObject.attachment.metadata) && (thisChatObject.isReceived==1 || thisChatObject.isSynced))
        {
            if(thisChatObject.hasFailedAttachment == 0){
                [chatBubbleCell.progressView setHidden:YES];
                [chatBubbleCell.messageImageView setHidden:YES];
                chatBubbleCell.messageTextView.text = @"";
                chatBubbleCell.timeStampLabel.text = @"";
                [chatBubbleCell.activityIndicator startAnimating];
                
                chatBubbleCell.statusLabel.text = @"";
                //we have not thisChatObject.attachment.metadata if we are here
                // accessibilityContent = [thisChatObject.attachment.metadata objectForKey:@"MediaType"];
                
                // if we've received an attachment but don't yet have the TOC, try downloading it again here (for the thumbnail)
                if(!thisChatObject.didTryDownloadTOC){
                    [[ChatManager sharedManager] downloadChatObjectTOC:thisChatObject];
                }
            }
            else{
                
                // show loading indicator, attachment is being loaded
                [chatBubbleCell.progressView setHidden:YES];
                [chatBubbleCell.messageImageView setHidden:YES];
                chatBubbleCell.messageTextView.text = @"";
            }
        }
    }
    
    
    if(thisChatObject.burnTime > 0)
    {
        [chatBubbleCell.burnTimeLabel setHidden:NO];
        [chatBubbleCell.burnIconImageView setHidden:NO];
        NSString *burnTime = [burnDictionary objectForKey:@"burnTime"];
        chatBubbleCell.burnTimeLabel.text = burnTime;
    } else
    {
        chatBubbleCell.burnTimeLabel.text = @"";
        [chatBubbleCell.burnIconImageView setHidden:YES];
    }
    
    if(!thisChatObject.location)
    {
        [chatBubbleCell.locationButton setHidden:YES];
        [chatBubbleCell.locationButtonTouchArea setHidden:YES];
    } else
    {
        [chatBubbleCell.locationButton setHidden:NO];
        [chatBubbleCell.locationButtonTouchArea setHidden:NO];
        chatBubbleCell.locationButtonTouchArea.thisChatObject = thisChatObject;
    }
    
    // sent messages read status
    NSString *accessibilityMessageStatus;
    if(thisChatObject.isReceived == 1)
    {
        accessibilityStatus = @"received";
        accessibilityMessageStatus = @"";
    } else
    {
        accessibilityStatus = @"sent";
        accessibilityMessageStatus = [NSString stringWithFormat:NSLocalizedString(@"Status %@", nil),chatBubbleCell.statusLabel.text];
    }
    
    if(!thisChatObject.isCall)
    {
        NSString *senderName = nil;
        if (isGroupChat)
        {
            if (thisChatObject.isReceived == 1)
            {
                senderName = thisChatObject.senderDisplayName;
            } else
            {
                senderName = kYou;
            }
        } else
        {
            if (thisChatObject.isReceived == 1)
            {
                senderName = openedRecent.displayName;
            } else
            {
                senderName = kYou;
            }
        }
        NSString *accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"%@, %@, %@, Burn time %@, %@", nil),senderName,accessibilityContent, chatBubbleCell.timeStampLabel.text, [burnDictionary objectForKey:@"accessibilityBurnTime"], accessibilityMessageStatus];
        
        if(thisChatObject.location)
            accessibilityLabel = [accessibilityLabel stringByAppendingString:[NSString stringWithFormat:@", %@", NSLocalizedString(@"includes location", nil)]];
        
        [chatBubbleCell setAccessibilityLabel:accessibilityLabel];
        
    } else
    {
        NSString *accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"%@, %@, Burn time %@", nil),thisChatObject.messageText, chatBubbleCell.callTimeStampLabel.text, [burnDictionary objectForKey:@"accessibilityBurnTime"]];
        
        [chatBubbleCell setAccessibilityLabel:accessibilityLabel];
    }
    
    [cell layoutSubviews];
    return cell;
}

/*
 scrolls to first unread when chat thread is opened, if all messages are read, scroll to bottom
 */
-(void) scrollToFirstUnread
{
    NSIndexPath *indexPathToScroll = nil;
    
    for (int i = 0; i<_chatHistory.count; i++) {
        SCSChatSectionObject *sectionObject = (SCSChatSectionObject *)_chatHistory[i];
        for (int j = 0; j<sectionObject.chatObjectsArray.count; j++) {
            ChatObject *thisChatObject = (ChatObject *)sectionObject.chatObjectsArray[j];
            if(thisChatObject.isRead != 1 && !indexPathToScroll && !thisChatObject.isSynced)
            {
                indexPathToScroll = [NSIndexPath indexPathForRow:j inSection:i];
            }
        }
    }
    
    if(indexPathToScroll)
    {
        if (indexPathToScroll.section >= [_chatTableView numberOfSections])
            return;
        
        if (indexPathToScroll.row >= [_chatTableView numberOfRowsInSection:indexPathToScroll.section])
            return;

        [_chatTableView scrollToRowAtIndexPath:indexPathToScroll
                              atScrollPosition:UITableViewScrollPositionMiddle
                                      animated:NO];
    }
    else
    {
        [self scrollToBottom:NO];
    }
}

/**
 * insert row when sending or receiving new message
 * dont reload chatTableView
 */
-(void) reloadTableAndScrollToBottom:(BOOL)scrollToBottom animated:(BOOL) animated
{
    
    shouldReloadTableWithAnimation = NO;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadVisibleRowBurnTimers) object:nil];
    [self reloadVisibleRowBurnTimers];
    [self scrollToBottom:animated];
    shouldReloadTableWithAnimation = NO;
}

/**
 scrolls chatTableView to bottom
 @param animated - should scroll with animation
 */
-(void) scrollToBottom:(BOOL) animated
{
    if(_chatTableView.numberOfSections <= 0 && isScrolling)
    {
        return;
    }
    
    // scroll to bottom only if contentsize is bigger than the view
    if (self.chatTableView.contentSize.height > self.chatTableView.frame.size.height)
    {
        CGPoint bottomOffset = CGPointMake(0, self.chatTableView.contentSize.height - self.chatTableView.bounds.size.height);
        [self.chatTableView setContentOffset:bottomOffset animated:animated];
    }
}

-(void) scrollToCell:(UITableViewCell *) cell animated:(BOOL) animated
{
    if (cell && !isScrolling) {
        [self.chatTableView scrollToRowAtIndexPath:[self.chatTableView indexPathForCell:cell] atScrollPosition:UITableViewScrollPositionBottom animated:animated];
    }
}

#pragma mark sendReceiveMessages

- (IBAction)sendMessageAction:(id)sender {
    [self sendMessage:sender];
}

#pragma mark testing
-(void) sendTestMessage
{
    actionSheetView.messageTextView.text = [self generateRandomString];
    [self sendMessageAction:doneBtn];
    [self performSelector:@selector(sendTestMessage) withObject:nil afterDelay:1.0f];
}

-(NSString *) generateRandomString {
    
    int numRandChars = arc4random() % 100;;
    NSString *randomString = @"";
    for ( int i = 0; i < numRandChars; i++ ) {
        
        int intChar = arc4random()%126;
        
        // Limit to above 33+
        while ( intChar < 33 ) { intChar = arc4random()%126; }
        
        // Use ascii table to convert
        char aChar = (char)toascii(intChar);
        
        randomString = [NSString stringWithFormat:@"%@%c",randomString,aChar];
    }
    randomString = [randomString stringByAppendingString:@"END"];
    return randomString;
}
/**
 *Take content from _messageTextView and send message
 @param messageContext - context to create message with, can be image or button which got clicked on for send
 */
-(void) sendMessage:(NSObject*) messageContext
{
    DDLogDebug(@"%s",__FUNCTION__);
    SendButton *sender;
    if([messageContext isKindOfClass:[SendButton class]])
    {
        sender = (SendButton *) messageContext;
    }
    NSString *messageViewText = actionSheetView.messageTextView.text;
    
    //
    if(messageViewText.length > kMessageMaxLength)
    {        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Message is too long", nil) message:NSLocalizedString(@"You have exceeded the 5000 character limit, please shorten your message", nil) preferredStyle:UIAlertControllerStyleActionSheet];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    messageViewText = [messageViewText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (messageViewText.length>0)
    {
        if(sender)
            [sender clickAnimation];
        
        // if message text > 1000 characters send as text file attachment
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if ([messageViewText length] > 1000)
            {
                SCAttachment *attachment = [SCAttachment attachmentFromText:messageViewText];
                [[ChatManager sharedManager] sendMessageWithAttachment:attachment upload:YES forGroup:isGroupChat];
            } else
            {
                [[ChatManager sharedManager] sendTextMessage:messageViewText forGroup:isGroupChat];
            }
        });

        actionSheetView.messageTextView.text = @"";
        actionSheetView.messageTextView.placeholder = NSLocalizedString(@"Say something...", nil);
    }
}

-(void)receiveMessage:(NSNotification*)notification
{
    DDLogDebug(@"%s",__FUNCTION__);
    ChatObject *receivedChatObject = [notification.userInfo objectForKey:kSCPChatObjectDictionaryKey];
    if (!receivedChatObject)
        return;
    int receivedMessagesInOtherThreads = [[ChatUtilities utilitiesInstance] getBadgeValueWithoutUser:lastOpenedUserNameForChat];
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
    
    [self addChatObjectSorted:receivedChatObject];
}


- (void)receiveAttachment:(NSNotification *)note {
    
    DDLogDebug(@"%s",__FUNCTION__);
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSString *receivedMessageID = [note.userInfo objectForKey:kSCPMsgIdDictionaryKey];
        if (!receivedMessageID)
            return;
        // walk this array backwards as the one we're looking for is most likely at the end
        // GO - reversed array, added scrolling to bottom
        for (long i = _chatHistory.count-1; i>=0; i--) {
            SCSChatSectionObject *sectionObject = (SCSChatSectionObject *)_chatHistory[i];
            for (long j = sectionObject.chatObjectsArray.count-1; j >= 0; j --) {
                ChatObject *thisChatObject = (ChatObject *)sectionObject.chatObjectsArray[j];
                if ([receivedMessageID isEqualToString:thisChatObject.msgId]) {
                    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:j];
                    UITableViewCell *existingCell = [_chatTableView cellForRowAtIndexPath:indexPath];
                    // does this row exist yet in the tableview?
                    if (existingCell) {
                        [_chatTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                        [self scrollToBottom:YES];
                    }
                    break;
                }
                
            }
        }
    });
}

-(void) removeMessage:(NSNotification*) notification
{
    DDLogDebug(@"%s",__FUNCTION__);
    ChatObject *chatObjectToRemove = [notification.userInfo objectForKey:kSCPChatObjectDictionaryKey];
    
    if (chatObjectToRemove) {
        
        [self deleteMessage:chatObjectToRemove
                  forceBurn:NO];
    }
}

- (void)onChatObjectCreated:(NSNotification *)note {
    // update on main' thread
    DDLogDebug(@"%s",__FUNCTION__);
    dispatch_async(dispatch_get_main_queue(), ^{
        ChatObject *chatObject = [note.userInfo objectForKey:kSCPChatObjectDictionaryKey];
        if (!chatObject)
            return ;
        NSString *contactName = [[ChatUtilities utilitiesInstance] removePeerInfo:chatObject.contactName lowerCase:NO];
        NSString *openedContactName = [[ChatUtilities utilitiesInstance] removePeerInfo:lastOpenedUserNameForChat lowerCase:NO];
        if ([contactName isEqualToString:openedContactName])
        {
            [self addChatObjectSorted:chatObject];
        }
    });
}

// Find chatobject to replace in background
// Replace it on main and reload corresponding row in tableview
- (void)onChatObjectUpdated:(NSNotification *)note
{
    __block ChatObject *chatObject = [note.userInfo objectForKey:kSCPChatObjectDictionaryKey];
    DDLogDebug(@"%s",__FUNCTION__);
    if(chatObject)
        [self reportFailedChatToSentry:chatObject
                             extraInfo:note.userInfo];

    if (chatObject && [chatObject.contactName isEqualToString:lastOpenedUserNameForChat])
    {
        NSBlockOperation *stateChangeOperation = [NSBlockOperation new];
        [stateChangeOperation addExecutionBlock:^{
            BOOL reload = NO;
            for (int i = (int)_chatObjectsHistory.count; i > 0; i--)
            {
                ChatObject *ca = (ChatObject *)_chatObjectsHistory[i - 1];
                if ([ca.msgId isEqualToString:chatObject.msgId])
                {
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        [_chatObjectsHistory replaceObjectAtIndex:i - 1 withObject:chatObject];
                        
                        // replaces chatobject in section, quicker than resorting all sections again
                        for (int j = (int)_chatHistory.count - 1; j >=0; j--)
                        {
                            SCSChatSectionObject *sectionObject = (SCSChatSectionObject *)_chatHistory[j];
                            if ([sectionObject.chatObjectsArray containsObject:ca])
                            {
                                [sectionObject.chatObjectsArray replaceObjectAtIndex:[sectionObject.chatObjectsArray indexOfObject:ca] withObject:chatObject];
                            }
                        }
                        //chatHistory = [self getChatSectionObjectsFromChatHistory:chatObjectsHistory];
                    });
                    reload = YES;
                    break;
                }
            }
            
            if(reload)
            {
                // reload sync
                dispatch_sync(dispatch_get_main_queue(), ^{
                    NSIndexPath *indexPath = [self indexPathForMsgID:chatObject.msgId];
                    if (indexPath)
                    {
                        ChatBubbleCell *cell = [_chatTableView cellForRowAtIndexPath:indexPath];
                        if(!cell)
                            return;
                        if([cell.messageTextView isFirstResponder])
                        {
                            [cell.messageTextView resignFirstResponder];
                        }
                        shouldReloadTableWithAnimation = NO;
                        //[_chatTableView beginUpdates];
                        [_chatTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                        // [_chatTableView endUpdates];
                        
                        if(chatObject.didTryDownloadTOC)
                        {
                            // We received attachment data and the reloaded cell contains image instead of progressview.
                            //Its height has changed, so we need to take it again to scroll to it's correct bottom
                            cell = [_chatTableView cellForRowAtIndexPath:indexPath];
                            [self scrollToCell:cell animated:YES];
                        }
                    }
                });
            }
        }];
        [chatHistoryQueue addOperation:stateChangeOperation];
    }
}
- (void)onChatObjectFailed:(NSNotification *)note {
    
    DDLogDebug(@"%s",__FUNCTION__);
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSError *notificationError = [note.userInfo objectForKey:kSCPErrorDictionaryKey];
        ChatObject *chatObject = (ChatObject*)[note.userInfo objectForKey:kSCPChatObjectDictionaryKey];
        NSUInteger errorCode = notificationError.code;
        
        if(chatObject && notificationError)
            [self reportFailedChatToSentry:chatObject extraInfo:@{ @"errorCode" : @(errorCode) }];
        
        if(errorCode == -16) { // NO_DEVS_FOUND
            
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil)
                                                                                     message:NSLocalizedString(@"User has no messaging devices", nil)
                                                                              preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *alertAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                                  style:UIAlertActionStyleDefault
                                                                handler:nil];
            [alertController addAction:alertAction];
            
            [self presentViewController:alertController
                               animated:YES
                             completion:nil];
        }
    });
}

- (void)reportFailedChatToSentry:(ChatObject *)chatObject extraInfo:(NSDictionary *)extraInfoDict {
    
    
    if(!chatObject)
        return;
    
    if(!chatObject.isFailed)
        return;
    DDLogDebug(@"%s",__FUNCTION__);
    
    NSMutableDictionary *additionalExtra = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                           @"message_identifier" : @(chatObject.messageIdentifier),
                                                                                           @"message_status" : @(chatObject.messageStatus)
                                                                                           }];
    
    if(extraInfoDict) {
        
        NSData *extraInfoData = nil;
        
        @try {
            
            extraInfoData = [NSJSONSerialization dataWithJSONObject:extraInfoDict
                                                            options:0
                                                              error:nil];
            
        } @catch (NSException *exception) { }
        
        if(extraInfoData) {
            
            NSString *extraInfoString = [[NSString alloc] initWithData:extraInfoData
                                                              encoding:NSUTF8StringEncoding];
            
            [additionalExtra setObject:extraInfoString
                                forKey:@"extra_info"];
        }
    }
    
    [[RavenClient sharedClient] captureMessage:@"Failed Chat Message"
                                         level:kRavenLogLevelDebugError
                               additionalExtra:additionalExtra
                                additionalTags:nil
                                    stacktrace:nil
                                       culprit:nil
                                       sendNow:YES];
}

- (void)_presentAttachment:(ChatObject *)chatObject {
    NSString *mediaType = [chatObject.attachment.metadata objectForKey:kSCloudMetaData_MediaType];
    if ([(__bridge NSString *)kUTTypeAudio isEqualToString:mediaType]) {
        // cancel closing of audioplaybackview
        
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadVisibleRowBurnTimers) object:nil];
        [self reloadVisibleRowBurnTimers];
        [self animateAudioPlayerViewWithDirection:[NSNumber numberWithInt:1]];
        [[AudioPlaybackManager sharedManager] playAttachment:chatObject inView:audioPlaybackHolderView];
    } else {
        
        [self resignFirstResponderForAction];
        
        cancelReloadBeforeAppearing = YES;
        AttachmentPreviewController *attachmentVC = [[AttachmentPreviewController alloc] initWithChatObject:chatObject];
        
        [self presentViewController:attachmentVC
                           animated:YES
                         completion:nil];
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
                destViewC.locationUserName = [UserService currentUser].displayName;
            }
//            else destViewC.locationUserName = [[ChatUtilities utilitiesInstance] removePeerInfo:lastOpenedUserNameForChat lowerCase:NO];
            else if (openedRecent.displayName)
            {
                destViewC.locationUserName = openedRecent.displayName;
            } 
            // Note that displayAlias returns RecentObject.contactName if nil or empty string.
            // This will not be what we want to display if it is an SSO user contactName (uuid).
            else {
                destViewC.locationUserName = openedRecent.displayAlias;
            }
            
            if (isGroupChat)
            {
                destViewC.locationUserName = clickedLocationButton.thisChatObject.senderDisplayName;
            }
        }
    }
    else if([segue.identifier isEqualToString:@"deviceSegue"])
    {
        DevicesViewController *destViewC = (DevicesViewController*)segue.destinationViewController;
        destViewC.remoteRecentObject = openedRecent;
        destViewC.transitionDelegate = _transitionDelegate;
    } else if ([segue.identifier isEqualToString:@"showAddMember"])
    {
        AddGroupMemberViewController *groupViewC = (AddGroupMemberViewController*)segue.destinationViewController;
        groupViewC.delegate = self;
        groupViewC.alreadyAddedContacts = groupMemberRecentObjects;
    }else if ([segue.identifier isEqualToString:@"groupInfoSegue"])
    {
        GroupInfoViewController *infoVC = (GroupInfoViewController *) segue.destinationViewController;
        infoVC.groupUUID = lastOpenedUserNameForChat;
        infoVC.transitionDelegate = _transitionDelegate;
    }
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
        // set audioplayers view to _containerView if player is about to open audioplayer
        // add frame observer for _containerView's frame to keep position 40 points above it
        [self addAudioPlaybackHolderViewFrameObserver];
        
        CGRect audioPlayerFrame = audioPlaybackHolderView.frame;
        audioPlayerFrame.origin.y = actionSheetView.frame.origin.y;
        audioPlayerFrame.size.width = actionSheetView.frame.size.width;
        audioPlaybackHolderView.frame = audioPlayerFrame;
        
        [audioPlaybackHolderView setHidden:NO];
    } else if (direction == -1) {
        
        if (audioPlaybackHolderView.hidden)
        {
            [self removeAudioPlaybackHolderViewFrameObserver];
            return; // already hidden
        }
    }
    
    [UIView animateWithDuration:0.3 animations:^{
        CGRect audioPlayerFrame = audioPlaybackHolderView.frame;
        audioPlayerFrame.origin.y -= kAudioPlayerFrameHeight*direction;
        audioPlayerFrame.size.width = actionSheetView.frame.size.width;
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

#pragma mark actionSheetDelegate
- (void)sendMessageWithAssetInfo:(NSDictionary *)assetInfo {
    
    _supressFirstResponder = YES;
    
    [[ChatManager sharedManager] sendMessageWithAssetInfo:assetInfo inView:self.view];
}

- (void)sendMessageWithAttachment:(SCAttachment *)attachment {
    [[ChatManager sharedManager] sendMessageWithAttachment:attachment upload:YES forGroup:isGroupChat];
}

-(void)didTapActionSheetButton
{
    [actionSheetView closeBurnSlider];
}

-(IBAction)locationButtonClick:(LocationButton *) button
{
    [self willDismissWithActionSheet];
    if(button.thisChatObject.location)
    {
        [self performSegueWithIdentifier:@"showMapView" sender:button];
    }
}

/*
 Delete message
 If message is visible on screen poof animation will be played and message will be deleted when it completes
 If message is invisible it's indexPath is calculated by index in datasource and it's deleted without animation
 */
-(void) deleteMessage:(ChatObject *) chatObject forceBurn:(BOOL)forceBurn
{
    DDLogDebug(@"%s",__FUNCTION__);
    __block ChatObject *blockChatObject = chatObject;
    
    NSBlockOperation *deletionOperation = [NSBlockOperation new];
    [deletionOperation addExecutionBlock:^{
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (blockChatObject.iDidBurnAnimation == 0)
            {
                // If cell is visible we play poof animation and delete afterwards
                for (ChatBubbleCell *cell in [_chatTableView visibleCells])
                {
                    if([cell.thisChatObject.msgId isEqualToString:blockChatObject.msgId])
                    {
                        cell.thisChatObject.iDidBurnAnimation = 1;
                        if(forceBurn)
                            [[DBManager dBManagerInstance] sendForceBurn:blockChatObject];

                        [self playPoofAnimationOnCell:cell
                                           completion:^(BOOL done) {
                                               
                            [self deleteRowWithChatObject:blockChatObject];
                        }];
                        
                        return;
                    }
                }
            }
            
            if(forceBurn)
                [[DBManager dBManagerInstance] sendForceBurn:blockChatObject];
            
            [self deleteRowWithChatObject:blockChatObject];
        });
    }];
    
    [chatHistoryQueue addOperation:deletionOperation];
}

-(void) deleteRowWithChatObject:(ChatObject * ) chatObjectToDelete
{
    DDLogDebug(@"%s",__FUNCTION__);
    __block ChatObject *blockChatObjectToDelete = chatObjectToDelete;
    NSBlockOperation *deletionOperation = [NSBlockOperation new];
    [deletionOperation addExecutionBlock:^{
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            NSIndexPath *indexPath = nil;
            for (ChatBubbleCell *cell in [_chatTableView visibleCells]) {
                if([cell.thisChatObject.msgId isEqualToString:blockChatObjectToDelete.msgId])
                {
                    indexPath = [_chatTableView indexPathForCell:cell];
                    break;
                }
            }
            if (!indexPath)
            {
                for (int i = 0; i<_chatHistory.count; i++)
                {
                    SCSChatSectionObject * section = (SCSChatSectionObject *) _chatHistory[i];
                    for (int j = 0; j<section.chatObjectsArray.count; j++)
                    {
                        ChatObject * thisChatobject = section.chatObjectsArray[j];
                        if([thisChatobject.msgId isEqualToString:blockChatObjectToDelete.msgId])
                        {
                            blockChatObjectToDelete = thisChatobject;
                            indexPath = [NSIndexPath indexPathForRow:j inSection:i];
                            break;
                        }
                    }
                }
            }
            if (indexPath)
            {
                if(!(_chatHistory.count>indexPath.section))
                {
                    blockChatObjectToDelete.iDidBurnAnimation = 0;
                }
                SCSChatSectionObject *sectionObject = (SCSChatSectionObject *)_chatHistory[indexPath.section];
                if(sectionObject.chatObjectsArray.count <= indexPath.row)
                {
                    blockChatObjectToDelete.iDidBurnAnimation = 0;
                }
                
                ChatBubbleCell *cell = (ChatBubbleCell *)[_chatTableView cellForRowAtIndexPath:indexPath];
                
                if (cell)
                {
                    blockChatObjectToDelete = cell.thisChatObject;
                }
                [sectionObject.chatObjectsArray removeObjectIdenticalTo:blockChatObjectToDelete];
                [_chatObjectsHistory removeObject:blockChatObjectToDelete];
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [[DBManager dBManagerInstance] removeChatMessage:blockChatObjectToDelete postNotification:NO];
                });
                if([cell.messageTextView isFirstResponder])
                    [cell.messageTextView resignFirstResponder];
                    
                // if there are not chatobject's left in this section remove it
                // no need to resort sections
                if (sectionObject.chatObjectsArray.count == 0)
                {
                    [_chatHistory removeObject:sectionObject];
                }
                // since all chattableView additions or removals happen in serial queue, we can do this
                if(sectionObject.chatObjectsArray.count <=0)
                {
                    [_chatTableView beginUpdates];
                    [_chatTableView deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationFade];
                    [_chatTableView endUpdates];
                } else
                {
                    [_chatTableView beginUpdates];
                    [_chatTableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                    [self reloadAdjacentRowsForChangedIndexPath:indexPath];
                    [_chatTableView endUpdates];
                }
                
                [self updateEmptyConversationViews:NO];
                    
                // if first section contains less than 2 messages after deletion, and last loaded message call returned any messages
                // check for more messages again
                if(lastLoadedMessageCount > 0 && [_chatTableView numberOfRowsInSection:0] < 2 && _chatTableView.numberOfSections <= 1)
                {
                    [self loadNextMessages];
                }
                shouldReloadTableWithAnimation = NO;
            }
        });
        
    }];
    
    [chatHistoryQueue addOperation:deletionOperation];
}

// reload previous and next row from passed indexPath
-(void) reloadAdjacentRowsForChangedIndexPath:(NSIndexPath *) indexPath
{
    DDLogDebug(@"%s",__FUNCTION__);
    if (!isGroupChat)
        return;
    NSMutableArray *indexPathsToReload = [[NSMutableArray alloc] initWithCapacity:2];
    
    NSIndexPath *previousIndexPath = [NSIndexPath indexPathForRow:indexPath.row - 1 inSection:indexPath.section];
    
    NSIndexPath *nextIndexPath = [NSIndexPath indexPathForRow:indexPath.row + 1 inSection:indexPath.section];
    
    if ([_chatTableView cellForRowAtIndexPath:previousIndexPath])
    {
        [indexPathsToReload addObject:previousIndexPath];
    }
    
    if ([_chatTableView cellForRowAtIndexPath:nextIndexPath])
    {
        [indexPathsToReload addObject:nextIndexPath];
    }
    
    [_chatTableView reloadRowsAtIndexPaths:indexPathsToReload withRowAnimation:UITableViewRowAnimationNone];
}

- (IBAction)burnNowClickIBAction:(id)sender {
    BurnButton *burnButtonLoc = (BurnButton *) sender;
    [self burnNowClick:burnButtonLoc];
}

-(void) burnNowClick:(BurnButton *) button
{
    for (ChatBubbleCell *cell in [_chatTableView visibleCells])
    {
        if(cell.thisChatObject == button.thisChatobject)
        {
            BOOL forceBurn = YES;
            if (isGroupChat)
            {
                [[GroupChatManager sharedInstance] burnGroupMessages:@[cell.thisChatObject.msgId] inGroup:lastOpenedUserNameForChat];
                forceBurn = NO;
            }
            [self deleteMessage:cell.thisChatObject
                      forceBurn:forceBurn];
            
            break;
        }
    }
}

/*
 * Performs poof animation on cell and calls completion when done
 */
-(void) playPoofAnimationOnCell:(ChatBubbleCell *) cell completion:(void(^) (BOOL done)) completion
{
    DDLogDebug(@"%s",__FUNCTION__);
    dispatch_async(dispatch_get_main_queue(), ^{
        cell.thisChatObject.iDidBurnAnimation = 1;
        [UIView animateWithDuration:0.5 animations:^{
            cell.contentView.alpha = 0;
        }];
        [cell.burnButton setUserInteractionEnabled:NO];
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
        
        
        //UIView *bubbleView = [cell.contentView viewWithTag:1];
        UIView *bubbleView;
        if(cell.thisChatObject.isCall)
        {
            bubbleView = cell.contentView;
        } else
        {
            if (cell.thisChatObject.attachment)
            {
                bubbleView = cell.messageImageView;
            } else
            {
                bubbleView = cell.messageTextView;
            }
        }
        
        CGFloat width = MIN(imageSize.width, cell.contentView.frame.size.width);
        CGFloat height = MIN(imageSize.height, cell.contentView.frame.size.height);
        CGPoint bubbleCenter = [self.view convertPoint:bubbleView.center fromView:cell];
        imageView.frame = CGRectMake(0, 0, width, height);
        imageView.center = bubbleCenter;
        [self.view addSubview:imageView];
        [imageView startAnimating];
        __weak UIImageView *weakImageView = imageView;
        __weak BurnButton *weakButton = cell.burnButton;
        
        [SPAudioManager playSound:@"poof"
                           ofType:@"aif"
                          vibrate:NO];

        double delayInSeconds = 0.5;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            __strong UIImageView *strongImageView = weakImageView;
            __strong BurnButton *strongButton = weakButton;
            if (strongImageView)
            {
                [savedBurnNowButton removeFromSuperview];
                [strongButton setUserInteractionEnabled:YES];
                [strongImageView removeFromSuperview];
                completion(YES);
            }
        });
    });
}

-(void) reloadVisibleRowBurnTimers
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        BOOL shouldReload = NO;
        NSArray *visibleCells = [_chatTableView visibleCells];
        if(!visibleCells)return;
        
        long now = time(NULL);
        for (ChatBubbleCell *cell in visibleCells) {
            // if one row counts time less than 1min or has received burn from other party reload all visible cells
            // if any row is being deleted(poof animation is playing) cancel reload
            
            NSDictionary *burnDict = [[ChatUtilities utilitiesInstance] getBurnNoticeRemainingTime:cell.thisChatObject];
            
            // Reload if new burn time is different from the one that's being displayed on the cell
            if (![cell.burnTimeLabel.text isEqualToString:[burnDict objectForKey:@"burnTime"]]) {
                shouldReload = YES;
                break;
            }
            long long burnStartTimeStamp = isGroupChat?cell.thisChatObject.unixCreationTimeStamp:cell.thisChatObject.unixReadTimeStamp;
            
            long long dif = cell.thisChatObject.burnTime + burnStartTimeStamp - now;
            if((cell.thisChatObject.burnNow || (cell.thisChatObject.burnTime && burnStartTimeStamp && dif >= 0 && dif < 60)) && !msgIDOfChatObjectInMenuController)
            {
                // reload burn timers only if we are not scrolling tableview
                if (!_chatTableView.isDragging && !_chatTableView.isDecelerating)
                {
                    shouldReload = YES;
                    break;
                }
            }
            if(cell.thisChatObject.iDidBurnAnimation != 0)
                shouldReload = NO;
            
            if (burnStartTimeStamp && dif < 0 && !cell.thisChatObject.errorString) {
                shouldReload = YES;
            }
        }
        if(shouldReload)
        {
            shouldReloadTableWithAnimation = NO;
            
            NSArray *ar = [_chatTableView indexPathsForVisibleRows];
            
            ar = [_chatTableView indexPathsForVisibleRows];
            
            for (SCSChatSectionObject *sectionObject in _chatHistory) {
                for (ChatObject *thisChatObject in sectionObject.chatObjectsArray)
                {
                    long long burnStartTimeStamp = isGroupChat?thisChatObject.unixCreationTimeStamp:thisChatObject.unixReadTimeStamp;
                    long long dif = thisChatObject.burnTime + burnStartTimeStamp - now;
                    
                    if(dif < 0 && burnStartTimeStamp && thisChatObject.burnTime)
                    {
                        thisChatObject.burnNow = 1;
                    }
                }
            }
            
            for (NSIndexPath *cellIndexPath in ar)
            {
                ChatBubbleCell *cell = (ChatBubbleCell*)[_chatTableView cellForRowAtIndexPath:cellIndexPath];
                
                long long burnStartTimeStamp = isGroupChat?cell.thisChatObject.unixCreationTimeStamp:cell.thisChatObject.unixReadTimeStamp;
                
                long long dif = cell.thisChatObject.burnTime + burnStartTimeStamp - now;
                
                if(cell.thisChatObject.burnNow || (burnStartTimeStamp && cell.thisChatObject.burnTime && dif >= 0 && dif < 60))
                {
                    if(cell.thisChatObject.burnNow || dif <= 0)
                    {
                        cell.thisChatObject.burnNow = 0;

                        [self deleteMessage:cell.thisChatObject
                                  forceBurn:YES];
                    }
                }
                
                // FIX - if burntimer runs out for message which is not visible it will not burn until conversation is reopened
                if (cell.thisChatObject.burnTime && dif < 0 && burnStartTimeStamp && !cell.thisChatObject.errorString)
                {
                    [self deleteMessage:cell.thisChatObject
                              forceBurn:YES];
                }
            }
            
            for (NSIndexPath *cellIndexPath in ar) {
                ChatBubbleCell *cell = (ChatBubbleCell*)[_chatTableView cellForRowAtIndexPath:cellIndexPath];
                if(cell.thisChatObject.iDidBurnAnimation == 1)
                {
                    cell.thisChatObject.iDidBurnAnimation = 2;
                }
                
                // change only burn time label on visible cells that require the second change
                NSDictionary *burnDictionary = [[ChatUtilities utilitiesInstance] getBurnNoticeRemainingTime:cell.thisChatObject];
                cell.burnTimeLabel.text = [burnDictionary objectForKey:@"burnTime"];
            }
            //NSLog(@"should reload in reloadBurnTimers in main %d",[NSThread isMainThread]);
            
        }
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadVisibleRowBurnTimers) object:nil];
        if (isChatOpen)
            [self performSelector:@selector(reloadVisibleRowBurnTimers) withObject:nil afterDelay:1.0];
    });
}

#pragma mark - Notification Registration

- (void)registerNotifications {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // Font
    [nc addObserver:self selector:@selector(reloadChatBubbles:) name:kSCPChatBubbleTextSizeChanged object:nil];
    
    // Message
    [nc addObserver:self selector:@selector(receiveMessage:) name:kSCPReceiveMessageNotification object:nil];
    [nc addObserver:self selector:@selector(removeMessage:)  name:kSCPRemoveMessageNotification object:nil];
    
    // Chat Object
    [nc addObserver:self selector:@selector(onChatObjectCreated:) name:ChatObjectCreatedNotification object:nil];
    [nc addObserver:self selector:@selector(onChatObjectUpdated:) name:ChatObjectUpdatedNotification object:nil];
    [nc addObserver:self selector:@selector(onChatObjectFailed:) name:ChatObjectFailedNotification object:nil];
    
    // Attachments
    [nc addObserver:self selector:@selector(receiveAttachment:)              name:AttachmentManagerReceiveAttachmentNotification object:nil];
    [nc addObserver:self selector:@selector(attachmentProgressNotification:) name:AttachmentManagerEncryptProgressNotification object:nil];
    [nc addObserver:self selector:@selector(attachmentProgressNotification:) name:AttachmentManagerUploadProgressNotification object:nil];
    [nc addObserver:self selector:@selector(attachmentProgressNotification:) name:AttachmentManagerVerifyProgressNotification object:nil];
    
    // Audio
    [nc addObserver:self selector:@selector(audioFinishedNotification:) name:AudioPlayerDidFinishPlayingAttachmentNotification object:nil];
    [nc addObserver:self selector:@selector(audioPausedNotification:)   name:AudioPlayerDidPausePlayingAttachmentNotification object:nil];
    
    // Contact Data
    [nc addObserver:self selector:@selector(recentObjectUpdated:)       name:kSCSRecentObjectUpdatedNotification object:nil];
    [nc addObserver:self selector:@selector(recentObjectRemoved:)       name:kSCSRecentObjectRemovedNotification object:nil];
    
    // Call screen
    [nc addObserver:self selector:@selector(willPresentCallScreen:) name:kSCPWillPresentCallScreenNotification object:nil];
    
    // Application state
    [nc addObserver:self selector:@selector(applicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    [nc addObserver:self selector:@selector(applicationDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    [nc addObserver:self selector:@selector(recentObjectResolved:) name:kSCSRecentObjectResolvedNotification object:nil];
    
    [actionSheetView registerKeyboardNotifications];
}

- (void)deregisterNotifications {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // Font
    [nc removeObserver:self name:kSCPChatBubbleTextSizeChanged object:nil];
    
    // Message
    [nc removeObserver:self name:kSCPReceiveMessageNotification object:nil];
    [nc removeObserver:self name:kSCPRemoveMessageNotification object:nil];
    
    // Chat Object
    [nc removeObserver:self name:ChatObjectCreatedNotification object:nil];
    [nc removeObserver:self name:ChatObjectUpdatedNotification object:nil];
    [nc removeObserver:self name:ChatObjectFailedNotification object:nil];
    
    // Attachments
    [nc removeObserver:self name:AttachmentManagerReceiveAttachmentNotification object:nil];
    [nc removeObserver:self name:AttachmentManagerEncryptProgressNotification object:nil];
    [nc removeObserver:self name:AttachmentManagerUploadProgressNotification object:nil];
    [nc removeObserver:self name:AttachmentManagerVerifyProgressNotification object:nil];
    
    // Audio
    [nc removeObserver:self name:AudioPlayerDidFinishPlayingAttachmentNotification object:nil];
    [nc removeObserver:self name:AudioPlayerDidPausePlayingAttachmentNotification object:nil];
    
    // Contact Data
    [nc removeObserver:self name:kSCSRecentObjectUpdatedNotification object:nil];

    // Call screen
    [nc removeObserver:self name:kSCPWillPresentCallScreenNotification object:nil];
    
    // Application state
    [nc removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [nc removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    [nc removeObserver:self name:kSCSRecentObjectResolvedNotification object:nil];
    
    [actionSheetView deregisterKeyboardNotifications];
}

-(void)resignFirstResponderForAction
{
    if ([actionSheetView.messageTextView isFirstResponder])
    {
        [actionSheetView.messageTextView resignFirstResponder];
        [self shouldChangeBottomOffsetTo:actionSheetView.frame.size.height canScroll:NO animated:YES];
    }
}

#pragma mark - AttachmentManager notfications

- (ChatObject *)chatObjectForMsgId:(NSString *)msgId {
    
    if(!msgId)
        return nil;
    
    for (long i = _chatHistory.count-1; i>=0; i--) {
        
        SCSChatSectionObject *sectionObject = _chatHistory[i];
        
        for (long j = sectionObject.chatObjectsArray.count-1; j>=0; j--) {
            
            ChatObject *thisChatObject = (ChatObject *)sectionObject.chatObjectsArray[j];
            
            if ([thisChatObject.msgId isEqualToString:msgId])
                return thisChatObject;
        }
    }
    
    return nil;
}

- (NSIndexPath *)indexPathForMsgID:(NSString *)msgId {

    for (long i = _chatHistory.count-1; i>=0; i--) {
        
        SCSChatSectionObject *sectionObject = _chatHistory[i];
        
        for (long j = sectionObject.chatObjectsArray.count-1; j>=0; j--) {
            
            ChatObject *thisChatObject = (ChatObject *)sectionObject.chatObjectsArray[j];
            
            if ([thisChatObject.msgId isEqualToString:msgId])
                return [NSIndexPath indexPathForRow:j inSection:i];
        }
    }
    
    return nil;
}

- (void)attachmentProgressNotification:(NSNotification *)note {

    AttachmentProgress *progressObj = [note.userInfo objectForKey:kSCPProgressObjDictionaryKey];
    
    if (!progressObj)
        return;
    
    ChatObject *chatObject = [self chatObjectForMsgId:progressObj.messageID];
    
    if(!chatObject)
        return;
    
    if(progressObj.progressType != kProgressType_Download &&
       (chatObject.isRead || chatObject.delivered || !chatObject.iSendingNow || chatObject.messageStatus >= 200))
        return;
    
    NSIndexPath *indexPath = [self indexPathForMsgID:progressObj.messageID];
    
    if (!indexPath)
        return;
    
    ChatBubbleCell *cell = (ChatBubbleCell*)[_chatTableView cellForRowAtIndexPath:indexPath];
    
    if (!cell)
        return;
    
    if(![chatObject.msgId isEqualToString:cell.thisChatObject.msgId])
        return;
    
    cell.progressView.progress = progressObj.progress;
    cell.progressView.hidden = ( (progressObj.progress <= 0) || (progressObj.progress >= 1.0) );
    
    if (isGroupChat) {
        
        [cell.progressView setHidden:YES];
        return;
    }
    
    [cell.statusLabel setTextColor:[UIColor chatBubbleStatusFontColor]];
    
    switch (progressObj.progressType) {
        case kProgressType_Encrypt:
            cell.statusLabel.text = NSLocalizedString(@"Preparing...", ni);
            break;
        case kProgressType_Upload:
            cell.statusLabel.text = NSLocalizedString(@"Uploading...", nil);
            break;
        case kProgressType_Verify:
            cell.statusLabel.text = NSLocalizedString(@"Verifying...", nil);
            break;
        case kProgressType_Download:
            cell.statusLabel.text = NSLocalizedString(@"Downloading...", nil);
            break;
    }
}

-(void) willPresentCallScreen:(NSNotification *) notification
{
    [actionSheetView closeBurnSlider];
    [self resignFirstResponderForAction];
    [[AudioPlaybackManager sharedManager].playbackView stop];
    if (!audioPlaybackHolderView.isHidden) {
        [self animateAudioPlayerViewWithDirection:[NSNumber numberWithInt:-1]];
    }
    if (_actionsheetViewRed.imagePickerController) {
        [_actionsheetViewRed.imagePickerController dismissViewControllerAnimated:NO completion:nil];
    }
    cancelReloadBeforeAppearing = YES;
}

#pragma mark - AudioPlaybackManager notification
- (void)audioFinishedNotification:(NSNotification *)note {
    [self animateAudioPlayerViewWithDirection:[NSNumber numberWithInt:-1]];
}
- (void)audioPausedNotification:(NSNotification *)note {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self reloadVisibleRowBurnTimers];
    [self performSelector:@selector(animateAudioPlayerViewWithDirection:) withObject:[NSNumber numberWithInt:-1] afterDelay:5.0];
}

#pragma mark touches
- (void)handleLongPress:(UIGestureRecognizer *)gestureRecognizer
{
    
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan)
    {
        [actionSheetView closeBurnSlider];
        CGPoint tableViewTouchPoint = [gestureRecognizer locationInView:_chatTableView];
        
        NSIndexPath *indexPath = [_chatTableView indexPathForRowAtPoint:tableViewTouchPoint];
        ChatBubbleCell *cell = (ChatBubbleCell *)[_chatTableView cellForRowAtIndexPath:indexPath];
        if (cell) {
            ChatObject *co = cell.thisChatObject;
            
            // Don't show menucontroller on group invitation cells
            if (co.isInvitationChatObject == 1)
            {
                return;
            }
            if ( (co.messageStatus < 0)
                && ([co.errorString length] > 0)
                && ([@"Policy Error" isEqualToString:co.messageText]) ) {
                // DR Policy Error messages show alert immediately
                UIAlertController *infoAlert =[UIAlertController alertControllerWithTitle:NSLocalizedString(@"Information", nil) message:co.errorString preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* okAction = [UIAlertAction
                                           actionWithTitle:NSLocalizedString(@"OK", nil)
                                           style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction * action)
                                           {
                                               [infoAlert dismissViewControllerAnimated:YES completion:nil];
                                           }];
                [infoAlert addAction:okAction];
                [self presentViewController:infoAlert animated:YES completion:nil];
                return;
            }

            [self displayMenuControllerForCell:cell atIndexPath:indexPath];
        }
    }
}
- (IBAction)handleTap:(id)sender {
    
    [actionSheetView closeBurnSlider];
    UITapGestureRecognizer *gestureRecognizer = (UITapGestureRecognizer *) sender;
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded)
    {
        CGPoint tableViewTouchPoint = [gestureRecognizer locationInView:_chatTableView];
        NSIndexPath *indexPath = [_chatTableView indexPathForRowAtPoint:tableViewTouchPoint];
        ChatBubbleCell *cell = (ChatBubbleCell *)[_chatTableView cellForRowAtIndexPath:indexPath];
        
        // if touch is inside attachment thumbnail or location button, do not show burnbutton
        if (cell.thisChatObject.attachment && CGRectContainsPoint(cell.messageImageView.frame, [_chatTableView convertPoint:tableViewTouchPoint toView:cell])) {
            return;
        }
        if (cell.thisChatObject.location && CGRectContainsPoint(cell.locationButtonTouchArea.frame, [_chatTableView convertPoint:tableViewTouchPoint toView:cell])) {
            return;
        }
        
        // for non attachment messages check if they contain url
        // if url is found and touch was inside message bubble, open url and don't show burn button
        if (!cell.thisChatObject.attachment)
        {
            CGRect messageViewRect = cell.messageBackgroundView.frame;
            CGPoint touchPointInCell = [_chatTableView convertPoint:tableViewTouchPoint toView:cell];
            if (CGRectContainsPoint(messageViewRect, touchPointInCell) && [[ChatUtilities utilitiesInstance] existsUrlInText:cell.thisChatObject.messageText])
            {
                [cell.messageTextView openUrl:gestureRecognizer];
                return;
            }
        }
        if (!cell.thisChatObject.isGroupChatObject ||
            !cell.thisChatObject.isReceived)
        {
            [self showBurnButtonCellOnCellWithChatObject:cell.thisChatObject];
        }
    }
}


- (void)displayMenuControllerForCell:(ChatBubbleCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    [menuController setMenuItems:nil];
    
    
    CGRect rowFrame = [_chatTableView rectForRowAtIndexPath:indexPath];
    
    CGRect bubbleFrameInTableView = CGRectZero;
    
    
    msgIDOfChatObjectInMenuController = cell.thisChatObject.msgId;
    
    if (cell.thisChatObject.isCall)
    {
        bubbleFrameInTableView = cell.callInfoLabel.frame;
    } else if(cell.thisChatObject.errorString)
    {
        bubbleFrameInTableView = cell.errorLabel.frame;
    }
    else
    {
        if (cell.thisChatObject.attachment)
        {
            bubbleFrameInTableView = cell.messageImageView.frame;
        } else
        {
            bubbleFrameInTableView = cell.messageTextView.frame;
        }
    }
    
    bubbleFrameInTableView.origin.x += rowFrame.origin.x;
    bubbleFrameInTableView.origin.y += rowFrame.origin.y;
    
    CGRect visibleTableFrame = CGRectZero;
    visibleTableFrame.origin = _chatTableView.contentOffset;
    visibleTableFrame.size = _chatTableView.frame.size;
    
    CGRect menuFrame = CGRectIntersection(bubbleFrameInTableView, visibleTableFrame);
    
    
    // common to calls && msgs
    NSArray *menuItemsArray;
    UIMenuItem *infoItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Info", @"Info")
                                                      action:@selector(textView:menuActionInfo:)];
    
    if(!cell.thisChatObject.isCall)
    {
        /*UIMenuItem *burnItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Burn", @"Burn")
         action:@selector(burn:)];*/
        
        UIMenuItem *forwardItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Forward", @"Forward")
                                                             action:@selector(textView:menuActionForward:)];
        
        UIMenuItem *resendItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Resend", @"Resend")
                                                            action:@selector(textView:menuActionResend:)];
        
        UIMenuItem *tryAgainItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Try Again", @"Try Again")
                                                              action:@selector(textView:menuActionTryAgain:)];
        
        //ET 05/06/16
        UIMenuItem *copyItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Copy", @"Copy")
                                                          action:@selector(textView:menuActionCopy:)];
        
        BOOL textCopy = (cell.thisChatObject.messageText.length > 0);
        
        if(cell.thisChatObject.isFailed && !isGroupChat)
        {
            menuItemsArray = (textCopy)?@[copyItem,infoItem,tryAgainItem]:@[infoItem,tryAgainItem];
        } else
        {
            if(cell.thisChatObject.isReceived == 1)
            {
                menuItemsArray=(textCopy)?@[copyItem,infoItem,forwardItem]:@[infoItem,forwardItem];
            }
            else
            {
                menuItemsArray=(textCopy)?@[copyItem,infoItem,forwardItem,resendItem]:@[infoItem,forwardItem,resendItem];
            }
        }
    } else
    {
        menuItemsArray = @[/*burnItem,*/infoItem];
    }
    
    [_chatTableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];//this fails if we have failed message
    [menuController setMenuItems:menuItemsArray];
    [self resignFirstResponderForAction];
    [self becomeFirstResponder];
    [menuController setTargetRect:menuFrame inView:_chatTableView];
    [menuController setMenuVisible:YES animated:YES];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didHideMenuController:)
                                               name:UIMenuControllerDidHideMenuNotification
                                             object:nil];
}
/*
 for UIMenucontroller, for some reason SilentText's method of setting UItextview as delegate for UIMenuController didn't work always
 some times delegate wasn't called on some random cells
 compiler showed unknown selector warnings for ChatBubbleTextView protocol function calls
 
 Now sets self as firstResponder for UIMenuControlelr and calls UIMenuItem functions directly to ChatViewcontroller
 GO
 */
-(BOOL)canBecomeFirstResponder
{
    return YES;
}

- (void)didHideMenuController:(NSNotification *)notification
{
    msgIDOfChatObjectInMenuController = nil;
    [self reloadVisibleRowBurnTimers];
    [self resignFirstResponder];
    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:UIMenuControllerDidHideMenuNotification
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
    ChatBubbleCell *cell = (ChatBubbleCell *)[_chatTableView cellForRowAtIndexPath:[_chatTableView indexPathForSelectedRow]];
    
    
    if(!cell)return NO;
    if(action == @selector(copy:))
    {
        if(sender.thisChatObject.messageText.length > 0 && !sender.thisChatObject.isCall)
            return YES;
        else
            return NO;
    }
    
    if(action == @selector(textView:menuActionInfo:)|| action == @selector(textView:menuActionResend:) || action == @selector(textView:menuActionTryAgain:))
    {
        return YES;
    }
    else if(action == @selector(textView:menuActionBurn:) || action == @selector(textView:menuActionForward:))
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


-(ChatObject *)getMenuSelectedObject
{
    
    NSIndexPath *selectedIndexPath = [_chatTableView indexPathForSelectedRow];
    
    ChatObject *thisChatObject = nil;;
    
    if(selectedIndexPath){
        
        SCSChatSectionObject *sectionObject = (SCSChatSectionObject *) _chatHistory[selectedIndexPath.section];

        if([sectionObject.chatObjectsArray count] <= selectedIndexPath.row)
            return nil;
        
        thisChatObject = (ChatObject*)sectionObject.chatObjectsArray[selectedIndexPath.row];
    } else
    {
        // this cell is visible when menucontroller is visible
        for (ChatBubbleCell *cell in [_chatTableView visibleCells])
        {
            if ([cell.thisChatObject.msgId isEqualToString:msgIDOfChatObjectInMenuController])
            {
                thisChatObject = cell.thisChatObject;
                break;
            }
        }
    }
    return thisChatObject;
}

-(void)textView:(UITextView *)textView menuActionCopy:(id)sender
{
    ChatObject *co = [self getMenuSelectedObject];
    if(!co)return;
    
    
    if(!co || co.messageText.length < 1)return;
    
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = co.messageText;
}

-(void)textView:(UITextView *)textView menuActionTryAgain:(id)sender {
    
    ChatObject *co = [self getMenuSelectedObject];
    
    if(!co)
        return;
    
    co.messageStatus = 0;
    co.iSendingNow = 1;
        
    // Find and refresh visible cell with this chantobject to show preparing status
    for (ChatBubbleCell *cell in _chatTableView.visibleCells)
    {
        // Cant compare chatobjects, since they can change
        if ([cell.thisChatObject.msgId isEqualToString:co.msgId])
        {
            [self.chatTableView beginUpdates];
            [self.chatTableView reloadRowsAtIndexPaths:@[[self.chatTableView indexPathForCell:cell]]
                                      withRowAnimation:UITableViewRowAnimationNone];
            [self.chatTableView endUpdates];
            
            break;
        }
    }
    
    if (co.attachment)
        [[ChatManager sharedManager] uploadAttachmentForChatObject:co];
    else
        [[ChatManager sharedManager] sendChatObjectAsync:co];
}


-(void)textView:(UITextView *)textView menuActionResend:(id)sender {
    
    
    ChatObject *co = [self getMenuSelectedObject];
    if(!co)return;
    
    // Essentially this works like fwd the message to the same person
    if(co.attachment)
        [[ChatManager sharedManager] sendMessageWithAttachment:co.attachment upload:NO forGroup:isGroupChat];
    else
        [[ChatManager sharedManager] sendTextMessage:co.messageText forGroup:isGroupChat];
}

-(void)textView:(UITextView *)textView menuActionBurn:(id)sender
{
   // ChatBubbleCell *cell = (ChatBubbleCell *)[_chatTableView cellForRowAtIndexPath:[_chatTableView indexPathForSelectedRow]];
   // [self burnNowClick:cell.burnInfoButton indexPath:[_chatTableView indexPathForSelectedRow]];
}

-(void)textView:(UITextView *)textView menuActionForward:(id)sender
{
    ChatObject *co = [self getMenuSelectedObject];
    if(!co)return;
    if(co.attachment && ![[UserService currentUser] hasPermission:UserPermission_SendAttachment]) {
        
        // off-load to upsell flow
        [[UserService sharedService] upsellPermission:UserPermission_SendAttachment];
        return;
    }
    
    if(_transitionDelegate && [_transitionDelegate respondsToSelector:@selector(presentForwardScreenInController:withChatObject:)])
        [_transitionDelegate presentForwardScreenInController:self         
                                               withChatObject:co];
    
    cancelReloadBeforeAppearing = YES;
}


-(void)textView:(UITextView *)textView menuActionInfo:(id)sender
{
    NSString *messageInfo;
    ChatObject *co = [self getMenuSelectedObject];
    if(!co)return;
    
    
    messageInfo = [[ChatUtilities utilitiesInstance] formatInfoStringForChatObject:co];
    
    UIAlertController *infoAlert =[UIAlertController alertControllerWithTitle:NSLocalizedString(@"Message Info", ni)
                                                                      message:messageInfo
                                                               preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* okAction = [UIAlertAction
                               actionWithTitle:NSLocalizedString(@"OK", nil)
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction * action)
                               {
                                   [infoAlert dismissViewControllerAnimated:YES completion:nil];
                               }];
    
    [infoAlert addAction:okAction];
    
    
    UIAlertAction* detailsAction = [UIAlertAction
                                    actionWithTitle:NSLocalizedString(@"Details", nil)
                                    style:UIAlertActionStyleDefault
                                    handler:^(UIAlertAction * action)
                                    {
                                        [infoAlert dismissViewControllerAnimated:YES completion:nil];
                                        
                                        
                                        UIAlertController *detailsAlert =[UIAlertController alertControllerWithTitle:NSLocalizedString(@"Details", nil)
                                                                                                             message:[NSString stringWithFormat:@"%@",co.errorString ?co.errorString: co.dictionary]
                                                                                                      preferredStyle:UIAlertControllerStyleAlert];
                                        
                                        UIAlertAction* okAction = [UIAlertAction
                                                                   actionWithTitle:NSLocalizedString(@"OK", nil)
                                                                   style:UIAlertActionStyleDefault
                                                                   handler:^(UIAlertAction * action)
                                                                   {
                                                                       [infoAlert dismissViewControllerAnimated:YES completion:nil];
                                                                   }];
                                        
                                        [detailsAlert addAction:okAction];
                                        
                                        [self presentViewController:detailsAlert animated:YES completion:nil];
                                        
                                        
                                    }];
    
    [infoAlert addAction:detailsAction];
    
    [self presentViewController:infoAlert animated:YES completion:nil];
}

/*
#pragma mark - SilentContactsViewControllerDelegate

- (void)silentContactsViewControllerWillDismissWithContact:(AddressBookContact *)contact {
    _pendingContactAttachment = contact;
    
    [self.navigationController popViewControllerAnimated:YES];
}
-(void)silentContactsViewControllerWillCancel
{
    cancelReloadBeforeAppearing = YES;
}
 */
-(void) willDismissWithActionSheet
{
    cancelReloadBeforeAppearing = YES;
}

#pragma mark - ChatBubbleCellDelegate

- (void)chatBubbleCellWasTapped:(ChatBubbleCell *)chatBubbleCell {
    
    if(chatBubbleCell.thisChatObject.attachment && !msgIDOfChatObjectInMenuController) // if uimenucontroller is not showing
    {
        NSIndexPath *indexPath = [_chatTableView indexPathForCell:chatBubbleCell];
        
        [self presentAttachmentForRow:indexPath];
    }
}

- (BOOL)chatBubbleCellWasDoubleTapped:(ChatBubbleCell *)chatBubbleCell {
    
    LocationButton *locationButton = chatBubbleCell.locationButton;
    
    if(locationButton.thisChatObject.location)
    {
        [self performSegueWithIdentifier:@"showMapView" sender:locationButton];
        
        return YES;
    }
    else
        return NO;
}

-(void)accessibilityBurnMessage:(ChatBubbleCell *)chatBubbleCell
{
    [self burnNowClick:chatBubbleCell.burnButton];
}

-(void)accessibilityShowLocation:(ChatBubbleCell *)chatBubbleCell
{
    [self locationButtonClick:chatBubbleCell.locationButtonTouchArea];
}

-(void)accessibilityInfo:(ChatBubbleCell *)chatBubbleCell
{
    [_chatTableView selectRowAtIndexPath:[_chatTableView indexPathForCell:chatBubbleCell] animated:NO scrollPosition:UITableViewScrollPositionNone];
    [self textView:nil menuActionInfo:nil];
}

-(void)accessibilityForward:(ChatBubbleCell *)chatBubbleCell
{
    [_chatTableView selectRowAtIndexPath:[_chatTableView indexPathForCell:chatBubbleCell] animated:NO scrollPosition:UITableViewScrollPositionNone];
    [self textView:nil menuActionForward:nil];
}

-(void)accessibilityCopyText:(ChatBubbleCell *)chatBubbleCell
{
    ChatObject *chatObject = chatBubbleCell.thisChatObject;
    if (!chatObject.isAttachment)
    {
        UIPasteboard *pasteBoard = [UIPasteboard generalPasteboard];
        pasteBoard.string = chatObject.messageText;
    }
}

-(void)accessibilityResend:(ChatBubbleCell *)chatBubbleCell
{
    [_chatTableView selectRowAtIndexPath:[_chatTableView indexPathForCell:chatBubbleCell] animated:NO scrollPosition:UITableViewScrollPositionNone];
    [self textView:nil menuActionResend:nil];
}

-(void) showBurnButtonCellOnCellWithChatObject:(ChatObject *) thisChatObject
{
    if (UIAccessibilityIsVoiceOverRunning()) {
        return;
    }
    ChatBubbleCell *thisCell = nil;
    for (ChatBubbleCell *cell in [_chatTableView visibleCells]) {
        if(cell.thisChatObject == thisChatObject)
        {
            thisCell = cell;
            break;
        }
    }
    
    if(!msgIDOfChatObjectInMenuController && thisCell)
    {
        if (thisChatObject.isCall) {
            
            // open for call
            if(thisCell.burnButton.isHidden)
            {
                [thisCell.layer removeAllAnimations];
                thisCell.callBackgroundViewLeadingConstraint.constant = 0;
                [thisCell layoutIfNeeded];
                thisCell.callBackgroundViewLeadingConstraint.constant = 50;
                thisChatObject.isShowingBurnButton = YES;
                [thisCell.burnButton setHidden:NO];
                
            }else
            {
                [thisCell.layer removeAllAnimations];
                thisCell.callBackgroundViewLeadingConstraint.constant = 50;
                [thisCell layoutIfNeeded];
                thisCell.callBackgroundViewLeadingConstraint.constant = 0;
                thisChatObject.isShowingBurnButton = NO;
                [thisCell.burnButton setHidden:YES];
            }
            
            [UIView animateWithDuration:0.2f
                                  delay:0.0f
                 usingSpringWithDamping:0.5f
                  initialSpringVelocity:1.0f
                                options:UIViewAnimationTransitionCurlUp animations:^{
                                    [thisCell layoutIfNeeded];
                                }
                             completion:^(BOOL finished) {
                                 
                             }];
            
        } else
        {
            
            // open for message
            if(thisCell.burnButton.isHidden)
            {
                [thisCell.layer removeAllAnimations];
                thisCell.burnButtonWidthConstant.constant = 0;
                thisCell.burnButtonHeightConstant.constant = 0;
                [thisCell layoutIfNeeded];
                thisCell.burnButtonWidthConstant.constant = 40;
                thisCell.burnButtonHeightConstant.constant = 40;
                thisChatObject.isShowingBurnButton = YES;
                [thisCell.burnButton setHidden:NO];
            }
            else
            {
                thisChatObject.isShowingBurnButton = NO;
                //[thisCell.burnButton setHidden:YES];
            }
            
            [UIView animateWithDuration:0.2f
                                  delay:0.0f
                 usingSpringWithDamping:0.5f
                  initialSpringVelocity:1.0f
                                options:UIViewAnimationTransitionCurlUp animations:^{
                                    [thisCell layoutIfNeeded];
                                }
                             completion:^(BOOL finished) {
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                     if (!thisChatObject.isShowingBurnButton) {
                                         [thisCell.burnButton setHidden:YES];
                                     }
                                 });
                             }];
        }
    }
}

#pragma mark Chat Data sourceV2

-(void) scheduleTableReload
{
    DDLogDebug(@"%s",__FUNCTION__);
    NSBlockOperation *reloadOperation = [NSBlockOperation new];
    [reloadOperation addExecutionBlock:^{
        [self.chatTableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
    }];
    [chatHistoryQueue addOperation:reloadOperation];
}

-(SCSChatSectionObject *) getSectionForChatObject:(ChatObject *) chatObject
{
    NSDate *chatObjectDate = [NSDate dateWithTimeIntervalSince1970:chatObject.timeVal.tv_sec];
    for (SCSChatSectionObject *section in _chatHistory)
    {
        NSDate *existingSectionDate = [NSDate dateWithTimeIntervalSince1970:section.lastChatObjectTimeStamp];
        if([[ChatUtilities utilitiesInstance] isDate:chatObjectDate sameDayAsDate:existingSectionDate])
        {
            return section;
        }
    }
    return nil;

}

-(SCSChatSectionObject *) createSectionWithChatObject:(ChatObject *) chatObject
{
    SCSChatSectionObject *section = nil;
    section = [[SCSChatSectionObject alloc] init];
    section.headerTitle = [[ChatUtilities utilitiesInstance] takeHeaderTitleTimeFromDateStamp:chatObject.timeVal.tv_sec];
    section.lastChatObjectTimeStamp = chatObject.timeVal.tv_sec;
    return section;
}

/*
 Adds new chatobject, sorts all chatobjects, reloads table!! and scrolls to bottom
 */
-(void)addChatObjectSorted:(ChatObject *)newChatObject
{
    DDLogDebug(@"%s",__FUNCTION__);
    NSBlockOperation *additionOperation = [NSBlockOperation new];
    __block ChatObject *blockChatObject = newChatObject;
    [additionOperation addExecutionBlock:^{
        __block NSUInteger indexToInsert = _chatObjectsHistory.count;
        BOOL didReplaceExistingMessage = NO;
        if(_chatObjectsHistory.count > 1)
        {
            // we need to check if a chatobject with this msgid exists,
            // in that case it will saved over the existing one in db and we should replace it
            // this can happen alot for group messages
            for (int i = (int)_chatObjectsHistory.count ; i > 0; i--)
            {
                ChatObject *thisChatObject = (ChatObject *) _chatObjectsHistory[i-1];
                if ([thisChatObject.msgId isEqualToString:blockChatObject.msgId])
                {
                    didReplaceExistingMessage = YES;
                    [_chatObjectsHistory replaceObjectAtIndex:i - 1 withObject:blockChatObject];
                }
            }
            
            if(!didReplaceExistingMessage)
            {
                const long long usec_per_sec = 1000000;
                long long tRecevived = (long long)blockChatObject.timeVal.tv_sec * usec_per_sec + (long long)blockChatObject.timeVal.tv_usec;
                
                for (int i = (int)_chatObjectsHistory.count ; i>0; i--) {
                    ChatObject *thisChatObject = (ChatObject *) _chatObjectsHistory[i-1];
                    
                    indexToInsert = i;
                    long long tThis = (long long)thisChatObject.timeVal.tv_sec * usec_per_sec + (long long)thisChatObject.timeVal.tv_usec;
                    
                    if(tRecevived > tThis)
                    {
                        break;
                    }
                    
                }
            }
        }
        __block NSMutableArray *newSectionObjectArray;
        if (!didReplaceExistingMessage)
        {
            [_chatObjectsHistory insertObject:blockChatObject atIndex:indexToInsert];
        }
        
        newSectionObjectArray = [self getChatSectionObjectsFromChatHistory:_chatObjectsHistory];
        __block long insertedSection = 0;
        __block long insertedRow = 0;
        for (int i = (int)newSectionObjectArray.count; i>0; i --)
        {
            SCSChatSectionObject *sectionObject = (SCSChatSectionObject *)newSectionObjectArray[i - 1];
            for (int j = (int)sectionObject.chatObjectsArray.count; j>0; j--)
            {
                ChatObject *chatObject = (ChatObject *)sectionObject.chatObjectsArray[j - 1];
                if ([chatObject isEqual:blockChatObject])
                {
                    insertedSection = i - 1;
                    insertedRow = j - 1;
                    break;
                }
            }
            
        }
        dispatch_sync(dispatch_get_main_queue(), ^{
            _chatHistory = newSectionObjectArray;
            if (didReplaceExistingMessage) // replace existing message with new one
            {
                [self.chatTableView beginUpdates];
                [self.chatTableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:insertedRow inSection:  insertedSection]] withRowAnimation:UITableViewRowAnimationNone];
                [self.chatTableView endUpdates];
            } else
            {
                // Insert new section or row
                if ([self.chatTableView numberOfSections] <= insertedSection || (insertedSection == 0 && insertedRow == 0) || [self.chatTableView numberOfSections] == 0)
                {
                    [self.chatTableView beginUpdates];
                    [self.chatTableView insertSections:[NSIndexSet indexSetWithIndex:insertedSection] withRowAnimation:UITableViewRowAnimationBottom];
                    [self.chatTableView endUpdates];
                } else
                {
                    [self.chatTableView beginUpdates];
                    [self.chatTableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:insertedRow inSection:  insertedSection]] withRowAnimation:UITableViewRowAnimationBottom];
                    [self.chatTableView endUpdates];
                }
                
                if (insertedSection == [_chatTableView numberOfSections] - 1 && insertedRow == [_chatTableView numberOfRowsInSection:insertedSection] - 1 && !isScrolling)
                {
                    [self.chatTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:insertedRow inSection:insertedSection] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
                }
            }
            [self updateEmptyConversationViews:NO];
        });
    }];
    [chatHistoryQueue addOperation:additionOperation];
    
}

-(void) loadNextMessages
{
    
    int totalMessageCount = 0;
    for (SCSChatSectionObject *sectionObject in _chatHistory)
    {
        totalMessageCount += sectionObject.chatObjectsArray.count;
    }
    __block NSMutableArray *weaksortedArray;
    __block NSMutableArray *weakSectionArray;
    
    NSBlockOperation *sortingOperation = [NSBlockOperation new];
    [sortingOperation addExecutionBlock:^{
        [[DBManager dBManagerInstance] loadEventsForRecent:openedRecent
                                                    offset:lastLoadedMsgNumber
                                                     count:[ChatUtilities utilitiesInstance].kMessageLoadingCount
                                           completionBlock:^(NSMutableArray *array, int lastMsgNumber)
         {
             lastLoadedMessageCount = (int)array.count;
             
             DDLogDebug(@"%s : %li",__FUNCTION__,array.count);
             
             // add existing messages to just loaded ones
             [array addObjectsFromArray:_chatObjectsHistory];
             
             // sort all messages array
             weaksortedArray = [[[DBManager dBManagerInstance] sort:array] mutableCopy];
             
             // If message is being burned right now, it will leave a blank space,
             // so we reset the burn animation started variable
             for (ChatObject *thisChatObject in weaksortedArray)
             {
                 if(thisChatObject.iDidBurnAnimation != 0)
                 {
                     thisChatObject.iDidBurnAnimation = 0;
                 }
             }
             
             // calculate sections
             weakSectionArray = [self getChatSectionObjectsFromChatHistory:weaksortedArray];
             dispatch_sync(dispatch_get_main_queue(), ^{
                 
                 // asign local arrays to calculated ones and reload in main
                 _chatObjectsHistory = weaksortedArray;
                 _chatHistory = weakSectionArray;
                 
                 [self updateEmptyConversationViews:NO];
                 
                 [_chatTableView setContentOffset:_chatTableView.contentOffset animated:NO];
                 CGFloat oldTableViewHeight = _chatTableView.contentSize.height;
                 [_chatTableView reloadData];
                 
                 // If we are loading first bunch of messages in tableview then we need to scroll to last indexpath, since we cant calculate contentOffset correctly with oldTableviewHeight as 0
                 if (oldTableViewHeight == 0)
                 {
                     [self scrollToFirstUnread];
                 } else
                 {
                     CGFloat newTableViewHeight = _chatTableView.contentSize.height;
                     _chatTableView.contentOffset = CGPointMake(0, newTableViewHeight - oldTableViewHeight);
                 }
                 lastLoadedMsgNumber = lastMsgNumber;
                 if(lastLoadedMsgNumber - 1 <= 0)
                 {
                     shouldCheckForMoreMessages = NO;
                     [[ChatUtilities utilitiesInstance] removeBadgesForConversation:openedRecent];
                 }
                 if(lastLoadedMessageCount > 0)
                 {
                     shouldCheckForMoreMessages = YES;
                     
                 }
                 else
                 {
                     shouldCheckForMoreMessages = NO;
                     [[ChatUtilities utilitiesInstance] removeBadgesForConversation:openedRecent];
                 }
             });
             
         }];
    }];
    [chatHistoryQueue addOperation:sortingOperation];
}

-(void) updateEmptyConversationViews:(BOOL) shouldHide {
    
    if (!openedRecent)
        return;
    
    if (_chatHistory.count <= 0 && !shouldHide)
    {
        [_emptyChatBackgroundView setHidden:NO];
        UIImage *contactImage = [AvatarManager avatarImageForConversationObject:openedRecent size:eAvatarSizeFull];
        [_emptyChatContactView setImage:contactImage];
        _emptyChatUserName.text = _displayTitle;
    }
    else
        [_emptyChatBackgroundView setHidden:YES];
}

- (void)requestAddressBookAvatar {
    
    if(!openedRecent)
        return;
    
    if(!openedRecent.abContact)
        return;
    
    if(openedRecent.abContact.contactImageIsCached)
        return;
    
    if(openedRecent.abContact.cachedContactImage)
        return;
    
    __weak ChatViewController *weakSelf = self;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [openedRecent.abContact requestContactImageSynchronously];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            __strong ChatViewController *strongSelf = weakSelf;
            
            if(!strongSelf)
                return;
            
            if([strongSelf.emptyChatBackgroundView isHidden])
                [strongSelf.emptyChatContactView setImage:openedRecent.abContact.cachedContactImage];
            else if(!isScrolling)
                [strongSelf scheduleTableReload];
        });
    });
}

-(void)splitViewController:(UISplitViewController *)svc willChangeToDisplayMode:(UISplitViewControllerDisplayMode)displayMode
{
    
    // if we are closing primaryVC and we have keyboard up for a textfield in it then ww need to close it
    if (displayMode == UISplitViewControllerDisplayModePrimaryHidden) {
        if (![actionSheetView.messageTextView isFirstResponder]) {
            [self.splitViewController.view endEditing:YES];
        }
    }
}


-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    
    [actionSheetView setFrameForScreenSize:size];
}

#pragma mark - KVO

// Wrappers for KVO so that we don't add observers that have already been added, or removing an observer that is already removed
// All of hte remove<something>Observer methods are being called on the ChatViewController's dealloc method so that we are sure that
// they are removed when the VC is freed from memory and not generate crashes
//
// NOTE/TODO: Most of the added observers can be removed when we move those views to IB AutoLayout logic


- (void)addAudioPlaybackHolderViewFrameObserver
{
    
    if(_audioPlaybackHolderViewFrameObserverAdded)
        return;
    
    _audioPlaybackHolderViewFrameObserverAdded = YES;
    
    [actionSheetView addObserver:audioPlaybackHolderView forKeyPath:@"frame" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)removeAudioPlaybackHolderViewFrameObserver
{
    
    if(!_audioPlaybackHolderViewFrameObserverAdded)
        return;
    
    _audioPlaybackHolderViewFrameObserverAdded = NO;
    
    [actionSheetView removeObserver:audioPlaybackHolderView forKeyPath:@"frame"];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"constant"] && [object isEqual:_chatTableViewBottomConstant]) {
        if (_chatTableViewBottomConstant.constant > kActionSheetHeight) {
            [self updateEmptyConversationViews:YES];
        } else
        {
            [self updateEmptyConversationViews:NO];
        }
    }
    /*
    // reload's tableview whenever a frame of self.view changes,
    // temporary easy fix to update layout of chatbubbles whenever device gets rotated or splitviewcontroller collapses
    if ([keyPath isEqualToString:@"frame"]) {
        NSLog(@"reloaded for ipad layout orientation changed");
    }*/
}
-(void) setUnreadMessageCountInOtherThreads
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int receivedOtherMessageCount = [[ChatUtilities utilitiesInstance] getBadgeValueWithoutUser:lastOpenedUserNameForChat];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            backButtonAlertLabel = [[UILabel alloc] init];
            [backButtonAlertLabel setBackgroundColor:[ChatUtilities utilitiesInstance].kAlertPointBackgroundColor];
            [backButtonAlertLabel setFont:[[ChatUtilities utilitiesInstance] getFontWithSize:12]];
            backButtonAlertLabel.numberOfLines = 1;
            backButtonAlertLabel.adjustsFontSizeToFitWidth = YES;
            [backButtonAlertLabel setTextColor:[UIColor whiteColor]];
            backButtonAlertLabel.text = [NSString stringWithFormat:@"%i",receivedOtherMessageCount];
            [backButtonAlertLabel setTextAlignment:NSTextAlignmentCenter];
            [backButtonAlertLabel setFrame:CGRectMake(backButtonWithImage.frame.size.width - backButtonAlertLabel.frame.size.width - 15, -6, 17, 17)];
            backButtonAlertLabel.layer.cornerRadius = backButtonAlertLabel.frame.size.width/2;
            backButtonAlertLabel.layer.masksToBounds = YES;
            [backButtonWithImage addSubview:backButtonAlertLabel];
            
            
            if(receivedOtherMessageCount <= 0)
            {
                [backButtonAlertLabel setHidden:YES];
            }
        });
    });
}

#pragma mark ActionSheetDelegate
-(void)doneButtonClick:(id)sender
{
    [self sendMessage:sender];
}

-(void)willOpenActionSheet:(id)actionsheetWithKeyboardView
{
    [_actionsheetViewRed updateButtonImages];
}

-(void)shouldChangeBottomOffsetTo:(CGFloat)offset canScroll:(BOOL)canScroll animated:(BOOL)animated
{
    self.chatTableViewBottomConstant.constant = offset;
    [self.view layoutIfNeeded];
    if (canScroll)
    {
        [self scrollToBottom:animated];
    }
}

- (void)burnSliderValueChanged:(long)newBurnTime
{
    if(!openedRecent || newBurnTime == openedRecent.burnDelayDuration)
        return;
    
    openedRecent.burnDelayDuration = newBurnTime;
    
    if (openedRecent.isGroupRecent)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            [[GroupChatManager sharedInstance] setBurnTime:newBurnTime
                                                   inGroup:openedRecent.contactName];
            
            [[GroupChatManager sharedInstance] applyGroupChanges:openedRecent.contactName];
        });
    }
}

#pragma mark - Utilities

- (IBAction)addGroupChatMember:(id)sender
{
    [actionSheetView closeBurnSlider];
    groupMemberRecentObjects = [GroupChatManager getAllGroupMemberRecentObjects:lastOpenedUserNameForChat];
    cancelReloadBeforeAppearing = YES;
    UIStoryboard *groupChatStoryBoard = [UIStoryboard storyboardWithName:@"GroupChat" bundle:nil];
    AddGroupMemberViewController *addGroupMemberViewController = (AddGroupMemberViewController *)[groupChatStoryBoard instantiateViewControllerWithIdentifier:@"AddGroupMemberViewController"];
    addGroupMemberViewController.delegate = self;
    addGroupMemberViewController.alreadyAddedContacts = groupMemberRecentObjects;
    [self.navigationController pushViewController:addGroupMemberViewController animated:YES];
}

-(void) addRightBarButtonForGroupChat
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        // adds image for rightbarbuttonItem
        UIButton *rightButtonWithImage = [UIButton buttonWithType:UIButtonTypeCustom];
        [rightButtonWithImage setTintColor:[UIColor whiteColor]];
        
        UIBarButtonItem *rightBarButton = [[UIBarButtonItem alloc] initWithCustomView:rightButtonWithImage];
        UIImage *addPeopleIcon = [UIImage navigationBarCreateGroupButton];
        [rightButtonWithImage addTarget:self action:@selector(addGroupChatMember:) forControlEvents:UIControlEventTouchUpInside];
        [rightButtonWithImage setAccessibilityLabel:NSLocalizedString(@"Add people", nil)];
        [rightButtonWithImage setImage:addPeopleIcon
                              forState:UIControlStateNormal];
        [rightButtonWithImage setFrame:CGRectMake(0,0,addPeopleIcon.size.width / 2,addPeopleIcon.size.height / 2)];
        self.navigationItem.rightBarButtonItem = rightBarButton;
    });
}

#pragma mark GroupChat MemberSelection
-(void)didfinishSelectinggroupMembers:(NSArray *)array
{
    NSMutableArray *contactNameArray = [[NSMutableArray alloc] initWithCapacity:array.count];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        for (RecentObject *recent in array)
        {
            [contactNameArray addObject:[[ChatUtilities utilitiesInstance] removePeerInfo:recent.contactName lowerCase:YES]];
            [[GroupChatManager sharedInstance] addUser:recent inGroup:lastOpenedUserNameForChat];
        }
        
        NSDictionary *grpCommand = @{@"grpId":lastOpenedUserNameForChat,@"grp":KGroupMembersAdded,@"mbrs":contactNameArray};
        
        [GroupChatManager createMemberCountChangedMessageFromGroupCommand:grpCommand byUserAction:YES showAlert:NO];
        
        [[GroupChatManager sharedInstance] applyGroupChanges:lastOpenedUserNameForChat];

        [[GroupChatManager sharedInstance] updateGroupAvatarWithCommandDict:grpCommand];
        [GroupChatManager updateGroupNameWithGroupCommand:@{@"grpId":lastOpenedUserNameForChat}];
    });
}


- (void)recentObjectResolved:(NSNotification *)notification
{
    [self recentObjectUpdated:notification];
}

#pragma mark - Public

- (void)presentContactSelection {
    
    if(_transitionDelegate && [_transitionDelegate respondsToSelector:@selector(presentContactSelectionScreenInController:completion:)])
       [_transitionDelegate presentContactSelectionScreenInController:self
                                                           completion:^(AddressBookContact *contact) {
            
                                                               if(contact)
                                                                   _pendingContactAttachment = contact;
                                                           }];
}

@end
