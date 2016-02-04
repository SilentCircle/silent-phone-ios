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
#import "UICellController.h"
#import "CallLogPopup.h"

const char *tg_translate(const char *key, int iKeyLen);
#define T_TR(_T_KEY) tg_translate(_T_KEY, sizeof(_T_KEY)-1)
#define T_TRL(_T_KEY, _T_KL) tg_translate(_T_KEY, _T_KL)
#define T_TRNS(_T_KEY) [NSString stringWithUTF8String:tg_translate(_T_KEY, sizeof(_T_KEY)-1)]

char *getLogForCall(const char *cid, int *iLen, int iAudioStats, int iSips, int iEvents, int iZRTP);
char* t_post_json(const char *url, char *bufResp, int iMaxLen, int &iRespContentLen, const char *pContent);
int t_encode_json_string(char *out, int iMaxOut, const char *in);
const char* getCurrentProvSrv();
const char *getAPIKey();

NSString *nsSubject = NULL;

static char *createFeedBack(NSString *userMsg, const char *log, int iLogLen){
   /*
   {
      "identifiable": true,
      "call_rating": 4,
      "details": {
         "foo": 37,
         "bar": "banana"
      }
   }
    */

   if(userMsg.length < 1){
      userMsg = @"no_subject";
   }
   
   char user_msg[256];
   int umlen = t_encode_json_string(user_msg, sizeof(user_msg), userMsg.UTF8String);
   
#define T_SIZE_OF_JSON_HDR 200
   
   const int sz = iLogLen * 2 + T_SIZE_OF_JSON_HDR + umlen + 2;
   char* msg = new char [sz+1];
   if(!msg)return NULL;
   int iMsgLen = 0;
   msg[0] = 0;
   iMsgLen = t_snprintf(msg, sz, "{\"identifiable\": true,\"call_rating\": 4,\"details\": { \"Subject\":\"%s\",\"log\":\"",user_msg);
   
   iMsgLen += t_encode_json_string(msg + iMsgLen, sz - iMsgLen, log);
   
   iMsgLen += t_snprintf(msg + iMsgLen, sz - iMsgLen,"\"}}");
   
   return msg;
}

@implementation CallLogPopup

+ (void)popupLogMessage:(CTRecentsItem*)i vc:(UIViewController*)vc{
   
   
   
   UIAlertController *ac = [UIAlertController alertControllerWithTitle:nil
                                                               message:T_TRNS("Do you want to send the log?")
                                                        preferredStyle:UIAlertControllerStyleAlert];
   
   [ac retain];
   
   [ac addTextFieldWithConfigurationHandler:^(UITextField *textField){
      [textField setBackgroundColor:[UIColor clearColor]];
      [textField setTextAlignment:NSTextAlignmentLeft] ;
      [textField setPlaceholder:T_TRNS("Enter Message Here")];
   }];
   
   [ac addAction:[UIAlertAction actionWithTitle:T_TRNS("Cancel")
                                          style:UIAlertActionStyleCancel
                                        handler:^(UIAlertAction *action){
                                           //[self okButtonTapped];
                                           [ac release];
                                        }]];
   
   [ac addAction:[UIAlertAction actionWithTitle:T_TRNS("Send the log")
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction *action){
                                           
                                           UITextField *tf = ac.textFields[0];
                                           if(nsSubject){
                                              [nsSubject release];
                                              nsSubject = NULL;
                                           }
                                           nsSubject = [[NSString alloc]initWithString:tf.text];
                                           [ac release];
                                           
                                           [CallLogPopup sendWithoutSIP:i isShowDetails:0 vc:vc];
                                           
                                        }]];
   
   [ac addAction:[UIAlertAction actionWithTitle:T_TRNS("Show Details")
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction *action){
                                           
                                           UITextField *tf = ac.textFields[0];
                                           if(nsSubject){
                                              [nsSubject release];
                                              nsSubject = NULL;
                                           }
                                           nsSubject = [[NSString alloc]initWithString:tf.text];
                                           [ac release];
                                           
                                           [CallLogPopup sendWithoutSIP:i isShowDetails:1 vc:vc];
                                           
                                           
                                        }]];
   
   [vc presentViewController:ac animated:YES completion:nil];
   //show
   
}

+(void)sendWithoutSIP:(CTRecentsItem*)i isShowDetails:(int)isShowDetails vc:(UIViewController*)vc{
   UIAlertController *ac = [UIAlertController alertControllerWithTitle:nil
                                                               message:T_TRNS("Do you want to include the call setup information?")
                                                        preferredStyle:UIAlertControllerStyleAlert];
   
   
   
   [ac addAction:[UIAlertAction actionWithTitle:T_TRNS("Yes")
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction *action){
                                           
                                           if(isShowDetails){
                                              [CallLogPopup showDetails:i includeSIP:1  vc:vc];
                                           }
                                           else{
                                              [CallLogPopup sendCallLog:i includeSIP:1];
                                           }
                                        }]];
   
   [ac addAction:[UIAlertAction actionWithTitle:T_TRNS("No")
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction *action){
                                           if(isShowDetails){
                                              [CallLogPopup showDetails:i includeSIP:0 vc:vc];
                                           }
                                           else{
                                              [CallLogPopup sendCallLog:i includeSIP:0];
                                           }
                                        }]];
   
   [vc presentViewController:ac animated:YES completion:nil];
}

