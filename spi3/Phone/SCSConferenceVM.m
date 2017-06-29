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
//  SCSConferenceVM.m
//  SPi3
//
//  Created by Eric Turner on 2/20/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "SCSConferenceVM.h"
// Common
#import "SCPCall.h"
#import "SCPCallbackInterface.h"
#import "SCPCallManager.h"
#import "SCPNotificationKeys.h"
#import "SCSCallNavDelegate.h"
#import "SCSConferenceCellDelegate.h"
#import "SCSAudioManager.h"
// TableView
#import "SCSConferenceTVCell.h"
#import "SCSConfHeaderFooterView.h"
// CollectionView
#import "SCSConferenceCVCell.h"
#import "SCSCVHeaderFooter.h"
#import "SCSMainCVFlowLayout.h"
// User
#import "UserService.h"
// Logging
#import "SCSPConfLog.h"
#import "NSString+SCUtilities.h"


typedef NS_ENUM(NSInteger, scsConfSections) {
    eConference = 0,
    ePrivate,
    eInProgress
};


#pragma mark - Logging
/* ---------------------------------------------------------------------
                                LOGGING
 * ---------------------------------------------------------------------

* For per-user log levels, use your name as it appears in LumberjackUser.h (post compile):
* Example:
#if DEBUG && robbie_hanson
    static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#elif DEBUG
    static const int ddLogLevel = LOG_LEVEL_INFO;
#else
    static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
*/
#if DEBUG && eric_turner

    /* Enable logging categories by OR-ing LOG_FLAG_CONF_[flag] values:
     Logging categories defined in SCSPConfLog.h 
     
     LOG_FLAG_CONF_NONE
     LOG_FLAG_CONF_MOVE_DIRECTION
     LOG_FLAG_CONF_MOVE_COUNT
     LOG_FLAG_CONF_MOVE_PATHS
     LOG_FLAG_CONF_HEADER_FOOTER
     LOG_FLAG_CONF_NOTIFICATIONS
     LOG_FLAG_CONF_DEFERRED_OP
     LOG_FLAG_CONF_ACCESSIBILITY
     LOG_FLAG_CONF_CELL
     LOG_FLAG_CONF_EVENT

     Examples:
     #define LOG_FLAG_CONF (LOG_FLAG_CONF_ACCESSIBILITY | LOG_FLAG_CONF_NOTIFICATIONS | LOG_FLAG_CONF_EVENT)
     #define LOG_FLAG_CONF LOG_FLAG_CONF_ALL
     #define LOG_FLAG_CONF LOG_FLAG_CONF_NONE
     */
    #define LOG_FLAG_CONF LOG_FLAG_CONF_NONE

    // Initialize with the bitmask defined by LOG_FLAG_CONF - 
    // the ddLogLevelConf variable is used in the log function macros 
    // defined in SCSPConfigLog.h
    static const DDLogLevel ddLogLevelConf = LOG_FLAG_CONF;

    // The ddLogLevel defines the level of the standard logging macros:
    // DDLogError(...), DDLogWarn(...), etc.
    // Debug levels: off, error, warn, info, debug, verbose, all
//    static const DDLogLevel ddLogLevel = DDLogLevelAll;

#elif DEBUG
    // If you're not eric_turner, define LOG_FLAG_CONF with a bitmask
    // (described above) for the logging you want to see.
    // By default, it is set here to "NONE" - no logging.
    #define LOG_FLAG_CONF LOG_FLAG_CONF_NONE
    static const DDLogLevel ddLogLevelConf = LOG_FLAG_CONF; 
//    static const DDLogLevel ddLogLevel = DDLogLevelInfo;     
#else
    #define LOG_FLAG_CONF LOG_FLAG_CONF_NONE
    static const DDLogLevel ddLogLevelConf = LOG_FLAG_CONF_NONE;
//    static const DDLogLevel ddLogLevel = DDLogLevelWarning; 
#endif

// Set this local flag to print the logging configuration to the debugger
// console when the Conference controller becomes active.
static BOOL const LOG_LOGGING_CONFIG = YES;

/* 
*-----------------------------------------------------------------------
                            END LOGGING
*-----------------------------------------------------------------------*/


// Section Titles
#define kConferenceSectionTitle NSLocalizedString(@"CONFERENCE", nil);
#define kPrivateSectionTitle NSLocalizedString(@"PRIVATE", nil);
#define kInProgressSectionTitle NSLocalizedString(@"INCOMING / OUTGOING", nil);
// header/footer message string
#define kConfSectionFooterTitle NSLocalizedString(@"Drag call into conference", nil);
#define kConfFeatureNotAvailable NSLocalizedString(@"Feature not available", nil);
#define kPrivateSectionAltHeaderTitle NSLocalizedString(@"Drag here to remove from conference", nil);


#pragma mark - TableView Constants
// SCSConferenceSectionHeaderView class xib IDs
static NSString * const kSCSConfHeaderFooterId = @"SCSConfHeaderFooterId";
static NSString * const kSCSConfFooterId       = @"SCSConfFooterId";
static NSString * const kSCSPrivateAltHeaderId = @"SCSPrivateAltHeaderId";

static CGFloat const kSectionHeaderHeight   = 30.;
static CGFloat const kHeaderFooterAltHeight = 38.;


#pragma mark - CollectionView Constants
// SCSConfHeaderFooter xib reuseIDs
static NSString * const kCVAltHeader_ID = @"CVAltHeader_ID";
static NSString * const kCVHeader_ID    = @"CVHeader_ID";
static NSString * const kCVFooter_ID    = @"CVFooter_ID";


#pragma mark - Move Direction Enum
typedef NS_ENUM(NSInteger, scsMoveDirection) {
    eUnknownOrUnchanged = 0,
    eDown,
    eUp
};


#pragma mark - Custom Block Operation Class
/**
 * A helper class for storing, executing, and identifying blocks of code.
 *
 * This helper class inherits from NSBlockOperation and is used for
 * executing blocks of code in reaction to "signals", i.e. user events
 * and NSNotifications.
 *
 * This subclass implements a way to report its "kind", i.e. whether is
 * is a reload, an update, or completion, operation block. The
 * aspect is used to make decisions about when to execute and to aid in
 * logging.
 */
typedef NS_ENUM(NSInteger, scsBlockOpKind) { eUpdate = 0, eReload, eCompletion };
@interface SCSBlockOperation : NSBlockOperation
@property (assign, nonatomic) enum scsBlockOpKind kind;
@property (readonly, nonatomic) BOOL isUpdateOp, isReloadOp, isCompletionOp;
@property (readonly, nonatomic) NSString *strKind;
@end
@implementation SCSBlockOperation
-(NSString*)description{
    return [NSString stringWithFormat:@"%@: %@",[self strKind],[super description]];
}
-(NSString*)strKind{
    switch (_kind) {
        case eUpdate:
            return @"Update";
            break;
        case eReload:
            return @"Reload";
            break;
        case eCompletion:
            return @"Completion";
            break;
    }
}
-(BOOL)isUpdateOp{return _kind==eUpdate;}
-(BOOL)isReloadOp{return _kind==eReload;}
-(BOOL)isCompletionOp{return _kind==eCompletion;}
@end


#pragma mark KVO Context
// Context for KVO isReloading listener
static void * SCConfContext = &SCConfContext;


@interface SCSConferenceVM () <SCSConferenceCellDelegate>

@property (weak, nonatomic) SCSMainCVFlowLayout *cvLayout;
@property (weak, nonatomic) NSMutableArray *conferenceCalls;
@property (weak, nonatomic) NSMutableArray *privateCalls;
@property (weak, nonatomic) NSMutableArray *inProgressCalls; // incoming/outgoing
@property (strong, nonatomic) NSArray *allCalls;
@property (strong, nonatomic) NSTimer *cellDurTimer;

@property (strong, nonatomic) NSOperationQueue *mainOpQueue;
@property (strong, nonatomic) NSMutableArray *deferredOpsQueue;
@property (assign, nonatomic) BOOL isReordering;
@property (assign, nonatomic) BOOL isReloading;  //KVO
@end

/**
 * The CollectionView "drag tracking" feature.
 *
 * Support for collectionView in this class includes a workaround for 
 * the default behavior of Apple's UICollectionView wherein reordering
 * is not supported into empty sections, i.e., if dragging a cell into a
 * section containing no cells, dropping the cell in the empty section
 * returns the cell to its original position.
 *
 * The issue appears to be that the collectionView needs to displace
 * an existing cell position with the dragging cell before it can
 * determine a new position for the dragging cell. The issue is visible
 * by observing that when dragging a cell into a populated section, if
 * the existing cells do not shift to accomodate the dragging cell,
 * when the dragging cell is released, it returns to its original 
 * position.
 *
 * The solution is to implement the collectionView delegate method,
 * targetIndexPathForMoveFromItemAtIndexPath:toProposedIndexPath:, to
 * return a proposed indexPath for the current drag position in all
 * cases. Thus, when dragging into an empty section, the method returns
 * an indexPath defining the first position.
 *
 * The drag tracking feature:
 * In the development of the workaround, a test app was employed in 
 * which multiple sections were populated with many cells, leaving one
 * section empty for testing the dragging behavior. In this way, the 
 * behavior of the collectionView scrolling while dragging could be 
 * tested.
 *
 * It was observed that when dragging downward into a populated section,
 * it was expected that dropping the cell (when the existing cells
 * were not displaced) would result in the dropped cell taking the 
 * first item position. Similarly, when dragging upward into a populated
 * section, when the cell was dropped (and existing cells were not
 * displaced), it would occupy the last position in the section.
 *
 * The "drag tracking" feature effects the expected behavior: when
 * dragging upward, return the last position indexPath, and when 
 * dragging downward, return the first position indexPath.
 */
@implementation SCSConferenceVM 
{
    // MoveItem tracking ivars
    CGPoint _lastMovingItemPosition;
    CGPoint _previousMovingItemPosition;
}


#pragma mark - Initialization

/**
 * Instantiates self for UITableView support.
 *
 * @param The tableView property instance ,for which the instance of
 *        this class will be datasource and delegate.
 *
 * @return Instance of the self class.
 */
-(instancetype)initWithTableView:(UITableView *)tv {
 
    self = [super init];
    if (!self) { return  nil; }
    
    tv.dataSource = self;
    tv.delegate   = self;
    _tableView = tv;

    UINib *cell = [UINib nibWithNibName:@"SCSConferenceTVCell" bundle:nil];
    [self.tableView registerNib:cell forCellReuseIdentifier:[SCSConferenceTVCell reuseId]];
    
    UINib *headerfooter = [UINib nibWithNibName:@"SCSConfHeaderFooterView" bundle:nil];
    [self.tableView registerNib:headerfooter forHeaderFooterViewReuseIdentifier:kSCSConfHeaderFooterId];
    
    UINib *confFooter = [UINib nibWithNibName:@"SCSConfFooterView" bundle:nil];
    [self.tableView registerNib:confFooter forHeaderFooterViewReuseIdentifier:kSCSConfFooterId];
    
    UINib *privateAltHeader = [UINib nibWithNibName:@"SCSPrivateAltHeaderView" bundle:nil];
    [self.tableView registerNib:privateAltHeader forHeaderFooterViewReuseIdentifier:kSCSPrivateAltHeaderId];

    [self initCommon];
              
    return self;
}

