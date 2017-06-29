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
#import "SettingsViewController+LockAlert.h"
#import "SCPSettingsManager.h"
#import <objc/runtime.h>

@implementation SettingsViewController (LockAlert)

@dynamic passwordAlertState;
- (void)setPasswordAlertState:(int)passwordAlertState
{
	objc_setAssociatedObject(self, @selector(passwordAlertState), [NSNumber numberWithInt:passwordAlertState], OBJC_ASSOCIATION_COPY);
}

- (int)passwordAlertState
{
	return [objc_getAssociatedObject(self, @selector(passwordAlertState)) intValue];
}

@dynamic enteredPassword;
- (void)setEnteredPassword:(NSString *)enteredPassword
{
	objc_setAssociatedObject(self, @selector(enteredPassword), enteredPassword, OBJC_ASSOCIATION_COPY);
}

- (NSString *)enteredPassword
{
	return objc_getAssociatedObject(self, @selector(enteredPassword));
}

@dynamic lockKeySwitch;
- (void)setLockKeySwitch:(UISwitch *)lockKeySwitch
{
	objc_setAssociatedObject(self, @selector(lockKeySwitch), lockKeySwitch, OBJC_ASSOCIATION_ASSIGN);
}

- (NSString *)lockKeySwitch
{
	return objc_getAssociatedObject(self, @selector(lockKeySwitch));
}


BOOL onSetPassLock(SCSettingsItem *setting) {
/* EA: TODO: this has not been finished or made to work again. I'm not going to worry about it since we don't use this code any longer.
 
	self.lockKeySwitch = sw;
	if(sw.isOn)
	{
		[self setPassWordWithAlertText:NSLocalizedString(@"Set Passcode", nil) andTag:sw.tag];
	}
	else // open password editing
	{
		[sw setOn:YES animated:YES];
		passwordAlertState = pDoneSetting;
		[self presentLockedAlertViewWithTag:sw.tag];
	}
 */
	return NO;
}

-(void) presentLockedAlertViewWithTag:(long)tag
{
	NSDictionary * delayInfo = [[NSUserDefaults standardUserDefaults] objectForKey:@"lockTimeDict"];
	NSNumber *delayTime = [delayInfo objectForKey:@"lockDelayTime"];
	NSString *delayString;
	switch ([delayTime intValue]) {
		case 5:
			delayString = @"5 Seconds";
			break;
		case 15:
			delayString = @"15 Seconds";
			break;
		case 60:
			delayString = @"1 Minute";
			break;
		case 60 * 15:
			delayString = @"15 Minutes";
			break;
		case 60 * 60:
			delayString = @"1 Hour";
			break;
		case 60 * 60 * 4:
			delayString = @"4 Hours";
			break;
		default:
			delayString = @"4 Hours";
			break;
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Passcode", nil)
														message:NSLocalizedString(@"Enter Passcode", nil)
													   delegate:self
											  cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
											  otherButtonTitles:NSLocalizedString(@"Turn Off", nil),NSLocalizedString(@"Change Passcode", nil),[NSString stringWithFormat:NSLocalizedString(@" Change Delay (%@)", nil),delayString], nil];
		alert.tag = tag;
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
//		[alert textFieldAtIndex:0].delegate = self;
		[alert show];
		//        [alert release];
	});
}

