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
#import "DevicesViewController.h"
#import "Utilities.h"
#import "DevicesTableHeaderView.h"
#import "DeviceCell.h"
#import "axolotl_glue.h"
#include "interfaceApp/AppInterfaceImpl.h"
#import "CallButton.h"

#define kSectionHeaderHeight 44.
#define kSectionFooterHeight 80.
#define kBackButtonSize 30.

#define kDevicesLocalSection 0
#define kDevicesRemoteSection 1
#define kDevicesOtherSection 2

using namespace axolotl;

@interface DevicesViewController () <UITableViewDataSource, UITableViewDelegate>
{
    NSMutableArray *peerDevices;
    NSMutableArray *myDevices;
    NSDictionary *localDevice;
    
    BOOL _hasRemoteDevices;
}
@end

@implementation DevicesViewController

#pragma mark - View Lifecycle

-(void) viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    [[Utilities utilitiesInstance] setTabBarHidden:YES];
    
    _hasRemoteDevices = ([Utilities utilitiesInstance].selectedRecentObject != nil);
    
    peerDevices = [[NSMutableArray alloc] init];
    myDevices = [[NSMutableArray alloc] init];
    
    UIButton *backButtonWithImage = [UIButton buttonWithType:UIButtonTypeCustom];
    [backButtonWithImage setFrame:CGRectMake(0,0,kBackButtonSize,kBackButtonSize)];
    [backButtonWithImage setUserInteractionEnabled:YES];
    [backButtonWithImage setImage:[UIImage imageNamed:@"BackButton.png"] forState:UIControlStateNormal];
    [backButtonWithImage addTarget:self.navigationController action:@selector(popViewControllerAnimated:) forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *backBarButton = [[UIBarButtonItem alloc] initWithCustomView:backButtonWithImage];
    self.navigationItem.leftBarButtonItem = backBarButton;
    
    [self.tableView setSeparatorColor:[UIColor colorWithWhite:1. alpha:.25]];
    [self.tableView setTableFooterView:[UIView new]];

    // If the list of user devices is empty, then do a full rescan
    if([self isMyDevicesListEmpty]) {
        
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            [self rescanFull];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                
                [self reloadDevicesFromAxo];
                [_tableView reloadData];
            });
        });
        
    } else {

        [self reloadDevicesFromAxo];
        [_tableView reloadData];
    }
}

-(void) viewDidLayoutSubviews {
    
    [super viewDidLayoutSubviews];
    
    if ([self.tableView respondsToSelector:@selector(setSeparatorInset:)]) {
        [self.tableView setSeparatorInset:UIEdgeInsetsZero];
    }
    
    if ([self.tableView respondsToSelector:@selector(setLayoutMargins:)]) {
        [self.tableView setLayoutMargins:UIEdgeInsetsZero];
    }
}

-(void) viewDidLoad {
    
    [super viewDidLoad];
    
    self.title = @"Devices";
    
    self.navigationController.navigationBar.backgroundColor = [Utilities utilitiesInstance].kNavigationBarColor;
    self.navigationController.navigationBar.translucent = NO;

    //UIView *darkTopView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [Utilities utilitiesInstance].screenWidth, [Utilities utilitiesInstance].kStatusBarHeight)];
    //[darkTopView setBackgroundColor:[Utilities utilitiesInstance].kStatusBarColor];
    //[self.view addSubview:darkTopView];
    
    [self.view setBackgroundColor:[Utilities utilitiesInstance].kChatViewBackgroundColor];
}

#pragma mark - UITableViewDelegate

-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    
    return kSectionHeaderHeight;
}

- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    
    DevicesTableHeaderView *headerView = [[DevicesTableHeaderView alloc] initWithFrame:CGRectMake(0, 0, [Utilities utilitiesInstance].screenWidth, kSectionHeaderHeight)];
    
    if(section == kDevicesLocalSection) {
        
        [headerView.title setText:@"Local messaging device"];
    }
    else if(_hasRemoteDevices && section == kDevicesRemoteSection) {
        
        if(peerDevices.count == 1)
            [headerView.title setText:@"Remote messaging device (1)"];
        else
            [headerView.title setText:[NSString stringWithFormat:@"Remote messaging devices (%lu)", (unsigned long)peerDevices.count]];
    }
    else {
        
        if(myDevices.count == 1)
            [headerView.title setText:@"My other device (1)"];
        else
            [headerView.title setText:[NSString stringWithFormat:@"My other devices (%lu)", (unsigned long)myDevices.count]];
    }

    if(section == kDevicesLocalSection) {
        
        [headerView.rescanButton setHidden:YES];
        
    } else {
        [headerView.rescanButton addTarget:self action:@selector(rescanButtonClick:) forControlEvents:UIControlEventTouchUpInside];
        [headerView.rescanButton setTag:section];
    }
    
    return headerView;
}