/**
 * Instantiates self for UICollectionView support.
 *
 * @param The collectionView property instance, for which the instance
 *        of this class will be datasource and delegate.
 *
 * @return Instance of the self class.
 */
-(instancetype)initWithCollectionView:(UICollectionView *)cv {
    
    self = [super init];
    if (!self) { return  nil; }
    
    cv.dataSource = self;
    cv.delegate   = self;
    _collectionView = cv;
    _cvLayout = (SCSMainCVFlowLayout *)cv.collectionViewLayout;
    
    // Configure gesture for dragging call cells between sections
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                            action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.25;
    [_collectionView addGestureRecognizer:longPress];
    _collectionView.alwaysBounceVertical = YES;
    
    // Register CV cell and header/footer nibs
    UINib *nib = [UINib nibWithNibName:@"SCSConferenceCVCell" bundle:nil];
    [_collectionView registerNib:nib forCellWithReuseIdentifier:[SCSConferenceCVCell reuseId]];
    
    [_collectionView registerNib:[UINib nibWithNibName:@"SCSCVHeader" bundle:nil]
          forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                 withReuseIdentifier:kCVHeader_ID];
    
    [_collectionView registerNib:[UINib nibWithNibName:@"SCSCVAltHeader" bundle:nil]
          forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                 withReuseIdentifier:kCVAltHeader_ID];
    
    [_collectionView registerNib:[UINib nibWithNibName:@"SCSCVFooter" bundle:nil]
          forSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                 withReuseIdentifier:kCVFooter_ID];
    
    [self initCommon];
    
    return self;
}

/**
 * Initializes the KVO isReloading listener and event queue properties.
 *
 * These properties are independent of the view collection view controller class.
 */
- (void)initCommon {
    _mainOpQueue = [NSOperationQueue mainQueue];
    _mainOpQueue.maxConcurrentOperationCount = 1;
    _deferredOpsQueue = [NSMutableArray array];
    [self registerKVO];
}

- (void)dealloc {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

#pragma mark - Initial Configuration

/**
 * Invoked by the view collection's viewWillApppear: method.
 */
-(void)prepareToBecomeActive{
//    DDLogConfEvent(@"%s called", __PRETTY_FUNCTION__);
    DDLogConfEvent(@"called");
    
    // Print logging config to debugger console
    if (LOG_LOGGING_CONFIG) {
        SCSPConfLog *logger = [[SCSPConfLog alloc] initWithLogLevel:ddLogLevel];
        logger.logFlagConf = LOG_FLAG_CONF;
        logger.ddLogLevelConf = ddLogLevelConf;
        [logger logConfig];
    }
    
    [self loadCalls];
    
    [_collectionView reloadData];
    [_tableView reloadData];
    
    if (_tableView) {
        _tableView.editing = YES;
    }
    
    [self registerForNotifications];
    [self startCellDurationUpdate];
    [self enableProximitySensor];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(remoteControlReceived)
                                                 name:kSCPRemoteControlClickedNotification
                                               object:nil];
}

/**
 * Invoked by the view collection's viewWillDisapppear: method.
 */
-(void)prepareToBecomeInactive{
    DDLogConfEvent(@"%s called", __PRETTY_FUNCTION__);
    
    [self unregisterKVO];
    [self unRegisterForNotifications];
    [self stopCellDurationUpdate];
    [self cleanupDeferredOperations];
    [self disableProximitySensor];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kSCPRemoteControlClickedNotification
                                                  object:nil];
}


#pragma mark - Notification Registration

- (void)registerForNotifications {
    DDLogConfNotifications(@" REGISTER FOR NOTIFICATIONS");
    
    NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
    [notifCenter addObserver:self
                    selector:@selector(notificationHandler:)
                        name:kSCPIncomingCallNotification
                      object:nil];
    [notifCenter addObserver:self
                    selector:@selector(notificationHandler:)
                        name:kSCPCallStateDidChangeNotification
                      object:nil];
    [notifCenter addObserver:self
                    selector:@selector(notificationHandler:)
                        name:kSCPZRTPDidUpdateNotification
                      object:nil];
    [notifCenter addObserver:self
                    selector:@selector(notificationHandler:)
                        name:kSCPCallDidEndNotification
                      object:nil];
    [notifCenter addObserver:self
                    selector:@selector(notificationHandler:)
                        name:kSCSAudioStateDidChange
                      object:nil];
}

- (void)registerKVO {
    DDLogConfEvent(@"%s called", __PRETTY_FUNCTION__);

    [self addObserver:self forKeyPath:@"isReloading"
              options:NSKeyValueObservingOptionNew context:SCConfContext];
}

- (void)unRegisterForNotifications {
    DDLogConfNotifications(@" UN-REGISTER FOR NOTIFICATIONS");
    
    NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
    [notifCenter removeObserver:self name:kSCPIncomingCallNotification object:nil];
    [notifCenter removeObserver:self name:kSCPCallStateDidChangeNotification object:nil];
    [notifCenter removeObserver:self name:kSCPZRTPDidUpdateNotification object:nil];
    [notifCenter removeObserver:self name:kSCPCallDidEndNotification object:nil];
    [notifCenter removeObserver:self name:kSCSAudioStateDidChange object:nil];
}

- (void)unregisterKVO {
    DDLogConfEvent(@"%s called", __PRETTY_FUNCTION__);

    // Unsubscribe KVO
    @try {
        [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(isReloading))];
    }
    @catch (NSException * __unused exception) {}
}

#pragma mark - SCSConferenceCellDelegate Methods

- (void)endCallButtonTappedInCell:(id)aCell {
    NSIndexPath *ip = nil;
    if (_collectionView) {
        ip = [_collectionView indexPathForCell:aCell];
    } else {
        ip = [_tableView indexPathForCell:aCell];
    }
    if (ip) {
        SCPCall *call = _allCalls[ip.section][ip.row];
        if (call) {
            [SPCallManager terminateCall:call];
        }
    }
}

- (void)answerCallButtonTappedInCell:(id)aCell {
    NSIndexPath *ip = nil;
    if (_collectionView) {
        ip = [_collectionView indexPathForCell:aCell];
    } else {
        ip = [_tableView indexPathForCell:aCell];
    }
    
    if (ip) {
        SCPCall *call = _allCalls[ip.section][ip.row];
        if (call) {
            [SPCallManager answerCall:call];
        }
    }
}

/**
 * Initializes/starts the cellDurTimer instance.
 *
 * The instance is set to nil whenever stopped; restarts initialize a
 * fresh instance each time.
 *
 * Note tolerance:
 *
 * NSTimer.h
 * "As the user of the timer, you will have the best idea of what an 
 *  appropriate tolerance for a timer may be. A general rule of thumb,
 *  though, is to set the tolerance to at least 10% of the interval, for
 *  a repeating timer. Even a small amount of tolerance will have a 
 *  significant positive impact on the power usage of your application.
 *  The system may put a maximum value of the tolerance."
 *
 * @see stopCellDuration
 * @see updateDurationInVisibleCells
 */
- (void)startCellDurationUpdate {
    if ([self activeCallsCount] == 0) { return; }
    
    if (!_cellDurTimer){
        _cellDurTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                         target:self
                                                       selector:@selector(updateDurationInVisibleCells)
                                                       userInfo:nil
                                                        repeats:YES];
        _cellDurTimer.tolerance = 0.15;
    }
}

/**
 * Invalidates the cellDurTimer instance and sets it to nil. This
 * teardown happens when entering a blocking state, and is also invoked
 * by the prepareToBecomeInactive method.
 *
 * @see startCellDurationUpdate
 * @see updateDurationInVisibleCells
 */
- (void)stopCellDurationUpdate {
    [_cellDurTimer invalidate];
    _cellDurTimer = nil;
}

/**
 * Invokes the updateDuration method on each cell in the view 
 * collection's visible cells array.
 *
 * This method is invoked by the cellDurTimer every second to update the
 * duration label text in the call cell.
 *
 * @see startCellDurationUpdate
 * @see stopCellDuration
 */
- (void)updateDurationInVisibleCells {
    if (_collectionView) {
        for (SCSConferenceCVCell *cell in _collectionView.visibleCells) {
            [cell updateDuration];
        }
    } else {
        for (SCSConferenceTVCell *cell in _tableView.visibleCells) {
            [cell updateDuration];
        }
    }
}


#pragma mark - Notification Handlers

- (void)notificationHandler:(NSNotification *)notif {
    DDLogConfEvent(@"%s called", __PRETTY_FUNCTION__);
    
    if ([notif.name isEqualToString:kSCPIncomingCallNotification]) {
        [self incomingCallNotificationHandler:notif];
    }
    else if ([notif.name isEqualToString:kSCPCallStateDidChangeNotification]) {
        [self callStateChangeNotificationHandler:notif];
    }
    else if ([notif.name isEqualToString:kSCPZRTPDidUpdateNotification]) {
        [self zrtpUpdateNotificationHandler:notif];
    }
    else if ([notif.name isEqualToString:kSCPCallDidEndNotification]) {
        [self callEndedNotificationHandler:notif];
    }
    else if ([notif.name isEqualToString:kSCSAudioStateDidChange]) {
        [self audioStateChangedNotificationHandler:notif];
    }
}

- (void)incomingCallNotificationHandler:(NSNotification *)notif {
    DDLogConfNotifications(@"\n ---- INCOMING CALL NOTIFICATION ----\n");
    
    if (! [notif.name isEqualToString:kSCPIncomingCallNotification]){
        DDLogError(@"Expected kSCPIncomingCallNotification but was passed %@", notif.name);
        return;
    }

    [self addOperation:[self reloadCallsOperation]];
}

- (void)outgoingCallNotificationHandler:(NSNotification *)notif {
    DDLogConfNotifications(@"\n ---- OUTGOING CALL NOTIFICATION ----\n");

    if (! [notif.name isEqualToString:kSCPOutgoingCallNotification]){
        DDLogError(@"Expected kSCPOutgoingCallNotification but was passed %@", notif.name);
        return;
    }
    
    [self addOperation:[self reloadCallsOperation]];
}


- (void)callStateChangeNotificationHandler:(NSNotification *)notif {
    DDLogConfNotifications(@"\n ---- CALL STATE DID CHANGE NOTIFICATION ----");
    
    if (! [notif.name isEqualToString:kSCPCallStateDidChangeNotification]){
        DDLogError(@"Expected kSCPCallStateDidChangeNotification but was passed %@", notif.name);
        return;
    }
    
    SCPCall *call = notif.userInfo[kSCPCallDictionaryKey];
    if (!call) { return; }

    // Call is in inProgress section, is answered, and is not ended:
    // call to reload for it to be moved to Private section.
    if (call.isAnswered && !call.isEnded && [_inProgressCalls containsObject:call])
    {
        DDLogConfNotifications(@"\n ---- CALL ANSWERED: ADD RELOAD OPERATION ----");

        [self addOperation:[self reloadCallsOperation]];
        
    }
    // Some call updates are posted when many or all call states change,
    // e.g. moving between sections. CallManager provides an additional
    // userInfo value for such cases.
    else if (notif.userInfo[kSCPReloadCellDictionaryKey]) {
        [self addOperation:[self reloadCallsOperation]];
    }
    // otherwise, execute an update block
    else {
        [self addOperation:[self updateOperationWithCall:call]];
    }
}

