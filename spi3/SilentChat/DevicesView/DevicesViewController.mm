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

#import "axolotl_glue.h"
#include "interfaceApp/AppInterfaceImpl.h"

#import "CallButton.h"
#import "ChatUtilities.h"
#import "DeviceCell.h"
#import "DevicesTableHeaderView.h"
#import "DevicesViewController.h"
#import "SCPCallbackInterface.h"
#import "SCPNotificationKeys.h"
#import "UserService.h"

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelWarning;
//#endif

#define kSectionHeaderHeight 44.
#define kSectionFooterHeight 80.
#define kBackButtonSize 30.

#define kDevicesLocalSection 0
#define kDevicesRemoteSection 1
#define kDevicesOtherSection 2

using namespace zina;
using namespace std;

@interface DevicesViewController () <UITableViewDataSource, UITableViewDelegate>
{    
    NSMutableArray *peerDevices;
    NSMutableArray *myDevices;
    NSDictionary *localDevice;
    
    BOOL _hasRemoteDevices;
    
    BOOL _firstLoad;
    
    NSOperationQueue *_scanQueue;
    
    BOOL _isEditing;
}
@end

@implementation DevicesViewController

#pragma mark - View Lifecycle

-(void) viewDidLoad
{
    DDLogInfo(@"%s",__FUNCTION__);
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"Devices", nil);
    
    self.navigationController.navigationBar.backgroundColor = [ChatUtilities utilitiesInstance].kNavigationBarColor;
    self.navigationController.navigationBar.translucent = NO;
    
    [self.view setBackgroundColor:[ChatUtilities utilitiesInstance].kChatViewBackgroundColor];
    
    _scanQueue = [NSOperationQueue new];
    [_scanQueue setMaxConcurrentOperationCount:1];
    
    _firstLoad = YES;
    _hasRemoteDevices = (_remoteRecentObject != nil);
    peerDevices = [[NSMutableArray alloc] init];
    myDevices = [[NSMutableArray alloc] init];
    
    UIRefreshControl *refreshControl = [UIRefreshControl new];
    [refreshControl setTintColor:[UIColor whiteColor]];
    [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    
    [self setRefreshControl:refreshControl];
    
    [self refresh:nil];
}

-(void) viewWillAppear:(BOOL)animated
{
    DDLogInfo(@"%s",__FUNCTION__);
    [super viewWillAppear:animated];
    
    UIButton *backButtonWithImage = [ChatUtilities getNavigationBarBackButton];
    [backButtonWithImage addTarget:self.navigationController action:@selector(popViewControllerAnimated:) forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *backBarButton = [[UIBarButtonItem alloc] initWithCustomView:backButtonWithImage];
    self.navigationItem.leftBarButtonItem = backBarButton;
    
    if(_hasRemoteDevices) {
        
        UIBarButtonItem *renewSessionButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Rekey", nil)
                                                                               style:UIBarButtonItemStylePlain
                                                                              target:self
                                                                              action:@selector(renewSession)];
        
        [self.navigationItem setRightBarButtonItem:renewSessionButton];
    }

    [self.tableView setSeparatorColor:[UIColor colorWithWhite:1. alpha:.25]];
    [self.tableView setTableFooterView:[UIView new]];
    
    [self registerNotifications];
}

-(void) viewWillDisappear:(BOOL)animated
{
    DDLogInfo(@"%s",__FUNCTION__);
    
    [self deregisterNotifications];
    
    [_scanQueue cancelAllOperations];

    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

    [super viewWillDisappear:animated];
}

#pragma mark - Accessibility

-(BOOL) accessibilityPerformEscape
{
    [self.navigationController popViewControllerAnimated:YES];
    
    return YES;
}

#pragma mark - UITableViewDelegate

-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return kSectionHeaderHeight;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    view.tintColor = [UIColor colorWithRed:38./256. green:38./256. blue:41./256. alpha:1.];
    
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    [header.textLabel setFont:[[ChatUtilities utilitiesInstance] getFontWithSize:header.textLabel.font.pointSize]];
    [header.textLabel setTextColor:[UIColor whiteColor]];
}

