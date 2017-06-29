//
//  scsContactTypeSearchVM.m
//  SPi3
//
//  Created by Gints Osis on 02/02/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "SCSSearchVM.h"

//DataSource
#import "SCSChatSectionObject.h"
#import "DBManager.h"
#import "SCPCallbackInterface.h"
#import "SCSAvatarManager.h"

#import "SCSEnums.h"
#import "SCPNotificationKeys.h"
#import "SCSConstants.h"

//Contacts
#import "AddressBookContact.h"
#import "SCSContactsManager.h"
#import "Silent_Phone-Swift.h"
#import "UserService.h"

//Chat
#import <MobileCoreServices/MobileCoreServices.h>
#import "AttachmentManager.h"
#import "ChatUtilities.h"
#import "SCAttachment.h"
#import "SCSSearchVMHeaderFooterView.h"

//Categories
#import "UIColor+ApplicationColors.h"
#import "UIImage+ApplicationImages.h"

// Constants
static CGFloat const kContactCellHeight     = 80.0;
static NSTimeInterval const kDelaySearch    = 0.25;
static int const kMaxRowsUpdatedThreshold   = 1000;

@interface scsContactTypeSearchVM ()
    @property (nonatomic, strong) UITableView *searchTableView;
@end

@implementation scsContactTypeSearchVM
{
    NSMutableArray<SCSChatSectionObject *> *dataSource;
    
    NSOperationQueue *avatarQueue;
    
    NSOperationQueue *searchResultsQueue;
    
    SCSGlobalContactSearch *globalContactSearch;
    
    /*
     Contact type being searched right now
     */
    scsContactType currentSearchContactType;
    
    /*
     Current Active searches full list display type
     */
    scsContactType currentFullListContactType;
    
    /*
     Does search string contains at least one letter or number
     */
    BOOL isSearchTextValid;
    
    NSString *_searchText;
    
    BOOL _isScrolling;
    
    // Timer when searching for text
    // There is 0.2 second wait time until inserted text is actually searched
    // If more text is inserted during the wait time timer and search is canceled and new one is assigned
    // Avoids text spamming that causes tableview to lock main thread with agressive changes
    NSTimer *searchTimer;
}

-(instancetype)initWithTableView:(UITableView *)tableView {
    
    if(self = [super init]) {
        
        _searchTableView = tableView;
        _searchTableView.delegate = self;
        _searchTableView.dataSource = self;
        
        dataSource = [NSMutableArray new];
        
        avatarQueue = [NSOperationQueue new];
        avatarQueue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;
        
        globalContactSearch = [SCSGlobalContactSearch new];
        [globalContactSearch setDelegate:self];
        
        searchResultsQueue = [NSOperationQueue new];
        searchResultsQueue.maxConcurrentOperationCount = 1;
        
        UINib *cell = [UINib nibWithNibName:@"SCSContactTVCell" bundle:nil];
        [self.searchTableView registerNib:cell forCellReuseIdentifier:[SCSContactTVCell reuseId]];
        
        UINib *headerfooter = [UINib nibWithNibName:@"SCSSearchVMHeaderFooterView" bundle:nil];
        [self.searchTableView registerNib:headerfooter forHeaderFooterViewReuseIdentifier:[SCSSearchVMHeaderFooterView reusedId]];

        [_searchTableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
        
        [self registerNotifications];
    }
    
    return self;
}

- (void)dealloc {
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

-(void)setIsMultiSelectEnabled:(BOOL)isMultiSelectEnabled
{
    _isMultiSelectEnabled = isMultiSelectEnabled;
    
    if (isMultiSelectEnabled)
        self.selectedContacts = [NSMutableArray new];
}

#pragma mark Notifications

-(void) registerNotifications {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self selector:@selector(dataSourceUpdated:) name:kSCPReceiveMessageNotification object:nil];
    [nc addObserver:self selector:@selector(dataSourceUpdated:) name:AttachmentManagerReceiveAttachmentNotification object:nil];
    [nc addObserver:self selector:@selector(dataSourceUpdated:) name:ChatObjectCreatedNotification object:nil];
    [nc addObserver:self selector:@selector(dataSourceUpdated:) name:ChatObjectUpdatedNotification object:nil];
    [nc addObserver:self selector:@selector(dataSourceUpdated:) name:ChatObjectFailedNotification object:nil];
    [nc addObserver:self selector:@selector(dataSourceUpdated:) name:kSCPRemoveMessageNotification object:nil];
    [nc addObserver:self selector:@selector(dataSourceUpdated:) name:kSCSResetBadgeNumberNotification object:nil];
    [nc addObserver:self selector:@selector(dataSourceUpdated:) name:kSCSRecentObjectUpdatedNotification object:nil];
    [nc addObserver:self selector:@selector(dataSourceUpdated:) name:kSCSRecentObjectRemovedNotification object:nil];
    [nc addObserver:self selector:@selector(dataSourceUpdated:) name:kSCSRecentObjectCreatedNotification object:nil];
}

/*
 When message is received if we are displaying full list of conversations
 refresh the entire list to display new last message info
 */
#pragma mark ReceiveMessage

-(void) dataSourceUpdated:(NSNotification*)notification {
    
    if([notification.name isEqualToString:kSCSRecentObjectUpdatedNotification]) {

        RecentObject *recent = [notification.userInfo objectForKey:kSCPRecentObjectDictionaryKey];
        
        if(recent)
            [self reloadCellWithRecentObject:recent
                             otherwiseUpdate:NO];
        
        return;
    }

    BOOL doesContainConversations = (self.displayedFullLists & scsContactTypeAllConversations ||
                                     self.displayedFullLists & scsContactTypeGroupConversations);
    
    if (doesContainConversations) {
        
        if([notification.name isEqualToString:kSCSRecentObjectCreatedNotification]) {

            RecentObject *recent = [notification.userInfo objectForKey:kSCPRecentObjectDictionaryKey];
            
            if(recent)
                [self reloadCellWithRecentObject:recent
                                 otherwiseUpdate:YES];
            
        }
        else if([notification.name isEqualToString:kSCSResetBadgeNumberNotification]) {
            
            ChatObject *chatObject = [notification.userInfo objectForKey:kSCPChatObjectDictionaryKey];
            
            if(!chatObject)
                return;
            
            RecentObject *recent = [[DBManager dBManagerInstance] getRecentByName:chatObject.contactName];
            
            if(recent)
                [self reloadCellWithRecentObject:recent
                                 otherwiseUpdate:!_isSearchActive];
        }
        else if([notification.name isEqualToString:kSCSRecentObjectRemovedNotification]) {
            
            RecentObject *recent = [notification.userInfo objectForKey:kSCPRecentObjectDictionaryKey];
            [self deleteRecentObject:recent];
            
        } else {
            
            // Handle the rest of notifications by refreshing the conversation list
            // as a conversation might have to bubble to the top:
            //
            // ChatObjectCreatedNotification, ChatObjectUpdatedNotification, ChatObjectFailedNotification
            // kSCPReceiveMessageNotification, AttachmentManagerReceiveAttachmentNotification
            [self showFullListsOfContactType:self.displayedFullLists];
        }
    }
}

#pragma mark UITableViewDelegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath
                             animated:YES];
    
    SCSChatSectionObject *sectionObject = dataSource[indexPath.section];
    RecentObject *recentObject = sectionObject.chatObjectsArray[indexPath.row];
    SCSContactTVCell *cell = (SCSContactTVCell*)[self.searchTableView cellForRowAtIndexPath:indexPath];
    
    if (self.isMultiSelectEnabled)
    {
        NSString *accessibilityString = nil;
        if ([self isRecentSelected:recentObject])
        {
            accessibilityString = [NSString stringWithFormat:@"%@ %@",NSLocalizedString(kAdd, nil),recentObject.displayName];
            [self removeSelectedRecent:recentObject callDelegate:YES];
            [cell setUnSelectedCheckmarkImage];
        } else
        {
            accessibilityString = [NSString stringWithFormat:@"%@ %@",NSLocalizedString(kRemove, nil),recentObject.displayName];
            [self addSelectedRecent:recentObject
                             ofType:sectionObject.contactType];
            [cell setSelectedCheckmarkImage];
        }
        cell.accessibilityLabel = accessibilityString;
    }
    
    if ([self.actionDelegate respondsToSelector:@selector(didTapRecentObject:)])
    {
        [self.actionDelegate didTapRecentObject:recentObject];
    }
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    SCSChatSectionObject *sectionObject = (SCSChatSectionObject *)dataSource[section];
    
    if(
       !sectionObject.headerTitle ||
       ((self.hiddenHeaders & sectionObject.contactType) && (self.hiddenHeaders & _displayedFullLists))
       )
        return 0;
    
    return 30;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return kContactCellHeight;
}
-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.isMultiSelectEnabled)
    {
        SCSContactTVCell *recentCell = (SCSContactTVCell *) cell;
        SCSChatSectionObject *sectionObject = dataSource[indexPath.section];
        RecentObject *thisRecent = sectionObject.chatObjectsArray[indexPath.row];
        if ([self isRecentSelected:thisRecent])
        {
            [recentCell setSelectedCheckmarkImage];
        } else
        {
            [recentCell setUnSelectedCheckmarkImage];
        }
    }
}
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SCSContactTVCell *recentCell = [tableView dequeueReusableCellWithIdentifier:[SCSContactTVCell reuseId]
                                                                forIndexPath:indexPath];
    
    recentCell.delegate = self;
    
    [recentCell.externaImageView setHidden:YES];
    [recentCell.contactInfoLabel setHidden:YES];    
    // lastMessageTimeLabel only shows in conversation cells (set below)
    recentCell.lastMessageTimeLabel.hidden = YES;    
    [recentCell.addGroupMemberImageView setHidden:!self.isMultiSelectEnabled];
    
    SCSChatSectionObject *sectionObject = dataSource[indexPath.section];
    
    RecentObject *thisRecent = sectionObject.chatObjectsArray[indexPath.row];
    
    //TODO JN: we must remove lastConversationObject, it because you have to sync it on every event
    ChatObject *lastChatObject = nil;
    
    BOOL isConversationType = (sectionObject.contactType == scsContactTypeAllConversations ||
                               sectionObject.contactType == scsContactTypeGroupConversations);
    
    if(!self.isMultiSelectEnabled && isConversationType)
        lastChatObject = thisRecent.lastConversationObject;
    
    //if (self.isMultiSelectEnabled)
     //   recentCell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    NSString *displayName = thisRecent.displayName;
    
    if(thisRecent.abContact && thisRecent.abContact.fullName)
        displayName = thisRecent.abContact.fullName;
        
    if(!displayName && !thisRecent.isGroupRecent)
        displayName = [[ChatUtilities utilitiesInstance] removePeerInfo:thisRecent.contactName
                                                              lowerCase:NO];
    
    if (!displayName)
    {
        if (!thisRecent.isGroupRecent)
            displayName = NSLocalizedString(kUnknown, nil);
        else
        {
            displayName = NSLocalizedString(kNewGroupConversation, nil);
        }
    }
    
    NSString *lastMessageLabelText = lastChatObject.messageText;
    
    recentCell.contactType = sectionObject.contactType;
    [recentCell.separatorView setHidden:YES];
    [recentCell.failedBadgeImageView setHidden:YES];