- (void)zrtpUpdateNotificationHandler:(NSNotification *)notif {
    DDLogConfNotifications(@"\n ---- ZRTP DID UPDATE NOTIFICATION ----");
    
    if (! [notif.name isEqualToString:kSCPZRTPDidUpdateNotification]){
        DDLogError(@"Expected kSCPZRTPDidUpdateNotification but was passed %@", notif.name);
        return;
    }
    
    SCPCall *call = notif.userInfo[kSCPCallDictionaryKey];
    if (!call) { return; }
    
    [self addOperation:[self updateOperationWithCall:call]];
}

- (void)callEndedNotificationHandler:(NSNotification *)notif {
    DDLogConfNotifications(@"\n ---- CALL DID END NOTIFICATION ----");
    
    if (! [notif.name isEqualToString:kSCPCallDidEndNotification]){
        DDLogError(@"Expected SCPCallDidEndNotification but was passed %@", notif.name);
        return;
    }    

    //TODO: implement "wait until end-call timeout"
    
    [self addOperation:[self reloadCallsOperation]];
}

- (void)audioStateChangedNotificationHandler:(NSNotification *)notif {
    
    if([SPAudioManager isHeadphoneOrBluetooth])
        [self disableProximitySensor];
    else
        [self enableProximitySensor];
}

#pragma mark - Operations Queue Manager

/**
 * Wraps a call to addOperation:completion: passing the given op and
 * nil.
 *
 * @param op An operation to execute.
 *        @see Block Operations constructors this class.
 */
- (void)addOperation:(SCSBlockOperation *)op {
    [self addOperation:op completion:nil];
}

/**
 * If blocking, defers the given op to the deferredOpsQueue, and 
 * otherwise, executes the given op immediately, followed by the 
 * completion, if any.
 *
 * @param op An operation to execute.
 *        @see Block Operations constructors this class.
 *
 * @param completion An ObjC block to be executed after the given op.
 *        May be nil.
 */
- (void)addOperation:(SCSBlockOperation *)op completion:(void (^)())completion  {
    DDLogConfEvent(@"%s called", __PRETTY_FUNCTION__);
    
    if (_isReloading || _isReordering) {
        [self queueDeferredOperation:op completion:completion];
        return;
    }
    
    BOOL isReload = op.isReloadOp;
    
    [self stopCellDurationUpdate];
    
    if (op.isReloadOp) {
        DDLogConfDeferredOp(@"%s\n    --- SET isReloading :: FIRE RELOAD OPERATION ---", __PRETTY_FUNCTION__);
        self.isReloading = YES;
        
    } else {
        DDLogConfDeferredOp(@"%s\n    --- FIRE UPDATE OPERATION ---", __PRETTY_FUNCTION__);
    }
    
    [_mainOpQueue addOperation:op];
    [_deferredOpsQueue removeAllObjects];
    
    if (completion) {
        completion();
    }
    
    if (isReload) {
        DDLogConfDeferredOp(@"%s\n    --- CLEAR isReloading flag ---", __PRETTY_FUNCTION__);
        
        self.isReloading = NO;
//        [self updateAccessibilityAfterReload];
    }

    [self startCellDurationUpdate];
}

/**
 * Stores deferred operations to _deferredOpsQueue.
 *
 * If the addOperation: method is invoked while in a blocking state,
 * i.e. when isReloading or isReordering is true, this method is 
 * invoked to store the operation in the deferredOpsQueue.
 *
 * Note that if a completion block is passed, this method instantiates
 * an SCSBlockOperation instance with the completion block and enqueues
 * it behind the given op.
 *
 * NOTE:
 * If the given op is a reloadOp, and there is currently a reloadOp
 * queued, the queue is flushed and the given reloadOp is added, 
 * followed by the completion block, if any.
 *
 * ### History:
 * Replacement of any queued operations with a new reloadOp is 
 * potentially tricky, though in this first implementation it has not
 * been found to be problematic.
 *
 * Note that a completion block could be anything. The 
 * first-implementation assumption is that a reload operation updates
 * the view collection satisfactorily, and in this implementation, this
 * method is never called with a completion block.
 *
 * However, if completion blocks become necessary to implement more
 * complex behavior, this brute force replacement of existing operations
 * will need to be revisited.
 *
 * @param op A block operation to enqueue
 *
 * @param completion An optional completion block to be executed after
 *        the give op. May be nil.
 */
- (void)queueDeferredOperation:(SCSBlockOperation *)op completion:(void (^)())completion {
    
    // Assume any existing updateOps and completionOps in the queue
    // are obviated by a new reloadOp, i.e., in the if block above,
    // if any updateOps and/or completionOps were enqueued when the
    // reloadOp came in, they are gone now, and we're making the
    // assumption that replacing with a new reloadOp will fine.
    //
    // This means the latest requested reloadOp will be enqueued
    if (op.isReloadOp) {
        DDLogConfDeferredOp(@"%s\n    --- ADD DEFERRED RELOAD OP ---",__PRETTY_FUNCTION__);
        
        [_deferredOpsQueue removeAllObjects];
        [_deferredOpsQueue addObject:op];
        // Add optional completionOp to queue
        if (completion) {
            SCSBlockOperation *op = [SCSBlockOperation blockOperationWithBlock:completion];
            op.kind = eCompletion;
            [_deferredOpsQueue addObject:op];
        }
    }
    else {
        // If current queue contain a reload, replace with this reloadOp
        // and add completionOp if any.
        BOOL containsReload = [self arrayContainsReloadOperation:_deferredOpsQueue];
        if (! containsReload) {
            DDLogConfDeferredOp(@"%s\n    --- ADD DEFERRED %@ OP ---",__PRETTY_FUNCTION__,op.description);
            
            [_deferredOpsQueue addObject:op];
        } else {
            DDLogConfDeferredOp(@"%s\n    --- DeferredQueue ALREADY CONTAINS RELOAD OP :: IGNORE UPDATE REQUEST ---",
                                 __PRETTY_FUNCTION__);
        }
    }
    
    // LOG ONLY
    DDLogConfDeferredOp(@"%s\n    --- CURRENT DEFERRED QUEUE:\n%@ ---",__PRETTY_FUNCTION__,_deferredOpsQueue);
}

/**
 * Executes operation blocks stored in the deferredOpsQueue.
 *
 * If the addOperation: method is invoked while in a blocking state, i.e.
 * when isReloading or isReordering is true, the operation is stored in
 * the deferredOpsQueue.
 *
 * This method is called by:
 * * May be called by the endMoveItemHandler method at the end of a 
 *   longPress gesture sequence:
 *
 *   For collectionView, the startMoveItemHandler method, and for
 *   tableView, the willBeginOrderingRowAtIndexPath: method, sets the
 *   isReordering flag at the beginning of a reordering activity.
 *
 *   At the end of the moveItem/RowAtIndexPath: view collection method
 *   the isReordering flag is cleared and addOperation: is invoked.
 *
 *   Typically, this reloads the view collection immediately. However,
 *   if the user drags a call cell around and then drops the call cell
 *   in its original position, the moveItem/RowAtIndexPath: method is
 *   not invoked by the view collection.
 *
 *   In that case the isReordering flag will still be set when the
 *   endMoveItem/RowHandler method is invoked, and the 
 *   endMoveItemHandler will invoke this method to execute dererred
 *   operations, if any.
 *
 *
 * * KVO listener, observeValueForKeyPath:ofObject:change:context:
 *
 *   When the isReload value is set to true, this signals the end of 
 *   operation blocking, and, if any, this method is invoked to execute
 *   deferred operations.
 */
- (void)fireDeferredOperations {
    [self fireDeferredOperationsWithCompletion:nil];
}

// Note that completion is never called in the current implementation
- (void)fireDeferredOperationsWithCompletion:(void (^)())completion {
    
    if (_deferredOpsQueue.count == 0) { return; }
    
    [self stopCellDurationUpdate];
    
    NSArray *ops = [NSArray arrayWithArray:_deferredOpsQueue];
    
    // Check for reload
    BOOL isReload = [self arrayContainsReloadOperation:ops];

    if (isReload) {
        DDLogConfDeferredOp(@"%s\n    --- FIRE DEFERRED: SET isReloading flag ---", __PRETTY_FUNCTION__);

        self.isReloading = YES;
        
        DDLogConfDeferredOp(@"%s\n    --- FIRE DEFERRED RELOAD OPERATION ---", __PRETTY_FUNCTION__);

    } else {
        DDLogConfDeferredOp(@"%s\n    --- FIRE DEFERRED UPDATE OPERATION ---", __PRETTY_FUNCTION__);
    }

    DDLogConfDeferredOp(@"%s\n    --- QUEUE BEFORE FIRING:\n%@ ---",__PRETTY_FUNCTION__,_deferredOpsQueue);
    
    if (completion) {
        SCSBlockOperation *op = [SCSBlockOperation blockOperationWithBlock:completion];
        op.kind = eCompletion;
        [_deferredOpsQueue addObject:op];
    }

    /*
     http://stackoverflow.com/questions/29992735/nsoperationqueue-addoperations-waituntilfinished
     Operations are generally executed in the order in which they were
     added to the queue. If you add an array of operations, though, the
     documentation makes no formal assurances that they are enqueued in
     the order they appear in that array. You might, therefore, want to
     add the operations one at a time.
     */
    for (SCSBlockOperation *op in _deferredOpsQueue) {
        /*
         [...] you should not add operations to the main queue in
         conjunction with the waitUntilFinished. Feel free to add them
         to a different queue, but don't dispatch from a serial queue,
         back to itself, with the waitUntilFinished option.
         */
//        [_mainOpQueue addOperations:ops waitUntilFinished:YES];
        [_mainOpQueue addOperation:op];
    }
    
    //flush
    [_deferredOpsQueue removeAllObjects];

    DDLogConfDeferredOp(@"%s\n    --- QUEUE AFTER FIRING:\n%@ ---",__PRETTY_FUNCTION__,_deferredOpsQueue);

    
    if (isReload) {
        DDLogConfDeferredOp(@"%s\n    --- CLEAR isReloading flag ---", __PRETTY_FUNCTION__);
        
        self.isReloading = NO;
    }
    
    [self startCellDurationUpdate];
}

- (BOOL)arrayContainsReloadOperation:(NSArray*)array {
    __block BOOL isReload = NO;
    [_deferredOpsQueue enumerateObjectsUsingBlock:^(SCSBlockOperation *op, NSUInteger idx, BOOL *stop) {
        if (op.isReloadOp) {
            isReload = YES;
            *stop = YES;
        }
    }];
    return isReload;
}

