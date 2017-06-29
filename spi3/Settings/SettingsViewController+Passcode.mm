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
#import "SettingsViewController+Passcode.h"
#import "SCPSettingsManager.h"
#import "SettingsCell.h"
#import "SCPCallbackInterface.h"
#import "SCPNotificationKeys.h"
#import "SCPPasscodeManager.h"
#import "MWSPinLockScreenVC.h"
#import <objc/runtime.h>


@implementation SettingsViewController (Passcode)

@dynamic savedPasscode;
- (void)setSavedPasscode:(NSString *)passcode
{
	objc_setAssociatedObject(self, @selector(savedPasscode), passcode, OBJC_ASSOCIATION_COPY);
}

- (NSString *)savedPasscode
{
	return objc_getAssociatedObject(self, @selector(savedPasscode));
}

@dynamic passcodeState;
- (void)setPasscodeState:(scsPasscodeScreenState)state
{
	objc_setAssociatedObject(self, @selector(passcodeState), [NSNumber numberWithInt:state], OBJC_ASSOCIATION_COPY);
}

- (scsPasscodeScreenState)passcodeState
{
	return (scsPasscodeScreenState)[objc_getAssociatedObject(self, @selector(passcodeState)) intValue];
}

@dynamic activeLockScreenVC;
- (void)setActiveLockScreenVC:(MWSPinLockScreenVC *)activeLockScreenVC
{
	objc_setAssociatedObject(self, @selector(activeLockScreenVC), activeLockScreenVC, OBJC_ASSOCIATION_ASSIGN);
}

- (NSString *)activeLockScreenVC
{
	return objc_getAssociatedObject(self, @selector(activeLockScreenVC));
}

- (void)reloadPasscodeList {
    BOOL bExists = [[SCPPasscodeManager sharedManager] doesPasscodeExist];
	
	SCSettingsItem *setting = [[SCPSettingsManager shared] settingForKey:@"iUsePasscode"];
	if (setting)
		setting.label = (bExists) ? NSLocalizedString(@"Turn Passcode Off", nil) : NSLocalizedString(@"Turn Passcode On", nil);

	setting = [[SCPSettingsManager shared] settingForKey:@"iChangePasscode"];
	if (setting)
		[setting setHidden:!bExists];
	
	setting = [[SCPSettingsManager shared] settingForKey:@"iPasscodeEnableTouchID"];
	if (setting)
		[setting setHidden:!bExists];
	
	setting = [[SCPSettingsManager shared] settingForKey:@"szPasscodeTimeout"];
	if (setting)
		[setting setHidden:!bExists];
	
	setting = [[SCPSettingsManager shared] settingForKey:@"iPasscodeEnableWipe"];
	if (setting) {
		[setting setHidden:!bExists];
		setting.value = [[SCPPasscodeManager sharedManager] isWipeEnabled] ? @YES : @NO;
	}
	
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)registerPasscodeNotifications {
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(showNewPasscode)
												 name:kSCSPasscodeShouldShowNewPasscode
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(showEditPasscode)
												 name:kSCSPasscodeShouldShowEditPasscode
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(removePasscode)
												 name:kSCSPasscodeShouldRemovePasscode
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(toggleWipe:)
												 name:kSCSPasscodeShouldEnableWipe
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(toggleWipe:)
												 name:kSCSPasscodeShouldDisableWipe
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(passcodeManagerDidUnlock)
												 name:kSCSPasscodeDidUnlock
											   object:nil];
}

- (void)unregisterPasscodeNotifications {
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:kSCSPasscodeShouldShowNewPasscode
												  object:nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:kSCSPasscodeShouldShowEditPasscode
												  object:nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:kSCSPasscodeShouldRemovePasscode
												  object:nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:kSCSPasscodeShouldEnableWipe
												  object:nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:kSCSPasscodeShouldDisableWipe
												  object:nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:kSCSPasscodeDidUnlock
												  object:nil];
}

#pragma mark - Passcode Notifications