-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    
    if((_hasRemoteDevices && section == kDevicesRemoteSection) || // If we are on the Remote section
       (_hasRemoteDevices && section == kDevicesOtherSection && myDevices.count == 0) || // If we are on the Other section and it's empty
       (!_hasRemoteDevices && section == kDevicesRemoteSection && myDevices.count == 0)) // If we are on the Other section and it's empty and there is no Remote section
        return kSectionFooterHeight;
    else
        return 0;
}

-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    
    if((_hasRemoteDevices && section == kDevicesRemoteSection) || // If we are on the Remote section
       (_hasRemoteDevices && section == kDevicesOtherSection && myDevices.count == 0) || // If we are on the Other section and it's empty
       (!_hasRemoteDevices && section == kDevicesRemoteSection && myDevices.count == 0)) // If we are on the Other section and it's empty and there is no Remote section
    {
        UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [Utilities utilitiesInstance].screenWidth, kSectionFooterHeight)];
        [footerView setBackgroundColor:[UIColor colorWithRed:64./256. green:65./256. blue:69./256. alpha:1.]];
        
        UILabel *footerLabel = [[UILabel alloc] initWithFrame:CGRectInset(footerView.frame, 10, 0)];
        [footerLabel setLineBreakMode:NSLineBreakByWordWrapping];
        [footerLabel setNumberOfLines:0];
        [footerLabel setTextColor:[UIColor lightGrayColor]];
        [footerLabel setFont:[[Utilities utilitiesInstance] getFontWithSize:14.]];
        
        if(_hasRemoteDevices && section == kDevicesRemoteSection)
        {
            [footerLabel setTextAlignment:NSTextAlignmentLeft];
            [footerLabel setText:@"Note: The list may show a device more than once if the app was removed and installed again on the partner's device."];
        }
        else
        {
            [footerLabel setTextAlignment:NSTextAlignmentCenter];
            [footerLabel setText:@"You don't have any other devices provisioned."];
        }
        
        [footerView addSubview:footerLabel];
        
        return footerView;
    }
    else
        return nil;
}

-(UITableViewCellEditingStyle) tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if((_hasRemoteDevices && indexPath.section == kDevicesOtherSection) ||  // If we are on the Other section
       (!_hasRemoteDevices && indexPath.section == kDevicesRemoteSection) ) // If we are on the Other section and there is no Remote section
        return UITableViewCellEditingStyleDelete;
    else
        return UITableViewCellEditingStyleNone;
}

-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    return 180;
}

-(void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
        [cell setSeparatorInset:UIEdgeInsetsZero];
    }
    
    if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
        [cell setLayoutMargins:UIEdgeInsetsZero];
    }
}

#pragma mark - UITableViewDataSource

-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    
    return (_hasRemoteDevices ? 3 : 2);
}

-(void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if((_hasRemoteDevices && indexPath.section == kDevicesOtherSection) ||  // If we are on the Other section
       (!_hasRemoteDevices && indexPath.section == kDevicesRemoteSection) ) // If we are on the Other section and there is no Remote section
    {
        NSDictionary *deviceDict = myDevices[indexPath.row];
        [myDevices removeObjectAtIndex:indexPath.row];
        
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            AppInterfaceImpl *app = (AppInterfaceImpl*)CTAxoInterfaceBase::sharedInstance()->getAxoAppInterface();
            
            string deviceId = ((NSString *)[deviceDict objectForKey:@"deviceId"]).UTF8String;
            string result;
            app->removeAxolotlDevice(deviceId,  &result);
            puts(result.c_str());
            
            [self rescanMine];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                
                [_tableView beginUpdates];
                [_tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                NSIndexPath * headerIndexPath = [NSIndexPath indexPathForRow:NSNotFound inSection:indexPath.section];
                [self.tableView reloadRowsAtIndexPaths:@[headerIndexPath] withRowAnimation: UITableViewRowAnimationFade];
                [_tableView endUpdates];
            });
        });
    }
}

-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    if(section == kDevicesLocalSection)
        return 1;
    if(_hasRemoteDevices && section == kDevicesRemoteSection)
        return peerDevices.count;
    else
        return myDevices.count;
}