-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if([self shouldShowFooterForSection:section])
        return kSectionFooterHeight;
    else
        return 0;
}

-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    if([self shouldShowFooterForSection:section])
    {
        UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [ChatUtilities utilitiesInstance].screenWidth, kSectionFooterHeight)];
        [footerView setBackgroundColor:[UIColor colorWithRed:64./256. green:65./256. blue:69./256. alpha:1.]];
        
        UILabel *footerLabel = [[UILabel alloc] initWithFrame:CGRectInset(footerView.frame, 10, 0)];
        [footerLabel setLineBreakMode:NSLineBreakByWordWrapping];
        [footerLabel setNumberOfLines:0];
        [footerLabel setTextColor:[UIColor lightGrayColor]];
        [footerLabel setFont:[[ChatUtilities utilitiesInstance] getFontWithSize:14.]];
        
        if(_firstLoad)
        {
            [footerLabel setTextAlignment:NSTextAlignmentCenter];
            [footerLabel setText:NSLocalizedString(@"Loading...", nil)];
        }
        else if(_hasRemoteDevices && section == kDevicesRemoteSection)
        {
            [footerLabel setTextAlignment:NSTextAlignmentLeft];
            [footerLabel setText:NSLocalizedString(@"Note: The list may show a device more than once if the app was removed and installed again on the partner's device.", nil)];
        }
        else
        {
            [footerLabel setTextAlignment:NSTextAlignmentCenter];
            [footerLabel setText:NSLocalizedString(@"You don't have any other devices provisioned.", nil)];
        }
        
        [footerView addSubview:footerLabel];
        
        return footerView;
    }
    else
        return [[UIView alloc] initWithFrame:CGRectZero];
}

-(UITableViewCellEditingStyle) tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if([self canDeleteRowForSection:indexPath.section])
        return UITableViewCellEditingStyleDelete;
    else
        return UITableViewCellEditingStyleNone;
}

-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 180;
}

-(void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([cell respondsToSelector:@selector(setSeparatorInset:)])
    {
        [cell setSeparatorInset:UIEdgeInsetsZero];
    }
    
    if ([cell respondsToSelector:@selector(setLayoutMargins:)])
    {
        [cell setLayoutMargins:UIEdgeInsetsZero];
    }
}

- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    _isEditing = YES;
}

- (void)tableView:(UITableView *)tableView didEndEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    _isEditing = NO;
}

#pragma mark - UITableViewDataSource

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if(section == kDevicesLocalSection)
        return NSLocalizedString(@"Local messaging device", nil);
    else if(_hasRemoteDevices && section == kDevicesRemoteSection)
    {
        NSString *remoteName = [[ChatUtilities utilitiesInstance] removePeerInfo:_remoteRecentObject.displayAlias
                                                                   lowerCase:NO];
        if ([[ChatUtilities utilitiesInstance] isUUID:remoteName])
        {
            RecentObject *cachedRecent = [Switchboard.userResolver cachedRecentWithUUID:_remoteRecentObject.contactName];
            
            if (!cachedRecent)
            {
                //workaround to force resolve a RecentObject taken out of database or created after received message
                _remoteRecentObject.isPartiallyLoaded = YES;
                
                [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectShouldResolveNotification object:self userInfo:@{kSCPRecentObjectDictionaryKey:_remoteRecentObject}];
            }
        }
        
        NSString *prefix = ([remoteName isEqualToString:@""] ? NSLocalizedString(@"Remote", nil) : remoteName);
        
        NSString *fullTitle = [NSString stringWithFormat:@"%@ %@ (%lu)",
                               prefix,
                               (peerDevices.count == 1 ? NSLocalizedString(@"messaging device", nil) : NSLocalizedString(@"messaging devices", nil)),
                               (unsigned long)peerDevices.count];

        return fullTitle;
    }
    else
    {
        if(myDevices.count == 1)
            return NSLocalizedString(@"My other device (1)", nil);
        else
            return [NSString stringWithFormat:NSLocalizedString(@"My other devices (%lu)", nil), (unsigned long)myDevices.count];
    }
}