#if HAS_DATA_RETENTION
    recentCell.dataRetentionImageView.hidden = (!thisRecent.drEnabled);
#else
    recentCell.dataRetentionImageView.hidden = YES;
#endif // HAS_DATA_RETENTION
    
    BOOL showAvatar = YES;
    
    // Look if the previous recent object has the same linked ab Contact
    if(indexPath.row > 0 && (sectionObject.contactType == scsContactTypeAddressBook || sectionObject.contactType == scsContactTypeAddressBookSilentCircle)) {
        
        RecentObject *previousRecent = sectionObject.chatObjectsArray[indexPath.row - 1];

        if(thisRecent.abContact && previousRecent.abContact && [thisRecent.abContact isEqualToAddressBookContact:previousRecent.abContact])
            showAvatar = NO;
    }

    [recentCell.contactNameLabel setHidden:!showAvatar];
    [recentCell.contactView setHidden:!showAvatar];
    
     int receivedMessageCount = [[ChatUtilities utilitiesInstance] getBadgeValueForUser:thisRecent.contactName];
    
    if(showAvatar)
    {
        UIImage *avatarImage = [AvatarManager avatarImageForConversationObject:thisRecent size:eAvatarSizeSmall];
        [recentCell setContactImage:avatarImage];
        
        if(thisRecent.isExternal)
            [recentCell.externaImageView setHidden:NO];
        
        if(thisRecent.isNumber)
        {
            displayName = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(kCall, nil), displayName];
        }

        BOOL highlighted = NO;
        if ((_isSearchActive && (
                                 sectionObject.contactType == scsContactTypeDirectory || sectionObject.contactType == scsContactTypeSearch) &&
             [_searchText isEqualToString:thisRecent.displayAlias])||(
           sectionObject.contactType == scsContactTypeAllConversations && receivedMessageCount > 0))
        {
            highlighted = YES;
        }
        
        [recentCell setContactName:displayName
                       highlighted:highlighted];
    }
    
    [recentCell.lastMessageTextLabel setTextColor:[UIColor recentsOriginalLastMessageFontColor]];
    
    // assign correct chat icon and last message font color
    if(lastChatObject)
    {
        if(lastChatObject.isCall)
        {
            UIColor *tintColor  = [UIColor callIconViewTintColor];
            UIImage *arrowImage = [UIImage incomingCallEventArrow]; 
            
            if (!lastChatObject.isIncomingCall) {
                arrowImage = [UIImage outgoingCallEventArrow];
            }
            switch (lastChatObject.callState) {
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
            
            [recentCell.callIconView setHidden:NO];
            [recentCell.callIconView setImage:[arrowImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
            [recentCell.callIconView setTintColor:tintColor];
            
            lastMessageLabelText = lastChatObject.messageText;
            
            [recentCell.lastMessageTextLabel setTextColor:tintColor];
        }
        // if lastchatobject exists, and is not a call
        else
        {
            if(lastChatObject.attachment)
            {
                // detect last message content
                NSString *mediaType = [lastChatObject.attachment.metadata objectForKey:kSCloudMetaData_MediaType];
                if(lastChatObject.hasFailedAttachment)
                {
                    lastMessageLabelText = NSLocalizedString(kFailedAttachment, nil);
                    [recentCell.failedBadgeImageView setHidden:NO];
                    recentCell.lastMessageTextLabel.textColor = [UIColor recentsLastMessageFontColor];
                } else
                    if ([(__bridge NSString *)kUTTypeAudio isEqualToString:mediaType])
                    {
                        lastMessageLabelText = NSLocalizedString(kAudio, nil);
                    } else if ([(__bridge NSString *)kUTTypeImage isEqualToString:mediaType])
                    {
                        lastMessageLabelText = NSLocalizedString(kImage, nil);
                    } else if([(__bridge NSString *)kUTTypeMovie isEqualToString:mediaType])
                    {
                        lastMessageLabelText = NSLocalizedString(kMovie, nil);
                    }
                    else if([(__bridge NSString *)kUTTypePDF isEqualToString:mediaType])
                    {
                        lastMessageLabelText = NSLocalizedString(kPDF, nil);
                    }
                    else
                    {
                        lastMessageLabelText = NSLocalizedString(kFile, nil);
                    }
                if(!lastChatObject.hasFailedAttachment)
                {
                    if(lastChatObject.isReceived == 1)
                    {
                        lastMessageLabelText = [NSString stringWithFormat:@"%@ %@",NSLocalizedString(kReceived, nil),lastMessageLabelText];
                    } else
                    {
                        lastMessageLabelText = [NSString stringWithFormat:@"%@ %@",NSLocalizedString(kSent, nil),lastMessageLabelText];
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
            
            // Append a "You: " in front of the last message if it has been sent by the user
            // to better understanding of who sent the last message (ala FB Messenger, Hangouts, etc)
            if(lastChatObject.isReceived == 0 && lastChatObject.isInvitationChatObject == 0)
                lastMessageLabelText = [NSString stringWithFormat:@"%@: %@",NSLocalizedString(kYou, nil), lastMessageLabelText];
            else if(lastChatObject.isReceived == 1 && lastChatObject.isGroupChatObject)
            {
                // For received group message append first name of senders display name
                NSString *sendersFirstName = [[ChatUtilities utilitiesInstance] firstNameFromFullName:lastChatObject.senderDisplayName];
                if (sendersFirstName)
                {
                    lastMessageLabelText = [NSString stringWithFormat:@"%@: %@",sendersFirstName, lastMessageLabelText];
                }
            }
            
            [recentCell.lastMessageTextLabel setTextColor:[UIColor recentsOriginalLastMessageFontColor]];
            [recentCell.callIconView setHidden:YES];
        }
    }
    else
    {
        if(!lastMessageLabelText)
        {
            if (sectionObject.contactType == scsContactTypeDirectory || sectionObject.contactType == scsContactTypeAddressBook || self.isMultiSelectEnabled || sectionObject.contactType == scsContactTypeAddressBookSilentCircle) {
                
                if (thisRecent.displayAlias)
                    lastMessageLabelText = [[ChatUtilities utilitiesInstance] removePeerInfo:thisRecent.displayAlias lowerCase:NO];
                else if (![[ChatUtilities utilitiesInstance] isUUID:thisRecent.contactName])
                    lastMessageLabelText = [[ChatUtilities utilitiesInstance] removePeerInfo:thisRecent.contactName lowerCase:NO];
            } else
            {
                    lastMessageLabelText = NSLocalizedString(kNoMessages, nil);
            }
        }
        [recentCell.callIconView setHidden:YES];
    }
    
    if(!showAvatar)
        [recentCell.lastMessageTextTopConstraint setConstant:-9.5f];
    else
        [recentCell.lastMessageTextTopConstraint setConstant:0];
        
    [recentCell.lastMessageTextLabel setText:lastMessageLabelText];
    
    if (thisRecent.contactInfoLabel && !self.isMultiSelectEnabled)
    {        
        [recentCell.contactInfoLabel setHidden:NO];
        [recentCell.contactInfoLabel setText:[thisRecent.contactInfoLabel uppercaseString]];
    } 
    //ET: Only show lastMessageLabel in conversation cells
    scsContactType contactType = sectionObject.contactType;
    if (contactType == scsContactTypeAllConversations || contactType == scsContactTypeGroupConversations)  
    {
        long timeStamp = 0;
        if (lastChatObject)
            timeStamp = lastChatObject.unixTimeStamp;
        else
            timeStamp = thisRecent.unixTimeStamp;
        
        NSString *timeLabelString = [[ChatUtilities utilitiesInstance] chatListDateFromDateStamp:timeStamp];
        [recentCell.lastMessageTimeLabel setText:timeLabelString];
        [recentCell.lastMessageTimeLabel setAccessibilityLabel:timeLabelString];
        recentCell.lastMessageTimeLabel.hidden = NO;
    }

    
    [recentCell.messageAlertView setHidden:YES];
    
    if(receivedMessageCount <= 0)
        [recentCell.messageAlertView setHidden:YES];
    else if(recentCell.failedBadgeImageView.hidden)
    {
        [recentCell.messageAlertView setHidden:NO];
        [recentCell.messageAlertView setText:[NSString stringWithFormat:@"%i",receivedMessageCount]];
    }
    if (!self.isMultiSelectEnabled)
    {
        NSMutableArray *accessibilityCustomActions = [NSMutableArray arrayWithCapacity:3];
        
        [accessibilityCustomActions addObject:[[UIAccessibilityCustomAction alloc] initWithName:NSLocalizedString(kCall, nil)
                                                                                         target:recentCell
                                                                                       selector:@selector(accessibilityCall)]];
        
        if(isConversationType) {
            [accessibilityCustomActions addObject:[[UIAccessibilityCustomAction alloc] initWithName:NSLocalizedString(kDelete, nil)
                                                                                             target:recentCell
                                                                                           selector:@selector(accessibilityDelete)]];
        }
        
        if (!thisRecent.abContact && !thisRecent.isGroupRecent) {
            [accessibilityCustomActions addObject:[[UIAccessibilityCustomAction alloc] initWithName:NSLocalizedString(kSaveToContacts, nil)
                                                                                             target:recentCell
                                                                                           selector:@selector(accessibilitySaveToContacts)]];
        }
        
        recentCell.accessibilityCustomActions = accessibilityCustomActions;
    } else
    {
        NSString *accessibilityString = nil;
        if ([self isRecentSelected:thisRecent])
        {
            accessibilityString = [NSString stringWithFormat:@"%@ %@",NSLocalizedString(kRemove, nil),thisRecent.displayName];
        } else
        {
            accessibilityString = [NSString stringWithFormat:@"%@ %@",NSLocalizedString(kAdd, nil),thisRecent.displayName];
        }
        recentCell.accessibilityLabel = accessibilityString;
    }
    
    [recentCell.contentView setBackgroundColor:[UIColor clearColor]];

    
    return recentCell;
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return dataSource.count;
}


-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    SCSChatSectionObject *sectionObject = dataSource[section];
    
    return sectionObject.chatObjectsArray.count;
}

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    SCSChatSectionObject *sectionObject = (SCSChatSectionObject *)dataSource[section];
    
    if(sectionObject.contactType == scsContactTypeSearch)
        return nil;
    SCSSearchVMHeaderFooterView *headerFooterView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:[SCSSearchVMHeaderFooterView reusedId]];
    headerFooterView.mainTitle.text = sectionObject.headerTitle;
    headerFooterView.subtitle.text = sectionObject.headerSubtitle;
    
    return headerFooterView;
}


#pragma mark DataSource
-(void)showFullListsOfContactType:(scsContactType)type
{
    self.displayedFullLists = type;
    
    _searchText = @"";

    [globalContactSearch searchText:@""
                             filter:[self getGlobalContactSearchFilterFromContactType:type]];
}


#pragma mark AvatarQueue

-(void) requestContactImageAsynchronouslyForContact:(AddressBookContact*) contact ofRecent:(RecentObject *)recent
{
    __weak scsContactTypeSearchVM *weakSelf = self;
    
    NSBlockOperation *imageOperation = [NSBlockOperation blockOperationWithBlock:^{
        
        [contact requestContactImageSynchronously];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            __strong scsContactTypeSearchVM *strongSelf = weakSelf;
            
            if(!strongSelf.searchTableView)
                return;
            
            if(!strongSelf)
                return;
            
            SCSContactTVCell *cell = [strongSelf getCellFromRecentObject:recent];
            
            if (cell)
                [self.searchTableView reloadRowsAtIndexPaths:@[[self.searchTableView indexPathForCell:cell]]
                                            withRowAnimation:UITableViewRowAnimationNone];
        });
    }];
    
    [avatarQueue addOperation:imageOperation];

}