-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"deviceCell";
    
    DeviceCell *cell = (DeviceCell *)[_tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    [cell.deviceVerified setTextColor:[UIColor greenColor]];
    [cell.callButton setHidden:NO];
    [cell.callButton setButtonIndexPath:indexPath];
    [cell.callButton addTarget:self action:@selector(callButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [cell setLayoutMargins:UIEdgeInsetsZero];
    
    NSDictionary *deviceData;
    
    if(indexPath.section == kDevicesLocalSection) {
        
        deviceData = localDevice;
        
        [cell.callButton setHidden:YES];
        
    } else if(_hasRemoteDevices && indexPath.section == kDevicesRemoteSection) {

        deviceData = peerDevices[indexPath.row];
        
    } else {
        
        deviceData = myDevices[indexPath.row];
    }
    
    NSString *fingerPrint = [deviceData objectForKey:@"fingerPrint"];
    NSString *deviceName = [deviceData objectForKey:@"deviceName"];
    NSString *deviceId = [deviceData objectForKey:@"deviceId"];
    int isVerified = [[deviceData objectForKey:@"isVerified"] intValue];
    
    cell.deviceFingerPrint.text = fingerPrint;
    cell.deviceId.text = deviceId;
    
    if([deviceName isEqualToString:@""]) {
        
        [cell.deviceName setAlpha:.5];
        cell.deviceName.text = @"[No Name]";
        
    } else {
        
        [cell.deviceName setAlpha:1.];
        cell.deviceName.text = deviceName;
    }
    
    if(isVerified == 0) {
        
        [cell.deviceVerified setHidden:YES];
        
    } else {
        
        [cell.deviceVerified setHidden:NO];
    }
    
    return cell;
}

#pragma mark - Custom

-(BOOL) isMyDevicesListEmpty {
    
    AppInterfaceImpl *app = (AppInterfaceImpl*)CTAxoInterfaceBase::sharedInstance()->getAxoAppInterface();
    string myUn = app->getOwnUser();
    list<string>* listMy = app->getIdentityKeys(myUn);
    
    // If list is completely empty, return YES
    BOOL returnValue = YES;
    
    if(!listMy->empty()) {
        
        // If it's not, check if it contains user devices but not the current device
        string ownKey = app->getOwnIdentityKey();

        while (!listMy->empty()) {
            
            std::string resultStr = listMy->front();
            NSString *deviceString = [NSString stringWithFormat:@"%s",resultStr.c_str()];
            NSArray *deviceInfoArray = [deviceString componentsSeparatedByString:@":"];
            
            if(ownKey == ((NSString *)deviceInfoArray[0]).UTF8String)
            {
                returnValue = NO;
                break;
            }
            
            listMy->erase(listMy->begin());
        }
        
    }
    
    delete listMy;

    return returnValue;
}

// Must be called from a background thread
-(void) rescanFull {
    
    [self rescanMine];
    [self rescanRemote];
}

// Must be called from a background thread
-(void) rescanMine {
    
    AppInterfaceImpl *app = (AppInterfaceImpl*)CTAxoInterfaceBase::sharedInstance()->getAxoAppInterface();
    
    string username = app->getOwnUser();
    app->rescanUserDevices(username);
}

// Must be called from a background thread
-(void) rescanRemote {
    
    if(!_hasRemoteDevices)
        return;
    
    AppInterfaceImpl *app = (AppInterfaceImpl*)CTAxoInterfaceBase::sharedInstance()->getAxoAppInterface();
    
    string remoteUsername = ([[Utilities utilitiesInstance] removePeerInfo:[Utilities utilitiesInstance].selectedRecentObject.contactName lowerCase:NO].UTF8String);
    app->rescanUserDevices(remoteUsername);
}

-(void)reloadDevicesFromAxo {
    
    AppInterfaceImpl *app = (AppInterfaceImpl*)CTAxoInterfaceBase::sharedInstance()->getAxoAppInterface();
    string ownKey = app->getOwnIdentityKey();
    
    string myUn = app->getOwnUser();
    list<string>* listMy = app->getIdentityKeys(myUn);
    
    if(_hasRemoteDevices) {
        
        [peerDevices removeAllObjects];
        string un([[Utilities utilitiesInstance] removePeerInfo:[Utilities utilitiesInstance].selectedRecentObject.contactName lowerCase:NO].UTF8String);
        list<string>* listPeer = app->getIdentityKeys(un);
        
        while (!listPeer->empty()) {
            std::string resultStr = listPeer->front();
            NSString *deviceString = [NSString stringWithFormat:@"%s",resultStr.c_str()];
            NSArray *deviceInfoArray = [deviceString componentsSeparatedByString:@":"];

            NSMutableDictionary *deviceInfoDict = [[NSMutableDictionary alloc] initWithObjects:@[deviceInfoArray[1],deviceInfoArray[2],deviceInfoArray[3]] forKeys:@[@"deviceName", @"deviceId",@"isVerified"]];
            [deviceInfoDict setValue:[DevicesViewController getFingerprintFromBase64WithString:deviceInfoArray[0]] forKey:@"fingerPrint"];
            
            if(deviceInfoArray.count > 2) {
                [peerDevices addObject:deviceInfoDict];
            }
            
            listPeer->erase(listPeer->begin());
        }
        delete listPeer;
    }
    
    [myDevices removeAllObjects];
    
    while (!listMy->empty()) {
        
        std::string resultStr = listMy->front();
        NSString *deviceString = [NSString stringWithFormat:@"%s",resultStr.c_str()];
        NSArray *deviceInfoArray = [deviceString componentsSeparatedByString:@":"];

        if(ownKey != ((NSString *)deviceInfoArray[0]).UTF8String) {
            
            NSMutableDictionary *deviceInfoDict = [[NSMutableDictionary alloc] initWithObjects:@[deviceInfoArray[1],deviceInfoArray[2],deviceInfoArray[3]] forKeys:@[@"deviceName", @"deviceId",@"isVerified"]];
            [deviceInfoDict setValue:[DevicesViewController getFingerprintFromBase64WithString:deviceInfoArray[0]] forKey:@"fingerPrint"];
            
            if(deviceInfoArray.count > 2) {
                [myDevices addObject:deviceInfoDict];
            }
        }
        else {
            
            localDevice = @{
                            @"deviceName": deviceInfoArray[1],
                            @"deviceId": deviceInfoArray[2],
                            @"isVerified": deviceInfoArray[3],
                            @"fingerPrint": [DevicesViewController getFingerprintFromBase64WithString:deviceInfoArray[0]]
                            };
        }
        
        listMy->erase(listMy->begin());
    }
    
    delete listMy;
    
    //NSLog(@"%@",peerDevices);
    //NSLog(@"%@",myDevices);
}

+(NSString *) getFingerprintFromBase64WithString:(NSString *) base64String {
    
    NSData *fingerPrintData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
    
    unsigned char h_result[128];// > SHA256_DIGEST_SIZE
    
    char szFingerprint[32*5];
    
    void sha256(unsigned char *data,
                unsigned int data_length,
                unsigned char *digest);
    // int binLen = hex2BinL(&bin[0], (char *)ns.UTF8String, ns.length);
    sha256((unsigned char *)fingerPrintData.bytes, (unsigned int)fingerPrintData.length, h_result);
    
    int pos = 0;
    for(int i=0;i<32;i++){
        pos += sprintf(&szFingerprint[pos],"%02x:",h_result[i]);
        if((i%8)==7 && i != 31)pos+=sprintf(&szFingerprint[pos],"\n");
    }
    
    NSString *fingerPrintString = [NSString stringWithUTF8String:szFingerprint];
    return fingerPrintString;
}

-(void) callButtonClick:(CallButton *) sender {
    
    NSIndexPath *indexPath = sender.buttonIndexPath;
    NSDictionary *deviceDict;
    NSString *userName;
    
    if(_hasRemoteDevices && indexPath.section == kDevicesRemoteSection) {
        
        deviceDict = peerDevices[indexPath.row];
        userName = [Utilities utilitiesInstance].selectedRecentObject.contactName;
        
    } else {
        
        deviceDict = myDevices[indexPath.row];
        userName = [[Utilities utilitiesInstance] getOwnUserName];
    }
    
    NSString *deviceId = [deviceDict objectForKey:@"deviceId"];
    NSString *callString = [NSString stringWithFormat:@"%@;xscdevid=%@",userName,deviceId];
    void callToApp(const char *dst);
    callToApp(callString.UTF8String);
}

/*
 * rescans devices in corresponding section
 * uses Callbutton class to pass indexpath
 */
-(void) rescanButtonClick:(UIButton *) button {
    
    [button setHidden:YES];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        if(_hasRemoteDevices && button.tag == kDevicesRemoteSection)
            [self rescanRemote];
        else
            [self rescanMine];

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
            
            [self reloadDevicesFromAxo];
            [button setHidden:NO];
            [button setNeedsDisplay];
            NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:button.tag];
            [_tableView reloadSections:indexSet withRowAnimation:UITableViewRowAnimationFade];
        });
    });
}

@end