-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return (_hasRemoteDevices ? 3 : 2);
}

-(void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(![self canDeleteRowForSection:indexPath.section])
        return;
    
    NSDictionary *deviceDict = myDevices[indexPath.row];
    [myDevices removeObjectAtIndex:indexPath.row];
    
    [self.tableView beginUpdates];
    [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    NSIndexPath * headerIndexPath = [NSIndexPath indexPathForRow:NSNotFound inSection:indexPath.section];
    [self.tableView reloadRowsAtIndexPaths:@[headerIndexPath] withRowAnimation: UITableViewRowAnimationFade];
    [self.tableView endUpdates];
    
    [_scanQueue cancelAllOperations];
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];

    NSString *deviceId = [deviceDict objectForKey:@"deviceId"];
    NSString *endpoint = [NSString stringWithFormat:SCPNetworkManagerEndpointV1MeDevice, deviceId];
    
    [Switchboard.networkManager apiRequestInEndpoint:endpoint
                                              method:SCPNetworkManagerMethodDELETE
                                           arguments:nil
                                          completion:^(NSError *error, id responseObject, NSHTTPURLResponse *httpResponse) {
         
                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                  
                                                  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                                              });
                                          }];
}

-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(_firstLoad)
        return 0;
    
    if(section == kDevicesLocalSection)
        return 1;
    
    if(_hasRemoteDevices && section == kDevicesRemoteSection)
        return peerDevices.count;
    else
        return myDevices.count;
}

-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"deviceCell";
    
    DeviceCell *cell = (DeviceCell *)[self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    [cell.deviceVerified setTextColor:[UIColor greenColor]];
    [cell setBackgroundColor:[ChatUtilities utilitiesInstance].kChatViewBackgroundColor];
    [cell.callButton setHidden:NO];
    [cell.callButton setButtonIndexPath:indexPath];
    [cell.callButton addTarget:self action:@selector(callButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [cell.callButton setAccessibilityLabel:NSLocalizedString(@"Call", nil)];
    [cell setLayoutMargins:UIEdgeInsetsZero];
    
    NSDictionary *deviceData;
    
    if(indexPath.section == kDevicesLocalSection)
    {
        deviceData = localDevice;
        
        [cell.callButton setHidden:YES];
    }
    else if(_hasRemoteDevices && indexPath.section == kDevicesRemoteSection)
    {
        deviceData = peerDevices[indexPath.row];
    }
    else
    {
        deviceData = myDevices[indexPath.row];
    }
    
    NSString *fingerPrint = [deviceData objectForKey:@"fingerPrint"];
    NSString *deviceName = [deviceData objectForKey:@"deviceName"];
    NSString *deviceId = [deviceData objectForKey:@"deviceId"];
    int isVerified = [[deviceData objectForKey:@"isVerified"] intValue];
    
    cell.deviceFingerPrint.text = fingerPrint;
    cell.deviceId.text = deviceId;
    
    if([deviceName isEqualToString:@""])
    {
        [cell.deviceName setAlpha:.5];
        cell.deviceName.text = @"[No Name]";
    }
    else
    {
        
        [cell.deviceName setAlpha:1.];
        cell.deviceName.text = deviceName;
    }
    
    if(isVerified == 0)
    {
        [cell.deviceVerified setHidden:YES];
    }
    else
    {
        [cell.deviceVerified setHidden:NO];
    }
    
    return cell;
}

#pragma mark - Custom

- (void)registerNotifications {
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(devicesUpdated:)
                                                 name:kSCSUserServiceUserDidUpdateDevicesNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(recentObjectResolved:) name:kSCSRecentObjectResolvedNotification object:nil];
}

- (void)deregisterNotifications {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)devicesUpdated:(NSNotification *)notification {
    
    DDLogInfo(@"%s SCSUserServiceUserDidUpdateDevicesNotification",__FUNCTION__);

    // If there is already an operation queued
    // then we do rescanRemote, else we just reload
    // the cached zina devices
    BOOL isQueueRunning = ([_scanQueue operationCount] > 0);
    
    [_scanQueue cancelAllOperations];
    
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
    
        if(isQueueRunning)
            [self rescanRemote];
        
        dispatch_async(dispatch_get_main_queue(), ^() {
            
            _firstLoad = NO;
            
            [self reloadDevicesFromAxo];
            
            [self.tableView reloadData];
        });
    }];
    
    [_scanQueue addOperation:operation];

}