- (void)passcodeManagerDidUnlock {
    if (self.activeLockScreenVC)
        [self.activeLockScreenVC updateLockScreenStatus];
}

- (void)showEditPasscode {
    
    SCPPasscodeManager *passcodeManager = [SCPPasscodeManager sharedManager];
    self.passcodeState = ePasscodeScreenStateEditing;
    
    NSString *oldPasscodeTitle = NSLocalizedString(@"Enter your old passcode", nil);
    NSString *newPasscodeTitle = NSLocalizedString(@"Enter a new passcode", nil);
    
    MWSPinLockScreenVC *lockScreen = [[MWSPinLockScreenVC alloc] initWithLabelTitle:oldPasscodeTitle
                                                                         completion:^(MWSPinLockScreenVC *pinLockScreenVC, NSString *passcode) {
                                                                             
                                                                             if(self.passcodeState == ePasscodeScreenStateEditing) {
                                                                                 
                                                                                 if([passcodeManager evaluatePasscode:passcode error:nil]) {
                                                                                     
                                                                                     self.passcodeState = ePasscodeScreenNewPasscode;
                                                                                 
                                                                                     [pinLockScreenVC setLabelTitle:newPasscodeTitle
                                                                                                          clearDots:YES];
                                                                                 }
                                                                                 else {
                                                                                     
                                                                                     self.passcodeState = ePasscodeScreenStateEditing;
                                                                                     
                                                                                     [pinLockScreenVC setUserInteractionEnabled:![passcodeManager isPasscodeLocked]];
                                                                                     [pinLockScreenVC animateInvalidEntryResponseWithText:nil
                                                                                                                               completion:^{ [pinLockScreenVC updateLockScreenStatus]; }];
                                                                                 }
                                                                             }
                                                                             // We do not allow user to enter the same new passcode as the old one
                                                                             else if(self.passcodeState == ePasscodeScreenNewPasscode &&
                                                                                     [passcodeManager evaluatePasscode:passcode calculateFailedAttempts:NO error:nil]) {
                                                                                 
                                                                                 self.passcodeState = ePasscodeScreenNewPasscode;
                                                                                 
                                                                                 [pinLockScreenVC animateInvalidEntryResponseWithText:NSLocalizedString(@"Enter a different passcode", nil)
                                                                                                                           completion:^{
                                                                                     
                                                                                     [pinLockScreenVC setLabelTitle:newPasscodeTitle
                                                                                                          clearDots:YES];
                                                                                 }];
                                                                             }
                                                                             else
                                                                                 [self newPasscodeLogic:pinLockScreenVC
                                                                                             firstLabel:newPasscodeTitle
                                                                                               passcode:passcode];
                                                                         }];
    lockScreen.delegate                 = self;
    lockScreen.passcodeManager          = passcodeManager;
    lockScreen.modalPresentationStyle   = UIModalPresentationOverFullScreen;
    lockScreen.modalTransitionStyle     = UIModalTransitionStyleCrossDissolve;
    
    self.activeLockScreenVC = lockScreen;

    [self presentViewController:lockScreen
                       animated:YES
                     completion:^{
                         [lockScreen updateLockScreenStatus];
                     }];
}

- (void)showNewPasscode {
    
    BOOL hasPasscode = [[SCPPasscodeManager sharedManager] doesPasscodeExist];
    
    if(hasPasscode) {
        
        [self showEditPasscode];
        return;
    }
    
    self.passcodeState = ePasscodeScreenNewPasscode;
    
    NSString *enterPasscodeTitle = NSLocalizedString(@"Enter a passcode", nil);
    
    MWSPinLockScreenVC *lockScreen = [[MWSPinLockScreenVC alloc] initWithLabelTitle:enterPasscodeTitle
                                                                         completion:^(MWSPinLockScreenVC *pinLockScreenVC, NSString *passcode) {
                                                                             [self newPasscodeLogic:pinLockScreenVC
                                                                                         firstLabel:enterPasscodeTitle
                                                                                           passcode:passcode];
                                                                         }];
    lockScreen.delegate                 = self;
    lockScreen.modalPresentationStyle   = UIModalPresentationOverFullScreen;
    lockScreen.modalTransitionStyle     = UIModalTransitionStyleCrossDissolve;

    [self presentViewController:lockScreen
                       animated:YES
                     completion:nil];
}