#pragma mark SCSGlobalContactSearchDelegate

- (void)scsGlobalContactSearchWillBeginSearching:(SCSGlobalContactSearch*)globalSearch
{
    if(self.displayedFullLists & scsContactTypeDirectory)
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

- (void)scsGlobalContactSearchDidStopSearching:(SCSGlobalContactSearch*)globalSearch
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

-(void)scsGlobalContactSearch:(SCSGlobalContactSearch *)globalSearch didReturnContacts:(NSMutableArray *)contacts ofFilter:(SCSGlobalContactSearchFilter)filter forSearchText:(NSString *)searchText
{
    // Do not show delayed responses for previous searches.
    //
    // This is already done inside the SCSGlobalContactSearch
    // but it's here as well for sanity purposes.
    if(![searchText isEqualToString:_searchText])
        return;
    
    scsContactType contactType = [self getContactTypeFromGlobalContactSearchFilter:filter];
    
    if (!self.isSearchActive && contactType == scsContactTypeDirectory)
        return;
    
    __block NSMutableArray *blockContacts = contacts;
    
    NSBlockOperation *searchResultsOperation = [NSBlockOperation blockOperationWithBlock:^{
        
        if (self.shouldDisableNumbers)
        {
            NSMutableArray *numberContacts = [NSMutableArray new];
            for (RecentObject *recent in blockContacts)
            {
                if (recent.isNumber)
                    [numberContacts addObject:recent];
            }
            [blockContacts removeObjectsInArray:numberContacts];
        }
        
         //Remove contacts existing in alreadyAddedContacts before displaying
        if (self.alreadyAddedContacts.count > 0)
        {
            NSMutableArray *nonAddedContacts = [NSMutableArray new];
            
            for (RecentObject *recent in blockContacts)
            {
                NSString *strippedContactName = [[ChatUtilities utilitiesInstance] removePeerInfo:recent.contactName lowerCase:YES];
                
                if(![self contactExistsInAddedArray:strippedContactName])
                {
                    [nonAddedContacts addObject:recent];
                }
            }
            
            blockContacts = nonAddedContacts;
        }
        
        [self addSectionOfType:contactType withContactArray:blockContacts];
    }];
    
    [searchResultsQueue addOperation:searchResultsOperation];
}


#pragma mark Search

-(void)activateSearchforTypes:(scsContactType) searchType andDisplayFullListsOfTypes:(scsContactType)displayType
{
    _isSearchActive = YES;
    currentSearchContactType = searchType;
    currentFullListContactType = displayType;
    
    scsContactType allSectionTypes = (scsContactTypeAllConversations|
                                      scsContactTypeGroupConversations|
                                      scsContactTypeAddressBook|
                                      scsContactTypeDirectory|
                                      scsContactTypeSearch|
                                      scsContactTypeAddressBookSilentCircle);
    
    [self removeSection:allSectionTypes];
    [self showFullListsOfContactType:displayType];
}

-(void)deactivateSearchAndShowContactTypes:(scsContactType) contactType
{
    _isSearchActive = NO;
    [searchResultsQueue cancelAllOperations];
    
    scsContactType allSectionTypes = (scsContactTypeAllConversations|
                                      scsContactTypeGroupConversations|
                                      scsContactTypeAddressBook|
                                      scsContactTypeDirectory|
                                      scsContactTypeSearch|
                                      scsContactTypeAddressBookSilentCircle);
    
    [self removeSection:allSectionTypes];
    [self showFullListsOfContactType:contactType];
}

- (void)searchText:(NSString*)text
{
    if ([searchTimer isValid])
        [searchTimer invalidate];
    
    _isSearchActive = YES;
    searchTimer = nil;
    
    // Immediately clear search
    NSTimeInterval delaySearch = (text == nil || [text isEqualToString:@""] ? 0.0f : kDelaySearch);
    
    searchTimer = [NSTimer scheduledTimerWithTimeInterval:delaySearch
                                                   target:self
                                                 selector:@selector(timerSearchAction:)
                                                 userInfo:text
                                                  repeats:NO];
}

-(void) timerSearchAction:(NSTimer *) timer
{
    if(!self.isSearchActive)
        return;

    NSString *text = (NSString *)timer.userInfo;
    
    NSRange characterRange = [text rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet]];
    NSRange numberRange = [text rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]];
    
    // Removes search if search string doesn't contain number or letter character
    if (numberRange.location != NSNotFound || characterRange.location != NSNotFound)
    {
        NSRange range = [text rangeOfString:@"^\\s*"
                                    options:NSRegularExpressionSearch];
        
        text = [text stringByReplacingCharactersInRange:range
                                             withString:@""];
        
        _searchText = text;

        isSearchTextValid = YES;
        
        [self setSectionsToSearch];
        
        self.displayedFullLists = currentSearchContactType;
        
        [globalContactSearch searchText:text
                                 filter:[self getGlobalContactSearchFilterFromContactType:currentSearchContactType]];
    }
    else
    {
        if (isSearchTextValid)
        {
            isSearchTextValid = NO;
            
            [self removeSection:scsContactTypeSearch | currentSearchContactType];
            [self showFullListsOfContactType:currentFullListContactType];
        }
    }
}