-(void) setPassWordWithAlertText:(NSString *) alertText andTag:(long) tag
{
	self.passwordAlertState = pEnterPassword;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:alertText
														message:NSLocalizedString(@"Enter New Passcode", nil)
													   delegate:self
											  cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
											  otherButtonTitles:NSLocalizedString(@"Next", nil), nil];
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
		alert.tag = tag;
		[alert textFieldAtIndex:0].secureTextEntry = YES;
		//[alert textFieldAtIndex:0].delegate = self;
		[alert show];
		//        [alert release];
	});
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	
	NSString *thisPassword = [alertView textFieldAtIndex:0].text;
	NSString *passWord = [[NSUserDefaults standardUserDefaults] valueForKey:@"lockKey"];
	
	if (buttonIndex != [alertView cancelButtonIndex])
	{
		if(self.passwordAlertState == pEnterPassword)
		{
			self.enteredPassword = [NSString stringWithFormat:@"%@",thisPassword];// retain];
			
			self.passwordAlertState = pRepeatPassword;
			dispatch_async(dispatch_get_main_queue(), ^{
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Passcode Lock", nil)
																message:NSLocalizedString(@"Reenter New Passcode", nil)
															   delegate:self
													  cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
													  otherButtonTitles:NSLocalizedString(@"Next", nil), nil];
				alert.alertViewStyle = UIAlertViewStylePlainTextInput;
				alert.tag = alertView.tag;
				//[alert textFieldAtIndex:0].delegate = self;
				[alert textFieldAtIndex:0].secureTextEntry = YES;
				[alert show];
				//                [alert release];
			});
		} else if(self.passwordAlertState == pRepeatPassword)
		{
			
			if(![self.enteredPassword isEqualToString:thisPassword])
			{
				[self setPassWordWithAlertText:NSLocalizedString(@"Password Mismatch", nil) andTag:alertView.tag];
			} else
			{
				[[NSUserDefaults standardUserDefaults] setValue:self.enteredPassword forKey:@"lockKey"];
				[[NSUserDefaults standardUserDefaults] synchronize];
				
				long currentTime = time(NULL);
				long timeDelay = 0;
				timeDelay = 5;
				NSDictionary *delayDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLong:currentTime],@"lockTime",[NSNumber numberWithLong:timeDelay],@"lockDelayTime",[NSNumber numberWithLong:0],@"isActive", nil];
				[[NSUserDefaults standardUserDefaults] setValue:delayDict forKey:@"lockTimeDict"];
				
				self.passwordAlertState = pDone;
				self.enteredPassword = nil;
			}
		}else if(self.passwordAlertState == pDoneSetting) // lock is active
		{
			switch (buttonIndex) {
				case 1:
				{
					if([passWord isEqualToString:thisPassword])
					{
						[self.lockKeySwitch setOn:NO animated:YES];
						[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"lockKey"];
						[[NSUserDefaults standardUserDefaults] synchronize];
					} else
					{
						// keep showing the same alertview
						[self presentLockedAlertViewWithTag:alertView.tag];
					}
				}
					break;
				case 2:
				{
					[self setPassWordWithAlertText:NSLocalizedString(@"Set new Passcode", nil) andTag:alertView.tag];
				}
					break;
				case 3:
				{
					if([passWord isEqualToString:thisPassword])
					{
						[self presentDelayAlertViewWithTag:alertView.tag];
					} else
					{
						[self presentLockedAlertViewWithTag:alertView.tag];
					}
				}
					break;
				default:
					break;
			}
		} else if(self.passwordAlertState == pEditDelay)
		{
			long currentTime = time(NULL);
			long timeDelay = 0;
			switch (buttonIndex) {
				case 1:
					timeDelay = 5;
					break;
				case 2:
					timeDelay = 15;
					break;
				case 3:
					timeDelay = 60;
					break;
				case 4:
					timeDelay = 60 * 15;
					break;
				case 5:
					timeDelay = 60 * 60;
					break;
				case 6:
					timeDelay = 60 * 60 * 4;
					break;
				default:
					break;
			}
			NSDictionary *delayDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLong:currentTime],@"lockTime",[NSNumber numberWithLong:timeDelay],@"lockDelayTime",[NSNumber numberWithLong:0],@"isActive", nil];
			[[NSUserDefaults standardUserDefaults] setValue:delayDict forKey:@"lockTimeDict"];
			[[NSUserDefaults standardUserDefaults] synchronize];
			
			self.passwordAlertState = pDoneSetting;
		}
	} else
	{
		if(!passWord)
		{
			// EA: there must be a better way!!
			NSInteger section = alertView.tag/100;
			//NSInteger row = alertView.tag % 100;
			SCSettingsItem *setting = [self.sectionList objectAtIndex:section];
			//SCSettingsItem *setting = [[sectionRoot visibleItems] objectAtIndex:row];
			setting.value = @NO; // @"0"
			[self.lockKeySwitch setOn:NO animated:NO];
		}
		self.passwordAlertState = pDone;
	}
}

-(void) presentDelayAlertViewWithTag:(long) tag
{
	self.passwordAlertState = pEditDelay;
	dispatch_async(dispatch_get_main_queue(), ^{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Passcode Delay", nil)
														message:nil
													   delegate:nil
											  cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
											  otherButtonTitles:[NSString stringWithFormat:NSLocalizedString(@"%d Seconds", nil), 5],
							  [NSString stringWithFormat:NSLocalizedString(@"%d Seconds", nil), 15],
							  [NSString stringWithFormat:NSLocalizedString(@"%d Minute", nil), 1],
							  [NSString stringWithFormat:NSLocalizedString(@"%d Minutes", nil), 15],
							  [NSString stringWithFormat:NSLocalizedString(@"%d Hour", nil), 1],
							  [NSString stringWithFormat:NSLocalizedString(@"%d Hours", nil), 4], nil];
		
		alert.tag = tag;
		alert.delegate = self;
		alert.alertViewStyle = UIAlertViewStyleDefault;
		[alert show];
		//    [alert release];
	});
}

@end



