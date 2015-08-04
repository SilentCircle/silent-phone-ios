/*
Copyright (C) 2012, Tivi LTD, www.tiviphone.com. All rights reserved.
Copyright (C) 2012-2015, Silent Circle, LLC.  All rights reserved.

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
#import <UIKit/UIKit.h>
#import "SCProgressView.h"

@protocol ProvResponce <NSObject>

@optional

- (void)onProvResponce:(int)ok;

@end

@class SCCheckbox;

@interface Prov : UIViewController<UITextFieldDelegate>
{
    //orig - moved to public (below) and .mm private properties
//   IBOutlet UITextField *tfUsername;
//   IBOutlet UITextField *tfPassword;
//   IBOutlet UITextField *tfToken;
//   IBOutlet UIBarButtonItem *btSignIn;
//   IBOutlet UIBarButtonItem *btSignUp;
//   IBOutlet UIProgressView *uiProg;
//   IBOutlet UIImageView *uiBackgr;
//   IBOutlet UINavigationItem *uiNI;
//    IBOutlet UIButton *btSignIn;
   
@public id <ProvResponce>  _provResponce;

   int iProvStat;
   int iPrevErr;
}

//06/30/15 properties from ivars
@property (retain, nonatomic) IBOutlet UITextField *tfUsername;
@property (retain, nonatomic) IBOutlet UITextField *tfPassword;
@property (retain, nonatomic) IBOutlet UITextField *tfToken;
@property (retain, nonatomic) IBOutlet UIBarButtonItem *btSignUp;
@property (retain, nonatomic) IBOutlet UIImageView *uiBackgr;
@property (retain, nonatomic) IBOutlet UINavigationItem *uiNI;
@property (retain, nonatomic) IBOutlet UIButton *btSignIn;   // "Login"


+(UIImage*)getSplashImage;


//@property(nonatomic,assign)   id <ProvResponce>   provResponce;

@end