/**
 * @return YES if the deferredOpsQueue contains a reloadOp.
 */
- (BOOL)isReloadQueued {
    return [self arrayContainsReloadOperation:_deferredOpsQueue];
}

/**
 * KVO listener for changes to the isReloading property value.
 *
 * The isReloading property flag is used to block execution of 
 * operations while an animated datasource reload is occurring.
 *
 * This method is fired whenever the isReloading property value changes.
 * If the value changes to true, the fireDeferredOperations method is
 * invoked, which will executed enqueued operations if any.
 *
 * @param keyPath The isReloading property name, the changes in value for
 *        which to listen.
 *
 * @param object The object on which to listen for keyPath value changes
 *
 * @param change The change dictionary will be populated with the change
 *        indicators set when subscribing. In our case, the "new" value.
 *        @see addObserver:forKeyPath:options:context: invocation in
 *        the initCommon method.
 *
 * @param context The context with which to identify the changed value.
 *        In our case it's SCConfContext, defined at top of file.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context
{
    if (SCConfContext != context) { return; }
    
      if ([keyPath isEqualToString:NSStringFromSelector(@selector(isReloading))])
    {
        BOOL isYes = [change[@"new"] boolValue];
        DDLogConfDeferredOp(@"%s\n    --- KVO listener fired: %@ = %@ ---",
         __PRETTY_FUNCTION__, keyPath, (isYes)?@"YES":@"NO");        
        
        if (!_isReloading && _deferredOpsQueue.count > 0) {
            [self fireDeferredOperations];
        }
    }
}

#pragma mark - Block Operations

// TODO: change the call param to callID
/**
 * This method returns a block operation that can be identified as an
 * "update operation", which calls the updateCellWithCall: method.
 *
 * An instance of this update operation is used by:
 * - SCPCallStateDidChangeNotification
 * - SCPZRTPDidUpdateNotification
 *
 * @return A block operation which invokes updateCellWithCall: on self.
 */
- (SCSBlockOperation *)updateOperationWithCall:(SCPCall *)aCall {
    if (! aCall) {
        NSLog(@"%s\n ---- ERROR: called with NIL CALL ----",__PRETTY_FUNCTION__);
    }
    
    __weak typeof (self) weakSelf = self;
    SCSBlockOperation *op = [SCSBlockOperation blockOperationWithBlock:^{
        DDLogConfDeferredOp(@"%s\n ---- EXECUTE UPDATE BLOCK \n    update with call: %@  ----",__PRETTY_FUNCTION__, aCall);
        
        if (aCall) {
            __strong typeof (weakSelf) strongSelf = weakSelf;
            [strongSelf updateCellWithCall:aCall];
        } else {
            DDLogConfDeferredOp(@"%s\n ---- EXECUTE UPDATE BLOCK ERROR: \n    update with NIL call: %@  ----",
                    __PRETTY_FUNCTION__, aCall);
        }
    }];
    
    /* Apple:
     The exact execution context for your completion block is not guaranteed
     but is typically a secondary thread. Therefore, you should not use this
     block to do any work that requires a very specific execution context.
    */
    __weak typeof (op) weakOp = op;
    op.completionBlock = ^{
        __strong typeof (weakOp) strongOp = weakOp;
            DDLogConfDeferredOp(@" .... Completed %@ operation ....",strongOp.strKind);
    };

    op.kind = eUpdate;
    return op;
}

/**
 * This method returns a block operation that can be identified as a 
 * "reload operation", which simply calls the reloadWithAnimation method.
 *
 * An instance of this reload operation is used for many "signals" and
 * events. Incoming calls, outgoing calls, and moves between sections,
 * all require a datasource reload.
 *
 * @return A block operation which invokes reloadWithAnimation on self.
 */
- (SCSBlockOperation *)reloadCallsOperation {
    __weak typeof (self) weakSelf = self;
    SCSBlockOperation *op = [SCSBlockOperation blockOperationWithBlock:^{
        DDLogConfDeferredOp(@"%s\n ---- EXECUTE RELOAD BLOCK ----",__PRETTY_FUNCTION__);
        __strong typeof (weakSelf) strongSelf = weakSelf;
        [strongSelf reloadWithAnimation];
    }];
    
    __weak typeof (op) weakOp = op;
    op.completionBlock = ^{
        __strong typeof (weakOp) strongOp = weakOp;
        DDLogConfDeferredOp(@" .... Completed %@ operation ....",strongOp.strKind);
    };
    
    op.kind = eReload;
    return op;
}


/**
 * Cleanup of KVO listener subscription, mainOpueue, and deferreOpsQueue
 * properties, called from prepareToBecomeInactive.
 */
- (void)cleanupDeferredOperations {
    DDLogConfEvent(@"%s called", __PRETTY_FUNCTION__);

    [_mainOpQueue cancelAllOperations];
    _deferredOpsQueue = nil;    
}


#pragma mark - Datasource Loading

/**
 * This method calculates the deltas between datasource arrays and
 * animates the resulting insertion and deletions.
 */
- (void)reloadWithAnimation {
    UICollectionView *cv = _collectionView;
    UITableView      *tv = _tableView;

    // Get a copy of datasource state before reloading from SPCallManager
    NSArray *startConf   = [_conferenceCalls copy];
    NSArray *startPriv   = [_privateCalls copy];
    NSArray *startInProg = [_inProgressCalls copy];
    NSUInteger startSecsCnt = (cv)?[cv numberOfSections]:[tv numberOfSections];

    // Return here if no changes
    DDLogConfDeferredOp(@"%s\n ---- RELOAD ANIM:  RELOAD DATASOURCE ARRAYS ----",__PRETTY_FUNCTION__);
    
    [self loadCalls];

    // Calculate datasource deltas between previous and current state
    NSUInteger endSecsCnt = (_inProgressCalls.count > 0) ? 3 : 2;
    int deltaSecs = (int)(endSecsCnt - startSecsCnt);
    
    // If the end count > start count it is an insert, otherwise, delete
    int deltaConf   = (int)(_conferenceCalls.count - startConf.count);
    int deltaPriv   = (int)(_privateCalls.count    - startPriv.count);
    int deltaInProg = (int)(_inProgressCalls.count - startInProg.count);

    DDLogConfDeferredOp(@"%s\n ---- RELOAD ANIM DELTAS:\nConf:%d _ Priv:%d _ InProg:%d section:%d----",
                        __PRETTY_FUNCTION__,deltaConf,deltaPriv,deltaInProg,deltaSecs);

    // Reload without animation and return here if no changes
    if ((deltaSecs+deltaConf+deltaPriv+deltaInProg) == 0) {
        DDLogConfDeferredOp(@"%s\n ---- RELOAD ANIM:  NO CHANGES AFTER RELOAD - RELOAD WITH NO ANIMATION - RETURN ----",__PRETTY_FUNCTION__);

        if (cv) { [_collectionView reloadData]; }
        else { [_tableView reloadData]; }
        [self updateInProgressAccessibility];
        return;
    }

    // Calculate insertions and deletions from datasource deltas
    NSMutableArray *insertIPs = [@[] mutableCopy];
    NSMutableArray *deleteIPs = [@[] mutableCopy];
    if (cv) {
        if (deltaConf > 0) {
            [insertIPs addObjectsFromArray: [self indexPathsFromInArray:_conferenceCalls outArr:startConf section:eConference]];
        } else if (deltaConf < 0) {
            [deleteIPs addObjectsFromArray: [self indexPathsFromInArray:startConf outArr:_conferenceCalls section:eConference]];
        }
        if (deltaPriv > 0) {
            [insertIPs addObjectsFromArray: [self indexPathsFromInArray:_privateCalls outArr:startPriv section:ePrivate]];
        } else if (deltaPriv < 0) {
            [deleteIPs addObjectsFromArray: [self indexPathsFromInArray:startPriv outArr:_privateCalls section:ePrivate]];
        }
        if (deltaInProg > 0) {
            [insertIPs addObjectsFromArray: [self indexPathsFromInArray:_inProgressCalls outArr:startInProg section:eInProgress]];
        } else if (deltaInProg < 0) {
            [deleteIPs addObjectsFromArray: [self indexPathsFromInArray:startInProg outArr:_inProgressCalls section:eInProgress]];
        }
    }
    
    if (deltaSecs != 0) {
        DDLogConfDeferredOp(@"%s\n ---- RELOAD ANIM  __ deltaSecs:%d  __  %@ SECTION ",
              __PRETTY_FUNCTION__, deltaSecs,(deltaSecs>0)?@"INSERT":@"DELETE");
    } else  {
        DDLogConfDeferredOp(@"%s\n ---- RELOAD ANIM:  NO CHANGE SECTIONS ",__PRETTY_FUNCTION__);
    }

    /*
     * Animate changes
     */
    
    // COLLECTION VIEW
    if (cv) {
        
        DDLogConfDeferredOp(@"%s\n ---- RELOAD ANIM: EXECUTE RELOAD ANIMATION BLOCK WITH CHANGES:\ninsertIPs: %@\ndeleteIPs: %@  ----",
                            __PRETTY_FUNCTION__, insertIPs, deleteIPs);

        [cv performBatchUpdates:^{
            if (insertIPs.count){ [cv insertItemsAtIndexPaths: insertIPs]; }
            if (deleteIPs.count){ [cv deleteItemsAtIndexPaths: deleteIPs]; }
            if (deltaSecs != 0) {
                NSIndexSet *set = [NSIndexSet indexSetWithIndex:eInProgress];
                if (deltaSecs > 0) {
                    [cv insertSections:set];
                } else  {
                    [cv deleteSections:set];
                }
            }
        } completion:^(BOOL finished) {
            [cv reloadData];
            [self updateInProgressAccessibility];
            [self fireDeferredOperations];
        }];
    }
    // TABLE VIEW
    else if (tv) {
        
        DDLogConfDeferredOp(@"%s\n ---- RELOAD ANIM: EXECUTE RELOAD ANIMATION BLOCK WITH CHANGES:\ninsertIPs: %@\ndeleteIPs: %@  ----",
                            __PRETTY_FUNCTION__, insertIPs, deleteIPs);

        [UIView transitionWithView:_tableView
                          duration:0.25
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
                            [_tableView reloadData];
                        }
                        completion:^(BOOL finished) {
                            [self updateInProgressAccessibility];
                            [self fireDeferredOperations];
                        }];
    }
}

/**
 * A helper method to return indexPaths for changes between datasource
 * arrays.
 *
 * The reloadWithAnimation method calculates deltas between states in 
 * datasource arrays. This method finds and returns indexPaths for those
 * changes.
 *
 * Where a datasource section array has changed from having an object to not
 * having an object (or vice versa), this method returns an indexPath constructed
 * with the index of the object in the array in which it now exists, 
 * with the section argument.
 *
 * An example:
 * There were three call objects in the Private section
 * (_privateCalls array) before the reload, and only one object after
 * the change. Let's say the user moved a call into the Conference 
 * section before the reloadWithAnim call and another Private call was
 * ended by the peer during the reordering.
 *
 * Private calls insertion indexPaths: none - only deletions.
 * Private calls deletion indexPaths:
 * - pass a copy made of that array before reloading to the inArr;
 *   *in* this array are contained the objects which have changed.
 * - pass the (current) _privateCalls array to the outArr paramenter;
 *   this array is the result of the calls taken *out*.
 * - pass the ePrivate enum int value as the section value.
 *
 * @param inArr This array must contain the objects which have changed,
 *        relative to the outArr.
 *
 * @param outArr This array is the result of the objects being taken out
 *        relative to the inArr.
 *
 * @param sec The section index with which to define the section
 *        attribute of an NSIndexPath.
 *
 * @return An array of indexPaths contructed with indexes of objects
 *         contained in the inArr which are not contained in the outArr,
 *         with the given section value.
 */
