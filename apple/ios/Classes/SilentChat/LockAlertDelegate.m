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
#import "LockAlertDelegate.h"
#import "Utilities.h"
@implementation LockAlertDelegate
{
    enum passWordState
    {
        pDone = 0,
        pEnterPassword = 1,
        pRepeatPassword = 2,
        pDoneSetting = 3, // meaning password is set to on
        pEditDelay = 4,
    };
}
+(LockAlertDelegate *)lockAlertInstance
{
    static dispatch_once_t once;
    static LockAlertDelegate *lockAlertInstance;
    dispatch_once(&once, ^{
        lockAlertInstance = [[self alloc] init];
    });
    lockAlertInstance.lockKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"lockKey"];
    
    if(lockAlertInstance.lockKey)
    {
        NSDictionary *locktimeDict = [[NSUserDefaults standardUserDefaults] objectForKey:@"lockKeyDelayTime"];
        lockAlertInstance.lockedTime = [locktimeDict objectForKey:@"lockTime"];
        lockAlertInstance.lockedTimeDelay = [locktimeDict objectForKey:@"lockDelayTime"];
        
        lockAlertInstance.lockedTimeStamp = [lockAlertInstance.lockedTime intValue] + [lockAlertInstance.lockedTimeDelay intValue];
    }
    return lockAlertInstance;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    NSString *thisPassword = [alertView textFieldAtIndex:0].text;
    NSString *passWord = [[NSUserDefaults standardUserDefaults] valueForKey:@"lockKey"];
    [[alertView textFieldAtIndex:0] resignFirstResponder];
    if (buttonIndex != [alertView cancelButtonIndex])
    {
        if(_passwordAlertState == pDone || _passwordAlertState == pDoneSetting)
        {
            switch (buttonIndex) {
                case 1:
                {

                    // turn lock off for this session
                    if([thisPassword isEqualToString:passWord] && _passwordAlertState == pDone)
                    {
                        //[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"lockKey"];
                        //[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"lockKeyDelayTime"];
                        NSMutableDictionary *delayDict = [[[NSUserDefaults standardUserDefaults] objectForKey:@"lockTimeDict"] mutableCopy];
                        [delayDict setValue:[NSNumber numberWithInt:0] forKey:@"isActive"];
                        [[NSUserDefaults standardUserDefaults] setValue:delayDict forKey:@"lockTimeDict"];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        

                        if([Utilities utilitiesInstance].lockedOverlayView)
                        {
                            [[Utilities utilitiesInstance].lockedOverlayView removeFromSuperview];
                        }
                    }else
                    {
                        [self presentLockedAlertView];
                    }
                }
                    break;
                case 2:
                {
                    if ([passWord isEqualToString:thisPassword]) {
                        _passwordAlertState = pEnterPassword;
                        [self presentPassWordWithAlertText:@"Set New Passcode"];
                    } else
                    {
                        [self presentLockedAlertView];
                    }
                }
                    break;
                    
                case 3:
                {
                    if ([passWord isEqualToString:thisPassword]) {
                        [self presentTimeDelayAlertView];
                    } else
                    {
                        [self presentLockedAlertView];
                    }
                }
                    break;
                default:
                    break;
            }
        } else
        {
            if(_passwordAlertState == pEnterPassword)
            {
                _enteredPassword = thisPassword;
                [self presentPassWordWithAlertText:@"Repeat New Passcode"];
                _passwordAlertState = pRepeatPassword;
            }
            else if(_passwordAlertState == pRepeatPassword)
            {
                if([_enteredPassword isEqualToString:thisPassword])
                {
                    [self savePassword];
                    _passwordAlertState = pDone;
                } else
                {
                    [self presentPassWordWithAlertText:@"Passcode Mismatch"];
                }
            } else if(_passwordAlertState == pEditDelay)
            {
                [self setDelayWithOption:buttonIndex];
            }
        }
    } else
    {
        _passwordAlertState = pDone;
    }
}

-(void) savePassword
{
    [[NSUserDefaults standardUserDefaults] setValue:_enteredPassword forKey:@"lockKey"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


-(void) setDelayWithOption:(long)buttonIndex
{
    
    [[Utilities utilitiesInstance].lockedOverlayView removeFromSuperview];
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
    

    NSDictionary *delayDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLong:time(NULL)],@"lockTime",[NSNumber numberWithLong:timeDelay],@"lockDelayTime",[NSNumber numberWithLong:0],@"isActive", nil];

    [[NSUserDefaults standardUserDefaults] setValue:delayDict forKey:@"lockTimeDict"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    _passwordAlertState = pDoneSetting;
    
    

}

#pragma mark AlertViews

-(void) presentTimeDelayAlertView
{
    _passwordAlertState = pEditDelay;
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Passcode Delay" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"5 Seconds",@"15 Seconds",@"1 Minute",@"15 Minutes",@"1 Hour",@"4 Hours", nil];
    // alert.tag = tag;
    [alert show];
}

-(void) presentPassWordWithAlertText:(NSString *) alertText
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:alertText message:@"Enter Passcode" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Next", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    // alert.tag = tag;
    [alert textFieldAtIndex:0].secureTextEntry = YES;
    [alert textFieldAtIndex:0].delegate = self;
    [alert show];
}

-(void) presentLockedAlertView
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

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Passcode" message:@"Enter Passcode" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Turn Off", nil];

    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert textFieldAtIndex:0].delegate = self;
    [alert show];
}
@end