- (void)renewSession {
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Re-key messaging sessions", nil)
                                                                             message:NSLocalizedString(@"Are you sure you want to establish new keys for messaging sessions?", nil)
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *yesAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", nil)
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {

                                                        AppInterfaceImpl *app = (AppInterfaceImpl*)CTAxoInterfaceBase::sharedInstance()->getAxoAppInterface();
                                                    
                                                        std::string remoteUsername = ([[ChatUtilities utilitiesInstance] removePeerInfo:_remoteRecentObject.contactName lowerCase:NO].UTF8String);
                                                    
                                                        app->reKeyAllDevices(remoteUsername);
                                                    
                                                        // Do not let user tap the button again right away.
                                                        // User has to go back and inside this view in order to do that again.
                                                        dispatch_async(dispatch_get_main_queue(), ^{
                                                            [self.navigationItem setRightBarButtonItem:nil];
                                                        });
                                                      }];
    [alertController addAction:yesAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                           style:UIAlertActionStyleCancel
                                                      handler:nil];
    [alertController addAction:cancelAction];
    
    [self presentViewController:alertController
                       animated:YES
                     completion:nil];
}

-(BOOL) shouldShowFooterForSection:(NSInteger)section
{
    return (_firstLoad ||
            (_hasRemoteDevices && section == kDevicesRemoteSection) || // If we are on the Remote section
            (_hasRemoteDevices && section == kDevicesOtherSection && myDevices.count == 0) || // If we are on the Other section and it's empty
            (!_hasRemoteDevices && section == kDevicesRemoteSection && myDevices.count == 0));
}

-(BOOL) canDeleteRowForSection:(NSInteger)section
{
    return ( (_hasRemoteDevices && section == kDevicesOtherSection) ||  // If we are on the Other section
             (!_hasRemoteDevices && section == kDevicesRemoteSection) );// If we are on the Other section and there is no Remote section
}

-(BOOL) isMyDevicesListEmpty
{
    DDLogInfo(@"%s",__FUNCTION__);
    
    AppInterfaceImpl *app = (AppInterfaceImpl*)CTAxoInterfaceBase::sharedInstance()->getAxoAppInterface();
    string myUn = app->getOwnUser();
    shared_ptr<list<string> > listMy = app->getIdentityKeys(myUn);
    
    // If list is completely empty, return YES
    BOOL returnValue = YES;
    
    if(!listMy->empty())
    {
        // If it's not, check if it contains user devices but not the current device
        NSString *ownDeviceInfo = [NSString stringWithUTF8String:app->getOwnIdentityKey().c_str()];
        NSArray *ownDeviceInfoArray = [ownDeviceInfo componentsSeparatedByString:@":"];

        while (!listMy->empty()) {
            
            std::string resultStr = listMy->front();
            NSString *deviceString = [NSString stringWithUTF8String:resultStr.c_str()];
            NSArray *deviceInfoArray = [deviceString componentsSeparatedByString:@":"];
            
            if([(NSString *)ownDeviceInfoArray[0] isEqualToString:(NSString *)deviceInfoArray[0]])
            {
                returnValue = NO;
                break;
            }
            
            listMy->erase(listMy->begin());
        }
        
    }

    return returnValue;
}