#pragma mark - Section Actions

-(void) removeSection:(scsContactType) contactType
{
    NSBlockOperation *removeSectionOperation = [NSBlockOperation blockOperationWithBlock:^{
        
        if (![self existsSection:contactType])
            return;
        
        NSMutableArray *sectionsToRemove = [[NSMutableArray alloc] initWithCapacity:dataSource.count];
        BOOL removeAddressBook = (contactType & scsContactTypeAddressBook);
        BOOL removeDirectory = (contactType & scsContactTypeDirectory);
        BOOL removeConversations = ((contactType & scsContactTypeAllConversations) || (contactType & scsContactTypeGroupConversations));
        BOOL removeSearch = (contactType & scsContactTypeSearch);
        BOOL removeSilentCircle = (contactType & scsContactTypeAddressBookSilentCircle);
        
        NSMutableIndexSet *sectionsToDelete = [NSMutableIndexSet indexSet];
        
        for (NSInteger i = 0; i<dataSource.count; i++)
        {
            SCSChatSectionObject *sectionObject = dataSource[i];
            
            if ((removeAddressBook && sectionObject.contactType == scsContactTypeAddressBook) ||
                (removeDirectory && sectionObject.contactType == scsContactTypeDirectory) ||
                (removeConversations && (sectionObject.contactType == scsContactTypeAllConversations ||
                                         sectionObject.contactType == scsContactTypeGroupConversations)) ||
                (removeSearch && sectionObject.contactType == scsContactTypeSearch) ||
                (removeSilentCircle && sectionObject.contactType == scsContactTypeAddressBookSilentCircle))
            {
                [sectionsToDelete addIndex:i];
                [sectionsToRemove addObject:sectionObject];
            }
        }
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            [dataSource removeObjectsInArray:sectionsToRemove];
            
            if([dataSource count] == 0)
                [self.searchTableView reloadData];
            else
            {
                [self.searchTableView beginUpdates];
                [self.searchTableView deleteSections:sectionsToDelete
                                    withRowAnimation:UITableViewRowAnimationNone];
                [self.searchTableView endUpdates];
            }
        });
    }];
    
    [searchResultsQueue addOperation:removeSectionOperation];
}