- (NSArray *)indexPathsFromInArray:(NSArray *)inArr outArr:(NSArray *)outArr section:(long)sec {
    NSMutableArray *indexPaths = [NSMutableArray array];
    [inArr enumerateObjectsUsingBlock:^(id  obj, NSUInteger idx, BOOL *stop) {
        if (! [outArr containsObject:obj]) {
            NSIndexPath *ip = [NSIndexPath indexPathForItem:idx inSection:sec];
            [indexPaths addObject:ip];
        }
    }];
    return indexPaths;
}


- (void)loadCalls {
    DDLogConfEvent(@"%s called", __PRETTY_FUNCTION__);
    
    NSArray *tmpAllCalls = [SPCallManager activeCalls];
    NSMutableArray *tmpInProgressCalls = [NSMutableArray array];
    NSMutableArray *tmpConfCalls = [NSMutableArray array];
    NSMutableArray *tmpPrivateCalls = [NSMutableArray array];
    for (SCPCall *aCall in tmpAllCalls) {
        if (aCall.isInProgress)        [tmpInProgressCalls addObject:aCall];
        else if (aCall.isInConference) [tmpConfCalls addObject:aCall];
        else if (aCall.uniqueCallId)   [tmpPrivateCalls addObject:aCall];
    }
    self.conferenceCalls = tmpConfCalls;
    self.privateCalls    = tmpPrivateCalls;
    self.inProgressCalls = tmpInProgressCalls;
    self.allCalls = @[_conferenceCalls, _privateCalls, _inProgressCalls];
}

#pragma mark - Common Utilities

- (void)updateCellWithCall:(SCPCall *)aCall {
    if (! aCall) {
        DDLogConfCell(@"%s\n    --- ERROR: called with NIL CALL ---", __PRETTY_FUNCTION__);
        return;
    }
    
    NSIndexPath *ip = [self indexPathWithCall:aCall];
    if (! ip) {
        DDLogConfCell(@"%s\n    --- ERROR: nil indexPath for call: %@ ---", __PRETTY_FUNCTION__, aCall);
        return;
    }
    
    if (_collectionView) {
        SCSConferenceCVCell *cell = (SCSConferenceCVCell*)[_collectionView cellForItemAtIndexPath:ip];
        if (! cell || ! [_collectionView.visibleCells containsObject:cell]) {
            DDLogConfCell(@"%s\n    --- ALERT: call: %@ NIl or NOT IN VISIBLE CELLS ---", __PRETTY_FUNCTION__, aCall);
            return;
        }
        // Reload cell
        [_collectionView reloadItemsAtIndexPaths:@[ ip ]];
    }
    else if (_tableView) {
        SCSConferenceTVCell *cell = (SCSConferenceTVCell*)[_tableView cellForRowAtIndexPath:ip];
        if (! cell || ! [_tableView.visibleCells containsObject:cell]) {
            DDLogConfCell(@"%s\n    --- ALERT: call: %@ NIl or NOT IN VISIBLE CELLS ---", __PRETTY_FUNCTION__, aCall);
            return;
        }
        // Reload cell
        [_tableView reloadRowsAtIndexPaths:@[ ip ] withRowAnimation:NO];
    }
}

#pragma mark Proximity Sensor

- (void)enableProximitySensor {
    
    if([[UIDevice currentDevice] isProximityMonitoringEnabled])
        return;
    
    if([SPAudioManager isHeadphoneOrBluetooth])
        return;
    
    UIDevice *device = [UIDevice currentDevice];
    device.proximityMonitoringEnabled = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(proximityStateChanged)
                                                 name:UIDeviceProximityStateDidChangeNotification
                                               object:nil];
}

- (void)disableProximitySensor {
    
    if(![[UIDevice currentDevice] isProximityMonitoringEnabled])
        return;
    
    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceProximityStateDidChangeNotification
                                                  object:nil];
}

- (void)proximityStateChanged {
    
    if([SPAudioManager isHeadphoneOrBluetooth])
        return;
    
    if(!UIAccessibilityIsVoiceOverRunning())
        return;
    
    [SPAudioManager routeAudioToLoudspeaker:![UIDevice currentDevice].proximityState
      shouldCheckHeadphonesOrBluetoothFirst:NO];
}

#pragma mark - Remote events

- (void)remoteControlReceived {
    
    for(SCPCall *call in _inProgressCalls) {
        
        [SPCallManager answerCall:call];
        return;
    }
    
    for(SCPCall *call in _privateCalls) {
        [SPCallManager terminateCall:call];
        return;
    }
}

#pragma mark - Common Datasource Utilities

- (BOOL)isInProgressCall:(SCPCall*)aCall {
    if (!aCall) { return NO; }
    return [_inProgressCalls containsObject:aCall];
}
- (BOOL)isPrivateCall:(SCPCall*)aCall {
    if (!aCall) { return NO; }
    return [_privateCalls containsObject:aCall];
}
- (BOOL)isConferenceCall:(SCPCall*)aCall {
    if (!aCall) { return NO; }
    return [_conferenceCalls containsObject:aCall];
}

- (long)activeCallsCount {
    return _conferenceCalls.count + _privateCalls.count;
}

- (SCPCall *)callWithIndexPath:(NSIndexPath *)indexPath {
    DDLogConfEvent(@"%s called", __PRETTY_FUNCTION__);
    
    SCPCall *call = nil;
    
    NSMutableArray *mArr = _allCalls[indexPath.section];
    
    // cell/datasource OutOfBounds Protection
    // cellForRow/ItemAtIndexPath: methods depend on this
    long idx = indexPath.row;
    long lastIdx = mArr.count - 1;
    idx = MIN(idx, lastIdx);
    call = mArr[idx];
    
    return call;
}

- (NSIndexPath *)indexPathWithCall:(SCPCall *)aCall {
    __block NSIndexPath *indexPath = nil;
    [_allCalls enumerateObjectsUsingBlock:^(NSArray *sectionArr, NSUInteger secIdx, BOOL *stop) {
        if ([sectionArr containsObject:aCall]) {
            long itemIdx = [sectionArr indexOfObject:aCall];
            indexPath = [NSIndexPath indexPathForItem:itemIdx inSection:secIdx];
            *stop = YES;
        }
    }];
    
    return indexPath;
}

- (NSArray *)indexPathsInSection:(NSUInteger)section {
    NSMutableArray *tmpArr = [NSMutableArray array];
    [_allCalls[section] enumerateObjectsUsingBlock:^(SCPCall *aCall, NSUInteger idx, BOOL *stop) {
        [tmpArr addObject:[NSIndexPath indexPathForItem:idx inSection:section]];
    }];
    return tmpArr;
}

- (NSUInteger)countInSection:(NSUInteger)section {
    if (_collectionView) {
        return [_collectionView numberOfItemsInSection:section];
    } else {
        return [_tableView numberOfRowsInSection:section];
    }
}

- (BOOL)shouldShowAltPrivateHeader {
    return (_conferenceCalls.count > 0);
}

- (void)swapArrItem:(NSMutableArray*)arr idx1:(NSInteger)idx1 idx2:(NSInteger)idx2 {
    if (idx1 == idx2) {
        return;
    }
    id item = arr[idx1];
    arr[idx1] = arr[idx2];
    arr[idx2] = item;
}

- (void)moveItemBetweenArrs:(NSMutableArray*)fromArr idx1:(NSInteger)idx1 toArr:(NSMutableArray*)toArr idx2:(NSInteger)idx2 {
    id item = fromArr[idx1];
    [fromArr removeObject:item];
    [toArr insertObject:item atIndex:idx2];
}


#pragma mark - Accessibility Common

- (void)updateInProgressAccessibility {
    
    DDLogConfAccessibility(@"called");
    
    // We need to do this check:
    // TVC always returns 3 sections but CVC returns 2, or 3 if there
    // are inProgress calls.
    if (_collectionView && [_collectionView numberOfSections] < 3) {
        return;
    }
    
    if ([self countInSection:eInProgress] > 0) {
        SCPCall *incomingCall = nil;
        // If there is an incoming call, set focus to the answer call button
        for (SCPCall *aCall in _inProgressCalls) {
            if (aCall.isIncomingRinging) {
                incomingCall = aCall;
                break;
            }
        }
        if (incomingCall) {
            DDLogConfAccessibility(@"post UIAccessibilityLayoutChangedNotification for cell answer button");
            
            NSIndexPath *ip = [self indexPathWithCall:incomingCall];            
            if (_tableView) {
                SCSConferenceTVCell *cell = [_tableView cellForRowAtIndexPath:ip];                
                UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, cell.btAnswerCall);
            }
            else if (_collectionView) {
                SCSConferenceCVCell *cell = (SCSConferenceCVCell *)[_collectionView cellForItemAtIndexPath:ip];                
                UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, cell.btAnswerCall);
            }
            return;
        }
    }
    
    DDLogConfAccessibility(@"post UIAccessibilityLayoutChangedNotification without object focus");
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

#pragma mark Magic Tap

- (BOOL)accessibilityPerformMagicTap {
    
    for(SCPCall *call in _inProgressCalls) {        
        DDLogConfAccessibility(@"ANSWER call.id: %d", call.iCallId);
        [SPCallManager answerCall:call];
        return YES;
    }
    
    for(SCPCall *call in _privateCalls) {
        DDLogConfAccessibility(@"END call.id: %d", call.iCallId);
        [SPCallManager terminateCall:call];
        return YES;
    }
    
    return YES;
}

#pragma mark ----------------------------------------
#pragma mark UITableView Methods
#pragma mark ----------------------------------------

#pragma mark - Sections

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _allCalls.count; // (_inProgressCalls.count > 0) ? 3 : 2;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == eInProgress) {
        return ([self tableView:tableView numberOfRowsInSection:eInProgress] > 0) ? kSectionHeaderHeight : 0.;
    }
    else if (section == ePrivate && [self shouldShowAltPrivateHeader]) {
        return kSectionHeaderHeight + kHeaderFooterAltHeight;
    }
    return kSectionHeaderHeight;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {

    SCSConfHeaderFooterView *hView = nil;
    
    switch (section) {
        case eConference:
            hView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:kSCSConfHeaderFooterId];
            hView.mainText = kConferenceSectionTitle;
            [hView useMainHeaderStyle];
            break;
        case ePrivate:
            if ([self shouldShowAltPrivateHeader]) {
                hView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:kSCSPrivateAltHeaderId];
                hView.mainText   = kPrivateSectionTitle;
                hView.bottomText = kPrivateSectionAltHeaderTitle;
                [hView useBottomFooterStyle];
            }
            else {
                hView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:kSCSConfHeaderFooterId];
                hView.mainText = kPrivateSectionTitle;
                [hView useMainHeaderStyle];
            }
            break;
        case eInProgress:
            if (_inProgressCalls.count > 0) {
                hView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:kSCSConfHeaderFooterId];
                hView.mainText = kInProgressSectionTitle;
                [hView useMainHeaderStyle];
            }
            break;
    }
    
    if (hView)
        [self updateTVCHeaderFooterAccessibility:hView section:section];
    
    hView.layer.zPosition = hView.layer.zPosition - 1;
    return hView;
}