// Must be called from a background thread
-(void) rescanFull
{
    DDLogInfo(@"%s",__FUNCTION__);
    
    [self rescanMine];
    [self rescanRemote];
}

-(void) rescanMine
{
    DDLogInfo(@"%s",__FUNCTION__);
    
    [Switchboard rescanLocalUserDevices];
}

-(void) rescanRemote
{
    DDLogInfo(@"%s",__FUNCTION__);
    
    if(!_hasRemoteDevices)
        return;

    [Switchboard rescanDevicesForUserWithUUID:_remoteRecentObject.contactName];
}

-(void)reloadDevicesFromAxo
{
    DDLogInfo(@"%s",__FUNCTION__);
    
    AppInterfaceImpl *app = (AppInterfaceImpl*)CTAxoInterfaceBase::sharedInstance()->getAxoAppInterface();
    
    NSString *ownDeviceInfo = [NSString stringWithUTF8String:app->getOwnIdentityKey().c_str()];
    NSArray *ownDeviceInfoArray = [ownDeviceInfo componentsSeparatedByString:@":"];
    
    if(ownDeviceInfoArray.count > 2) {

        localDevice = @{
                        @"deviceName": (NSString *)ownDeviceInfoArray[1],
                        @"deviceId": (NSString *)ownDeviceInfoArray[2],
                        @"isVerified": @"0",
                        @"fingerPrint": [self getFingerprintFromBase64WithString:(NSString *)ownDeviceInfoArray[0]]
                        };
    }
    
    if(_hasRemoteDevices) {
        
        [peerDevices removeAllObjects];
        string un([[ChatUtilities utilitiesInstance] removePeerInfo:_remoteRecentObject.contactName lowerCase:NO].UTF8String);
        shared_ptr<list<string> > listPeer = app->getIdentityKeys(un);
        
        while (!listPeer->empty()) {
            
            std::string resultStr = listPeer->front();
            
            NSString *deviceString = [NSString stringWithUTF8String:resultStr.c_str()];
            NSArray *deviceInfoArray = [deviceString componentsSeparatedByString:@":"];
            
            if(deviceInfoArray.count > 2) {
                
                [peerDevices addObject:@{
                                         @"deviceName": (NSString *)deviceInfoArray[1],
                                         @"deviceId": (NSString *)deviceInfoArray[2],
                                         @"isVerified": (NSString *)deviceInfoArray[3],
                                         @"fingerPrint": [self getFingerprintFromBase64WithString:(NSString *)deviceInfoArray[0]]
                                         }];
            }
            
            listPeer->erase(listPeer->begin());
        }
    }
    
    [myDevices removeAllObjects];
    
    string myUn = app->getOwnUser();
    shared_ptr<list<string> > listMy = app->getIdentityKeys(myUn);
    
    while (!listMy->empty()) {
        
        std::string resultStr = listMy->front();
        NSString *deviceString = [NSString stringWithUTF8String:resultStr.c_str()];
        NSArray *deviceInfoArray = [deviceString componentsSeparatedByString:@":"];
        
        if(![(NSString *)ownDeviceInfoArray[0] isEqualToString:(NSString *)deviceInfoArray[0]]) {
            
            NSMutableDictionary *deviceInfoDict = [[NSMutableDictionary alloc] initWithObjects:@[deviceInfoArray[1],deviceInfoArray[2],deviceInfoArray[3]] forKeys:@[@"deviceName", @"deviceId",@"isVerified"]];
            [deviceInfoDict setObject:[self getFingerprintFromBase64WithString:deviceInfoArray[0]] forKey:@"fingerPrint"];
            
            if(deviceInfoArray.count > 2) {
                [myDevices addObject:deviceInfoDict];
            }
        }
        
        listMy->erase(listMy->begin());
    }
   
}