- (void)newPasscodeLogic:(MWSPinLockScreenVC *)pinLockScreenVC firstLabel:(NSString *)firstLabel passcode:(NSString *)passcode {
 
    if(self.passcodeState == ePasscodeScreenNewPasscode) {
        
		self.savedPasscode = passcode;
        self.passcodeState = ePasscodeScreenVerifyPasscode;
        
        [pinLockScreenVC setLabelTitle:NSLocalizedString(@"Verify your new passcode", nil)
                             clearDots:YES];
    }
    else if(self.passcodeState == ePasscodeScreenVerifyPasscode) {
        
        if([passcode isEqualToString:self.savedPasscode]) {
            
            [[SCPPasscodeManager sharedManager] setPasscode:passcode];
            
            [pinLockScreenVC dismissViewControllerAnimated:YES completion:^{
                self.activeLockScreenVC = nil;
                [self reloadPasscodeList];
            }];
        }
        else {
            
            self.passcodeState = ePasscodeScreenNewPasscode;
            
            [pinLockScreenVC animateInvalidEntryResponseWithText:NSLocalizedString(@"Passcodes did not match", nil)
                                                      completion:^{
                                                          
                [pinLockScreenVC setLabelTitle:firstLabel
                                     clearDots:YES];
            }];
        }
		self.savedPasscode = nil;
    }
}

- (void)toggleWipe:(NSNotification *)notification {
    
    BOOL shouldEnable = [notification.name isEqualToString:kSCSPasscodeShouldEnableWipe];
    
    SCPPasscodeManager *passcodeManager = [SCPPasscodeManager sharedManager];
    
    NSString *enterPasscodeTitle = NSLocalizedString(@"Enter passcode", nil);
    
    MWSPinLockScreenVC *lockScreen = [[MWSPinLockScreenVC alloc] initWithLabelTitle:enterPasscodeTitle
                                                                         completion:^(MWSPinLockScreenVC *pinLockScreenVC, NSString *passcode) {
                                                                             
                                                                             if([passcodeManager evaluatePasscode:passcode error:nil]) {
                                                                                 
                                                                                 if(shouldEnable)
                                                                                     [Switchboard doCmd:@"set cfg.iPasscodeEnableWipe=1"];
                                                                                 else
                                                                                     [Switchboard doCmd:@"set cfg.iPasscodeEnableWipe=0"];
                                                                                 
                                                                                 [Switchboard doCmd:@":s"];

                                                                                 [pinLockScreenVC dismissViewControllerAnimated:YES completion:^{
                                                                                     
                                                                                     self.activeLockScreenVC = nil;
                                                                                     
                                                                                     [self reloadPasscodeList];
                                                                                 }];
                                                                             }
                                                                             else {
                                                                                 [pinLockScreenVC setUserInteractionEnabled:![passcodeManager isPasscodeLocked]];
                                                                                 [pinLockScreenVC animateInvalidEntryResponseWithText:nil
                                                                                                                           completion:^{ [pinLockScreenVC updateLockScreenStatus]; }];
                                                                             }
                                                                         }];
    lockScreen.delegate                 = self;
    lockScreen.passcodeManager          = passcodeManager;
    lockScreen.modalPresentationStyle   = UIModalPresentationOverFullScreen;
    lockScreen.modalTransitionStyle     = UIModalTransitionStyleCrossDissolve;
    
    self.activeLockScreenVC = lockScreen;
    
    [self presentViewController:lockScreen
                       animated:YES
                     completion:^{ [lockScreen updateLockScreenStatus]; }];
}