#pragma mark - Section Footer

// Only show footer in Conference section, and only if there is one
// or more call in Private section
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == eConference && [self shouldShowConfSectionFooter]) {
        return kHeaderFooterAltHeight;
    }
    return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    SCSConfHeaderFooterView *fView = nil;
    if (section == eConference && [self shouldShowConfSectionFooter]) {
        fView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:kSCSConfFooterId];
        if([[UserService currentUser] hasPermission:UserPermission_CreateConference]) {
            fView.mainText = kConfSectionFooterTitle
        }else{
            fView.mainText = kConfFeatureNotAvailable;
        }

        [fView useMainFooterStyle];
    }
    // AccessibilityLabel/Hint string construction handled in
    // updateTVCHeaderFooterAccessibility:section: method. Footer text
    // is incorporated as hint in conference section view label.
    fView.mainViewLabel.isAccessibilityElement = NO;
    fView.mainViewLabel.accessibilityLabel = @"";
    
    fView.layer.zPosition = fView.layer.zPosition - 1;
    return fView;
}

- (BOOL)shouldShowConfSectionFooter {
    return _privateCalls.count > 0;
}


#pragma mark - TVC HeaderFooter Accessibility

- (void)updateTVCHeaderFooterAccessibility:(SCSConfHeaderFooterView *)aView section:(NSInteger)section {
    
    int n = (int)[_allCalls[section] count];//[self.tableView numberOfRowsInSection:section];
    NSString *nCalls = [NSString stringWithFormat:@"%i", n];
    NSString *sStr = (n==1)?@"":@"s";
    NSString *lbl = nil;
    switch (section) {
        case eConference: {
            lbl = [NSString stringWithFormat:NSLocalizedString(@"conference. %@ call%@.", nil), nCalls, sStr];
            aView.accessibilityLabel = lbl;
            if (n > 0) {
                if([[UserService currentUser] hasPermission:UserPermission_CreateConference]){
                    aView.accessibilityHint = kConfSectionFooterTitle;
                }else{
                    aView.accessibilityHint = kConfFeatureNotAvailable;
                }
            }
        }
            break;
        case ePrivate: {
            lbl = [NSString stringWithFormat:NSLocalizedString(@"private. %@ call%@.", nil) , nCalls, sStr];
            aView.accessibilityLabel = lbl;
            if ([self shouldShowAltPrivateHeader]) {
                aView.accessibilityHint = kPrivateSectionAltHeaderTitle;
            }
        }
            break;
        case eInProgress: {
            if (_inProgressCalls.count > 0) {
                NSArray *calls = _allCalls[eInProgress];
                __block int iCalls=0; __block int oCalls=0;
                [calls enumerateObjectsUsingBlock:^(SCPCall *call, NSUInteger idx, BOOL *stop) {
                    if (call.isIncoming)
                        ++iCalls;
                    else
                        ++oCalls;
                }];
                NSString *inCalls = @"";
                if (iCalls > 0){
                    inCalls = [NSString stringWithFormat:NSLocalizedString(@"%i call%@", nil),iCalls,sStr];
                }
                NSString *outCalls = @"";
                if (oCalls > 0) {
                    outCalls = [NSString stringWithFormat:NSLocalizedString(@"%i call%@", nil),oCalls,sStr];
                }
                lbl = [NSString stringWithFormat:NSLocalizedString(@"incoming, outgoing. %@, %@", nil), inCalls, outCalls];
                aView.accessibilityLabel = lbl;
            }
        }
            break;
    }
    
    DDLogConfAccessibility(@"\n   --- SECTION ACCESSIBILITY:  %@  for view: %@ ---", lbl, aView);
}


#pragma mark - ROWS

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_allCalls[section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    SCSConferenceTVCell *cell = [tableView dequeueReusableCellWithIdentifier:[SCSConferenceTVCell reuseId]
                                                              forIndexPath:indexPath];
    
    SCPCall *call = _allCalls[indexPath.section][indexPath.row];
    cell.call = call;
    cell.delegate = self;
    
    DDLogConfCell(@"CELL{%ld,%ld} _ onHold:%@ _ isReordering:%@ _ isIncomingRinging:%@",
                  (long)indexPath.section, (long)indexPath.row,
                  (cell.call.isOnHold)?@"YES":@"NO",
                  (cell.isReordering)?@"YES":@"NO",
                  (call.isIncomingRinging)?@"YES":@"NO");
    
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(nonnull UITableViewCell *)cell forRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    DDLogConfCell(@"CELL height: %1.2f", cell.frame.size.height);
}


#pragma mark TableView didSelectRow

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    // EA: verify user permission and upsell if permission not available
    if ( (indexPath.section == eConference) && (![[UserService currentUser] hasPermission:UserPermission_CreateConference]) ) {
            // off-load to upsell flow
        [[UserService sharedService] enablePermission:UserPermission_CreateConference];
        [_tableView reloadData];
        return;
    }
    
    SCPCall *call = _allCalls[indexPath.section][indexPath.row];

    [SPCallManager setSelectedCall:call
                    informProvider:YES];
    
    if(call.hasSAS && call.shouldShowVideoScreen && !call.isEnded){
        if ([_navDelegate respondsToSelector:@selector(switchToVideo:call:)]) {
            [_navDelegate switchToVideo:nil call:call];
        }
    }
    else if ([_navDelegate respondsToSelector:@selector(switchToCallScreen:call:)]) {
        [_navDelegate switchToCallScreen:nil call:call];
    }
}


#pragma mark - TableView Editing Methods

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

// Disallow moves from/to inProgress
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    if ( (indexPath.section > eConference)
        && (![[UserService currentUser] hasPermission:UserPermission_CreateConference]) ) {
        // can't start a conf call
        return NO;
    }
    if (indexPath.section == eInProgress) {
        return NO;
    }
    return YES;
}

- (void)tableView:(UITableView *)tableView willBeginReorderingRowAtIndexPath:(NSIndexPath *)indexPath {
    SCSConferenceTVCell *cell = (SCSConferenceTVCell*)[tableView cellForRowAtIndexPath:indexPath];
    cell.isReordering = YES;
//    if (!cell.isSelected) NSLog(@"%s\n   SET cell SELECTED", __PRETTY_FUNCTION__);
    if (!cell.isSelected) cell.selected = YES;
    
    [self startMoveItemHandler];
}
- (void)tableView:(UITableView *)tableView didEndReorderingRowAtIndexPath:(NSIndexPath *)indexPath {

    SCSConferenceTVCell *cell = (SCSConferenceTVCell*)[tableView cellForRowAtIndexPath:indexPath];
    cell.isReordering = NO;
//    if (cell.isSelected) NSLog(@"%s\n   SET cell NOT SELECTED", __PRETTY_FUNCTION__);
    if (cell.isSelected) cell.selected = NO;
    
    if (_isReordering) {
        [self endMoveItemHandler];
    }
}
- (void)tableView:(UITableView *)tableView didCancelReorderingRowAtIndexPath:(NSIndexPath *)indexPath {
    
    SCSConferenceTVCell *cell = (SCSConferenceTVCell*)[tableView cellForRowAtIndexPath:indexPath];
    cell.isReordering = NO;
//    if (cell.isSelected) NSLog(@"%s\n   SET cell NOT SELECTED", __PRETTY_FUNCTION__);
    if (cell.isSelected) cell.selected = NO;

    [self endMoveItemHandler];
}

- (BOOL)tableView:(UITableView *)tableview shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath{
    return UITableViewCellEditingStyleNone;
}

// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    DDLogConfMovePaths(@"    -- MOVE -- sourceIndexPath: { %ld, %ld }\n    -- TO -- destinationIndexPath: { %ld, %ld }",
                       (long)fromIndexPath.section, (long)fromIndexPath.row,
                       (long)toIndexPath.section, (long)toIndexPath.row);
    
    NSInteger fromIdx = fromIndexPath.row;
    NSInteger toIdx   = toIndexPath.row;
    
    NSMutableArray *fromArr = _allCalls[fromIndexPath.section];
    NSMutableArray *toArr   = _allCalls[toIndexPath.section];
    
    [self clearAllCellReorderingFlags];
    
    // reset cell flags
    // (not supporting swap)
    if (fromArr == toArr) {
        // Note that not swapping call objects' positions in their
        // section array here, i.e. not supporting swapping, the from/to
        // indexPaths should be the same, so it doesn't matter which one
        // we use here to get the call instance.
        SCPCall *call = fromArr[fromIdx];
        

        [SPCallManager setSelectedCall:call
                        informProvider:YES];
    }
    //move
    else {
        [self moveItemBetweenArrs:fromArr idx1:fromIdx toArr:toArr idx2:toIdx];
        
        BOOL moveToConf = (fromArr == _privateCalls && toArr == _conferenceCalls);
        BOOL moveToPriv = (fromArr == _conferenceCalls && toArr == _privateCalls);
        
        SCPCall *call = toArr[toIdx];
        
        if (moveToConf) {
            [SPCallManager moveCallToConference:call];
        }
        else if (moveToPriv) {
            [SPCallManager moveCallFromConfToPrivate:call];
        }
    }
    
    // The datasource arrays have been updated with the move, and the
    // tableView and datasource are in sync. However, for the cells
    // to reflect the state change in potentially many calls, the
    // tableView must be reloaded.
    //
    // Note that if a call has come in during reordering, the
    // incomingCall notification listener will fire a reload request,
    // but the operation will be deferred because the reordering flag
    // was set at the beginning of reordering by the startMoveItemHandler
    // method.
    //
    // Therefore, we will clear the isReordering flag and call for a reload.
    // If an incoming call is in the datasource array, it will be added
    // to incoming/outgoing section in the reload.
    SCSBlockOperation *op = [self reloadCallsOperation];
    _isReordering = NO;
    
    DDLogConfDeferredOp(@"%s\n ---- MOVE ITEM:  CLEAR isReordering FLAG and REQUEST RELOAD OP: %@ ----",
                        __PRETTY_FUNCTION__, op);
    
    [self addOperation:op];
    
}