-(BOOL) existsSection:(scsContactType) contactType
{
    for (SCSChatSectionObject *sectionObject in dataSource)
    {
        if(contactType & sectionObject.contactType)
            return YES;
    }
    return NO;
}
/*
 Set's section header's to searching ... string
 If contact type passed in this flag doesn't exist it is added with empty contact array
 */
-(void) setSectionsToSearch
{
    BOOL existsAddressBook = (currentSearchContactType & scsContactTypeAddressBook);
    BOOL existsDirectory = (currentSearchContactType & scsContactTypeDirectory);
    BOOL existsConversations = ((currentSearchContactType & scsContactTypeAllConversations) || (currentSearchContactType & scsContactTypeGroupConversations));
    BOOL existsSearch = (currentSearchContactType & scsContactTypeSearch);
    BOOL existsSilentCircle = (currentSearchContactType & scsContactTypeAddressBookSilentCircle);
    
        for (NSInteger i = 0; i<dataSource.count; i++)
    {
        SCSChatSectionObject *section = dataSource[i];
        if ((existsAddressBook && section.contactType == scsContactTypeAddressBook) ||
            (existsDirectory && section.contactType == scsContactTypeDirectory) ||
            (existsConversations && (section.contactType == scsContactTypeAllConversations ||
                                     section.contactType == scsContactTypeGroupConversations)) ||
            (existsSearch && section.contactType == scsContactTypeSearch) ||
            (existsSilentCircle && section.contactType == scsContactTypeAddressBookSilentCircle))
        {
            section.headerSubtitle = NSLocalizedString(kSearching, nil);
            [self updateHeaderForSection:i];
        }
    }

}

/*
 Add section of type with array of recentObjects
 @param contactType - section of type to add or refresh
 @param array - array of RecentObject's to add
 */
-(void) addSectionOfType:(scsContactType) contactType  withContactArray:(NSMutableArray *) array
{
    NSString *headerTitle = nil;
    NSString *headerSubtitle = nil;
    
    if ((_hiddenHeaders & contactType))
    {
        headerTitle = nil;
    }
    else
    {
        switch (contactType)
        {
            case scsContactTypeAllConversations:
            {
                headerTitle = NSLocalizedString(kAllConversations, nil);
            }
                break;
            case scsContactTypeGroupConversations:
            {
                headerTitle = NSLocalizedString(kGroupConversations, nil);
            }
                break;
            case scsContactTypeAddressBook:
            {
                headerTitle = NSLocalizedString(kContacts, nil);
            }
                break;
            case scsContactTypeAddressBookSilentCircle:
            {
                headerTitle = [NSString stringWithFormat:@"%@ %@", kSilentCircle, kcontacts];
            }
                break;
            case scsContactTypeDirectory:
            {
                NSString *organizationString = [UserService currentUser].displayOrganization;
                
                if(!organizationString)
                    organizationString = kSilentCircle;
                
                headerTitle = [NSString stringWithFormat:@"%@ %@", organizationString, NSLocalizedString(kdirectory,nil)];
            }
                break;
                
            default:
                break;
        }
    }
    
    if (array.count == 0)
    {
        if(contactType == scsContactTypeDirectory ||
           contactType == scsContactTypeAllConversations ||
           contactType == scsContactTypeGroupConversations) {
            headerSubtitle = NSLocalizedString(kNoResults, nil);
        }
        else
            headerSubtitle = NSLocalizedString(kNoContacts, nil);
    }
    else if (contactType == scsContactTypeDirectory && array.count > 20)
    {
        headerSubtitle = NSLocalizedString(kMoreThan20Results, nil);
    }
    else
    {
        NSString *suffix = kFound;
        
        if(contactType == scsContactTypeDirectory)
            suffix = (array.count == 1 ? kResult : kResults);
        
        headerSubtitle = [NSString stringWithFormat:@"%lu %@",(unsigned long)array.count, suffix];
    }
    
    __block SCSChatSectionObject *newSectionObject = [SCSChatSectionObject new];
    newSectionObject.headerTitle        = headerTitle;
    newSectionObject.headerSubtitle     = headerSubtitle;
    newSectionObject.contactType        = contactType;
    newSectionObject.chatObjectsArray   = array;
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        
        if ([self existsSection:contactType])
        {
            for (NSInteger i = 0; i<dataSource.count; i++)
            {
                SCSChatSectionObject *sectionObject = dataSource[i];
                
                if (sectionObject.contactType == contactType)
                {
                    if (![sectionObject.chatObjectsArray isEqualToArray:array] ||
                        contactType == scsContactTypeSearch ||
                        contactType == scsContactTypeAllConversations ||
                        contactType == scsContactTypeGroupConversations)
                    {
                        [dataSource replaceObjectAtIndex:i
                                              withObject:newSectionObject];
                        
                        BOOL doesExceedThreshold = ([sectionObject.chatObjectsArray count] > kMaxRowsUpdatedThreshold ||
                                                    [array count] > kMaxRowsUpdatedThreshold);
                        
                        if(doesExceedThreshold)
                            [self.searchTableView reloadData];
                        else
                        {
                            [UIView setAnimationsEnabled:NO];
                            [self.searchTableView beginUpdates];
                            [self.searchTableView reloadSections:[NSIndexSet indexSetWithIndex:i]
                                                withRowAnimation:UITableViewRowAnimationNone];
                            [self.searchTableView endUpdates];
                            [UIView setAnimationsEnabled:YES];
                        }
                    }
                    else
                    {
                        sectionObject.headerSubtitle = newSectionObject.headerSubtitle;
                        sectionObject.headerTitle = newSectionObject.headerTitle;
                    }
                    
                    [self updateHeaderForSection:i];
                    break;
                }
            }
        }
        else
        {
            /**
             Order of display:
             
             1) Search
             2) Conversations (All or just groups)
             3) Directory
             4) Address Book SC
             5) Address Book
             */
            
            NSInteger index = 0;
            
            switch (contactType)
            {
                case scsContactTypeSearch:
                {
                    index = 0;
                }
                    break;
                case scsContactTypeAllConversations:
                case scsContactTypeGroupConversations:
                {
                    if ([self existsSection:scsContactTypeSearch])
                        index++;
                }
                    break;
                case scsContactTypeDirectory:
                {
                    if ([self existsSection:scsContactTypeSearch])
                        index++;

                    if([self existsSection:scsContactTypeAllConversations] ||
                       [self existsSection:scsContactTypeGroupConversations])
                        index++;
                }
                    break;
                case scsContactTypeAddressBookSilentCircle:
                {
                    if ([self existsSection:scsContactTypeSearch])
                        index ++;

                    if([self existsSection:scsContactTypeAllConversations] ||
                       [self existsSection:scsContactTypeGroupConversations])
                        index++;

                    if ([self existsSection:scsContactTypeDirectory])
                        index ++;
                }
                    break;
                case scsContactTypeAddressBook:
                {
                    if ([self existsSection:scsContactTypeSearch])
                        index ++;

                    if ([self existsSection:scsContactTypeDirectory])
                        index ++;

                    if([self existsSection:scsContactTypeAllConversations] ||
                       [self existsSection:scsContactTypeGroupConversations])
                        index++;

                    if ([self existsSection:scsContactTypeAddressBookSilentCircle])
                        index ++;
                }
                    break;
                default:
                    break;
            }

            [dataSource insertObject:newSectionObject
                             atIndex:index];
            
            BOOL doesExceedThreshold = ([array count] > kMaxRowsUpdatedThreshold);
            
            if(doesExceedThreshold)
                [self.searchTableView reloadData];
            else
            {
                [self.searchTableView beginUpdates];
                [self.searchTableView insertSections:[NSIndexSet indexSetWithIndex:index]
                                    withRowAnimation:UITableViewRowAnimationNone];
                [self.searchTableView endUpdates];
            }
        }
        
        [self requestVisibleAddressBookAvatars];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSContactTypeSearchTableUpdated
                                                            object:self];
    });
}