- (void)removePasscode {
    
    SCPPasscodeManager *passcodeManager = [SCPPasscodeManager sharedManager];
    
    NSString *enterPasscodeTitle = NSLocalizedString(@"Enter passcode", nil);

    MWSPinLockScreenVC *lockScreen = [[MWSPinLockScreenVC alloc] initWithLabelTitle:enterPasscodeTitle
                                                                         completion:^(MWSPinLockScreenVC *pinLockScreenVC, NSString *passcode) {
        
                                                                             if([passcodeManager evaluatePasscode:passcode error:nil]) {
                                                                                 
                                                                                 BOOL passcodeDeleted = [passcodeManager deletePasscode];
                                                                                 
                                                                                 [pinLockScreenVC dismissViewControllerAnimated:YES completion:^{
                                                                                     
                                                                                     self.activeLockScreenVC = nil;
                                                                                     
                                                                                     if(passcodeDeleted)
                                                                                         [self reloadPasscodeList];
                                                                                     else
                                                                                         [self showError:NSLocalizedString(@"Error", nil)
                                                                                         andErrorMessage:NSLocalizedString(@"Error while removing passcode. Try again.", nil)];
                                                                                 }];
                                                                             }
                                                                             else {
                                                                                 [pinLockScreenVC setUserInteractionEnabled:![passcodeManager isPasscodeLocked]];
                                                                                 [pinLockScreenVC animateInvalidEntryResponseWithText:nil
                                                                                                                           completion:^{ [pinLockScreenVC updateLockScreenStatus]; }];
                                                                             }
                                                                         }];
    lockScreen.delegate                 = self;
    lockScreen.passcodeManager          = passcodeManager;
    lockScreen.modalPresentationStyle   = UIModalPresentationOverFullScreen;
    lockScreen.modalTransitionStyle     = UIModalTransitionStyleCrossDissolve;

    self.activeLockScreenVC = lockScreen;
    
    [self presentViewController:lockScreen
                       animated:YES
                     completion:^{
                         [lockScreen updateLockScreenStatus];
                     }];
}

#pragma mark - MWSPinLockScreenDelegate

- (void)lockScreenSelectedCancel:(MWSPinLockScreenVC *)pinLockScreenVC {
    
    [pinLockScreenVC dismissViewControllerAnimated:YES completion:^{
        
        self.activeLockScreenVC = nil;

        [self reloadPasscodeList];
    }];
}

@end

BOOL passcodeChanged(SCSettingsItem *setting) {//(void *pSelf, void *pRetCB) {
	SCPPasscodeManager *passcodeManager = [SCPPasscodeManager sharedManager];
	if([passcodeManager doesPasscodeExist])
		[[NSNotificationCenter defaultCenter] postNotificationName:kSCSPasscodeShouldRemovePasscode
															object:[SCPSettingsManager shared]];
	else
		[[NSNotificationCenter defaultCenter] postNotificationName:kSCSPasscodeShouldShowNewPasscode
															object:[SCPSettingsManager shared]];
	
	return YES;
}

BOOL passcodeWipeChanged(SCSettingsItem *setting) {//(void *pSelf, void *pRetCB) {
	//    CTSettingsItem *it=(CTSettingsItem*)pSelf;
	//    BOOL shouldEnableWipe = [it->sc.value isEqualToString:@"1"];
	//    it->sc.value = (shouldEnableWipe  ? @"0" : @"1");
	BOOL shouldEnableWipe = [setting boolValue];
	setting.value = (shouldEnableWipe) ? @NO : @YES;
	[[NSNotificationCenter defaultCenter] postNotificationName:(shouldEnableWipe ? kSCSPasscodeShouldEnableWipe : kSCSPasscodeShouldDisableWipe)
														object:[SCPSettingsManager shared]];
	return YES;
}

BOOL passcodeEdited(SCSettingsItem *setting) {//(void *pSelf, void *pRetCB) {
	setting.value = @NO;
	//    CTSettingsItem *it=(CTSettingsItem*)pSelf;
	//    it->sc.value = @"0";
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kSCSPasscodeShouldShowEditPasscode
														object:[SCPSettingsManager shared]];
	
	return YES;
}