// 1st pass: allow any move except into/out of inProgress section
- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath
       toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath
{
    if (proposedDestinationIndexPath.section == eInProgress) {
        return sourceIndexPath;
    }
    // Not supporting swapping within section yet
    else if (sourceIndexPath.section == proposedDestinationIndexPath.section) {
        return sourceIndexPath;
    }
    
    // Is this a good idea? Recently, occasional crashes when starting
    // to reorder - crashes with "[this method] needs to return a non-nil value"
    return (proposedDestinationIndexPath) ?: sourceIndexPath;
}



#pragma mark - --------------------------------------
#pragma mark UICollectionView Methods
#pragma mark ----------------------------------------

#pragma mark - UICollectionViewDataSource Methods

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return (_inProgressCalls.count > 0) ? 3 : 2;
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    DDLogConfMoveCount(@"    RETURN  %ld   items for   SECTION  %ld", (long)[_allCalls[section] count], (long)section);
    return [_allCalls[section] count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    SCSConferenceCVCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[SCSConferenceCVCell reuseId]
                                                                          forIndexPath:indexPath];
    SCPCall *call = [self callWithIndexPath:indexPath];
    cell.call = call;
    cell.delegate = self;
    
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    NSString *aKind = (kind == UICollectionElementKindSectionHeader) ? @"HEADER" : @"FOOTER";
    
    DDLogConfHeaderFooter(@"\n     supplementaryView %@     COUNT %ld      in SECTION %ld", aKind,
                          (long)[collectionView numberOfItemsInSection:indexPath.section], (long)indexPath.section);
    
    UICollectionReusableView *rView = nil;
    NSString *reuseId = nil;
    NSString *title = nil;
    
    if (kind == UICollectionElementKindSectionHeader) {
        
        BOOL useAltHeader = [self shouldShowAltPrivateHeader];
        reuseId = (useAltHeader) ? kCVAltHeader_ID : kCVHeader_ID;
        
        SCSCVHeaderFooter *header = (SCSCVHeaderFooter*)[collectionView dequeueReusableSupplementaryViewOfKind:kind
                                                                                           withReuseIdentifier:reuseId
                                                                                                  forIndexPath:indexPath];
        switch (indexPath.section) {
            case eConference:
                title = kConferenceSectionTitle;
                break;
            case ePrivate:
                title = kPrivateSectionTitle;
                break;
            case eInProgress:
                title = kInProgressSectionTitle;
                break;
        }
        
        header.mainViewLabel.text = title;
        if (useAltHeader) {
            header.altBottomLabel.text = kPrivateSectionAltHeaderTitle;
        } else {
            header.altBottomLabel.text = nil;
        }

        [self updateCVCHeaderAccessibility:(SCSCVHeaderFooter *)header
                                   section:indexPath.section];

        rView = header;
    }
    else if (kind == UICollectionElementKindSectionFooter) {
        reuseId = kCVFooter_ID;
        SCSCVHeaderFooter *footer = (SCSCVHeaderFooter*)[collectionView dequeueReusableSupplementaryViewOfKind:kind
                                                                                           withReuseIdentifier:reuseId
                                                                                                  forIndexPath:indexPath];
        switch (indexPath.section) {
            case eConference:
                if([[UserService currentUser] hasPermission:UserPermission_CreateConference]){
                    title = kConfSectionFooterTitle;
                }else{
                    title = kConfFeatureNotAvailable;
                }
                break;
            case ePrivate:
                title = kPrivateSectionAltHeaderTitle;
                break;
            case eInProgress:
                DDLogConfHeaderFooter(@"ERROR: no footer should be shown here.");
                title = @"";
                break;
        }
        
        if (eConference == indexPath.section && [self countInSection:ePrivate] > 0) {
            footer.mainViewLabel.text = title;
            [footer useMainFooterStyle];
        } else {
            footer.mainViewLabel.text = @"";
            footer.mainView.backgroundColor = [UIColor clearColor];
        }
        
        footer.mainViewLabel.isAccessibilityElement = NO;
        
        rView = footer;
    }
    
    return rView;
}

- (BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath {
    if (eInProgress == indexPath.section) return NO;
    return YES;
}

- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath*)destinationIndexPath
{
    DDLogConfMovePaths(@"    -- MOVE -- sourceIndexPath: { %ld, %ld }\n    -- TO -- destinationIndexPath: { %ld, %ld }",
                       (long)sourceIndexPath.section, (long)sourceIndexPath.item,
                       (long)destinationIndexPath.section, (long)destinationIndexPath.item);
    
    NSInteger fromIdx = sourceIndexPath.row;
    NSInteger toIdx   = destinationIndexPath.row;
    
    NSMutableArray *fromArr = _allCalls[sourceIndexPath.section];
    NSMutableArray *toArr   = _allCalls[destinationIndexPath.section];

    [self clearAllCellReorderingFlags];
    
    // reset cell flags and backgrounds
    // (not supporting swap)
    // non-support  works - try swapping next
    if (fromArr == toArr) {
        SCPCall *aCall = fromArr[fromIdx];
        [self swapArrItem:fromArr idx1:fromIdx idx2:toIdx];
        
        [SPCallManager setSelectedCall:aCall
                        informProvider:YES];
    }
    //move
    else {
        [self moveItemBetweenArrs:fromArr idx1:fromIdx toArr:toArr idx2:toIdx];

        BOOL moveToConf = (fromArr == _privateCalls && toArr == _conferenceCalls);
        BOOL moveToPriv = (fromArr == _conferenceCalls && toArr == _privateCalls);
        
        SCPCall *call = toArr[toIdx];
        
//        [self clearAllCellReorderingFlags];
        
        if (moveToConf) {
            [SPCallManager moveCallToConference:call];
        }
        else if (moveToPriv) {
            [SPCallManager moveCallFromConfToPrivate:call];
        }
        
    }
    
    // The datasource arrays have been updated with the move, and the
    // tableView and datasource are in sync. However, for the cells
    // to reflect the state change in potentially many calls, the
    // tableView must be reloaded.
    //
    // Note that if a call has come in during reordering, the
    // incomingCall notification listener will fire a reload request,
    // but the operation will be deferred because the reordering flag
    // was set at the beginning of reordering by the startMoveItemHandler
    // method.
    //
    // Therefore, we will clear the isReordering flag and call for a reload.
    // Any new incoming calls will be added to the incoming section of
    // the datasource array in the reload.
    SCSBlockOperation *op = [self reloadCallsOperation];
    _isReordering = NO;
    
    DDLogConfDeferredOp(@"%s\n ---- MOVE ITEM:  CLEAR isReordering FLAG and REQUEST RELOAD OP: %@ ----",
                        __PRETTY_FUNCTION__, op);
    
    [self addOperation:op];

}


#pragma mark - UICollectionViewDelegate Methods

- (NSIndexPath *)collectionView:(UICollectionView *)collectionView targetIndexPathForMoveFromItemAtIndexPath:(NSIndexPath *)originalIndexPath toProposedIndexPath:(NSIndexPath *)proposedIndexPath
{
    
    NSIndexPath *proposeThisIndexPath = proposedIndexPath;
    
    // @see "drag tracking feature" documentation at top of file.
    BOOL lastPosIsInitialized = !CGPointEqualToPoint(_lastMovingItemPosition, CGPointZero);
    if (lastPosIsInitialized) {
        NSInteger secIdx = [self sectionIndexWithLocation:_lastMovingItemPosition];
        
        if (NSNotFound != secIdx && secIdx != proposedIndexPath.section) {
            // If going up, the item index will be the count of items
            // in the section - as reported by the collectionView,
            // NOT the datasource array. That is, the indexPath will be
            // one position past the last existing item, or zero if empty.
            scsMoveDirection direction = [self directionOfMovingItem];
            long itemIdx = (direction == eUp) ? [collectionView numberOfItemsInSection:secIdx] : 0;
            proposeThisIndexPath = [NSIndexPath indexPathForItem:itemIdx inSection:secIdx];
            // Otherwise, dragging downward, we will return the first
            // position indexPath, i.e. the 0th element position.
        }
    }
    
    DDLogConfMovePaths(@"\n    FOR targetIndexPath: { %ld, %ld }\n    RETURN proposedIndexPath: { %ld, %ld }",
                       (long)originalIndexPath.section, (long)originalIndexPath.item,
                       (long)proposeThisIndexPath.section, (long)proposeThisIndexPath.item);
    
    // No swap support right now
    // This works - try swapping next
    if (originalIndexPath.section == proposeThisIndexPath.section) {
        return originalIndexPath;
    }

    return proposeThisIndexPath;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    DDLogConfEvent(@"%s called", __PRETTY_FUNCTION__);
    
    //TODO: should use?
    //  [self callWithIndexPath:indexPath] here?
    SCPCall *aCall = _allCalls[indexPath.section][indexPath.row];
    
    [SPCallManager setSelectedCall:aCall
                    informProvider:YES];
    
    if ([_navDelegate respondsToSelector:@selector(switchToCallScreen:call:)]) {
        [_navDelegate switchToCallScreen:nil call:aCall];
    }
}