// SCSContactTVCell is a subclass of SCSContactViewSwipeCell, which is
// a subclass of MGSwipeTableCell.
// The SCSContactViewSwipeCellDelegate, declared in SCSContactViewSwipeCell.h,
// extends MGSwipeTableCellDelegate.
#pragma mark - MGSwipeTableCellDelegate Methods

-(BOOL) swipeTableCell:(MGSwipeTableCell*) cell canSwipe:(MGSwipeDirection) direction {
    
    if (!self.isSwipeEnabled)
        return NO;

    NSIndexPath *indexPath = [self.searchTableView indexPathForCell:cell];
    SCSChatSectionObject *sectionObject = dataSource[indexPath.section];
    
    if(sectionObject.contactType != scsContactTypeAllConversations &&
       sectionObject.contactType != scsContactTypeGroupConversations) {
        
        if(direction == MGSwipeDirectionRightToLeft)
            return NO;
    }
    
    return YES;
}

-(void)swipeTableCellWillBeginSwiping:(SCSContactTVCell *)cell
{
    // get buttons by tags and assign them as accessibility elements
    SCSContactTVCell *callButton = [cell viewWithTag:25];
    SCSContactTVCell *chatbutton = [cell viewWithTag:26];
    SCSContactTVCell *deleteButton = [cell viewWithTag:27];
    
    if(callButton && chatbutton && deleteButton)  {
        
        SCSContactTVCell *btSaveContact = [cell viewWithTag:26];
        if (btSaveContact) {
            [cell setAccessibilityElements:@[callButton, chatbutton, btSaveContact, deleteButton]];
        }
    }
}

-(void)swipeTableCellWillEndSwiping:(SCSContactTVCell *)cell
{
    // reset accessibility to contact name and last message text
    
    SCSContactTVCell *contactCell = (SCSContactTVCell *)cell;
    [cell setAccessibilityElements:@[]];
    [cell setAccessibilityLabel:[NSString stringWithFormat:@"%@ %@",contactCell.contactNameLabel.text, contactCell.lastMessageTextLabel.text]];
}

-(NSArray*) swipeTableCell:(SCSContactTVCell*) cell swipeButtonsForDirection:(MGSwipeDirection)direction
             swipeSettings:(MGSwipeSettings*) swipeSettings expansionSettings:(MGSwipeExpansionSettings*) expansionSettings
{
    swipeSettings.transition = MGSwipeTransitionDrag;
    NSIndexPath *indexPath = [self.searchTableView indexPathForCell:cell];
    SCSChatSectionObject *sectionObject = dataSource[indexPath.section];
    RecentObject *recentObjectFromCell = sectionObject.chatObjectsArray[indexPath.row];
    
    // if swiping from right to left in directory search or search result
    if(sectionObject.contactType == scsContactTypeDirectory || sectionObject.contactType == scsContactTypeSearch) {
        if (direction == MGSwipeDirectionRightToLeft)
            return nil;
    }
    // Place Call
    if(direction == MGSwipeDirectionLeftToRight) {
        
        if (recentObjectFromCell.isGroupRecent)
        {
            return @[];
        }
        
        MGSwipeButton *callButton = [MGSwipeButton buttonWithTitle:@""
                                                              icon:[UIImage swipeCallIcon]
                                                   backgroundColor:[UIColor clearColor]
                                                          callback:^BOOL(MGSwipeTableCell *sender) {
                                                              
                                                              if ([self.actionDelegate respondsToSelector:@selector(didTapCallButtonOnRecentObject:)])
                                                              {
                                                                  [self.actionDelegate didTapCallButtonOnRecentObject:recentObjectFromCell];
                                                              }
                                                              return YES;
                                                          }];
        [callButton setTag:25];
        
        
        // Save to Contacts
        if (!recentObjectFromCell.abContact && !recentObjectFromCell.isGroupRecent) {
            
            MGSwipeButton *saveToContactsButton = [MGSwipeButton buttonWithTitle:@""
                                                                            icon:[UIImage swipeSaveContactsIcon]
                                                                 backgroundColor:[UIColor clearColor]
                                                                        callback:^BOOL(MGSwipeTableCell *sender) {
                                                                            
                                                                            if ([self.actionDelegate respondsToSelector:@selector(didTapSaveContactsButtonOnRecentObject:)])
                                                                            {
                                                                                [self.actionDelegate didTapSaveContactsButtonOnRecentObject:recentObjectFromCell];
                                                                            }
                                                                            return YES;
                                                                        }];
            [saveToContactsButton setTag:26];
            
            return @[saveToContactsButton,callButton];
        }
        
        return @[callButton];
    }
    // Delete Conversation
    else {

        UIImage *redTrashIcon = [[UIImage swipeTrashIcon] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        MGSwipeButton *deleteButton = [MGSwipeButton buttonWithTitle:@"" icon:redTrashIcon backgroundColor:[UIColor clearColor] 
                                                              insets:UIEdgeInsetsMake(0, 20, 0, 20) 
                                                            callback:^BOOL(MGSwipeTableCell *sender)
                                       {
                                           if (recentObjectFromCell.isGroupRecent && 
                                               [_actionDelegate respondsToSelector:@selector(didTapDeleteButtonOnGroupRecent:)])
                                           {
                                               [_actionDelegate didTapDeleteButtonOnGroupRecent:recentObjectFromCell];
                                            }
                                           else if ([_actionDelegate respondsToSelector:@selector(didTapDeleteButtonOnRecentObject:)])
                                           {
                                               [self deleteRecentObject:recentObjectFromCell];
                                               [_actionDelegate didTapDeleteButtonOnRecentObject:recentObjectFromCell];
                                           }
                                           
                                           return YES;
                                       }];
        [deleteButton setTintColor:[UIColor swipeCellDeleteButtonTintColor]];
        [deleteButton setTag:27];
        
        return @[deleteButton];
    }
}


#pragma mark - SCSContactTVCellDelegate Methods

-(void)accessibilityCall:(SCSContactTVCell *)contactCell {
    
    if ([self.actionDelegate respondsToSelector:@selector(didTapCallButtonOnRecentObject:)])
    {
        NSIndexPath *indexPath = [self.searchTableView indexPathForCell:contactCell];
        SCSChatSectionObject *sectionObject = dataSource[indexPath.section];
        RecentObject *recentObject = sectionObject.chatObjectsArray[indexPath.row];
        [self.actionDelegate didTapCallButtonOnRecentObject:recentObject];
    }
}

-(void)accessibilitySaveToContacts:(SCSContactTVCell *)contactCell {
    
    if ([self.actionDelegate respondsToSelector:@selector(didTapSaveContactsButtonOnRecentObject:)])
    {
        NSIndexPath *indexPath = [self.searchTableView indexPathForCell:contactCell];
        SCSChatSectionObject *sectionObject = dataSource[indexPath.section];
        RecentObject *recentObject = sectionObject.chatObjectsArray[indexPath.row];
        [self.actionDelegate didTapSaveContactsButtonOnRecentObject:recentObject];
    }
}

-(void)accessibilityDelete:(SCSContactTVCell *)contactCell {
    
    NSIndexPath *ip = [self.searchTableView indexPathForCell:contactCell];
    if (!ip)
        return;
    
    RecentObject *recentObj = [self recentObjWithIndexPath:ip];
    if (recentObj.isGroupRecent && [_actionDelegate respondsToSelector:@selector(didTapDeleteButtonOnGroupRecent:)])
    {
        [_actionDelegate didTapDeleteButtonOnGroupRecent:recentObj];
    }
    else if ([_actionDelegate respondsToSelector:@selector(didTapDeleteButtonOnRecentObject:)])
    {
        [self deleteRecentObject:recentObj];
        [_actionDelegate didTapDeleteButtonOnRecentObject:recentObj];
        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
    }
}


#pragma mark Helpers

- (void)requestVisibleAddressBookAvatars {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        for (SCSContactTVCell *cell in self.searchTableView.visibleCells)
            [self requestAddressBookAvatarForCell:cell];
    });
}