+(void) sendCallLog:(CTRecentsItem *)i includeSIP:(int)includeSIP{
   
   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      //char* t_post_json(const char *url, char *bufResp, int iMaxLen, int &iRespContentLen, const char *pContent);
      int l=0;
      char *log = getLogForCall(i->szSIPCallID, &l,1,includeSIP,1,1);
      if(log && l>0){
         char* json = createFeedBack(nsSubject, log,l);
         if(json){
            char bufResp[1024];
            char url[1024];
            int respLen=0;
            
            const char *web = getCurrentProvSrv();
            t_snprintf(url, sizeof(url), "%s/v1/feedback/call/?api_key=%s", web,getAPIKey());
            
            char *rec = t_post_json(url, bufResp, sizeof(bufResp)-1, respLen, json);
            if(rec){
               puts(rec);
            }
            delete json;
         }
         delete log;
      //https://sccps-dev.silentcircle.com/v1/feedback/call/?api_key=<
      }
      
      
//
   });
   
}

+(void) showDetails:(CTRecentsItem *)i includeSIP:(int)includeSIP vc:(UIViewController*)vc{
   
   char *log = getLogForCall(i->szSIPCallID, NULL,1,includeSIP,1,1);
   
   if(log){
      NSString *msg = [NSString stringWithUTF8String:log ];
#if 1
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:T_TRNS("Call log")
                                                                               message:msg
                                                                        preferredStyle:UIAlertControllerStyleAlert];
      
      if ([[[UIDevice currentDevice] systemVersion] floatValue] < 8.3) {
         
         CGFloat screenHeight;
         CGFloat screenWidth;
         if ([[UIApplication sharedApplication] statusBarOrientation] == UIDeviceOrientationPortrait || [[UIApplication sharedApplication] statusBarOrientation] == UIDeviceOrientationPortraitUpsideDown){
            screenHeight = [UIScreen mainScreen].applicationFrame.size.height;
            screenWidth = [UIScreen mainScreen].applicationFrame.size.width;
         } else{
            screenHeight = [UIScreen mainScreen].applicationFrame.size.width;
            screenWidth = [UIScreen mainScreen].applicationFrame.size.height;
         }
         CGRect alertFrame = CGRectMake([UIScreen mainScreen].applicationFrame.origin.x, [UIScreen mainScreen].applicationFrame.origin.y+40, screenWidth, screenHeight-80);
         alertController.view.frame = alertFrame;
         
      }
      /*
       [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField){
       [textField setBackgroundColor:[UIColor clearColor]];
       [textField setTextAlignment:NSTextAlignmentLeft] ;
       CGRect frameRect = textField.frame;
       frameRect.size.height = [UIScreen mainScreen].applicationFrame.size.height*2/3;
       textField.frame = frameRect;
       
       textField.enabled=false;
       [textField setText:msg];
       
       }];
       */
      [alertController addAction:[UIAlertAction actionWithTitle:T_TRNS("Cancel")
                                                          style:UIAlertActionStyleCancel
                                                        handler:^(UIAlertAction *action){
                                                           
                                                        }]];
      [alertController addAction:[UIAlertAction actionWithTitle:T_TRNS("Send the log")
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action){
                                                           
                                                           [CallLogPopup sendCallLog:i includeSIP:includeSIP];
                                                   
                                                        }]];
      [vc presentViewController:alertController animated:YES completion:nil];
#else
#if 0
      UIAlertView *av = [[UIAlertView alloc] initWithTitle: T_TRNS("Call log")
                                                   message:msg
                                                  delegate:nil
                                         cancelButtonTitle:T_TRNS("Cancel")
                                         otherButtonTitles:nil];
#else
      UIAlertView *av = [[UIAlertView alloc] initWithTitle: T_TRNS("Call log")
                                                   message:nil
                                                  delegate:nil
                                         cancelButtonTitle:T_TRNS("Cancel")
                                         otherButtonTitles:nil];
      
      UITextView *txtView = [[UITextView alloc] init];
      [txtView setBackgroundColor:[UIColor clearColor]];
      [txtView setTextAlignment:NSTextAlignmentLeft] ;
      [txtView setEditable:NO];
      [txtView setText:msg];
      
      [av setValue:txtView forKey:@"accessoryView"];
      
      
#endif
      
      [av addButtonWithTitle:T_TRNS("Send the log")];
      
      
      [av show];
      [av release];
#endif
      
      delete log;
   }
   
}


@end;