#pragma mark - UICollectionViewDelegateFlowLayout Methods

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    UIEdgeInsets insets = [(UICollectionViewFlowLayout*)collectionViewLayout sectionInset];
    
    // Expand the conference section with insets if empty
    if (eConference == section && [self countInSection:eConference] < 1) {
        
        // ONLY expand conference section if it is empty AND the
        // Incoming/Outgoing section is not empty.
        // Note that there are 3 collectionView sections ONLY when there
        // are incoming/outgoing calls, and otherwise only 2 sections.
        // So we need the secCount check.
        long secCount = [collectionView numberOfSections];
        if (secCount < 3) {
            CGFloat vInsetH = [(SCSMainCVFlowLayout*)collectionViewLayout sectionInset].top;
            vInsetH *= 2;
            insets = UIEdgeInsetsMake(vInsetH, insets.left, vInsetH, insets.right);
        }
    }
    return insets;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(nonnull UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    CGSize refSize = [(UICollectionViewFlowLayout*)collectionViewLayout headerReferenceSize];
    BOOL hasIncoming = (eInProgress == section && [self countInSection:eInProgress] > 0);
    
    if (ePrivate == section && [self countInSection:eConference] > 0) {
        refSize.height = scsSectionHeaderH + scsSectionFooterH;
    }
    else if (ePrivate == section || eConference == section || hasIncoming) {
        refSize.height = scsSectionHeaderH;
    }
    
    return refSize;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(nonnull UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section
{
    NSInteger privCount = [collectionView numberOfItemsInSection:ePrivate];
    // Conf Section Footer
    if (eConference == section && privCount > 0) {
        return CGSizeMake(collectionView.frame.size.width, scsSectionFooterH);
    }
    
    return [(UICollectionViewFlowLayout*)collectionViewLayout footerReferenceSize];
}


#pragma mark - CVC HeaderFooter Accessibility

// NOTE: very little difference between this and the TVC version.
// Could be collapsed into a single method easily.
- (void)updateCVCHeaderAccessibility:(SCSCVHeaderFooter *)view section:(NSInteger)section {
    
    int n = (int)[_collectionView numberOfItemsInSection:section];
    NSString *nCalls = [NSString stringWithFormat:@"%i", n];
    NSString *sStr = (n==1)?@"":@"s";
    switch (section) {
        case eConference: {
            NSString *lbl = [NSString stringWithFormat:NSLocalizedString(@"conference. %@ call%@.", nil), nCalls, sStr];
            view.accessibilityLabel = lbl;
            if (n > 0) {
                if([[UserService currentUser] hasPermission:UserPermission_CreateConference]){
                    view.accessibilityHint = kConfSectionFooterTitle;
                }else{
                    view.accessibilityHint = kConfFeatureNotAvailable;
                }
            }
        }
            break;
        case ePrivate: {
            NSString *lbl = [NSString stringWithFormat:NSLocalizedString(@"private. %@ call%@.", nil), nCalls, sStr];
            view.accessibilityLabel = lbl;
            if ([self shouldShowAltPrivateHeader]) {
                view.accessibilityHint = kPrivateSectionAltHeaderTitle;
            }
        }
            break;
        case eInProgress: {
            if (_inProgressCalls.count > 0) {
                NSArray *calls = _allCalls[eInProgress];
                __block int iCalls=0; __block int oCalls=0;
                [calls enumerateObjectsUsingBlock:^(SCPCall *call, NSUInteger idx, BOOL *stop) {
                    if (call.isIncoming)
                        ++iCalls;
                    else
                        ++oCalls;
                }];
                NSString *inCalls = @"";
                if (iCalls > 0){
                    inCalls = [NSString stringWithFormat:NSLocalizedString(@"%i call%@", nil),iCalls,sStr];
                }
                NSString *outCalls = @"";
                if (oCalls > 0) {
                    outCalls = [NSString stringWithFormat:NSLocalizedString(@"%i call%@", nil),oCalls,sStr];
                }
                NSString *lb = [NSString stringWithFormat:NSLocalizedString(@"incoming, outgoing. %@, %@", nil), inCalls, outCalls];
                view.accessibilityLabel = lb;
            }
        }
            break;
    }
    
    DDLogConfHeaderFooter(@"\n     ACCESSIBILITY in SECTION %ld \n    LABEL: %@", (long)section, view.accessibilityLabel);
    
}


#pragma mark - CollectionViewDelegate Utilities

/**
 * This method iterates backwards through the count of collectionView
 * sections to determine the index of bottommost section containing
 * the given point.
 *
 * The determination is made by accessing the section header view and
 * comparing the given point y value with the vertical extent of the
 * header view frame.
 *
 * @param loc The point with which to determine the bottommost section 
 *        index.
 *
 * @return The index of the bottommost section containing the given point.
 */
- (NSInteger)sectionIndexWithLocation:(CGPoint)loc {
    
    UICollectionView *cv = self.collectionView;
    NSInteger retIdx = NSNotFound;
    
    long secCount = [cv numberOfSections];
    for (long sec = secCount-1; sec >= 0; sec--) {
        NSIndexPath *ip = [NSIndexPath indexPathForItem:0 inSection:sec];
        UICollectionReusableView *hdr = [self collectionView:cv
                           viewForSupplementaryElementOfKind:UICollectionElementKindSectionHeader
                                                 atIndexPath:ip];
        
        CGFloat secMaxY = CGRectGetMaxY(hdr.frame);
        
        // Without this, sometimes header view artefacts remain in view
        [hdr removeFromSuperview];
        hdr = nil;
        
        if (loc.y > secMaxY) {
            retIdx = sec;
            break;
        }
    }
    
    return retIdx;
}

// DEPRECATED - was only called by
// collectionView:targetIndexPathForMoveFromItemAtIndexPath:toProposedIndexPath:
// as a workaround for undefined section item count (supposedly?) reported
// by the collectionView.
//
//- (long)totalItemsCount {
//    long count = 0;
//    UICollectionView *cv = self.collectionView;
//    for (long sec = 0; sec <= [cv numberOfSections]-1; sec++) {
//        count += [cv numberOfItemsInSection:sec];
//    }
//    return count;
//}

- (scsMoveDirection)directionOfMovingItem {
    scsMoveDirection dir = eUnknownOrUnchanged;
    if (_lastMovingItemPosition.y > _previousMovingItemPosition.y) {
        dir = eDown;
    }
    if (_lastMovingItemPosition.y < _previousMovingItemPosition.y) {
        dir = eUp;
    }

    NSString *strDir = (dir == eUnknownOrUnchanged) ? @"UNKNOWN OR UNCHANGED" : @"DOWN";
    strDir = (dir == eUp) ? @"UP" : @"DOWN";

    DDLogConfMoveDirection(@"\n MOVE DIRECTION:   %@,  previousY: %1.2f  lastY: %1.2f",
                           strDir, _previousMovingItemPosition.y, _lastMovingItemPosition.y);

    return dir;
}


#pragma mark - CV LongPress Handler

- (IBAction)handleLongPress:(UILongPressGestureRecognizer *)gr {
    UICollectionView *cv = self.collectionView;
    switch(gr.state) {
        case UIGestureRecognizerStateBegan: {
            DDLogConfMovePaths(@"%s\n    --- BEGIN MOVE ITEM - LONG PRESS BEGAN ---", __PRETTY_FUNCTION__);
            
            CGPoint ptTouch = [gr locationInView:cv];
            NSIndexPath *selIP = [cv indexPathForItemAtPoint:ptTouch];
            
            if (selIP) {
                SCSConferenceCVCell *cell = (SCSConferenceCVCell*)[cv cellForItemAtIndexPath:selIP];
                cell.isReordering = YES;
                cell.selected = YES;
                DDLogConfMovePaths(@"%s\n    --- SET cell:%@ isReordering flag YES ---", __PRETTY_FUNCTION__, cell);
                
                [self startMoveItemHandler];
                [cv beginInteractiveMovementForItemAtIndexPath:selIP];
            }
            // Force gesture to cancel
            else {
                gr.enabled = NO;
                gr.enabled = YES;

                DDLogConfMovePaths(@"%s\n    --- FORCE CANCEL GESTURE - NIL indexPath ---", __PRETTY_FUNCTION__);
                [self endMoveItemHandler];
            }
        }
            break;
        case UIGestureRecognizerStateChanged: {
            CGPoint ptTouch = [gr locationInView:gr.view];
            _previousMovingItemPosition = _lastMovingItemPosition;
            _lastMovingItemPosition = ptTouch;
            [cv updateInteractiveMovementTargetPosition:ptTouch];
        }
            break;
        case UIGestureRecognizerStateEnded:
            [cv endInteractiveMovement];
            // if ended normally, isReordering should be cleared elsewhere
            DDLogConfMovePaths(@"%s\n    --- END MOVE ITEM PRESS ENDED NORMALLY - CLEAR CELL REORDER FLAGS ---", __PRETTY_FUNCTION__);

            // Must clear cell flags if a swap was attempted
            [self clearAllCellReorderingFlags];
            [self endMoveItemHandler];
            
            break;
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateCancelled:
            [cv cancelInteractiveMovement];
            DDLogConfMovePaths(@"%s\n    --- END MOVE ITEM PRESS ENDED WITH FAILURE OR CANCEL - CLEAR CELL REORDER FLAGS ---", __PRETTY_FUNCTION__);
            [self clearAllCellReorderingFlags];
            [self endMoveItemHandler];
            break;
        default:
            break;
    }
}

- (void)clearAllCellReorderingFlags {
    UICollectionView *cv = _collectionView;
    UITableView *tv = _tableView;
    [_allCalls enumerateObjectsUsingBlock:^(NSArray *arr, NSUInteger sectionIdx, BOOL *stop) {
        [arr enumerateObjectsUsingBlock:^(SCPCall *call, NSUInteger itemIdx, BOOL *stop) {
            if (cv) {
                NSIndexPath *ip = [NSIndexPath indexPathForItem:itemIdx inSection:sectionIdx];
                if (ip) {
                    SCSConferenceCVCell *cell = (SCSConferenceCVCell*)[cv cellForItemAtIndexPath:ip];
                    cell.isReordering = NO;
                    // Note that the actual selected state is determined by the
                    // cell setSelected: method, based on its call state.
                    // In other words, setting to "NO" here only ensures the
                    // method is invoked, not that the selected state will be OFF.
                    cell.selected = NO;
                }
            }
            else if (tv) {
                NSIndexPath *ip = [NSIndexPath indexPathForRow:itemIdx inSection:sectionIdx];
                if (ip) {
                    SCSConferenceTVCell *cell = (SCSConferenceTVCell*)[tv cellForRowAtIndexPath:ip];
                    cell.isReordering = NO;
                    // Note that the actual selected state is determined by the
                    // cell setSelected: method, based on its call state.
                    // In other words, setting to "NO" here only ensures the
                    // method is invoked, not that the selected state will be OFF.
                    cell.selected = NO;
                }
            }
        }];
    }];
}

- (void)startMoveItemHandler {
    DDLogConfEvent(@"%s called", __PRETTY_FUNCTION__);

    DDLogConfDeferredOp(@"%s\n    --- BEGIN MOVE ITEM :: SET isReordering ---", __PRETTY_FUNCTION__);
    
    self.isReordering = YES;
    [self stopCellDurationUpdate];
}

/**
 * (CollectionView)
 * Handles state cleanup at the end of a move gesture.
 *
 * When the user begins reordering, the startMoveItemHandler method
 * sets the isReordering flag. The moveItemAtIndexPath: delegate
 * method is called when a move between sections is complete, and it
 * shuffles the datasource arrays as necessary, clears the isReordering
 * flag, and invokes a reloadOp request. Then the longPress gesture
 * completes and this method is called.
 *
 * However, if the user drags the cell around and finishes by
 * releasing the cell in the same position in which it started,
 * the moveItemAtIndexPath: method is not invoked. If in the
 * meantime an incoming call came in, the incomingCallNotification
 * handler would have invoked a reloadOp request. The isReordering
 * flag having been set would cause the reloadOp to be deferred.
 *
 * When the longPress gesture finishes and this method is called,
 * the isReordering flag will still be true, preventing execution
 * of operations.
 *
 * So we check the "blocking" flags, isReordering and isReloading,
 * and if there is a deferred reload operation enqueued, we invoke the
 * fireDeferredOperations method.
 */
- (void)endMoveItemHandler {
    DDLogConfEvent(@"%s called", __PRETTY_FUNCTION__);

    _lastMovingItemPosition     = CGPointZero;
    _previousMovingItemPosition = CGPointZero;

    if (_isReordering) {
        DDLogConfDeferredOp(@"%s\n    --- END MOVE ITEM :: CLEAR isReordering ---",__PRETTY_FUNCTION__);

        _isReordering = NO;
        if (_deferredOpsQueue.count > 0) {
            DDLogConfDeferredOp(@"%s\n    --- END MOVE ITEM: FIRE DEFERRED OPERATIONS ---",__PRETTY_FUNCTION__);

            [self fireDeferredOperations];
        }
    } else {
        DDLogConfDeferredOp(@"%s\n    --- END MOVE ITEM :: isReordering is %@ ---",
                            __PRETTY_FUNCTION__,(_isReordering)?@"TRUE":@"FALSE");

        [self startCellDurationUpdate];
    }
}

@end