- (void)requestAddressBookAvatarForCell:(SCSContactTVCell *)cell {
    
    RecentObject *thisRecent = [self getRecentObjectFromCell:cell];
    
    if(!thisRecent)
        return;
    
    if(!thisRecent.abContact)
        return;
    
    if(thisRecent.abContact.contactImageIsCached)
        return;
    
    if(thisRecent.abContact.cachedContactImage)
        return;
    
    [self requestContactImageAsynchronouslyForContact:thisRecent.abContact
                                             ofRecent:thisRecent];
    
}

- (RecentObject *)recentObjWithIndexPath:(NSIndexPath *)ip {
    if (ip && ip.row < dataSource[ip.section].chatObjectsArray.count) {
        return dataSource[ip.section].chatObjectsArray[ip.row];
    }
    return nil;
}

- (void)updateHeaderForSection:(NSInteger) section
{
    SCSSearchVMHeaderFooterView *headerView = (SCSSearchVMHeaderFooterView *)[self.searchTableView headerViewForSection:section];
    if (!headerView)
        return;
    SCSChatSectionObject *sectionObject = (SCSChatSectionObject *)dataSource[section];
    [headerView.mainTitle setText:sectionObject.headerTitle];
    [headerView.subtitle setText:sectionObject.headerSubtitle];
}

-(BOOL) isTableViewEmpty
{
    if (dataSource.count > 0)
    {
        for (SCSChatSectionObject *section in dataSource)
        {
            if (section.chatObjectsArray.count > 0)
            {
                return NO;
            }
        }
    }
    return YES;
}
-(SCSContactTVCell *)getCellFromRecentObject:(RecentObject *)recent
{
    for (NSInteger i = 0; i<dataSource.count; i++) {
        
        SCSChatSectionObject *sectionObject = dataSource[i];
        
        for (NSInteger j = 0; j<sectionObject.chatObjectsArray.count; j++) {
            
            RecentObject *recentObject = sectionObject.chatObjectsArray[j];
            
            if ([recentObject isEqual:recent]) {
                
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:j
                                                            inSection:i];
                
                if(!indexPath)
                    return nil;
                
                return [self.searchTableView cellForRowAtIndexPath:indexPath];
            }
        }
    }
    
    return nil;
}

-(RecentObject *) getRecentObjectFromCell:(SCSContactTVCell *) cell
{
    NSIndexPath *indexPath = [self.searchTableView indexPathForCell:cell];
    
    if (!indexPath)
        return nil;

    if(indexPath.section >= [dataSource count])
        return nil;

    SCSChatSectionObject *section = dataSource[indexPath.section];
        
    if (!section)
        return nil;
    
    if(indexPath.row >= [section.chatObjectsArray count])
        return nil;
    
    return section.chatObjectsArray[indexPath.row];
}

-(void) deleteRecentObject:(RecentObject *) recent
{
    NSBlockOperation *deleteOperation = [NSBlockOperation blockOperationWithBlock:^{
        NSIndexPath *indexPathToDelete = nil;
        SCSChatSectionObject *sectionToDeleteIn = nil;
        
        for (NSUInteger i = 0; i<dataSource.count; i++) {
            SCSChatSectionObject *sectionObject = dataSource[i];
            for (NSUInteger j = 0; j<sectionObject.chatObjectsArray.count; j++)
            {
                RecentObject *recentObject = sectionObject.chatObjectsArray[j];
                if ([recentObject isEqual:recent]) {
                    indexPathToDelete = [NSIndexPath indexPathForRow:j inSection:i];
                    sectionToDeleteIn = sectionObject;
                    break;
                }
            }
        }
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            if(sectionToDeleteIn)
                [sectionToDeleteIn.chatObjectsArray removeObject:recent];
            
            if(indexPathToDelete)
                [self.searchTableView deleteRowsAtIndexPaths:@[indexPathToDelete]
                                            withRowAnimation:UITableViewRowAnimationNone];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kSCSContactTypeSearchTableUpdated
                                                                object:self];
        });
    }];
    
    [searchResultsQueue addOperation:deleteOperation];
}

/*
 Parse SCSGlobalContactSearchFilter enum received from globalSearch delegate to scsContactType
 */
-(scsContactType) getContactTypeFromGlobalContactSearchFilter:(SCSGlobalContactSearchFilter) filter
{
    scsContactType contactType = 0;
    
    BOOL existsAddressBook = (filter & SCSGlobalContactSearchFilterAddressBook);
    BOOL existsDirectory = (filter & SCSGlobalContactSearchFilterDirectory);
    BOOL existsAllConversations = (filter & SCSGlobalContactSearchFilterAllConversations);
    BOOL existsGroupConversations = (filter & SCSGlobalContactSearchFilterGroupConversations);
    BOOL existsSilentCircle = (filter & SCSGlobalContactSearchFilterAddressBookSC);
    BOOL existsSearch = (filter & SCSGlobalContactSearchFilterAutocomplete);
    
    if (existsAddressBook)
    {
       contactType = contactType | scsContactTypeAddressBook;
    }
    if (existsDirectory)
    {
        contactType = contactType | scsContactTypeDirectory;
    }
    if (existsAllConversations)
    {
        contactType = contactType | scsContactTypeAllConversations;
    }
    if (existsGroupConversations)
    {
        contactType = contactType | scsContactTypeGroupConversations;
    }
    if (existsSilentCircle)
    {
        contactType = contactType | scsContactTypeAddressBookSilentCircle;
    }
    if (existsSearch)
    {
        contactType = contactType | scsContactTypeSearch;
    }
    
    return contactType;
}

/*
 Parse scsContactType enum used to detect contact type displayed in cell to SCSGlobalContactSearchFilter for searching
 */