-(NSString *) getFingerprintFromBase64WithString:(NSString *) base64String
{
    NSData *fingerPrintData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
    
    unsigned char h_result[128];// > SHA256_DIGEST_SIZE
    
    char szFingerprint[32*5];
    
    void sha256(unsigned char *data,
                unsigned int data_length,
                unsigned char *digest);
    // int binLen = hex2BinL(&bin[0], (char *)ns.UTF8String, ns.length);
    sha256((unsigned char *)fingerPrintData.bytes, (unsigned int)fingerPrintData.length, h_result);
    
    int pos = 0;
    
    for(int i=0;i<32;i++)
    {
        pos += sprintf(&szFingerprint[pos],"%02x:",h_result[i]);
        if((i%8)==7 && i != 31)pos+=sprintf(&szFingerprint[pos],"\n");
    }
    
    NSString *fingerPrintString = [NSString stringWithUTF8String:szFingerprint];
    return fingerPrintString;
}

-(void) callButtonClick:(CallButton *) sender
{
    DDLogInfo(@"%s",__FUNCTION__);
    
    if(_isEditing)
        return;
    
    NSIndexPath *indexPath = sender.buttonIndexPath;
    NSDictionary *deviceDict;
    NSString *userName;
    
    if(_hasRemoteDevices && indexPath.section == kDevicesRemoteSection)
    {
        deviceDict = peerDevices[indexPath.row];
        userName = _remoteRecentObject.contactName;
        
    }
    else
    {
        deviceDict = myDevices[indexPath.row];
        userName = [[ChatUtilities utilitiesInstance] getOwnUserName];
    
        // If the username does not contain the full sip address, append it
        // in order to be able to check afterwards if there is already a call in progress
        // with the same device id
        // @see AppDelegate.mm -callToS:dst:eng: method
        if([userName rangeOfString:@"@sip.silentcircle.net"].location == NSNotFound)
            userName = [userName stringByAppendingString:@"@sip.silentcircle.net"];
    }

    NSString *deviceId = [deviceDict objectForKey:@"deviceId"];
    NSString *callString = [NSString stringWithFormat:@"%@;xscdevid=%@",userName,deviceId];
    
    /* burger - replace delegate call with notification 
    if ([_transitionDelegate respondsToSelector:@selector(placeCallFromVC:withNumber:)])
    {
        [_transitionDelegate placeCallFromVC:self withNumber:callString];
    }
     */
    NSDictionary *userInfo = @{kSCPOutgoingCallNumber: callString}; 
    [[NSNotificationCenter defaultCenter] postNotificationName:kSCPOutgoingCallRequestNotification 
                                                        object:self 
                                                      userInfo:userInfo]; 
}

- (void)refresh:(UIRefreshControl*)refreshControl
{
    DDLogInfo(@"%s",__FUNCTION__);

    [_scanQueue cancelAllOperations];
    
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        
        [self rescanFull];

        dispatch_async(dispatch_get_main_queue(), ^() {

            _firstLoad = NO;
        
            [self reloadDevicesFromAxo];

            if(refreshControl)
                [refreshControl endRefreshing];
            
            [self.tableView reloadData];
        });
    }];
    
    [_scanQueue addOperation:operation];
}

- (void)recentObjectResolved:(NSNotification *)notification
{
    DDLogDebug(@"%s",__FUNCTION__);
    __block RecentObject *updatedRecent = (RecentObject *)[notification.userInfo objectForKey:kSCPRecentObjectDictionaryKey];
    
    if (!updatedRecent || !_remoteRecentObject)
        return;
    if (![updatedRecent isEqual:_remoteRecentObject])
        return;
    
    __weak DevicesViewController *weakSelf = self;
    NSBlockOperation *reloadOperation = [NSBlockOperation blockOperationWithBlock:^{
                
        dispatch_async(dispatch_get_main_queue(), ^() {
            
            __strong DevicesViewController *strongSelf = weakSelf;
            [strongSelf.tableView reloadData];
        });
    }];
    
    [_scanQueue addOperation:reloadOperation];
}

@end