-(SCSGlobalContactSearchFilter) getGlobalContactSearchFilterFromContactType:(scsContactType) contactType
{
    SCSGlobalContactSearchFilter filter = 0;
    BOOL existsAddressBook = (contactType & scsContactTypeAddressBook);
    BOOL existsDirectory = (contactType & scsContactTypeDirectory);
    BOOL existsAllConversations = (contactType & scsContactTypeAllConversations);
    BOOL existsGroupConversations = (contactType & scsContactTypeGroupConversations);
    BOOL existsSilentCircle = (contactType & scsContactTypeAddressBookSilentCircle);
    BOOL existsSearch = (contactType & scsContactTypeSearch);
    
    if (existsAddressBook)
    {
        filter = filter | SCSGlobalContactSearchFilterAddressBook;
    }
    if (existsDirectory)
    {
        filter = filter | SCSGlobalContactSearchFilterDirectory;
    }
    if (existsAllConversations)
    {
        filter = filter | SCSGlobalContactSearchFilterAllConversations;
    }
    if (existsGroupConversations)
    {
        filter = filter | SCSGlobalContactSearchFilterGroupConversations;
    }
    if (existsSilentCircle)
    {
        filter = filter | SCSGlobalContactSearchFilterAddressBookSC;
    }
    if(existsSearch)
    {
        filter = filter | SCSGlobalContactSearchFilterAutocomplete;
    }
    
    return filter;
}


#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    
    _isScrolling = NO;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    
    _isScrolling = YES;
    
    if ([self.actionDelegate respondsToSelector:@selector(scrollViewWillBeginDragging:)])
        [self.actionDelegate scrollViewWillBeginDragging:scrollView];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    
    [self requestVisibleAddressBookAvatars];
}

#pragma mark multiSelect
-(BOOL) addSelectedRecent:(RecentObject *) selectedRecent ofType:(scsContactType)contactType
{
    for (RecentObject *recent in self.selectedContacts)
    {
        if ([recent isEqual:selectedRecent])
        {
            return NO;
        }
    }
    
    [self.selectedContacts addObject:selectedRecent];
    [self checkVisibleCellsForSelectedRecent:selectedRecent remove:NO];
    
    if ([self.actionDelegate respondsToSelector:@selector(didAddRecentObjectToSelection:ofType:)])
    {
        [self.actionDelegate didAddRecentObjectToSelection:selectedRecent ofType:contactType];
    }
    return YES;
}

-(BOOL) removeSelectedRecent:(RecentObject *) selectedRecent callDelegate:(BOOL) call
{
    if (![self isRecentSelected:selectedRecent])
    {
        return NO;
    }
    
    [self.selectedContacts removeObject:selectedRecent];
    
    [self checkVisibleCellsForSelectedRecent:selectedRecent remove:YES];
    
    if ([self.actionDelegate respondsToSelector:@selector(didRemoveRecentObjectFromSelection:)] && call)
    {
        [self.actionDelegate didRemoveRecentObjectFromSelection:selectedRecent];
    }
    return YES;
}

-(void)shouldRemoveContactNameFromSelection:(NSString *) contactName
{
    contactName = [[ChatUtilities utilitiesInstance] removePeerInfo:contactName lowerCase:YES];
    RecentObject *recentToRemove = nil;
    for (RecentObject *recent in self.selectedContacts)
    {
        NSString *strippedSelectedContactName = [[ChatUtilities utilitiesInstance] removePeerInfo:recent.contactName lowerCase:YES];
        if ([strippedSelectedContactName isEqualToString:contactName])
        {
            recentToRemove = recent;
            break;
        }
    }
    
    [self removeSelectedRecent:recentToRemove callDelegate:NO];
}

-(BOOL) isRecentSelected:(RecentObject *) selectedRecent
{
    for (RecentObject *recent in self.selectedContacts)
    {
        if ([recent isEqual:selectedRecent])
        {
            return YES;
        }
    }
    return NO;
}

-(BOOL) contactExistsInAddedArray:(NSString *) contactName
{
    contactName = [[ChatUtilities utilitiesInstance] removePeerInfo:contactName lowerCase:NO];
    // Check if returned contact from search exists in _alreadyAddedContacts array
    // this means that it was added in CreateGroupChatViewController before
    // also skip our own username
    
    if ([contactName isEqualToString:[[ChatUtilities utilitiesInstance] getOwnUserName]])
    {
        return YES;
    }
    
    for (RecentObject *alreadyAddedRecent in _alreadyAddedContacts)
    {
        NSString *existingContactName = [[ChatUtilities utilitiesInstance] removePeerInfo:alreadyAddedRecent.contactName lowerCase:YES];
        
        if ([existingContactName isEqualToString:contactName])
        {
            return YES;
        }
    }
    return NO;
}


-(void) checkVisibleCellsForSelectedRecent:(RecentObject *) selectedRecentObject remove:(BOOL) remove
{
    for (SCSContactTVCell *cell in self.searchTableView.visibleCells)
    {
        NSIndexPath *indexPath = [self.searchTableView indexPathForCell:cell];
        if (!indexPath)
            continue;
        SCSChatSectionObject *sectionObject = dataSource[indexPath.section];
        RecentObject *recentObject = sectionObject.chatObjectsArray[indexPath.row];
        if ([self isRecentSelected:recentObject])
        {
            [cell setSelectedCheckmarkImage];
        } else
        {
            [cell setUnSelectedCheckmarkImage];
        }
        [self.searchTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
}

-(void) reloadCellWithRecentObject:(RecentObject *) recent otherwiseUpdate:(BOOL)forceUpdate
{
    __block RecentObject *blockRecent = recent;
    NSBlockOperation *rowReloadOperation = [NSBlockOperation new];
    
    [rowReloadOperation addExecutionBlock:^{
        
        NSIndexPath *indexPathToBeUpdated = nil;

        for (int i = 0; i<dataSource.count; i++) {
            
            SCSChatSectionObject *section = dataSource[i];

            BOOL isConversationType = (section.contactType == scsContactTypeAllConversations ||
                                       section.contactType == scsContactTypeGroupConversations);
            
            BOOL shouldGetLastConversation = (isConversationType && !self.isMultiSelectEnabled);
            
            for (int j = 0; j<section.chatObjectsArray.count; j++) {
                
                RecentObject *existingRecent = section.chatObjectsArray[j];
                
                if ([existingRecent isEqual:blockRecent]) {
                    
                    [existingRecent updateWithRecent:blockRecent];
                    
                    if(shouldGetLastConversation)
                        [existingRecent loadLastConversation];

                    indexPathToBeUpdated = [NSIndexPath indexPathForRow:j
                                                              inSection:i];
                    
                    break;
                }
            }

            if(indexPathToBeUpdated)
                break;
        }
        
        if(indexPathToBeUpdated) {
            
            dispatch_sync(dispatch_get_main_queue(), ^{
                
                [self.searchTableView reloadRowsAtIndexPaths:@[indexPathToBeUpdated]
                                            withRowAnimation:UITableViewRowAnimationNone];
                
                SCSContactTVCell *cell = [self.searchTableView cellForRowAtIndexPath:indexPathToBeUpdated];
                
                if(!_isScrolling && cell)
                    [self requestAddressBookAvatarForCell:cell];
            });
        }
        else if(forceUpdate)
            [self showFullListsOfContactType:self.displayedFullLists];
    }];
    
    [searchResultsQueue addOperation:rowReloadOperation];
}

@end
