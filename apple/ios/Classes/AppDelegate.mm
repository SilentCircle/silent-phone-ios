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
#import <MediaPlayer/MPVolumeSettings.h>
#import <MediaPlayer/MPVolumeView.h>
#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>

#include <string.h>
#include "../../../os/CTMutex.h"
#include "../../../tiviandroid/engcb.h"
#include "../../../utils/CTNumberHelper.h"

#import "AppDelegate.h"
#import "CallManeger.h"
#import "DBManager.h"
#import "LocationManager.h"
#import "SP_FastContactFinder.h"
#import "VideoViewController.h"
#import "Utilities.h"
#import "../../../utils/Reachability.h"
#import "ZRTPInfoView.h"
#import "ZIDViewController.h"
#import "SCFileManager.h"

#import "ChatViewController.h"
#import "LaunchScreenVC.h"
#import "SCContainerVC.h"

#import "LockAlertDelegate.h"

CTNumberHelperBase *pDialerHelper = g_getDialerHelper();

#define T_DISABLE_BLINK_WARN 1

#define T_CREATE_CALL_MNGR
//iSASConfirmClickCount
#define T_SAS_NOVICE_LIMIT 2
//#define T_TEST_MAX_JIT_BUF_SIZE

@interface MZActionSheet : UIActionSheet <UIActionSheetDelegate>
//
@property (nonatomic, copy) void (^actionBlockz)(NSInteger buttonPressed);

-(void) setActionBlock:(void (^)(NSInteger))actionBlock;

@end

@implementation MZActionSheet


-(void) setActionBlock:(void (^)(NSInteger))actionBlock
{
	self.delegate = self;
	self.actionBlockz = actionBlock;
}
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	_actionBlockz(buttonIndex);
	self.actionBlockz = nil;
}
@end;


const char *tg_translate(const char *key, int iKeyLen);
#define T_TR(_T_KEY) tg_translate(_T_KEY, sizeof(_T_KEY)-1)
#define T_TRL(_T_KEY, _T_KL) tg_translate(_T_KEY, _T_KL)
#define T_TRNS(_T_KEY) [NSString stringWithUTF8String:tg_translate(_T_KEY, sizeof(_T_KEY)-1)]

#define getAccountTitle(pS) sendEngMsg(pS,"title")

int canModifyNumber();

void *findGlobalCfgKey(const char *key);
int fncCBRet(void *ret, void *ph, int iCallID, int msgid, const char *psz, int iSZLen);
char* z_main(int iResp,int argc, const char* argv[]);;
int get_time();
void safeStrCpy(char *dst, const char *name, int iMaxSize);
void* findCfgItemByServiceKey(void *ph, char *key, int &iSize, char **opt, int *type);
NSString *toNSFromTB(CTStrBase *b);
const char* sendEngMsg(void *pEng, const char *p);
int getCallInfo(int iCallID, const char *key, char *p, int iMax);
int getCallInfo(int iCallID, const char *key, int *v);
void *getAccountByID(int id, int iIsEnabled);
void* getAccountCfg(void *eng);
void *getCurrentDOut();
int getMediaInfo(int iCallID, const char *key, char *p, int iMax);

int setCurrentDOut(int idx, const char *sz);
void apple_log_x(const char *p);
int findIntByServKey(void *pEng, const char *key, int *ret);
int isVideoCall(int iCallID);
char *iosLoadFile(const char *fn, int &iLen);
void initCC(char *p, int iLen);
int getReqTimeToLive();
void translateZRTP_errMsg(CTEditBase &warn, CTEditBase *general, CTEditBase *descr);
int isZRTPInfoVisible();
int isPlaybackVolumeMuted();
unsigned int getTickCount();
int fixNR(const char *in, char *out, int iLenMax);
void setAudioRouteChangeCB(void(*fncCBOnRouteChange)(void *self, void *ptrUserData), void *ptrUserData);

void playTestRingTone(const char *name);
const char * getRingtone(const char *p=NULL);
int getIOSVersion(void);
int secSinceAppStarted(void);

static int iIsTmpWorkingInBackGround=0;
static int iIsTmpWorkingNetCalls=0;
int isTmpWorkingInBackGround(){return iIsTmpWorkingInBackGround || iIsTmpWorkingNetCalls>0;}

int isPlaybackVolumeMutedIOS6();

static CTMutex mutexCallManeger;
void *pCurService=NULL;
void *pCurCfg=NULL;
static int iCfgOn=0;
static void *prevEng=NULL;


const char* sendEngMsg(void *pEng, int iCallID, const char *p){
   char msg[64];
   snprintf(msg,63,"%s%u",p,iCallID);
   return sendEngMsg(pEng,msg);
}

int isSDESSecure(int iCallId, int iVideo){
   int v=0;
   if(getCallInfo(iCallId,iVideo?"media.video.zrtp.sec_state": "media.zrtp.sec_state", &v)==0 && v & 0x100)
      return 1;
   return 0;
}




NSString *checkNrPatterns(NSString *ns){
   
   char buf[64];
   if(fixNR(ns.UTF8String,&buf[0],63)){
      return [NSString stringWithUTF8String:&buf[0]];
   }
   return ns;
}

typedef struct{
   NSString *ns;
}T_Log;

static void fnc_log(void *ret, const char *line, int iLen){
   char buf[256];
   
   if(iLen>=sizeof(buf))iLen=sizeof(buf)-1;
   memcpy(buf,line,iLen);
   buf[iLen]=0;
   
   T_Log *l=(T_Log*)ret;
   
   NSString *ns=l->ns;
   l->ns=[ns stringByAppendingString:[NSString stringWithUTF8String:buf]];
}

// Added for provisioning window handling
@interface AppDelegate()
@property(retain, nonatomic) UIWindow *cachedWindow;
@property(retain, nonatomic) UIWindow *provWindow;
@property(retain, nonatomic) SCContainerVC *provRootVC;
@end

@implementation AppDelegate

@synthesize window;
@synthesize navigationController;

/*
 onts provided by application
 Item 0        myfontname.ttf
 Item 1        myfontname-bold.ttf
 ...
 Then check to make sure your font is included by running :
 
 for (NSString *familyName in [UIFont familyNames]) {
  for (NSString *fontName in [UIFont fontNamesForFamilyName:familyName]) {
    NSLog(@"%@", fontName);
  }
 }
 Note that your ttf file name might not be the same name that you use when you set the font for your label (you can use the code above to get the "fontWithName" parameter):
 
 [label setFont:[UIFont fontWithName:@"MyFontName-Regular" size:18]];
 */


/*
 ￼-(BOOL)isForeground
 {
 ! if (![self isMultitaskingOS])
 ! ! return YES;
 ! UIApplicationState state = [UIApplication sharedApplication].applicationState;
 ! //return (state==UIApplicationStateActive || state==UIApplicationStateInactive );
 ! return (state==UIApplicationStateActive); 
 }
 */
/*
 
 NSString *myIDToCancel = @"some_id_to_cancel";
 UILocalNotification *notificationToCancel=nil;
 for(UILocalNotification *aNotif in [[UIApplication sharedApplication] scheduledLocalNotifications]) {
 if([aNotif.userInfo objectForKey:@"ID"] isEqualToString:myIDToCancel]) {
 notificationToCancel=aNotif;
 break;
 }
 }
 [[UIApplication sharedApplication] cancelLocalNotification:notificationToCancel];
 */

/*
 ￼-(BOOL)isForeground
 {
 if (![self isMultitaskingOS])   return YES;
 UIApplicationState state = [UIApplication sharedApplication].applicationState;
 //return (state==UIApplicationStateActive || state==UIApplicationStateInactive );
 return (state==UIApplicationStateActive); 
 }
 */

#pragma mark - Init

-(void)makeDPButtons{
   static  int iInitOk=0;
   if(iInitOk)return ;
   iInitOk=1;
   
   NSString *ns[]={
      @"1",@"2",@"3",
      @"4",@"5",@"6",
      @"7",@"8",@"9",
      @"*",@"0",@"#",
   };
   
   NSString *ns_text[]={
      @"",@"ABC",@"DEF",
      @"GHI",@"JKL",@"MNO",
      @"PQRS",@"TUV",@"WXYZ",
      @"",@"+",@"",
   };
   
   float ofsx=0;//10;
   float ofsy=0;//nr.frame.size.height+10;//115;
   float spx=14;
   float spy=-4;
   
   float szx=(dialPadBTView.frame.size.width-spx*2)/3;
   float szy=(dialPadBTView.frame.size.height-spy*3)/4;
   
   
   if(szx>szy){ofsx+=3*(szx-szy)/2; szx=szy;}
   else {ofsy+=4*(szy-szx)/2; szy=szx;}

   
   UIImage *bti=[UIImage imageNamed:@"bt_dial_up.png"];
   UIImage *btid=[UIImage imageNamed:@"bt_dial_down.png"];
   CGSize szShadow=CGSizeMake(0,-1);
   UIEdgeInsets uiEI=UIEdgeInsetsMake(0,0,szy/6,0);
   
   for(int y=0,i=0;y<4;y++)
      for(int x=0;x<3;x++,i++){
         UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
         [button addTarget:self  action:@selector(pressDP_Bt:) forControlEvents:UIControlEventTouchDown];
         [button addTarget:self  action:@selector(textFieldReturn:) forControlEvents:UIControlEventTouchDown];
         [button addTarget:self  action:@selector(pressDP_Bt_up:) forControlEvents:UIControlEventTouchUpInside];
         [button addTarget:self  action:@selector(pressDP_Bt_up:) forControlEvents:UIControlEventTouchUpOutside];
         [button addTarget:self  action:@selector(pressDP_Bt_up:) forControlEvents:UIControlEventTouchDragOutside];
         

         [button setBackgroundImage:bti forState:UIControlStateNormal];
         [button setBackgroundImage:btid forState:UIControlStateHighlighted];
         
         [button.titleLabel setFont:[UIFont boldSystemFontOfSize:i==9?48:30]];
         [button.titleLabel setTextColor:[UIColor whiteColor]];
         [button.titleLabel setShadowOffset:szShadow];
         
         [button setIsAccessibilityElement:YES];

         button.accessibilityLabel=ns[i];
         button.accessibilityTraits=UIAccessibilityTraitKeyboardKey;
         // button a
         
         if(i==9)
            button.contentEdgeInsets=UIEdgeInsetsMake(szy/4,0,0,0);
         else if(i!=11 && i!=9)
            button.contentEdgeInsets=uiEI;
         
         
         [button setTitle:ns[i] forState:UIControlStateNormal];
         
         float ox=ofsx+x*(szx+spx);
         float oy=ofsy+y*(szy+spy);
         button.frame = CGRectMake(ox,oy, szx, szy);
         
         UILabel *lb=[[UILabel alloc]initWithFrame:CGRectMake(0,0+szy*5/8,szx,szy*1/8)];
         lb.text=ns_text[i];
         lb.font=[UIFont systemFontOfSize:10];
         lb.textColor=[UIColor whiteColor];
         lb.textAlignment=NSTextAlignmentCenter;
         lb.backgroundColor=[UIColor clearColor];           
         [button addSubview:lb ];
         [lb release];
         
         [dialPadBTView addSubview:button];
      }

   szx=(keyPadInCall.frame.size.width-spx*2)/3;
   szy=(keyPadInCall.frame.size.height-spy*3)/4;
   ofsx = ofsy = 0;
   if(szx>szy){ofsx+=3*(szx-szy)/2; szx=szy;}
   else {ofsy+=4*(szy-szx)/2; szy=szx;}
   
   
   //- (void)loadView
   {
      /*
       CGRect appFrame = [[UIScreen mainScreen] applicationFrame];
       UIView *view = [[UIView alloc] initWithFrame:appFrame];
       view.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
       self.view = view;
       [view release];
       */
      //[UIScreen mainScreen] 
      /*   
       CGRect webFrame = CGRectMake(0,0,dialPadBTView.frame.size.width,dialPadBTView.frame.size.height);//[[UIScreen mainScreen] applicationFrame];
       UIWebView *webview2 = [[UIWebView alloc] initWithFrame:webFrame];
       webview2.backgroundColor = [UIColor whiteColor];
       webview2.scalesPageToFit = YES;
       webview2.allowsInlineMediaPlayback=YES;
       [dialPadBTView addSubview:webview2];
       NSString *html = @"<html><head><meta name=""viewport"" content=""width=640""/></head><body>\
       <object style=""height: 390px; width: 640px""><param name=""movie"" value=""http://www.youtube.com/v/ucivXRBrP_0?version=3&feature=player_detailpage""><param name=""allowFullScreen"" value=""true""><param name=""allowScriptAccess"" value=""always""><embed src=""http://www.youtube.com/v/ucivXRBrP_0?version=3&feature=player_detailpage"" type=""application/x-shockwave-flash"" allowfullscreen=""true"" allowScriptAccess=""always"" width=""640"" height=""360""></object>\
       </body</html>";
       
       [webview2 loadHTMLString:html baseURL:[NSURL URLWithString:@"http://www.apple.com"]];
       */
      /*
       NSString *html = @"<html><head><meta name=""viewport"" content=""width=320""/></head><body><h1>Header</h1><p>This is some of my introduction..BLA BLA BLA!!</body</html>";
       */
      
   }
   

   uiEI=UIEdgeInsetsMake(0,0,szy/8,0);
   [keyPadInCall setUserInteractionEnabled:YES];

   // keyPadInCall 
   for(int y=0,i=0;y<4;y++)
      for(int x=0;x<3;x++,i++){
         
         
         UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
         
         [button addTarget:self  action:@selector(inCallKeyPad_down:) forControlEvents:UIControlEventTouchDown];
         [button addTarget:self  action:@selector(inCallKeyPad_up:) forControlEvents:UIControlEventTouchUpInside];
         [button addTarget:self  action:@selector(inCallKeyPad_up:) forControlEvents:UIControlEventTouchUpOutside];
         [button addTarget:self  action:@selector(inCallKeyPad_up:) forControlEvents:UIControlEventTouchDragOutside];
         
         
         
         
         
         [button setBackgroundImage:btid forState:UIControlStateHighlighted];
         [button setBackgroundImage:bti forState:UIControlStateNormal];
    //     [button setBackgroundImage:btid forState:UIControlStateHighlighted];
         
         //setTitleColor
         button.showsTouchWhenHighlighted=YES;
         
         [button.titleLabel setFont:[UIFont boldSystemFontOfSize:i==9?64:36]];
         [button.titleLabel setTextColor:[UIColor whiteColor]];
         
         [button setTitle:ns[i] forState:UIControlStateNormal];
         
         [button setIsAccessibilityElement:YES];
         button.accessibilityLabel=ns[i];
         button.accessibilityTraits=UIAccessibilityTraitKeyboardKey;

         
         float ox=ofsx+x*(szx+spx);
         float oy=ofsy+y*(szy+spy);
         button.frame = CGRectMake(ox,oy, szx, szy);
         
         UILabel *lb=[[UILabel alloc]initWithFrame:CGRectMake(0,0+szy*5/8,szx,szy*3/8)];
         lb.text=ns_text[i];
         lb.font=[UIFont systemFontOfSize:10];
         lb.textColor=[UIColor whiteColor];
         lb.textAlignment=NSTextAlignmentCenter;
         lb.backgroundColor=[UIColor clearColor];           
         [button addSubview:lb ];
         [lb release];
         [button setEnabled:YES];
         
         if(i==9)button.contentEdgeInsets=UIEdgeInsetsMake(szy/4,0,0,0);else
            if(i!=11 && i!=9)button.contentEdgeInsets=uiEI;
         
         [keyPadInCall addSubview:button];
      }
   
   [keyPadInCall setHidden:YES];
   
   btHideKeypad= [UIButton buttonWithType:UIButtonTypeCustom];
   bti=[UIImage imageNamed:@"bt_gray.png"];
   
   [btHideKeypad setBackgroundImage:bti  forState:UIControlStateNormal];
   [btHideKeypad setTitle:@"Hide Keypad" forState:UIControlStateNormal];
   [btHideKeypad addTarget:self  action:@selector(hideKeypad:) forControlEvents:UIControlEventTouchUpInside];
   
   btHideKeypad.frame=answer.frame;
   
   [[answer superview]addSubview:btHideKeypad];
   
   [btHideKeypad setHidden:YES];
}

-(void)init_or_reinitDTMF{
   
   void setDtmfEnable(int f);
   
   setDtmfEnable(UIAccessibilityIsVoiceOverRunning()?0:1);
   
   return;
   /*
   NSLog(@"Init dtmf");
   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      static int iX=0;
      if(!iX){
         iX=1;
         const char *xr[]={"",":d ",":d"};//onforeground
         z_main(0,3,xr);
         iX=0;
         
      }
   });
    */
}

-(void)awakeFromNib{
   [self initT];
}

-(void)setTranslations{
   btCM.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
   btCM.titleLabel.textAlignment = NSTextAlignmentCenter;
   btCM.titleLabel.numberOfLines=0;
   [btCM setTitle:T_TRNS("Call\nManager") forState:UIControlStateNormal];
  
   [answer setTitle:T_TRNS("Answer") forState:UIControlStateNormal];
   
   //[keypaditem setTitle:T_TRNS("Call")];
   [lbVolumeWarning setText:T_TRNS("Volume is too low")];
}

-(void)initT {
   
   static int iInit=1;
   if(!iInit)return;
   iInit=0;
   
   
   
   void t_init_log();
   t_init_log();

   iOnMute=0;
   iVideoScrIsVisible=0;
   iExiting=0;
   iLoudSpkr=0;
   
 //  iAudioUnderflow=0;
   iSettingsIsVisble=0;
   iShowCallMngr=0;
 //  iCanShowMediaInfo=0;
   iAudioBufSizeMS=700;
   vvcToRelease=NULL;
#ifdef T_CREATE_CALL_MNGR 
   callMngr=NULL;
#endif
   iPrevCallLouspkrMode=0;
   uiCanShowModalAt=0;
   
   endCallRect=endCallBT.frame;
   sList=NULL;
   iCallScreenIsVisible=0;
   iAnimateEndCall=1;
   iIsClearBTDown=0;
   iIsInBackGround=1;
   iSecondsInBackGroud=0;
   incomCallNotif=NULL;
   
   szLastDialed[0]=0;
   
   calls.init();
   
   iCanHideNow=0;
   
   setPhoneCB(&fncCBRet,self);
   doCmd("set cfg.szOnHoldMusic=onHoldMusic.raw");
   //doCmd("set cfg.szPutOnHoldSound=putOnHoldBeep.raw");
   
   //view6pad.frame.size = CGSizeMake(view6pad.frame.size.width,view6pad.frame.size.height+40);
   if([UIScreen mainScreen].scale == 2.f && [UIScreen mainScreen].bounds.size.height == 568.0f){
      for(int i = 4401; i<=4403 ;i++){
         UIButton *bt1 = (UIButton *)[view6pad viewWithTag:i];
         if(bt1)bt1.center = CGPointMake(bt1.center.x, bt1.center.y+14);
      }
   }
   
   objLogTab=nil;

   [self hideLogTab];
   
   [self checkProvValues];
   
   [uiMainTabBarController setSelectedIndex:3];
    [uiTabBar selectSeperatorWithTag:3];
   
   nr.delegate=self;
   nr.enablesReturnKeyAutomatically = NO;
   nr.keyboardAppearance = UIKeyboardAppearanceDark;
   [nr setText:@""];
   [lbNRFieldName setText:@""];
 
   uiCallInfo.lineBreakMode = NSLineBreakByWordWrapping;
   uiCallInfo.numberOfLines = 0;
   
   [backToCallBT setHidden:YES];
   [btShowCSDPad setHidden:YES];
   
   CALayer *l;
   
   [lbVolumeWarning setHidden:YES];
   l=lbVolumeWarning.layer;
   l.borderColor = [UIColor whiteColor].CGColor;
   l.cornerRadius = 5;
   l.borderWidth=2;
   
   setAudioRouteChangeCB(&_fncCBOnRouteChange, self);
   
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(routeChangeHandler:)
                                                name:AVAudioSessionRouteChangeNotification
                                              object:[AVAudioSession sharedInstance]];
   
   
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(onNewProximityState)
                                                name:UIDeviceProximityStateDidChangeNotification
                                              object:nil];
   
   // Register for battery level and state change notifications.
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(batteryLevelDidChange:)
                                                name:UIDeviceBatteryLevelDidChangeNotification object:nil];
   
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(batteryStateDidChange:)
                                                name:UIDeviceBatteryStateDidChangeNotification object:nil];
   
   [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(reachabilityChanged:)
                                                name: kReachabilityChangedNotification object: nil];
   
   [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:)
                                                name:UIKeyboardWillShowNotification object:nil];
   [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:)
                                                name:UIKeyboardWillHideNotification object:nil];
   
   /*
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(keyboardWillShow:)
                                                name:UIKeyboardWillShowNotification
                                              object:nil];
   */
   
	
   internetReach = [[Reachability reachabilityForInternetConnection] retain];
	[internetReach startNotifier];

   
   [UIDevice currentDevice].batteryMonitoringEnabled = YES;
   
   iSASConfirmClickCount=(int*)findGlobalCfgKey("iSASConfirmClickCount");;
   backspaceBT.accessibilityTraits=UIAccessibilityTraitKeyboardKey;
   
   [self setTranslations];
}


- (void) keyboardWillToggle:(NSNotification *)aNotification willShow:(int)willShow
{
   int ct=[uiMainTabBarController selectedIndex];
   if(willShow && (ct!=3 || ![nr isFirstResponder]))return;
  
   static int iMovedUp=0;
   if(!iMovedUp  && !willShow)return;
   iMovedUp=willShow;
   
   
   
   CGRect frame = [uiTabBar frame];
   CGRect keyboard = [[aNotification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
   frame.origin.y = keyboard.origin.y - frame.size.height - uiMainTabBarController.view.frame.origin.y;
   float dur = [[aNotification.userInfo valueForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];

   [UIView animateWithDuration:dur animations:^
    {
       [uiTabBar setFrame:frame];
       [dialPadBTView setHidden:willShow];
    }];
}

- (void) keyboardWillShow:(NSNotification *)aNotification{
   [self keyboardWillToggle:aNotification willShow:1];
   [btShowCSDPad setHidden:NO];
}
- (void) keyboardWillHide:(NSNotification *)aNotification{
   [self keyboardWillToggle:aNotification willShow:0];
   [btShowCSDPad setHidden:YES];
}

#pragma mark - Network notifications

- (void) reachabilityChanged: (NSNotification* )note
{
	Reachability* curReach = [note object];
	NSParameterAssert([curReach isKindOfClass: [Reachability class]]);
   
   NetworkStatus netStatus = [curReach currentReachabilityStatus];
   BOOL connectionRequired= [curReach connectionRequired];
   NSString* statusString= @"";
   int checkIPNow();
   
   switch (netStatus)
   {
      case NotReachable:
      {
         statusString = @"Access Not Available";
         //Minor interface detail- connectionRequired may return yes, even when the host is unreachable.  We cover that up here...
         connectionRequired= NO;
         break;
      }
         
      case ReachableViaWWAN:
      {
         statusString = @"Reachable WWAN";
         [self startBackgrTask_test_netw];
         break;
      }
      case ReachableViaWiFi:
      {
         statusString= @"Reachable WiFi";
         [self startBackgrTask_test_netw];
         break;
      }
   }

   int net_ok = checkIPNow();
   NSLog(@"Connection:(%@) net_ok=%d req=%d", statusString, net_ok, connectionRequired);

}

- (void)routeChangeHandler:(NSNotification *)notification{
   void t_routeChangeHandler(NSNotification *n);
   t_routeChangeHandler(notification);
}


#pragma mark - Battery notifications

- (void)batteryLevelDidChange:(NSNotification *)notification
{
   [self checkBattery];
}

- (void)batteryStateDidChange:(NSNotification *)notification
{
   [self checkBattery];
}

-(void) checkBattery{
   
   if(iVideoScrIsVisible)return;
   
   int iKeepScreenOnIfBatOk=0;
   findIntByServKey(NULL, "iKeepScreenOnIfBatOk", &iKeepScreenOnIfBatOk);
   
   UIDeviceBatteryState bs = [UIDevice currentDevice].batteryState;
   float bl = [UIDevice currentDevice].batteryLevel;
   
   int on=0;

   if(bs==UIDeviceBatteryStateFull || bs==UIDeviceBatteryStateCharging){
      if(bl>=.3)on=1;
   }
   
   [[ UIApplication sharedApplication ] setIdleTimerDisabled: on && iKeepScreenOnIfBatOk==1? YES : NO];
}

-(void)showChatTab{
   if(objLogTab){
      NSMutableArray *newControllers = [NSMutableArray arrayWithArray: [uiMainTabBarController viewControllers]];
      [newControllers addObject:objLogTab];
      [uiMainTabBarController setViewControllers: newControllers animated: NO];
      [objLogTab release];
      objLogTab=nil;
      [self updateLogTab]; 
   }
   
}
-(void)hideLogTab{
   if(objLogTab)return;
   
   NSMutableArray *newControllers = [NSMutableArray arrayWithArray: [uiMainTabBarController viewControllers]];
   objLogTab=[newControllers objectAtIndex:4];
   [objLogTab retain];
   [newControllers removeObjectAtIndex:4];
   [uiMainTabBarController setViewControllers: newControllers animated: NO];
}

#pragma mark - Motion Manager
- (CMMotionManager *)initMotionManager
{
   NSString *ns = [[UIDevice currentDevice] model];
   
   if(!ns || ![ns isEqualToString:@"iPod touch"])return nil;
   //if !iPod_Touch return
   
   if (!motionManager) motionManager = [[CMMotionManager alloc] init];
   return motionManager;
}

- (void)startMotionDetect{
   [self initMotionManager];
   if(!motionManager)return;
   bButtonsEnabled=FALSE;
   //accelerometerActive
   
   [motionManager setDeviceMotionUpdateInterval:0.5f];
   [motionManager startAccelerometerUpdatesToQueue:[[NSOperationQueue alloc] init]
                                            withHandler:^(CMAccelerometerData *data, NSError *error) {
                                               dispatch_async(dispatch_get_main_queue(), ^{
                                         
                                                  float angle = atan2(data.acceleration.y, data.acceleration.x)+3.1416f;//i want positive
                                                  float z=data.acceleration.z;
                                                      //3*pi/2
                                                  //pi,      0;2pi
                                                       //pi/2
                                                  /*
                                                  NSString *ns =
                                                  [NSString stringWithFormat:
                                                   @"angle=%.2f %.1f %.1f %.1f"
                                                   ,angle, data.acceleration.x, data.acceleration.y, z ];
                                                  [uiServ setText:ns];
                                                  */
                                                  int on=angle>3.7f && angle<5.7f && z<.5f && z>-.5f;
                                                  int off=(angle>.8 && angle<2.2) || (z>.85f || z<-.85f); //pi/2 +-pi/4
                                                  
                                                  if(on)
                                                     [self disableButtons];
                                                  else if(off)
                                                     [self enableButtons];
            
                                               });
                                            }
    ];
}

-(void) stopMotionDetect{
   if(!motionManager)return;
   [motionManager stopAccelerometerUpdates];
   [self enableButtons];
}

-(void)enableButtons{
   if(bButtonsEnabled)return;
   bButtonsEnabled=TRUE;
   [endCallBT setEnabled:TRUE];
   [viewCSMiddle setUserInteractionEnabled:TRUE];
   [self enableViewButtons:TRUE v:view6pad];
}



-(void)disableButtons{
   if(!bButtonsEnabled)return;
   bButtonsEnabled=FALSE;
   [endCallBT setEnabled:FALSE];
   [viewCSMiddle setUserInteractionEnabled:FALSE];
   [self enableViewButtons:FALSE v:view6pad];
   
}

-(void)enableViewButtons:(BOOL)onOff v:(UIView*)v{
   for (UIControl *someObj in v.subviews)
   {
      if ([someObj isMemberOfClass:[UIButton class]]){
         [someObj setEnabled:onOff];
      }
   }
}

#pragma mark - push

-(void)setupVoipPush{
   
   PKPushRegistry *pushRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
   pushRegistry.delegate = self;
   pushRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
   
}

- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type{
   if([credentials.token length] == 0) {
      NSLog(@"voip token NULL");
      return;
   }
   NSLog(@"PushCredentialsVoip: %@ type:%@", credentials.token, type);
   
   NSString* newToken = [credentials.token description];
  	newToken = [newToken stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
   newToken = [newToken stringByReplacingOccurrencesOfString:@" " withString:@""];
   
   void setVPushToken(const char *p);
   setVPushToken(newToken.UTF8String);
   //TODO should I tell the server about old token ?? or invalid token
}

- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(NSString *)type {
   NSLog(@"didInvalidatePushTokenForType");
}

time_t iLastPushVoipAt=0;


- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type{
   NSLog(@"didReceiveIncomingVoipPushWithPayload %@: state:%d",type, [UIApplication sharedApplication].applicationState);
   NSLog(@"payload %@",payload.dictionaryPayload);
   iLastPushVoipAt = time(NULL);
   
   
   int getPhoneState(void);
   //if app is not online kill tls sock, create new try to go online
   if(secSinceAppStarted()>20 && getPhoneState()!=2 && calls.getCallCnt()==0){
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
         
         [self short_sleep_and_check_exit:3000 step:200];
         
         if(!iExiting && getPhoneState()!=2 && calls.getCallCnt()==0){//if still we are not online and we do not have a call
            doCmd(":force.network_reset");
         }
      });
   }

}

#ifndef T_DISABLE_REGULAR_PUSH
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    NSLog(@"[Push didReceiveRemoteNotification:fetchCompletionHandler %@]", userInfo);
   //TODO
   //if incoming call, show call screen
   sleep(1);//TODO trst
   
   completionHandler(UIBackgroundFetchResultNewData);
   
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
   NSLog(@"[Push: %@]", userInfo);
   /*
    for (id key in userInfo)
    {
    NSLog(@"key: %@, value: %@", key, [userInfo objectForKey:key]);
    }
    
    NSLog(@"remote notification: %@",[userInfo description]);
    NSDictionary *apsInfo = [userInfo objectForKey:@"aps"];
    
    NSString *alert = [apsInfo objectForKey:@"alert"];
    NSLog(@"Received Push Alert: %@", alert);
    
    NSString *sound = [apsInfo objectForKey:@"sound"];
    NSLog(@"Received Push Sound: %@", sound);
    
    NSString *badge = [apsInfo objectForKey:@"badge"];
    NSLog(@"Received Push Badge: %@", badge);
    application.applicationIconBadgeNumber = [[apsInfo objectForKey:@"badge"] integerValue];
    
    UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:@"Notification" message:alert delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];
    [alertView release];
    */
}

- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken: (NSData*)deviceToken{
   NSLog(@"My token is: %@", deviceToken);
   
   NSString* newToken = [deviceToken description];
  	newToken = [newToken stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
   newToken = [newToken stringByReplacingOccurrencesOfString:@" " withString:@""];
   
   void setPushToken(const char *p);
   setPushToken(newToken.UTF8String);
}

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError: (NSError*)error{
   NSLog(@"Failed to get token, error: %@", error);
   
}
#endif
#pragma mark - UIApplication notifications

- (NSUInteger)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window{
   return iVideoScrIsVisible==1 ? (UIInterfaceOrientationMaskAll):(UIInterfaceOrientationMaskPortrait|UIInterfaceOrientationMaskPortraitUpsideDown);//UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight;
}

 - (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void(^)())completionHandler {
    //{"aps":{"alert":"Hello Testing","badge":1,"sound":"default","category":"your_category_key"}}
    /*
     UIMutableUserNotificationAction *notificationAction2 = [[UIMutableUserNotificationAction alloc] init];
     notificationAction2.identifier = @"Reject";
     notificationAction2.title = @"Reject";
     notificationAction2.activationMode = UIUserNotificationActivationModeBackground;
     notificationAction2.destructive = YES;
     notificationAction2.authenticationRequired = YES;
     
     UIMutableUserNotificationCategory *notificationCategory = [[UIMutableUserNotificationCategory alloc] init];
     notificationCategory.identifier = @"Email";
     [notificationCategory setActions:@[notificationAction1,notificationAction2,notificationAction3] forContext:UIUserNotificationActionContextDefault];
     [notificationCategory setActions:@[notificationAction1,notificationAction2] forContext:UIUserNotificationActionContextMinimal];
     
     NSSet *categories = [NSSet setWithObjects:notificationCategory, nil];
     */
 
    NSLog(@"handleActionWithIdentifier:forRemoteNotification: %@", userInfo);
     completionHandler();
 }
 /*
 - (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification completionHandler:(void(^)())completionHandler{
 }
 */

- (void)application:(UIApplication *)app didReceiveLocalNotification:(UILocalNotification *)notif {
    
    //[[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil] instantiateViewControllerWithIdentifier:@"ViewController"];
    
    NSString *userName = [notif.userInfo objectForKey:@"contactName"];
    UITabBarController *tabBarContrller = (UITabBarController *)self.window.rootViewController;
    [self checkForLockAlert];
    
    if(userName)
        [[Utilities utilitiesInstance] assignSelectedRecentWithContactName:userName];
    
    if(userName && tabBarContrller.selectedIndex != 4)
    {
        tabBarContrller.selectedIndex = 4;
        
        
        UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Chat" bundle:nil];
        UIViewController *chatViewController = [storyBoard instantiateViewControllerWithIdentifier:@"ChatViewController"];
        
        UINavigationController *navigationViewC = (UINavigationController *)tabBarContrller.selectedViewController;
        
        // pop chat viewcontroller since we are going to present a new one
        [navigationViewC popViewControllerAnimated:YES];
        [navigationViewC pushViewController:chatViewController animated:YES];
        [uiTabBar selectSeperatorWithTag:4];
    }
    else if(![notif.userInfo objectForKey:@"call_id"])
    {
        // we dont know if chat is open or not, so just pop to root and push new chat view
        
        UINavigationController *navigationViewC = (UINavigationController *)tabBarContrller.selectedViewController;
        [navigationViewC popToRootViewControllerAnimated:NO];
        UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Chat" bundle:nil];
        UIViewController *chatViewController = [storyBoard instantiateViewControllerWithIdentifier:@"ChatViewController"];
        [navigationViewC pushViewController:chatViewController animated:YES];
    }
    //
   // Handle the notificaton when the app is running
//   NSLog(@"Recieved Notification %@",notif);
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation{
    NSLog(@"Recieved openURL %@ %@",[url absoluteString],sourceApplication);
    
    if ([[url scheme] isEqualToString:@"file"])
    {
        [Utilities utilitiesInstance].deepLinkUrl = url;
        [uiMainTabBarController setSelectedIndex:4];
        UITabBarController *tabBarContrller = (UITabBarController *)self.window.rootViewController;
        tabBarContrller.selectedIndex = 4;
        
        
        UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Chat" bundle:nil];
        UIViewController *searchViewController = [storyBoard instantiateViewControllerWithIdentifier:@"SearchViewController"];
        UINavigationController *navigationViewC = (UINavigationController *)tabBarContrller.selectedViewController;
        
        // pop chat viewcontroller since we are going to present a new one
        [navigationViewC popViewControllerAnimated:YES];
        
        [navigationViewC pushViewController:searchViewController animated:YES];
        [uiTabBar selectSeperatorWithTag:4];
        return YES;
    }
    
    
   const char *p=[[url absoluteString] UTF8String];
   int l=[url absoluteString].length;
   
   int isProvisioned(int iCheckNow);
   int provOk=isProvisioned(0);
   
   if(!provOk){
      return YES;
   }
   
   
   int isSPURL(const char *p, int &l);
   int iIs=isSPURL(p, l);
   
   
   if(l>0 && iIs)
      [self setText:[NSString stringWithUTF8String:p+iIs]];
   
   [uiMainTabBarController setSelectedIndex:3];
    [uiTabBar selectSeperatorWithTag:3];
   
   return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    [[[[UIApplication sharedApplication] delegate] window] endEditing:YES];
	
    /*DELETE*/
    /*
   //we have to disable splash screen when app goes to background
   if(0){
      if (!_splashVC) {
         UIStoryboard *splashStoryBoard = [UIStoryboard storyboardWithName:@"LaunchScreen" bundle:nil];
         _splashVC = [splashStoryBoard instantiateViewControllerWithIdentifier:@"LaunchScreenVC"];
      }
      [self.window.rootViewController presentViewController:_splashVC animated:NO completion:nil];
   }
	*/
    
   // [UIApplication sharedApplication].applicationIconBadgeNumber|=16;
   // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
   // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

//UIBackgroundTaskIdentifier uiBackGrTaskID_calls = UIBackgroundTaskInvalid;


-(void) atBackgroundNetwork{
   int iSec=1;
   iIsTmpWorkingNetCalls++;
   NSLog(@"background network");
   usleep(1000);
   NSTimeInterval t;
   for(int i=0;i<30 && iIsInBackGround;i++){
      sleep(1);
      iSec++;
      //TODO test how Long we are online

      if(i>4){
         if(i&1){
            const char *all_on=sendEngMsg(NULL,"all_online");
            int iAllOn = all_on && strcmp(all_on,"true")==0;
            if(iAllOn)break;
         }
         t=[[UIApplication sharedApplication] backgroundTimeRemaining];
         if(t<20)break;
      }
   }
   
//   NSLog(@"[end backTask netw=%d %f]",iSec,[[UIApplication sharedApplication] backgroundTimeRemaining]);
   iIsTmpWorkingNetCalls--;
   if(iIsInBackGround)
     sleep(1);
   
  // if(bgTask &&  bgTask!=UIBackgroundTaskInvalid){

   //}
}

-(void) atBackgroundCall{
   int iSec=2;
   iIsTmpWorkingNetCalls++;
   NSLog(@"background received a call");
   //TODO fixSock
   usleep(1000);
   NSTimeInterval t;
   for(int i=0;i<55 && iIsInBackGround;i++){
      sleep(1);
      if(calls.getCallCnt(CTCalls::eStartupCall)==0){
         if(i<20)sleep(2);//give some time to release a call
         break;
      }
      iSec++;
      
      if(i>6){
         t=[[UIApplication sharedApplication] backgroundTimeRemaining];
         if(t<10)break;
      }
   }
   
   iIsTmpWorkingNetCalls--;
   if(iIsInBackGround)
      sleep(1);

   
}

-(void)startBackgrTask_test_netw{
   
   //if(uiBackGrTaskID_calls!=UIBackgroundTaskInvalid)return;
   UIApplication *app=[UIApplication sharedApplication];
   
   //if(UIApplicationStateBackground!=app.applicationState)return ;
   
   if(!iIsInBackGround)return;
   
   
   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      __block UIBackgroundTaskIdentifier bgTask = UIBackgroundTaskInvalid;
      
      bgTask=[app beginBackgroundTaskWithExpirationHandler:^{
         
         //if(bgTask && bgTask!=UIBackgroundTaskInvalid)
         [app endBackgroundTask:bgTask];
         bgTask = UIBackgroundTaskInvalid;
         //  bgTask=UIBackgroundTaskInvalid;
         
      }];
      if(bgTask == UIBackgroundTaskInvalid)NSLog(@"bgTask_netw fail");
      [self atBackgroundNetwork];
      NSLog(@"going to sleep 3.[%d] bgtr=%f",bgTask, [[UIApplication sharedApplication] backgroundTimeRemaining]);
      [[UIApplication sharedApplication] endBackgroundTask:bgTask];
      NSLog(@"going to sleep 3");
      bgTask = UIBackgroundTaskInvalid;
      
   });
   
}
-(void)startBackgrTask_test{
   
   //if(uiBackGrTaskID_calls!=UIBackgroundTaskInvalid)return;
   UIApplication *app=[UIApplication sharedApplication];
   
   //if(UIApplicationStateBackground!=app.applicationState)return ;
   
   if(!iIsInBackGround)return;
   

   
   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      __block UIBackgroundTaskIdentifier bgTask = UIBackgroundTaskInvalid;
      
      bgTask=[app beginBackgroundTaskWithExpirationHandler:^{
         
         [app endBackgroundTask:bgTask];
         bgTask = UIBackgroundTaskInvalid;
         //  bgTask=UIBackgroundTaskInvalid;
         
      }];
      if(bgTask == UIBackgroundTaskInvalid)NSLog(@"bgTask fail");
      [self atBackgroundCall];
      NSLog(@"[end backTask_c=%f]",[app backgroundTimeRemaining]);
      [[UIApplication sharedApplication] endBackgroundTask:bgTask];
      bgTask = UIBackgroundTaskInvalid;
      
   });
   
}

-(void)tryWorkInBackground{
   
   const char *xr[]={"",":onbackground"};
   z_main(0,2,xr);
   
   UIApplication *app=[UIApplication sharedApplication];

   iIsInBackGround=1;
   iSecondsInBackGroud=0;
   

   BOOL yes=[app setKeepAliveTimeout:(UIMinimumKeepAliveTimeout) handler: ^{
      [self keepalive2];
   }];
   
   NSLog(@"bg=%d mi=%d",(int)yes, (int)UIMinimumKeepAliveTimeout+5);

#if defined(_WAKE_FROM_BACKGROUD_SLOW)
   [self performSelectorOnMainThread:@selector(keepalive2)    withObject:nil waitUntilDone:YES];
#else

   //uiBackGrTaskID

   //TODO if uiBackGrTaskID is ok, then sleep(1)*40,rereg(600s),sleep(1)*20,endBackgroundTask
   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      __block UIBackgroundTaskIdentifier bgTask = UIBackgroundTaskInvalid;
      bgTask=[[UIApplication sharedApplication]  beginBackgroundTaskWithExpirationHandler:^{
         
         //if(uiBackGrTaskID && uiBackGrTaskID!=UIBackgroundTaskInvalid)
         [[UIApplication sharedApplication] endBackgroundTask:bgTask];
         bgTask = UIBackgroundTaskInvalid;
         // uiBackGrTaskID=NULL;
         
      }];
      printf("[task0=%d]",bgTask);
      [self atBackgroundStart:bgTask];
      printf("[task1=%d]",bgTask);
      [[UIApplication sharedApplication] endBackgroundTask:bgTask];
      bgTask = UIBackgroundTaskInvalid;
      
   });
#endif
   NSLog(@".abc back.");
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
   [[LocationManager locationManagerInstance].locationManager stopUpdatingLocation];
    
    // start counting lock time
    NSMutableDictionary *delayDict = [[[NSUserDefaults standardUserDefaults] objectForKey:@"lockTimeDict"] mutableCopy];
    int isActive = [[delayDict objectForKey:@"isActive"] intValue];
    
    if(isActive == 0)
    {
        [delayDict setValue:[NSNumber numberWithLong:time(NULL)] forKey:@"lockTime"];
    }
    
    [delayDict setValue:[NSNumber numberWithInt:1] forKey:@"isActive"];
    [[NSUserDefaults standardUserDefaults] setValue:delayDict forKey:@"lockTimeDict"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // invalidate and remove burn timers when user closes app
    [[Utilities utilitiesInstance] invalidateBurnTimers];
    
    /*
    // FIX: dissapearing tab bar after launch
    // must pop viewcontrollers with hidesBottomBarWhenPushed = YES
    
    UITabBarController *tabBarController = (UITabBarController *)self.window.rootViewController;
    UIViewController *viewC = tabBarController.selectedViewController;
    if([viewC isKindOfClass:[UINavigationController class]])
    {
        UINavigationController *navigationViewC = (UINavigationController *) viewC;
        [navigationViewC popToRootViewControllerAnimated:NO];
    }
     */
    
   NSLog(@"applicationDidEnterBackground");//ViewControllerWithBottomBar
   [nr setText:@""];
    
    // put it back if everything fails
  // [uiMainTabBarController setSelectedIndex:3];
    //[uiTabBar selectSeperatorWithTag:3];
   
    
   /*
    //bugy
   UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.window.bounds];
   imageView.tag = 50105;
   [imageView setImage:[Prov getSplashImage]];
   [UIApplication.sharedApplication.keyWindow.subviews.lastObject addSubview:imageView];
   [imageView release];
   */

   [recentsController saveRecents];
   
   [self tryHideAlertView];
   
   [self tryStopCallScrTimer:1];
   
   if(!iExiting){
      if(vvcToRelease && iVideoScrIsVisible) [vvcToRelease onGotoBackground];
      {const char *xr[]={"",":d"};z_main(0,2,xr);}//stop dtmf player
      [self tryWorkInBackground];
      [self stopRingMT];
   }
   calls.relCallsNotInUse();
    
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[UITableViewCell appearance] setBackgroundColor:[UIColor clearColor]];
    
#pragma mark Configure TabBar    
    // Replace MainTabBarControllers Contacts view controller from MainWindow.xib with
    // SilentContactsViewController from Contacts storyboard.
    NSMutableArray* controllersArray = [NSMutableArray arrayWithArray:uiMainTabBarController.viewControllers];
    UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Contacts" bundle:nil];
    UIViewController *contactsViewController = [storyBoard instantiateViewControllerWithIdentifier:@"ContactsNavigationViewController"];
    [controllersArray replaceObjectAtIndex:2 withObject:contactsViewController];
    [uiMainTabBarController setViewControllers:controllersArray animated:YES];
    uiMainTabBarController.delegate = self;
    
    [uiTabBar addSeperators];
    [Utilities utilitiesInstance].appDelegateTabBar = uiTabBar;
    UIColor *tbTint = [UIColor colorWithRed:0.965 green:0.953 blue:0.922 alpha:1];
    [[UITabBar appearance] setTintColor:tbTint];
    
    //10/13/15 - Accessibility for tabbaritems:
    // NOTE: accessibility labels are not VoiceOver enabled on UITabBarItem without titles.
    // Set titles and labels.
    ((UITabBarItem*)uiTabBar.items[0]).accessibilityLabel = ((UITabBarItem*)uiTabBar.items[0]).title = T_TRNS("Favorites");
    ((UITabBarItem*)uiTabBar.items[1]).accessibilityLabel = ((UITabBarItem*)uiTabBar.items[1]).title = T_TRNS("Recents");
    ((UITabBarItem*)uiTabBar.items[2]).accessibilityLabel = ((UITabBarItem*)uiTabBar.items[2]).title = T_TRNS("Contacts");
    ((UITabBarItem*)uiTabBar.items[3]).accessibilityLabel = ((UITabBarItem*)uiTabBar.items[3]).title = T_TRNS("Call");
    ((UITabBarItem*)uiTabBar.items[4]).accessibilityLabel = ((UITabBarItem*)uiTabBar.items[4]).title = T_TRNS("Text");
    // Loop thru tabbaritems and offset title out of view.
    for (UITabBarItem *tbItem in uiTabBar.items) {
        tbItem.isAccessibilityElement = YES;
        tbItem.titlePositionAdjustment = UIOffsetMake(0, 1000);
    }
    
    [Utilities utilitiesInstance].dialPadActionButtonView = actionButtonsView;
    [DBManager dBManagerInstance];
   NSLog(@"didFinishLaunchingWithOptions %d", application.applicationState);
   
   if(UIApplicationStateBackground==application.applicationState)
      [self tryWorkInBackground];
   
   //#SP-673
   
   if ([UIApplication instancesRespondToSelector:@selector(registerUserNotificationSettings:)]){
      
      /*
      UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert) categories:nil];
      [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
       */
      [self setupLocalIncomingCallNotif];
      
   }
   
   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      {const char *xr[]={"",":reg"};z_main(0,2,xr);}
      setPhoneCB(&fncCBRet,self);
   });
   
   
   
   if(getIOSVersion()>=8 || [UIApplication instancesRespondToSelector:@selector(registerForRemoteNotifications:)]){
    //--
#define T_DISABLE_REGULAR_PUSH
      
#ifndef T_DISABLE_REGULAR_PUSH
      const int iVoipOnly = 0;
      if(iVoipOnly){
         [application registerForRemoteNotifications];//we can not have two at the same time
      }
#else
      NSLog(@"[remote-notif=%d]",application.isRegisteredForRemoteNotifications);
      
//#SP-831
      if(time(NULL)<1430438400 && application.isRegisteredForRemoteNotifications){//expire: may 1 2015
         [application unregisterForRemoteNotifications];
      }
     // [application unregisterForRemoteNotifications];
    //
#endif
      [self setupVoipPush];
   }
   else{
      [application registerForRemoteNotificationTypes: UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge|UIRemoteNotificationTypeSound];//UIRemoteNotificationTypeNewsstandContentAvailability

   }
   
#pragma mark Provisioning Window
    // present provisioning VC if not yet provisioned
    int isProvisioned(int iCheckNow);
    int provOk=isProvisioned(0);
    if(!provOk){        
        [self setupAndDisplayProvisioningWindow];
    }
   
   
   [SP_FastContactFinder start];
   
   return YES;
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    UITabBarItem *item = [tabBarController.tabBar selectedItem];
    [uiTabBar selectSeperatorWithTag:(int)item.tag];
    if((tabBarController.selectedIndex == 1 || tabBarController.selectedIndex == 4))
    {
        [self checkForLockAlert];
    }
}

-(void) checkForLockAlert
{

    NSString *lockKey = [[NSUserDefaults standardUserDefaults] valueForKey:@"lockKey"];
    NSDictionary * delayInfo = [[NSUserDefaults standardUserDefaults] objectForKey:@"lockTimeDict"];
    NSNumber *delayTime = [delayInfo objectForKey:@"lockDelayTime"];
    NSNumber *delayTimeStamp = [delayInfo objectForKey:@"lockTime"];

    
    NSNumber *isActive = [delayInfo objectForKey:@"isActive"];
    
    
    long fullDelayTime = [delayTime intValue] + [delayTimeStamp intValue];
    if(fullDelayTime > time(NULL))
    {
        if([Utilities utilitiesInstance].lockedOverlayView)
        {
            [[Utilities utilitiesInstance].lockedOverlayView removeFromSuperview];
        }
        NSMutableDictionary *delayDict = [[[NSUserDefaults standardUserDefaults] objectForKey:@"lockTimeDict"] mutableCopy];
        [delayDict setValue:[NSNumber numberWithInt:0] forKey:@"isActive"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    UITabBarController *mainController = (UITabBarController*)  self.window.rootViewController;
    if(lockKey && (mainController.selectedIndex == 1 || mainController.selectedIndex == 4))
    {
        // has app been minimized after setting lock
        if([isActive intValue] == 1)
        {
            if(fullDelayTime < time(NULL))
            {
                if([Utilities utilitiesInstance].lockedOverlayView)
                {
                    [[Utilities utilitiesInstance].lockedOverlayView removeFromSuperview];
                }
                [Utilities utilitiesInstance].lockedOverlayView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [Utilities utilitiesInstance].screenWidth, [Utilities utilitiesInstance].screenHeight)];
                [[Utilities utilitiesInstance].lockedOverlayView setBackgroundColor:[UIColor blackColor]];
                
                [mainController.selectedViewController.view addSubview:[Utilities utilitiesInstance].lockedOverlayView];
                [[LockAlertDelegate lockAlertInstance] presentLockedAlertView];
            }
        }

    } else
    {
        if([Utilities utilitiesInstance].lockedOverlayView)
        {
            [[Utilities utilitiesInstance].lockedOverlayView removeFromSuperview];
        }

    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    if([Utilities utilitiesInstance].selectedRecentObject && [Utilities utilitiesInstance].selectedRecentObject.shareLocationTime > time(NULL))
    {
        [[LocationManager locationManagerInstance].locationManager startUpdatingLocation];
    }
    
	// make sure we don't have any lingering decrypted attachments lying around
	[SCFileManager cleanMediaCache];
	 // reinstantiate burn timers for every chatobject
   //GO: what will happen if we are reading data from DB a the same time ?
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    for (NSArray *conversationArray in [Utilities utilitiesInstance].chatHistory.allValues) {
        NSArray *a = [conversationArray mutableCopy];
        for (ChatObject *thisChatObject in a) {
            [[DBManager dBManagerInstance] setOffBurnTimerForBurnTime:thisChatObject.burnTime andChatObject:thisChatObject checkForRemoveal:YES];
        }
    }
    });
    
   NSLog(@"applicationWillEnterForeground");

   iIsInBackGround=0;
   
   if(vvcToRelease && iVideoScrIsVisible) [vvcToRelease onGotoForeground];
   
   if(!calls.getCallCnt()){
      [self stopRingMT];
      iCanHideNow=1;
      [self hideCallScreen:NO];
   }
   
   [[UIApplication sharedApplication]clearKeepAliveTimeout];
    
    [self checkForLockAlert];
   
   // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*DELETE*/
    /*
	if (0 && _splashVC) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [_splashVC dismissViewControllerAnimated:NO completion:nil];
            _splashVC = nil;
        });
	}
     */
    
	NSLog(@"applicationDidBecomeActive %d", application.applicationState);
   setPhoneCB(&fncCBRet,self);
   iIsInBackGround=0;
   
   [self tryStartCallScrTimer];
   
   [self showCallScrMT];
   
   [self checkBattery];
   
   [self makeDPButtons];

   [self loadCC];
   
   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      const char *xr[]={"",":onka",":onforeground"};//
      z_main(0,3,xr);
   });
   
/*
 bugy - the view sometimes stays,
   UIImageView *imageView = (UIImageView *)[UIApplication.sharedApplication.keyWindow.subviews.lastObject viewWithTag:50105];   // search by the same tag value
   [imageView removeFromSuperview];
*/
   
   
   [self init_or_reinitDTMF];
   
   int isProvisioned(int iCheckNow);
   int provOk=isProvisioned(0);
   
    if (provOk) {
        [self setOutgoingAccount:nil];
    }
    else if (!provOk && nil == _cachedWindow) {
        [self setupAndDisplayProvisioningWindow];
    }

    
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
   
   [recentsController resetBadgeNumber:false];
   
   
   MPVolumeView *myVolumeView =
   [[MPVolumeView alloc] initWithFrame: CGRectMake(switchSpktBt.bounds.origin.x, switchSpktBt.bounds.origin.y,switchSpktBt.bounds.size.width,switchSpktBt.bounds.size.height)];
   myVolumeView.showsVolumeSlider=NO;
   myVolumeView.showsRouteButton=YES;
   
   if(getIOSVersion()>=6){
      UIImage *imgRoute=[UIImage imageNamed:@"ico_speaker_bt.png"];
      [myVolumeView setRouteButtonImage:imgRoute forState:UIControlStateNormal];
      [myVolumeView setRouteButtonImage:imgRoute forState:UIControlStateHighlighted];
      [myVolumeView setRouteButtonImage:imgRoute forState:UIControlStateSelected];
   }
   myVolumeView.center=switchSpktBt.center;
   
   [switchSpktBt addSubview: myVolumeView];
   myVolumeView.tag=55011;
   [myVolumeView release];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
   // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
   iExiting=1;
   
   NSLog(@"Terminating app");
   
   if(iIsInBackGround){
      iIsInBackGround=0;
      [[UIApplication sharedApplication] clearKeepAliveTimeout];
   //   if(uiBackGrTaskID && uiBackGrTaskID!=UIBackgroundTaskInvalid)[[UIApplication sharedApplication] endBackgroundTask:uiBackGrTaskID];
   }
   
   setAudioRouteChangeCB(NULL, self);
   
   void t_onEndApp();
   t_onEndApp();
   
   [internetReach stopNotifier];
   [internetReach release];
   [[NSNotificationCenter defaultCenter] removeObserver:self
                                                   name:UIKeyboardWillShowNotification object:nil];
   [[NSNotificationCenter defaultCenter] removeObserver:self
                                                   name:UIKeyboardWillHideNotification  object:nil];
   
   NSLog(@"Terminated");
}

-(void) short_sleep_and_check_exit:(int)msec step:(int)step{
   int stepNS = step * 1000;
   
   stepNS-=4;
   if(stepNS<5)stepNS=5;
   
   usleep(stepNS);
   for(int i=step; i<msec && !iExiting;i+=step)usleep(stepNS);
}


#pragma mark - backgroud

-(void) atBackgroundStart:(UIBackgroundTaskIdentifier)bg{
   
   printf("[task2=%d]",bg);

  // UIBackgroundTaskIdentifier bgTask = bg;//uiBackGrTaskID;
   
   iSecondsInBackGroud=0;
   iIsTmpWorkingInBackGround=1;
   usleep(1000);
   NSTimeInterval t;
   for(int i=0;i<30 && iIsInBackGround;i++){
      iSecondsInBackGroud++;
      sleep(1);
      if(i>6){
         t=[[UIApplication sharedApplication] backgroundTimeRemaining];
         if(t<20)break;
      }
   }
   if(iIsInBackGround){
      const char *xr[]={"",":onka"};//will rereg here
      z_main(0,2,xr);
      
      NSLog(@"rereg ");
      for(int i=0;i<60 && iIsInBackGround;i++){
         iSecondsInBackGroud++;
         sleep(1);
         if(i>2){
            if(i>10 && getReqTimeToLive()<1)break;
            t=[[UIApplication sharedApplication] backgroundTimeRemaining];
            if(t<10)break;
         }
         //TODO if all eng are online goto sleep
      }
   }
   iIsTmpWorkingInBackGround=0;
   
   if(iIsInBackGround){
      sleep(1);
      NSLog(@"going to sleep");
   }
   
//   if(iIsInBackGround && uiBackGrTaskID && uiBackGrTaskID!=UIBackgroundTaskInvalid)
  //    [[UIApplication sharedApplication] endBackgroundTask:uiBackGrTaskID];

 //  uiBackGrTaskID=NULL;
   
   
}


-(void) keepalive2{
   
   iIsTmpWorkingInBackGround=1;
   NSTimeInterval t=0;
   NSLog(@"KA waking up ");
   
   const char *xr[]={"",":onka"};//will rereg here
   z_main(0,2,xr);
   
   NSLog(@" ,rereg ok");
   
   for(int i=0;i<7 && iIsInBackGround;i++){
      iSecondsInBackGroud++;
      sleep(1);
      if(i>4){
         if(getReqTimeToLive()<1)break;
         t=[[UIApplication sharedApplication] backgroundTimeRemaining];
         if(t<2)break;
      }
   }
   iIsTmpWorkingInBackGround=0;
   NSLog(@"KA going to sleep bckgr=%ds rem=%fs\n", iSecondsInBackGroud,t);
}


-(void)loadCC{
   static int iCLoaded=0;
   if(iCLoaded)return ;
   iCLoaded=1;
   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      
      int iLen=0;
      char *p=iosLoadFile("Country.txt",iLen);
      if(p){
         initCC(p,iLen);
         delete p;
      }
   });
}

- (void)dealloc
{
   //	[navigationController release];
   //TODO releaseALL obj
   NSLog(@"dealloc 1");
   [btSAS release];
   [btChangePN release];
   [lbSecure release];
   [uiZRTP_peer release];
   [uiDur release];
   [fPadView release];
   [second release];
   if(callMngr)[callMngr release];
   [window release];
   callMngr=nil;
    [callButton release];
    [chatBtnInCallScr release];
	[actionButtonsView release];
    
    [_provRootVC release];
    [_provWindow release];
    [_cachedWindow release];
    
   [super dealloc];
   NSLog(@"dealloc ok");
}

-(IBAction)showSettings{
   
   static int iLoading=0;
   
   if(iLoading)return;
   iLoading=1;
   
   sList=new CTList();//
   void loadSettings(CTList *l);
   loadSettings(sList);
   [settings_ctrl setList:sList];
   
   
   iSettingsIsVisble=1;
   //presentViewController

   settings_ctrl.title = T_TRNS("Settings");
   [recentsController presentViewController:settings_nav_ctrl animated:YES completion:^(){}];
   //[recentsController presentModalViewController:settings_nav_ctrl animated:YES];
   iLoading=0;
}



-(IBAction)saveSettings{
   
   void saveCfgFromList(CTList *l,AppDelegate *s);
   prevEng = NULL; //reset dialer Helper cfg
   saveCfgFromList(sList, self);
   sList=NULL;
   [self settingsDone];
   
}

-(IBAction)settingsDone{
   [settings_nav_ctrl dismissViewControllerAnimated:YES completion:^(){}];
   iSettingsIsVisble=0;
   [self performSelector:@selector(showCallScrMT) withObject:nil afterDelay:1.5];
   CTList *l=sList;
   if(l){l->removeAll();sList=NULL;}
}

-(void) setNewCurCallMT{
   int cc=calls.getCallCnt();
   
   NSLog(@"setNewCurCallMT cc=%d",cc);
   
   if(cc<2)iShowCallMngr=0;
   if(cc==1){
      CTCall *c=calls.curCall;//calls.getLastCall();
      if(!c || ! (CTCalls::isCallType(c,CTCalls::ePrivateCall) || CTCalls::isCallType(c,CTCalls::eConfCall)) )c=calls.getLastCall();
      if(!c || c->iEnded){
         [self hideCallScreen:YES];
      }else{
         [self setCurCallMT:c];
         //self checkMedia:c
         if(vvcToRelease && iVideoScrIsVisible){
            if(!vvcToRelease.isBeingDismissed){
               iVideoScrIsVisible=0;
               [vvcToRelease.navigationController popViewControllerAnimated:YES];
            }
            
         }
      }
      //  [self updateCallDurMT
   }
   else if(cc>1){
      [self needShowCallMngr]; 
   }
   else [self hideCallScreen:YES];
}


-(void)needShowCallMngr{
   int cc=calls.getCallCnt();
   NSLog(@"show call mngr cc=%d",cc);

   iShowCallMngr=1;
   if(iCallScreenIsVisible){
      [self showCallManeger];
   }
}
#pragma mark - Local notifications

-(void)setupLocalIncomingCallNotif{
   if ([UIMutableUserNotificationAction class]
       && [UIMutableUserNotificationCategory class]
       && [[UIApplication sharedApplication] respondsToSelector:@selector(currentUserNotificationSettings)]
       && [[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)])
   {
      
      UIMutableUserNotificationAction *answerAction = [[UIMutableUserNotificationAction alloc] init];
      answerAction.identifier = @"ANSWER";
      answerAction.title = @"Answer";
      answerAction.activationMode = UIUserNotificationActivationModeBackground;//UIUserNotificationActivationModeForeground;
      answerAction.destructive = NO;
      answerAction.authenticationRequired = NO; // Ignored with UIUserNotificationActivationModeForeground mode (YES is implied)
      
      UIMutableUserNotificationAction *declineAction = [[UIMutableUserNotificationAction alloc] init];
      declineAction.identifier = @"DECLINE";
      declineAction.title = @"Decline";
      declineAction.activationMode = UIUserNotificationActivationModeBackground;
      declineAction.destructive = YES;
      declineAction.authenticationRequired = NO;
      /*
      UIMutableUserNotificationAction *silentAction = [[UIMutableUserNotificationAction alloc] init];
      silentAction.identifier = @"IGNORE_CALL";
      silentAction.title = @"Silence";
      silentAction.activationMode = UIUserNotificationActivationModeBackground;
      silentAction.destructive = NO;
      silentAction.authenticationRequired = NO;
      
      */
      UIMutableUserNotificationCategory *actionsCategory = [[UIMutableUserNotificationCategory alloc] init];
      actionsCategory.identifier = @"INCOMING_CALL_NOTIFICATION";
            // You may provide up to 4 actions for this context
      [actionsCategory setActions:@[answerAction, declineAction] forContext:UIUserNotificationActionContextDefault];
      [actionsCategory setActions:@[answerAction, declineAction] forContext:UIUserNotificationActionContextMinimal];
      
      
      UIMutableUserNotificationAction *endAction = [[UIMutableUserNotificationAction alloc] init];
      endAction.identifier = @"END_CALL";
      endAction.title = @"End Call";
      endAction.activationMode = UIUserNotificationActivationModeBackground;
      endAction.destructive = YES;
      endAction.authenticationRequired = NO;
      
      UIMutableUserNotificationCategory *endCategory = [[UIMutableUserNotificationCategory alloc] init];
      endCategory.identifier = @"CALL_NOTIFICATION";

      [endCategory setActions:@[endAction] forContext:UIUserNotificationActionContextDefault];
      [endCategory setActions:@[endAction] forContext:UIUserNotificationActionContextMinimal];
      
      UIUserNotificationSettings *currentNotifSettings = [UIApplication sharedApplication].currentUserNotificationSettings;
      
      UIUserNotificationType notifTypes = currentNotifSettings.types;
      if (notifTypes == 0) {
         notifTypes = UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
      }
      
      NSSet *cat = [NSSet setWithObjects:actionsCategory,endCategory,nil];
      
      UIUserNotificationSettings *newNotifSettings = [UIUserNotificationSettings settingsForTypes:notifTypes categories:cat];
      [[UIApplication sharedApplication] registerUserNotificationSettings:newNotifSettings];
   }
}

- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification completionHandler:(void (^)())completionHandler
{
   CTCall *c = NULL;
   
   if(notification.userInfo){
      NSString *s = [notification.userInfo objectForKey:@"call_id"];
      unsigned int strToUint(char* p);
      unsigned int cid = s ?  strToUint((char *)s.UTF8String) : 0;
      c = [self findCallById:cid];
   }
   
   NSLog(@"handleActionWithIdentifier %@ %u", identifier, c ? c->iCallId : 0);
   
   [self stopRingMT];
   
   if ([identifier isEqualToString:@"ANSWER"]) {
      if(c){
         [self answerCallN:c];
         [self notifyActiveCall:c];
      }
   }
   else if ([identifier isEqualToString:@"DECLINE"]) {
      if(c)[self endCallN:c];
   }
   else if ([identifier isEqualToString:@"END_CALL"]) {
      [self endCallBt];
   }
   else if ([identifier isEqualToString:@"IGNORE_CALL"]) {
      
   }
   
   // Delete the consumed notification
   [application cancelLocalNotification:notification];

   completionHandler();
}

-(void)notifyMissedCall:(CTCall *)c{
   if ([UIApplication sharedApplication].applicationState !=  UIApplicationStateActive) {
      // Create a new notification
      UILocalNotification* notif = [[[UILocalNotification alloc] init] autorelease];
      if (notif) {
         [self findName: c];
         notif.repeatInterval = 0;
         notif.alertAction = T_TRNS("Missed Call"); //?? c->incomCallPriority
         notif.alertBody =[NSString stringWithFormat: @"%@ %@",notif.alertAction, toNSFromTB(&c->nameFromAB)];
         notif.soundName = nil;

         [[UIApplication sharedApplication]  presentLocalNotificationNow:notif];
      }
   }
}

-(void)notifyIncomCall:(CTCall *)c{
   if ([UIApplication sharedApplication].applicationState !=  UIApplicationStateActive) {
      // Create a new notification
      UILocalNotification* notif = [[UILocalNotification alloc] init];
      if (notif) {
         notif.repeatInterval = 0;
         // toNSFromTB(&c->nameFromAB)
         NSString *p = [self findName:c];
         
         NSString *bestName = toNSFromTB(&c->nameFromAB);
         
         notif.alertBody =[NSString stringWithFormat: @"%@\n%@ %@ \n%@",T_TRNS("Incoming call"),bestName, p, toNSFromTB(&c->incomCallPriority)];
         //notif.alertAction = T_TRNS("Answer");
         notif.category = @"INCOMING_CALL_NOTIFICATION";
         //int useRetroRingtone();
         
         NSString *rt =  [NSString stringWithFormat: @"%s.caf",getRingtone()];
         
         notif.soundName = rt;// useRetroRingtone()?@"ring_retro.caf":@"ring.caf";
         
         notif.userInfo = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%u",c->iCallId ] forKey:@"call_id"];
         
         [[UIApplication sharedApplication]  presentLocalNotificationNow:notif];
         incomCallNotif=notif;
         
      }
   }
}

-(void)notifyActiveCall:(CTCall *)c{
   if ([UIApplication sharedApplication].applicationState !=  UIApplicationStateActive) {
      // Create a new notification
      UILocalNotification* notif = [[[UILocalNotification alloc] init] init];
      if (notif) {
         [self findName: c];
         notif.repeatInterval = 0;
         //name, call in progress, unlock screen to check security
         notif.alertAction = T_TRNS("Check security"); //?? c->incomCallPriority
        //%@\n //, toNSFromTB(&c->nameFromAB)
         notif.alertBody =[NSString stringWithFormat: @"%@", T_TRNS("Call in Progress\nUnlock screen to check security")];
         notif.soundName = nil;
         notif.category = @"CALL_NOTIFICATION";
         
         [[UIApplication sharedApplication]  presentLocalNotificationNow:notif];
         
         if(activeCallNotifaction){
            [activeCallNotifaction release];
         }
         activeCallNotifaction = notif;
         
      }
   }
}


-(void)incomingCall:(CTCall *)c{
   int cc=calls.getCallCnt();
   
   if(!cc)return;
   
   
   
   int d=(int)(getTickCount()-uiCanShowModalAt);
   if(second.isBeingDismissed || (d<0 && d>-5000)){
      
      [self performSelector:@selector(incomingCall:) withObject:nil afterDelay:1];
      return;
   }
   
   if(c){
      
      [self startBackgrTask_test];
      
      if(cc==1){
         [self setCurCallMT:c];
         
         [self notifyIncomCall:c];//will do this if app is in background
         
         void* playDefaultRingTone(int iIsInBack);
         
         //if i will fix this it will brake #SP-389 and #SP-433 (we have to play in background not via local notif)
         
         //#SP-834
         //#SP-833
         playDefaultRingTone(iIsInBackGround);
         
      }
      else{
         [self needShowCallMngr];
         int ca=calls.getCallCnt(calls.eStartupCall);
         if(ca){
            //beep
            char buf[64];
            sprintf(&buf[0],"*r%u",c->iCallId);
            sendEngMsg(c->pEng, &buf[0]);
         }
      }
      
   }
   
   if(cc==1){
      [self switchAR:iPrevCallLouspkrMode];//
      [self muteMic:0];
   }
   
   [self showCallScrMT];
   
}

-(void)updateRecents:(CTCall *)c{
   if(!c || c->iRecentsUpdated || !c->iInUse || (!c->iCallId && !c->bufDialed[0]))return;
   c->iRecentsUpdated=1;
   
   unsigned int tc = getTickCount();
   
   c->uiEndedAt = tc;
   c->uiRelAt = tc + 5000;//we have to set rel time, because we are saving on main thread
   if(!c->uiRelAt)c->uiRelAt=1;//if getTickCount()+5000 == 0
   
   [recentsController addToRecentsCall:c];
   
   if(c->iIsIncoming && !c->uiStartTime && !c->iDontAddMissedCall){
      [self notifyMissedCall: c];
   }

   
   /*
   
   // c->
   const char *pServ="Unknown";
   if(!c->pEng)c->pEng=getCurrentDOut();;
   if(c->pEng){
      int sz=0;
      char *pRet=(char*)findCfgItemByServiceKey(c->pEng, (char*)"tmpServ", sz, NULL, NULL);
      if(pRet && sz>0){
         pServ=pRet;
      }
      
   }
   char *_nr = &c->bufPeer[0];
   if(!_nr[0])_nr = &c->bufDialed[0];
   
   int len = strlen(_nr);
   
   if(c->iIsIncoming && _nr[0]!='+' && _nr[0]!='0' && isdigit(_nr[0]) && len>6 && len+1<sizeof(c->bufDialed)){//hack all numbers should start with +
      memmove(_nr+1,_nr,len+1);
      _nr[0]='+';
   }

   
   
   if(c->iIsIncoming && !c->uiStartTime){
      if(c->iDontAddMissedCall){
         //answered somewhere else
         [recentsController addToRecents:CTRecentsAdd::addReceived(&c->nameFromAB, _nr,c->szSIPCallId,0,pServ,1)];
      }
      else{
         [self notifyMissedCall: c];
         [recentsController addToRecents:CTRecentsAdd::addMissed(&c->nameFromAB, _nr,c->szSIPCallId,0,pServ)];
      }
   }
   else if(c->iIsIncoming)
      [recentsController addToRecents:CTRecentsAdd::addReceived(&c->nameFromAB, _nr,c->szSIPCallId,get_time()-(int)c->uiStartTime,pServ)];
   else 
      [recentsController addToRecents:CTRecentsAdd::addDialed(&c->nameFromAB, _nr,c->szSIPCallId,c->uiStartTime?(get_time()-(int)c->uiStartTime):0,pServ)];
    */
   
}

-(CTCall *)getEmptyCall:(int)iIsMainThread{
   
   return calls.getEmptyCall(iIsMainThread);
}
-(CTCall *)findCallById:(int)iCallId{
   
   return calls.findCallById(iCallId);
}


-(void)clearZRTP_infoMT{
   [btSAS setHidden:YES];
   [btChangePN setHidden:YES];
   [uiZRTP_peer setHidden:YES];
   [verifySAS setHidden:YES];
   
   [uiDur setText:@""];
   [uiMediaInfo setText:@""];
   [lbSecure setText:@"Connecting"];
   lbSecure.alpha=1.0;
   [lbSecure setHidden:NO];
   
}
//
#if 1
-(void)updateZRTP_infoMT:(CTCall*)c{
   
   if(vvcToRelease && iVideoScrIsVisible){
      [vvcToRelease showInfoView];
   }
   

   
   int iHideSASAndVerify = iCanShowSAS_verify==0 && iSASConfirmClickCount && iSASConfirmClickCount[0]<T_SAS_NOVICE_LIMIT && c->zrtpWarning.getLen()==0 && c->zrtpPEER.getLen()==0;
   
   
   
   int iShowPeer=(c->zrtpPEER.getLen()>0 || (!(c->iShowEnroll|c->iShowVerifySas) && c->bufSAS[0]));
   
   int iGreenDispName=(c->nameFromAB==&c->zrtpPEER);//if cache matches display name
   
   if(iShowPeer && iGreenDispName)iShowPeer=0;
   
   [lbDstName setTextColor:iGreenDispName?[UIColor greenColor]:[UIColor whiteColor]];
   
   
   if(iShowPeer){
      [uiZRTP_peer setHidden:NO];
      [uiZRTP_peer setText:toNSFromTB(&c->zrtpPEER)];
      [ivBubble setHidden:NO];
      [btChangePN setHidden:NO];
   }else {
      [uiZRTP_peer setHidden:YES];
      [ivBubble setHidden:YES];
      [btChangePN setHidden:YES];
   }
   int iSecureInGreen=0;
   
   [btAntena setHidden:!c->iActive];
   
   
   if(c->iActive || (!c->iEnded && c->bufSecureMsg[0])){
      lbSecure.alpha=1.0;
      [lbSecure setHidden:NO];
      iSecureInGreen = c->setSecurityLines(lbSecure, lbSecureSmall);
   }
   else {
      [lbSecure setText:@""];
      [lbSecureSmall setText:@""];
   }
   
   if(c->bufSAS[0]){
      //[btSAS.titleLabel setFont:[UIFont fontWithName:@"Courier New" size:17]];
      
      if(c->bufSAS[4]!=0){//!base32 SAS
         [btSAS.titleLabel setFont:[UIFont systemFontOfSize:16]];
      }else{
         
         [btSAS.titleLabel setFont:[UIFont fontWithName:@"OCRB" size:17]];
         btSAS.titleLabel.adjustsFontSizeToFitWidth=YES;
      }
      btSAS.titleLabel.minimumScaleFactor = .6f;
      
      [btSAS setTitle:[NSString stringWithUTF8String:&c->bufSAS[0]] forState:UIControlStateNormal];
      [btSAS setHidden:NO];
      [verifySAS setHidden:NO];
      if(c->iShowEnroll || c->iShowVerifySas){
//         [self showVerifyBT];
         
         btSAS.alpha=1.0;
         verifySAS.alpha=1.0;
         btSAS.frame = CGRectMake(btSAS.frame.origin.x,btSAS.frame.origin.y,224, 49);
         
         [verifySAS.titleLabel setFont:[UIFont boldSystemFontOfSize:20]];
         [verifySAS.titleLabel setNumberOfLines:1];
         
         verifySAS.titleLabel.adjustsFontSizeToFitWidth=YES;
         verifySAS.titleLabel.minimumScaleFactor=0.4f;
         
         [verifySAS setBackgroundImage:[UIImage imageNamed:@"bt_blue.png" ] forState:UIControlStateNormal];
 
         [verifySAS setTitle:c->iShowVerifySas?T_TRNS("Touch and verify"):@"Trust PBX" forState:UIControlStateNormal];
         [verifySAS setEnabled:YES];
      }
      else{
         [verifySAS setEnabled:NO];
         [verifySAS.titleLabel setFont:[UIFont systemFontOfSize:12]];
         [verifySAS setTitle:T_TRNS("Verified") forState:UIControlStateDisabled];
         [verifySAS setBackgroundImage:nil forState:UIControlStateDisabled];
         [verifySAS setBackgroundImage:nil forState:UIControlStateNormal];
         //[verifySAS setImage:nil forState:UIControlStateNormal];
         btSAS.frame = CGRectMake(btSAS.frame.origin.x,btSAS.frame.origin.y,224, 21);
         btSAS.alpha=0.2;
         verifySAS.alpha=0.5;
      }
      
   }
   else{
      [verifySAS setHidden:YES];
      [btSAS setHidden:YES];
   }

   
   [self checkVideoBTState:c];
   
   
   int iCanEnableVBt=c->iActive && !c->iEnded && !c->iShowVerifySas && c->bufSAS[0] && c->zrtpPEER.getLen()>0;
   
   if(c->iShowVideoSrcWhenAudioIsSecure==1){
      
      if(iCanEnableVBt){
         c->iShowVideoSrcWhenAudioIsSecure=2;
         if(!iVideoScrIsVisible)[self showVideoScr:1 call:c];
      }
   }
}


#endif

-(void)checkVideoBTState:(CTCall *)c{
   int iCanEnableVBt=c->iActive && !c->iEnded && !c->iShowVerifySas && c->bufSAS[0] && c->zrtpPEER.getLen()>0;
   
   videoBT.enabled=!!iCanEnableVBt;
   
   int iCanAttachDetachVideo;
   
   if(0>=findIntByServKey(c->pEng,"iCanAttachDetachVideo",&iCanAttachDetachVideo)){
      [videoBT setHidden:!iCanAttachDetachVideo];
   }
   
}

- (void)onNewProximityState{
   BOOL b = UIAccessibilityIsVoiceOverRunning();
   NSLog(@"UIAccessibilityIsVoiceOverRunning()=%d",b);
   if(!b){
      return;
   }
   
   if([UIDevice currentDevice].proximityState){//if true device is close to user
      [self switchAR:0];
   }
   else{
      [self switchAR:1];
   }
}

-(int)showCallScrMT{
   if(iIsInBackGround){

      return 0;
   }

   int cc=calls.getCallCnt();
   NSLog(@"cc=%d",cc);
   if(!cc)return -1;
   
   if(cc==1){
      [self setCurCallMT:calls.getCall(0)];
   }
   [self tryShowCallScrMT];
   
   return 1;
}

-(IBAction)showCallScrPress{
   [self setCurCallMT:calls.curCall]; 
   [self tryShowCallScrMT];
}

-(void)checkLeds{
   int *pi=(int*)findGlobalCfgKey("iShowRXLed");
   int hideLeds=!pi || *pi==0;
   [iwLed setHidden:hideLeds];
   
   {
      CGPoint p = CGPointMake(
                              hideLeds ? iwLed.frame.origin.x : (iwLed.frame.origin.x+10),
                              uiMediaInfo.frame.origin.y
                              );
      
      
      CGRect r = CGRectMake(p.x, p.y, uiMediaInfo.frame.size.width, uiMediaInfo.frame.size.height);
      uiMediaInfo.frame = r;
   }
}

-(void)tryShowCallScrMT{
   NSLog(@"iCallScreenIsVisible=%d iSettingsIsVisble=%d",iCallScreenIsVisible,iSettingsIsVisble);
   
   if([ZIDViewController isZIDVisible])return;
   
   if(second.isBeingDismissed){
      [self performSelector:@selector(tryShowCallScrMT) withObject:nil afterDelay:1];
      return;
   }
   
   NSLog (@"res=%d %p",second==recentsController.presentedViewController,recentsController.presentedViewController);
   
   if(iSettingsIsVisble)return;
   if([ZIDViewController isZIDVisible])return;
   
   if(second==recentsController.presentedViewController)iCallScreenIsVisible=1;
   

   if(iCallScreenIsVisible || second.isBeingPresented){
      if(iShowCallMngr)
         [self showCallManeger];
      return ;
   }
   
    /*DELETE*/
//   if((recentsController.presentedViewController)
//		&& (![recentsController.presentedViewController isKindOfClass:[LaunchScreenVC class]])) {
//      return;
//   }
   
   iCallScreenIsVisible = 3;

   [self checkVolumeWarning];
   
   [self checkLeds];
   
   [self startMotionDetect];
   
   int isHeadphonesOrBT(void);
   
   if(!isHeadphonesOrBT()){
      UIDevice *device = [UIDevice currentDevice];
      device.proximityMonitoringEnabled = YES;
      if (device.proximityMonitoringEnabled == YES){
         NSLog(@"pr ok");
      }
   }

   //TODO checkSpkrState
   
   iAnimateEndCall=1;
   if(1){
      
      [self.navigationController setNavigationBarHidden:YES animated:NO];
      
      [recentsController presentViewController:second animated:YES completion:^(){
         iCallScreenIsVisible = 1;
         if(calls.getCallCnt()==1)[self setCurCallMT:calls.getLastCall()];
         [self tryStartCallScrTimer];
      }];
      
      [second setNavigationBarHidden:YES];
      
     // void LaunchThread(AppDelegate *p);
     // LaunchThread(self);

      
     // findIntByServKey(NULL, "iAudioUnderflow", &iAudioUnderflow);
   }
   
   
   if(iShowCallMngr)
      [self showCallManeger];
}

-(NSString *)findName:(CTCall *)c{
   
   // static CTMutex t;
   // t.lock();
   char bufRet[128];
   char bufRet2[128];
   
   char *p2=&c->bufPeer[0];
   if(!c->iIsIncoming && c->bufDialed[0]){
      p2=&c->bufDialed[0];
   }
   //remove server
   for(int i=0;i<sizeof(bufRet);i++){
      if(!p2[i])break;
      if(p2[i]=='@'){
         strncpy(bufRet,p2,i);
         bufRet[i]=0;
         p2=&bufRet[0];
         break;
      }
   }


   int ret=[self findName:p2 len:strlen(p2) pEng:c->pEng  bOut:&c->nameFromAB];
   
   if(fixNR(p2,bufRet2,sizeof(bufRet2)-1)>=0)
      p2=&bufRet2[0];
   
   if(ret>=0){
      
   }
   else if(c->iIsIncoming){
      c->findSipName();
   }
   return  [NSString stringWithUTF8String:p2];
   
}

-(NSString *)loadUserData:(CTCall*)c{
   
   // static CTMutex t;
   // t.lock();
   char bufRet[128];
   char bufRet2[128];
   
   char *p2=&c->bufPeer[0];   
   if(!c->iIsIncoming && c->bufDialed[0]){
      p2=&c->bufDialed[0];
   }

   for(int i=0;i<sizeof(bufRet);i++){
      if(!p2[i])break;
      if(p2[i]=='@'){
         strncpy(bufRet,p2,i);
         bufRet[i]=0;
         p2=&bufRet[0];
         break;
      }
   }
 
   if(fixNR(p2,bufRet2,sizeof(bufRet2)-1)>=0)
      p2=&bufRet2[0];
   
   if(c->iUserDataLoaded){
      if(!c->nameFromAB.getLen()){
         if(c->iActive)c->findSipName();
      }
      //      t.unLock();
      return [NSString stringWithUTF8String:p2];
   }
   c->iUserDataLoaded=1;
   
   int ret=[self findName:p2 len:strlen(p2) pEng:c->pEng  bOut:&c->nameFromAB];
   
   if(ret>=0){
      if(!c->img){
         c->img = [SP_FastContactFinder getPersonImage:ret];
         if(c->img){
            c->iUserDataLoaded=2;
            [c->img retain]; c->iImgRetainCnt++;
         }
         /*
         
         NSData *data = [recentsController getImageData:ret];
         if(data){
            // c->img=[UIImage imageWithData:data];
            c->img=[[UIImage alloc]initWithData:data];if(c->img)c->iImgRetainCnt++;
            
            [data release];
            if(c->img){
               c->iUserDataLoaded=2;
               [c->img retain]; c->iImgRetainCnt++;
            }
         }
          */
      }
   }
   else if(c->iIsIncoming){
      c->findSipName();

   }
   return [NSString stringWithUTF8String:p2];
}
-(void)unholdAndPutOthersOnHold:(CTCall*)c{
   if(!c)return;//or put all on hold
   calls.lock();
   int cc=calls.getCallCntIncudeDisappearing();
   
   
   [self holdCallN:c hold:0];
   
   
   //int n=0;
   for(int i=0;i<cc+1;i++){
      CTCall *ch=calls.getCall(i);
      if(!ch || ch->iEnded || !ch->iActive)continue;
      if(ch!=c){
         if(ch->iIsInConferece && c->iIsInConferece){
            [self holdCallN:ch hold:0];
         }
         else{
            [self holdCallN:ch hold:1];
         }
      }
      //  NSLog(@"%p %p %s",c,ch,ch->bufPeer);
   }
   calls.unLock();
}

-(void)setCallScrFlagMT:(const char *)pNr{
   
   int findCSC_C_S(const char *nr, char *szCountry, char *szCity, char *szID, int iMaxLen);
   char bufC[64],szCity[64],sz2[64];
	
   CGRect frameR = lbDst.frame;
   if(findCSC_C_S(pNr, &bufC[0], &szCity[0], &sz2[0],64)>0){
      strcat(sz2,".png");
      UIImage *im=[UIImage imageNamed: [NSString stringWithUTF8String:&sz2[0]]];
	  frameR.origin.x = callScreenFlag.frame.origin.x+callScreenFlag.frame.size.width+3;
	  lbDst.frame = frameR;
//      lbDst.center=CGPointMake(126,53);
      [callScreenFlag setImage:im];
   }
   else{
	  frameR.origin.x = callScreenFlag.frame.origin.x;
	  lbDst.frame = frameR;
//      lbDst.center=CGPointMake(100,53);
      [callScreenFlag setImage:nil];
   }
}

int iAnimatingKeyPadInCall=0;

-(int)setCurCallMT:(CTCall*)c{

   
   if(!c || !c->iInUse)return 0;
   
   //if(true) hide ZRTP peer popup window
   if(calls.curCall != c)[self tryHideAlertView];
   
   calls.setCurCall(c);
   
   int cc=calls.getCallCnt();
   if(!cc){
      NSLog(@"GUI Err no active calls");
      return -1;
   }
   
   [self checkVolumeWarning];
   
   [self unholdAndPutOthersOnHold:c];
   
   //TODO lockCalls
   
   [btAntena setHidden:!c->iActive];
   
   [backToCallBT setHidden:NO];
   
   
   int iShowAnswBt=c->mustShowAnswerBT();
   
   if(iShowAnswBt){
      if(isVideoCall(c->iCallId)){
         [answer setImage:[UIImage imageNamed:@"ico_camera.png"] forState:UIControlStateNormal];
      }
      else{
         [answer setImage:nil forState:UIControlStateNormal];
      }
   }
   

   [answer setHidden:!iShowAnswBt];
   
   [endCallBT setTitle:!iShowAnswBt || c->iEnded?T_TRNS("End Call"):T_TRNS("Decline") forState:UIControlStateNormal];
   
   if(!iAnimatingKeyPadInCall){

      [infoPanel setHidden:NO];
      [fPadView setHidden:NO];
      [view6pad setHidden:NO];
      [keyPadInCall setHidden:YES];
      [btHideKeypad setHidden:YES];
      [self setEndCallBT:0 wide:!iShowAnswBt];
   }

   
   fPadView.alpha=1.0;
   
   if(!c->iEnded && !c->iActive && c->bufSecureMsg[0])
      [self showZRTPPanel:0];
   else if(!c->iActive || c->iEnded)
      [self showInfoLabel:0];
   else if(c->iActive)
      [self showZRTPPanel:0];

   
   NSString *ci=[NSString stringWithUTF8String:&c->bufMsg[0]];
   [uiCallInfo setText:ci];
   
   if(!c->iActive){
      [uiMediaInfo setText:@""];
   }
   
   if((c->bufSecureMsg[0] || uiCallInfo.isHidden) && !c->iActive && !c->iEnded){
      [uiDur setText:ci];
      NSLog(@"ci=%@",ci);
   }
   else [uiDur setText:@""];
   
   if(!c->bufServName[0]){
      safeStrCpy(c->bufServName,getAccountTitle(c->pEng), sizeof(c->bufServName)-1);
     // strcpy(c->bufServName,getAccountTitle(c->pEng));
   }
   [uiServ setText:[NSString stringWithUTF8String:&c->bufServName[0]]];

   NSString *p2=[self loadUserData:c];
   
   if(c->img){
      [c->img retain];c->iImgRetainCnt++;
      [peerPB_Img setImage:nil];
      [peerPB_Img setImage:c->img];
   }
   else{
      [peerPB_Img setImage:nil];
   }
   const char *pUtfP2=[p2 UTF8String];
   
   [lbDstName setText:toNSFromTB(&c->nameFromAB)];

   //dont repeat if matches
   [lbDst setText:(c->nameFromAB==pUtfP2?@"":p2)];
   
   [self setCallScrFlagMT:pUtfP2];
   
   [self updateZRTP_infoMT:c];
   
   if(!c->iEnded){
      if(c->iIsIncoming && !c->iActive)view6pad.alpha=.3;
      else view6pad.alpha=1.0;
   }
    
   NSString *un = c->getUsernameFromCall();
    if(un.length > 0)
    {
        [chatBtnInCallScr setUserInteractionEnabled:YES];
        chatBtnInCallScr.alpha = 1.f;
    }else
    {
        [chatBtnInCallScr setUserInteractionEnabled:NO];
        chatBtnInCallScr.alpha = 0.6f;
    }
  // [self.chatBtn setHidden:un.length<1];
    
   return 0;
   
}

+(int)isAudioDevConnected{
   int isAudioDevConnected();
   return isAudioDevConnected();
}

-(int)callToR:(CTRecentsItem*)i{
   
   if(!i || i->peerAddr.getLen()<=0)return -1;
   
   void *findEngByServ(CTEditBase *b);
   void *eng = findEngByServ(&i->lbServ);
   if(!eng && i->lbServ.getLen()){
      UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"SIP account is disabled or deleted"
                                                      message:nil
                                                     delegate:nil
                                            cancelButtonTitle:@"Ok"
                                            otherButtonTitles:nil];
      [alert show];
      [alert release];
      return -1;
   }
   
   char buf[128];
   //i->peerAddr.getTextUtf8(buf, &ml);
   getText(&buf[0],127,&i->peerAddr);
   
   return [self callToCheckUS:'c' dst:&buf[0] eng:eng];
}

-(int)callTo:(int)ctype dst:(const char*)dst{
   return [self callToS:ctype dst:dst eng:NULL];
}

-(int)callToCheckUS:(int)ctype dst:(const char*)dst eng:(void*)eng{
   
   int canAddUS_CCode(const char *nr);
   if(0 && canAddUS_CCode(dst)){//KPN ??
      char dstnr[64];
      snprintf(dstnr, sizeof(dstnr)-1, "+1%s",dst );
      dstnr[63]=0;
      return [self callToS:ctype dst:dstnr eng:eng];
   }
   
   char buf[128];
   
   safeStrCpy(buf, dst, sizeof(buf)-2);
   
   int cleanPhoneNumber(char *p, int iLen);
   cleanPhoneNumber(buf, strlen(buf));
   
   char *newdst = &buf[0];
   
   if(strncmp(newdst, "sip:", 4)==0)newdst+=4;
   else if(strncmp(newdst, "sips:", 5)==0)newdst+=5;
   
   if(((newdst[0] =='+' || isdigit(newdst[0])) && canModifyNumber())){
      
      for(int n=0;;n++){
         if(!newdst[n])break;
         
         if(newdst[n]=='@'){
            void *findBestEng(const char *dst, const char *name);
            if(!eng)eng=findBestEng(dst,NULL);
            
            if(eng!=getCurrentDOut()){
               [self setOutgoingAccount:eng];
            }
            newdst[n]=0;
            break;
         }
      }
      if(!eng)eng=getCurrentDOut();

      if(canModifyNumber(eng)){
         
#if 0
         [uiMainTabBarController setSelectedIndex:3];
          [uiTabBar selectSeperatorWithTag:3];
         [self setText:[NSString stringWithUTF8String:newdst]];
#else
         
         // [uiMainTabBarController setSelectedIndex:3];
         NSString *n0 = [NSString stringWithUTF8String:newdst];
         
         if(newdst[0]!='+'){
            memmove(newdst+1, newdst, strlen(newdst)+1);newdst[0]='+';//we do support the numebers with only a + as prefix
         }
         printf("[newdst=%s]",newdst);
         
         NSString *n1 = [NSString stringWithUTF8String:newdst];
         NSString *n2 = [self getModifyedNumber:n0 reset:1 eng:eng];
         
#define T_MIN_NR_LEN_CAN_APPLY_DIAL_HELPER 6
         
         int n1n2 = [n1 isEqualToString:n2];
         
         if(newdst[0]=='+' && [n2 isEqualToString:n0] && strlen(newdst) < T_MIN_NR_LEN_CAN_APPLY_DIAL_HELPER){
            n1n2=1;
            memmove(newdst, newdst+1, strlen(newdst));//include '\0'
         }

         if(!n1n2){
            
            [n1 retain];
            [n2 retain];
            
            MZActionSheet *as = [[MZActionSheet alloc]initWithTitle:@"Call to" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:n1, n2,nil];
            
            [as setActionBlock:^(NSInteger v){
               if(v==0){
                  NSLog(@"ct=%@",n1);
                  [self callToS:ctype dst:n1.UTF8String eng:eng];
               }
               else if(v==1){
                  NSLog(@"ct=%@",n2);
                  [self callToS:ctype dst:n2.UTF8String eng:eng];
                  
               }
               [n1 release];
               [n2 release];
               [as release];
            }];
            
            [as showFromTabBar:uiTabBar];
            return 0;
         }
      }

#endif
   }
   
   return [self callToS:ctype dst:newdst eng:eng];
}

-(int)callToS:(int)ctype dst:(const char*)dst eng:(void*)eng{
   
   if(strncmp(dst,"*##*",4)==0){
      int l=strlen(dst);
      if(l>5 && dst[l-1]=='*'){
         //test AssociatedURI
         /*
         const char *u  = sendEngMsg(getAccountByID(0,1), "AssociatedURI");
         NSString * nsu = [NSString stringWithUTF8String:u];
         NSString *a1 =  [nsu componentsSeparatedByString:@","][0];
         printf("ret=%s\n",a1.UTF8String);
         
         NSString *a= [NSString stringWithFormat:@"AssociatedURI=%@",a1 ];
         puts(sendEngMsg(getAccountByID(0,1), a.UTF8String));
         
         return 0;
          */
         /*
         if(strcmp(dst+4,"tlsstresstest*")==0){
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
               for(int i=0;i<20;i++){
                 doCmd(":force.network_reset");
                  usleep(20000);
               }
            });
            return 0;
         }
         */
         /*
         const char *getAPIKey();
         printf("key=%s",getAPIKey());
         return 0;
*/
         if(strncmp(dst+4,"674",3)==0){
            char b[1024];
            snprintf(b, 1023, ":m %s",dst+4+3);
            for(int i=0;;i++){if(!b[i])break;if(b[i]=='.'){b[i]=' ';break;}}
            doCmd(b,getAccountByID(0, 1));
            return 0;
         }
         if(strcmp(dst+4,"112233*")==0){
             [Utilities utilitiesInstance].isLockEnabled = YES;
            void test_close_last_sock();
            test_close_last_sock();
            return 0;
         }
         
         if(strncmp(dst+4,"112244",6)==0){
            void test_send_options(const char *name);
            test_send_options(dst+4+6);
            return 0;
         }
         
         if(strcmp(dst+4,"668423*")==0){
            if(iSASConfirmClickCount){
               iSASConfirmClickCount[0]=0;
               void t_save_glob();
               t_save_glob();
            }
            return 0;
         }
         if(strcmp(dst+4,"735*")==0){
            calls.relCallsNotInUse();
            return 0;
         }

         if(strcmp(dst+4,"56466*")==0){//logon
            [self showChatTab];
            return 0;
         }
         int canEnableCFG();
         if(1){
            unsigned int calcMD5(const char *p, int iLen, int n);
            unsigned int code=calcMD5(dst+4,0,20000000);
            printf("[md5=0x%08x]\n",code);
            
            if(code==0x448683f6){
               void switchToTest443();
               switchToTest443();
               return 0;
            }
            
            if(code==0x58e7fa40 && canEnableCFG()){
               [self showAdvCfg];
               return 0;
            }
            if(code==0x678fe423){
               [self showBasicCfg];
               return 0;
            }

// Disable ZRTP ID cache diagnostic
            if(code == 0x1dbf0933){
               ZIDViewController *zid =[[ZIDViewController alloc]initWithNibName:@"ZIDViewController" bundle:nil];
               //zid->vc = recentsController;
               
               [recentsController presentViewController:zid animated:YES completion:^(){}];
               //  [self.navigationController  pushViewController:zid animated:YES];
               [zid release];
               return 0;
            }


         }
         
         const char *x[2]={"",dst};
         z_main(0,2,x); 
         return 0;
      }
   }
   
   CTCall *c=[self getEmptyCall:1];
   if(!c){
      return -1;
   }
   calls.setCurCall(c);
   
   strcpy(c->bufMsg,T_TR("Calling..."));//"Calling...");

   iShowCallMngr=0;
   if(strncmp(dst,"sip:",4)==0){
      dst+=4;
   }
   else if(strncmp(dst,"sips:",5)==0){
      dst+=5;
   }
   
   int iNRLen=strlen(dst);
   if(iNRLen>=sizeof(szLastDialed)-1){
      iNRLen=sizeof(szLastDialed)-1;
   }
   
   strncpy(szLastDialed,dst,iNRLen);
   szLastDialed[iNRLen]=0;
   
   int stripDotsIfNumber(char *p, int iLen);
   iNRLen = stripDotsIfNumber(szLastDialed, iNRLen);
   
   void *findBestEng(const char *dst, const char *name);
   void *pEng=eng?eng:findBestEng(szLastDialed,NULL);
   
   safeStrCpy(&c->bufDialed[0],szLastDialed,sizeof(c->bufDialed)-1);
   
   c->pEng=pEng;
   c->iShowVideoSrcWhenAudioIsSecure='c'!=ctype;
   char buf[128];
   snprintf(buf,127,":%c %s",ctype,szLastDialed);
   if(pEng){
      safeStrCpy(c->bufServName,getAccountTitle(pEng), sizeof(c->bufServName)-1);
      printf("[ds=%s, cmd={%s}]",c->bufServName,&buf[0]);
      sendEngMsg(pEng,&buf[0]);
   }
   else{
      const char *x[2];
      x[0]="";
      x[1]=&buf[0];
      z_main(0,2,x); 
   }
   
   [self setCurCallMT:c];
   
   if(calls.getCallCnt()==1){
      [self switchAR:iPrevCallLouspkrMode];// 
      [self muteMic:0];
   }
   
   [self setText:@""];

   
   if(![self showCallScrMT])return -2;

   
   return 0;
}

-(void)showAdvCfg{
   iCfgOn=2;
   [cfgBT setHidden:NO];
   //?? show cancel bt
   //rename ok to save 
}

-(void)showBasicCfg{
   iCfgOn=1;
   [cfgBT setHidden:NO];
   //?? show cancel bt
   //rename ok to save
}


-(IBAction)makeCall:(int)ctype{
   
   const char *p=[[nr text] UTF8String];
   if(!p[0]){
      [self pickContact];
      return;
   }
   [self callTo:ctype dst:p];

}
/*
 - (BOOL)textFieldShouldBeginEditing:(UITextField *)textField;        // return NO to disallow editing.
 - (void)textFieldDidBeginEditing:(UITextField *)textField;           // became first responder
 
 - (BOOL)textFieldShouldEndEditing:(UITextField *)textField{          // return YES to allow editing to stop and to resign first responder status. NO to disallow the editing session to end
 return NO;
 }
 */

-(void)clearDelayed{
   [self setText:@""];
   [nr resignFirstResponder];

}
- (BOOL)textFieldShouldReturn:(UITextField *)textField{
   [self chooseCallType];
   return NO;
}

- (BOOL) textFieldShouldClear:(UITextField *)textField{
   [nr resignFirstResponder];   
   [self performSelector:@selector(clearDelayed) withObject:nil afterDelay:.1];
   return NO;
}
- (void)textFieldDidEndEditing:(UITextField *)textField{             // may be called if forced even if shouldEndEditing returns NO (e.g. view removed from window) or endEditing:YES called
   
   [self numberChange];
}
-(void) hideCountryCity:(void*)unused{
   if(uiCanHideCountryCityAt>getTickCount())return;
   uiCanHideCountryCityAt=0;
   
   int findCSC_C_S(const char *nr, char *szCountry, char *szCity, char *szID, int iMaxLen);
   char bufC[64],szCity[64],sz2[64];
   if(findCSC_C_S([nr text].UTF8String, &bufC[0], &szCity[0], &sz2[0],64)>0){
      char buf[4]={toupper(sz2[0]),toupper(sz2[1]),0,0};
      [countryID setText: [NSString stringWithUTF8String:&buf[0]]];
   }
   [lbNRFieldName setHidden:NO];
}

-(IBAction)onFlagClick{
   int findCSC_C_S(const char *nr, char *szCountry, char *szCity, char *szID, int iMaxLen);
   char bufC[64],szCity[64+64+4],sz2[64];
   szCity[0]=0;
   if(findCSC_C_S([nr text].UTF8String, &bufC[0], &szCity[0], &sz2[0],64)>0){
      if(szCity[0])strcat(szCity,", ");
      strcat(szCity,bufC);
      [countryID setText: [NSString stringWithUTF8String:&szCity[0]]];
      uiCanHideCountryCityAt=getTickCount()+2000;
      [self performSelector:@selector(hideCountryCity:) withObject:nil afterDelay:3];
      [lbNRFieldName setHidden:YES];
   }
   
}

-(int)checkCC_FLAG_CountryLabels{
   
   int findCSC_C_S(const char *nr, char *szCountry, char *szCity, char *szID, int iMaxLen);
   char bufC[64],szCity[64],sz2[64];
   static char prevsz2[5];
   int iOfsX=0;
   if(findCSC_C_S([nr text].UTF8String, &bufC[0], &szCity[0], &sz2[0],64)>0){
      
      char buf[4]={toupper(sz2[0]),toupper(sz2[1]),0,0};
      [countryID setText: [NSString stringWithUTF8String:&buf[0]]];
      
      
      if(strcmp(prevsz2,sz2)){
         strcpy(prevsz2,sz2);
         strcat(sz2,".png");
         UIImage *im=[UIImage imageNamed: [NSString stringWithUTF8String:&sz2[0]]];
         [nrflag setImage:im];
      }
      iOfsX = nrflag.frame.size.width+5;
      
      CGFloat actualFontSize;
      [nr.text sizeWithFont:nr.font
                minFontSize:nr.minimumFontSize
             actualFontSize:&actualFontSize
                   forWidth:nr.bounds.size.width
              lineBreakMode:UILineBreakModeTailTruncation];
      
      CGPoint c=nrflag.center;
      
      actualFontSize/=1.15f; 
      nrflag.frame=CGRectMake(nrflag.frame.origin.x,nrflag.frame.origin.y,nrflag.frame.size.width,actualFontSize);
      nrflag.center=c;
      
      [nrflagBt setHidden:NO];
      
      

   }
   else{
      [nrflagBt setHidden:YES];
      prevsz2[0]=0;
      [nrflag setImage:nil];
      [countryID setText:@""];
   }
   

  // nr.frame = CGRectMake(iOfsX, nr.frame.origin.y, self.window.frame.size.width-iOfsX, nr.frame.size.height);

//   void freemem_to_log();freemem_to_log();
   return 0;   
}

- (void)textFieldDidBeginEditing:(UITextField *)textField{
   [btQwerty setHidden:YES];
   [btShowCSDPad setHidden:NO];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string   // return NO to not change text
{
   // [self numberChange];
   return YES;
}

-(IBAction)textFieldReturn:(id)sender
{
   [btShowCSDPad setHidden:YES];
   [btQwerty setHidden:NO];
   [sender resignFirstResponder];
   [nr resignFirstResponder];
} 

#define CHECK_NAME_DELAYMS 500
-(void)forceFindName {
	iMustSearch = 1;
	[self tryFindName:nil];
}

-(void)tryFindName:(int*)unused{
   
   // return;
   static int iIn=0;
   if(iIn)return;
   
   if(!iMustSearch || uiNumberChangedAt+CHECK_NAME_DELAYMS>getTickCount() || iIsClearBTDown>0)return;
   iMustSearch=0;
   iIn=1;
   const char *p=[nr.text UTF8String];
   int l=nr.text.length;
   CTEditBuf<128> bOut;
   
   
   int ret=[self findName:p len:l pEng:getCurrentDOut() bOut:&bOut];
   if(ret>=0)[lbNRFieldName setText:toNSFromTB(&bOut)];else [lbNRFieldName setText:@""];
   iIn=0;
}

-(IBAction)numberChange{
   int l=nr.text.length;
   if(l==0) [nr resignFirstResponder];
   uiNumberChangedAt=getTickCount();
   iMustSearch=1;
   
   if(!l){
      [lbNRFieldName setText:@""];
   //   backspaceBT.accessibilityLabel=@"backspace";
   }
   else{
      [self performSelector:@selector(tryFindName:) withObject:nil afterDelay:((float)CHECK_NAME_DELAYMS/1000.f)+0.1f];
   }
   [self checkCC_FLAG_CountryLabels ];
   [self checkQwertyKeypad:l];
   
   
}
-(int)findName:(const char*)p len:(int)len pEng:(void *)pEng bOut:(CTEditBase *)bOut{
   
   if(len>4 &&  strncmp(p,"sip:",4)==0){
      len-=4;p+=4;
   }
   if(len<1)return -1;
   
   int l=len;
   int r;
   
   CTEditBuf<128> b;
   b.setText(p,l);
   
   if(1){
      int iHasAt=0;
      for(int i=0;i<l;i++){if(p[i]=='@'){iHasAt=1;break;}}
      
      if(!iHasAt){

         int iSize=0;
         
         if(!pEng)pEng=getCurrentDOut();
         
         char *ret=(char*)findCfgItemByServiceKey(pEng, (char*)"tmpServ", iSize, NULL, NULL);
         
         if(ret){
            b.addChar('@');
            b.addText(ret);
         }
      }
   }
   CTEditBuf<128> out;
   
   r=[recentsController findContactByEB:&b outb:&out];
   if(r>=0 && out.getLen())
      bOut->setText(out);
   return r;
}

int canModifyNumber(void *eng){
   if(!canModifyNumber())return 0;
   if(!eng)return 0;
   
   int* findIntByServKey(void *pEng, const char *key);
   
   static int *iDisableDialingHelper=findIntByServKey(eng, "iDisableDialingHelper");
   if(prevEng!=eng){
      prevEng = eng;
      iDisableDialingHelper=findIntByServKey(eng, "iDisableDialingHelper");
   }
   
   return iDisableDialingHelper? !(*iDisableDialingHelper) : 0 ;
}

-(NSString*) getModifyedNumber:(NSString *)ns reset:(int)reset eng:(void*)curDO{
   int iCanModifyNumber = canModifyNumber(curDO);

   if(iCanModifyNumber){
      if(ns.length<1 || reset)pDialerHelper->clear();
   
      static const char *r = (const char *)findGlobalCfgKey("szDialingPrefCountry");
      //
      pDialerHelper->setID(r);
      
      ns = [NSString stringWithUTF8String:pDialerHelper->tryUpdate(ns.UTF8String)];
      ns = [NSString stringWithUTF8String:pDialerHelper->tryRemoveNDD(ns.UTF8String)];
   }
   return ns;
}

-(void)setText:(NSString *)ns{
   
   ns = [self getModifyedNumber:ns reset:0  eng:getCurrentDOut()];

   [nr setText:checkNrPatterns(ns)];
   [self numberChange];
}

-(IBAction)clearEditUP{
   iIsClearBTDown=-5;
}

-(void) clearEditRep:(int *)rep{
   
   int i=iIsClearBTDown;
   int l=[[nr text]length];
   if(l>0 && i>0){
      const char *p=[nr text].UTF8String;
      int iSlowDown=0;
      if(p[l-1]=='@' && i>2){
         iSlowDown=1;
      //   iIsClearBTDown=i=1;//slow down when we see @.
      }
      else
      if(l>2 && p[l-2]=='@' && i>2){
         iSlowDown=1;
         //iIsClearBTDown=i=1;//slow down when we see @.
      }
      
      int rm=((p[l-1]==' ' || p[l-1]=='-' || p[l-1]=='(' || p[l-1]==')')?2:1);
      if(rm==2 && l>2 && p[l-1]=='(' && p[l-2]==' ')rm=3;
   
      while(rm<l && (p[l-rm-1]=='(' || p[l-rm-1]=='-' || p[l-rm-1]==' ') ){
         rm++;
      }
      if(rm>l)rm=l;
      int nl = l - rm;
      
      NSString *n= [[nr text] substringToIndex:nl];
      [self setText:n];

      int v=i<3 || iSlowDown?0:(i-1);
      NSTimeInterval ti=1/(v*v*v+.9)+.02;
      
      if(nl > 0)[self performSelector:@selector(clearEditRep:) withObject:nil afterDelay:ti];
      iIsClearBTDown++;
   }
}



-(IBAction)backgroundTouched:(id)sender
{
   [nr resignFirstResponder];
}

-(IBAction)clearEdit{
   
   iIsClearBTDown=1;
   
   [self clearEditRep:nil]; 
}


-(IBAction)pickContact{
   //  [nr 
   if([[nr text]length]>0){
      [recentsController showUnknownPersonViewControllerNS:[nr text]];
   }
   else [recentsController showPeoplePickerController];
}

-(void)updateLogTab{
   if(iExiting || objLogTab)return;
   int l;
   const char *t_getDevID(int &l);
   const char *t_getDevID_md5(void);
   const char *getPushToken(void);
   //iLastPushVoipAt
   void insertTimeDateFriendly(char  *buf, int iTime, int utc);
   NSString *ns= [NSString stringWithFormat:@"dev-id: %.*s-%.*s\n",4,t_getDevID(l),4,t_getDevID_md5()];
   char tt[128];
   if(iLastPushVoipAt){
      insertTimeDateFriendly(&tt[0], iLastPushVoipAt, 0);
      NSString *t=[NSString stringWithFormat:@"last-voip-push %s\n", tt];
      ns=[ns stringByAppendingString:t];
   }
   const char *pToken = getPushToken();
   if(pToken && pToken[0]){
      NSString *t=[NSString stringWithFormat:@"token-voip-push [%s]\n", pToken];
      ns=[ns stringByAppendingString:t];
   }
   
   for(int i=0;;i++){

      void *eng=getAccountByID(i,1);
      if(!eng)break;
      
      const char *p=sendEngMsg(eng,NULL);

      NSString *a=[NSString stringWithUTF8String:p];
      ns=[ns stringByAppendingString:a];
      ns=[ns stringByAppendingString:@"\n"];
     // [a release];
   }
   
   NSString *n = [[NSLocale systemLocale] localeIdentifier ];
   NSString *n2 = [[NSLocale currentLocale] localeIdentifier ];
   NSString *nf = [NSString stringWithFormat:@"LOCALE sys=[%@] client=%@\n",n,n2 ];
   
   ns=[ns stringByAppendingString:nf];
   
   const char *g_getInfo(const char *cmd);
   ns=[ns stringByAppendingString:[NSString stringWithUTF8String:g_getInfo(NULL)]];
   
   if(iLogPlus>0)
   {
      void t_read_log(int iLastNLines, void *ret, void(*fnc)(void *ret, const char *line, int iLen));
      T_Log l;
      l.ns=ns;
      t_read_log(100,&l,fnc_log);
      ns=l.ns;
      iLogPlus--;
   }
   
   if(ns && ns.length>0){
      [log performSelectorOnMainThread:@selector(setText:) withObject:ns waitUntilDone:FALSE];
   }
}

-(IBAction)refreshLog:(id)sender{
   iLogPlus=3;
   [self updateLogTab];
}

-(IBAction)pressDP_Bt_up:(id)sender{
   const char *x[]={"",":d"};
   z_main(0,2,x);   
   iDialIsPadDown=0;
}

-(IBAction)pressDP_Bt:(id)sender{
   
   iDialIsPadDown=1;
   UIButton *bt=(UIButton *)sender;
   const char *p=[[[bt titleLabel]text]  UTF8String];
   
   char buf[4];
   buf[0]=':';buf[1]='d';buf[2]=p[0];buf[3]=0;
   const char *x[]={"",&buf[0]};
   
   
   if(calls.getCallCnt()>0 && !iLoudSpkr && ![AppDelegate isAudioDevConnected])
      [self switchAR:1];
   
   z_main(0,2,x);

   NSString * ns =[[nr text] stringByAppendingString:[[bt titleLabel]text] ];
   if(p[0]=='0'){
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
         for(int i=0;iDialIsPadDown;i++){
            usleep(1000*10);
            if(i==60){
               if([[nr text] length]>0){
                  NSString *n= [[nr text] substringToIndex:[[nr text] length] - 1];
                  n=[n stringByAppendingString:@"+"];
                  [nr performSelectorOnMainThread:@selector(setText:) withObject:n waitUntilDone:TRUE];
                  [self numberChange]; 
               }
               break;
            }
         }
      });
   }
   [self setText:ns];
}

/*
 - (BOOL)navigationBar:(UINavigationBar *)navigationBar shouldPushItem:(UINavigationItem *)item{return YES;} // called to push. return NO not to.
 - (void)navigationBar:(UINavigationBar *)navigationBar didPushItem:(UINavigationItem *)item{}    // called at end of animation of push or immediately if not animated
 - (BOOL)navigationBar:(UINavigationBar *)navigationBar shouldPopItem:(UINavigationItem *)item{return YES;}// same as push methods
 - (void)navigationBar:(UINavigationBar *)navigationBar didPopItem:(UINavigationItem *)item{}
 */
-(void)confCallN:(CTCall*)c add:(int)add{
   if(!c || c->iEnded || !c->iInUse)return;
   char buf[64];
   sprintf(&buf[0],add?"*+%u":"*-%u",c->iCallId);
   const char *x[2]={"",&buf[0]};
   z_main(0,2,x);
   c->iIsInConferece=add;
}

-(void)holdCallN:(CTCall*)c hold:(int)hold{
   if(!c || c->iEnded || !c->iInUse)return;
   char buf[64];
   sprintf(&buf[0],hold?"*h%u":"*u%u",c->iCallId);
   const char *x[2]={"",&buf[0]};
   z_main(0,2,x);
   c->iIsOnHold=hold;
}
-(void)answerCallFromVidScr:(CTCall*)c{
   if(c->iEnded || !c->iCallId || !c->iIsIncoming)return;
   c->iActive=1;
   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      char buf[64];
      sprintf(&buf[0],"*a%u",c->iCallId);
      const char *x[2]={"",&buf[0]};
      z_main(0,2,x);
   });
   
}

-(void)answerCallN:(CTCall*)c{
   c->iActive=1;
   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      char buf[64];
      sprintf(&buf[0],"*a%u",c->iCallId);
      const char *x[2]={"",&buf[0]};
      z_main(0,2,x);
      [self setCurCallMT:c];
      //      [self unholdAndPutOthersOnHold:c];
   } );
   [answer setHidden:YES];
   view6pad.alpha=1.0;
   [self setEndCallBT:1 wide:1];
   
}
-(IBAction)answerBT{
   [self stopRingMT];
   
   CTCall *c=calls.curCall;
   if( !c)return;
   
   [uiCallInfo setText:@"Answering"];
   [self answerCallN:c];
}

-(void)remoteEventClick{
   if(!answer.isHidden){
      [self answerBT];
   }
   else if(iCallScreenIsVisible && calls.curCall){
      [self endCallBt];
   }
}

-(CGRect)getFullWithEndCallRect{
   CGRect r= CGRectMake(endCallBT.frame.origin.x, answer.frame.origin.y,
                        answer.frame.origin.x+answer.frame.size.width-endCallBT.frame.origin.x,
                        endCallBT.frame.size.height);
   return r;
}


-(void)checkCallMngr{
   if(iCallScreenIsVisible && callMngr){
      dispatch_async(dispatch_get_main_queue(), ^(void) {
         [self checkCallMngrMT];
      });
   }
}
-(void)checkCallMngrMT{
   
   CTMutexAutoLock a(mutexCallManeger);
   
   if(iCallScreenIsVisible && callMngr && [CallManeger isVisibleOrShowningNow]){
      [callMngr redraw];
   }
}

-(IBAction)showCallMngrClick{
   void setFlagShowningCallManeger(int f);
   setFlagShowningCallManeger(0);
   iShowCallMngr=1;
   [self showCallManeger];
   
}

-(IBAction)showCallManeger{
   
   if(iVideoScrIsVisible && vvcToRelease){
      [vvcToRelease showIncomingCallMT];
      return;
   }
   
   ZRTPInfoView *v=(ZRTPInfoView*)[second.view viewWithTag:1001]; 
   if(v){[v removeFromSuperview]; }
   
   CTMutexAutoLock a(mutexCallManeger);

   if(!iShowCallMngr){
      if(callMngr)[callMngr redraw];
      return; 
   }
   iShowCallMngr=0;
   
   [self tryHideAlertView];
   
#ifdef T_CREATE_CALL_MNGR
   if(!callMngr){
      
      //    iIsVisible=0;
      callMngr =[[CallManeger alloc]initWithNibName:@"CallManeger" bundle:nil];
      //callMngr autor
   }
#endif
   [callMngr setCallArray:&calls];
   callMngr->appDelegate=self;
   if(callMngr.isBeingDismissed){
      [self performSelector:@selector(showCallManeger) withObject:nil afterDelay:2];
      return;
   }
   
   if([CallManeger isVisibleOrShowningNow] || callMngr.isBeingPresented){
      NSLog(@"cm %d %d",[CallManeger isVisibleOrShowningNow],callMngr.isBeingPresented);
      [callMngr redraw];
      return;
   }
   void setFlagShowningCallManeger(int f);
   setFlagShowningCallManeger(1);
   
   [[uiCallVC navigationController] pushViewController:callMngr animated:YES];
}

-(IBAction)inCallKeyPad_down:(id)sender{

   UIButton *bt=(UIButton *)sender;
   const char *p=[[[bt titleLabel]text]  UTF8String];
   char buf[4];
   char bufx[4];
   
   if(!iLoudSpkr && ![AppDelegate isAudioDevConnected])
      [self switchAR:1];
   
   buf[0]=':';buf[1]='D';buf[2]=p[0];buf[3]=0;//send dtmf
   bufx[0]=':';bufx[1]='d';bufx[2]=p[0];bufx[3]=0;//play dtmf
   const char *x[]={"",&buf[0],&bufx[0]};
   z_main(0,3,x);
}

-(IBAction)inCallKeyPad_up:(id)sender{
   // keyPadInCall 
   //stop send dtmf
}

//

-(void)showZRTPPanel:(int)anim{
   
   zrtpPanel.alpha = 1.0;
   
   if(!anim){
      [uiCallInfo setHidden:YES];
      [zrtpPanel setHidden:NO];
      return;
   }
   zrtpPanel.hidden=YES;
   infoPanel.hidden=NO;
   
   
   [UIView transitionWithView:infoPanel
                     duration:1.0
                      options:UIViewAnimationOptionTransitionFlipFromLeft//UIViewAnimationOptionTransitionCurlUp
                   animations:^{
                      uiCallInfo.hidden = YES;
                      zrtpPanel.hidden = NO;
                   }
                   completion:^(BOOL finished){
                      [uiCallInfo setHidden:YES];
                      [self setCurCallMT:calls.curCall];
                   }];
   
   
   
}

-(void)showInfoLabel:(int)anim{
   
   uiCallInfo.alpha = 1.0;
   if(!anim){
      [uiCallInfo setHidden:NO];
      [zrtpPanel setHidden:YES];
      return;
   }
   
   
   [uiCallInfo setHidden:NO];
   [zrtpPanel setHidden:YES];
   if(anim && iAnimateEndCall){
      
      [UIView animateWithDuration:1.0 
                            delay:0.0 
                          options:UIViewAnimationCurveEaseInOut 
                       animations:^ {
                          fPadView.alpha=0.0;
                       } 
                       completion:^(BOOL finished) {
                          [fPadView setHidden:YES];
                          fPadView.alpha=1.0;
                       }];
   }
   
}


-(void)animEndCallBT:(CGRect)rect img:(UIImage*)im ico:(UIImage*)ico wide:(int)wide{

   [UIView beginAnimations:@"resizeButton" context:NULL];
   CTCall *c=calls.curCall;

   [UIView setAnimationDuration:0.5];
   [UIView setAnimationTransition:UIViewAnimationTransitionNone forView:endCallBT cache:YES];
   if(ico){
      [endCallBT setImageEdgeInsets:UIEdgeInsetsMake(0, -20, 0, 0)];
   }
   if(c && c->iActive)
      [endCallBT setTitle:T_TRNS("End Call") forState:UIControlStateNormal];
   
   [endCallBT setBackgroundImage:im forState:UIControlStateNormal];
   
   if(!wide)[endCallBT setImage:ico forState:UIControlStateNormal];
   if(!wide)[endCallBT setImage:ico forState:UIControlStateHighlighted];
   
   rect.origin.y=answer.frame.origin.y;
   endCallBT.frame=rect;
   
   if(wide)btHideKeypad.hidden=YES;
   if(wide)answer.hidden=YES;

   if(wide)[endCallBT setImage:ico forState:UIControlStateNormal];
   if(wide)[endCallBT setImage:ico forState:UIControlStateHighlighted];

   [UIView commitAnimations];
   
}
-(void)stopAnimEndCallWide{
   UIImage *ico=[UIImage imageNamed:@"ico_end_call.png"];
   [endCallBT setImage:ico forState:UIControlStateNormal];
   [endCallBT setImage:ico forState:UIControlStateHighlighted];
   
}

-(void)setEndCallBT:(int)animate wide:(int)wide{

   NSString *ns=@"bt_red.png";
   
   UIImage    *im_bt_red=[[UIImage imageNamed:ns] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 11, 0, 11)];
   
   
   CGRect r=wide?[self getFullWithEndCallRect]:endCallRect;
   UIImage *im=nil;
   if(wide)im=[UIImage imageNamed:@"ico_end_call.png"];
   
   CTCall *c=calls.curCall;
   
   if(!wide && c && !c->iActive && isVideoCall(c->iCallId)){
      im=[UIImage imageNamed:@"ico_camera_not.png"];
   }
   
   if(wide){
      [answer setHidden:YES];
   }
   
   if(animate){
      [self animEndCallBT:r img:im_bt_red ico:im wide:wide];
   }
   else{
      
      r.origin.y=answer.frame.origin.y;
      
      if(wide){
         [answer setHidden:YES];
         [btHideKeypad setHidden:YES];
      }
      
      endCallBT.frame=r;
      [endCallBT setBackgroundImage:im_bt_red forState:UIControlStateNormal];
      [endCallBT setImage:im forState:UIControlStateNormal];
      [endCallBT setImage:im forState:UIControlStateHighlighted];
      [endCallBT setImageEdgeInsets:UIEdgeInsetsMake(0, -20, 0, 0)];
      if(c && c->iActive)
         [endCallBT setTitle:T_TRNS("End Call") forState:UIControlStateNormal];
      
      
   }
}

-(void)restoreEndCallBt{
   [self setEndCallBT:0 wide:0];
}

-(void)stopRingMT{
   void stoRingTone();stoRingTone();
   //cancelLocalNotification
   if(incomCallNotif){
      
      [[UIApplication sharedApplication] cancelLocalNotification:incomCallNotif];//cancelAllLocalNotifications];
      [incomCallNotif release];
      incomCallNotif=NULL;
   }
}

-(void)onStopCallMT{
   puts(__func__);
   //TODO do this if is visible
   int cc=calls.getCallCnt();
   if(cc==0){
      [answer setHidden:YES];
      [verifySAS setHidden:YES];
      [self showInfoLabel:cc==0];
      
      if(activeCallNotifaction) {
         [[UIApplication sharedApplication] cancelLocalNotification:activeCallNotifaction];
      }
   }
   [self setNewCurCallMT];
   
   ZRTPInfoView *v=(ZRTPInfoView*)[second.view viewWithTag:1001]; 
   if(v){[v removeFromSuperview]; }
   
   [self stopRingMT];
}

-(void)onStopCall{
   puts(__func__);
   if(calls.getCallCnt()){
      //[self performSelector:@selector(onStopCallMT) withObject:nil afterDelay:1];//does not call onStopCallMT
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
         sleep(1);
         [self performSelectorOnMainThread:@selector(onStopCallMT) withObject:nil waitUntilDone:NO];
      });
   }
   else [self performSelectorOnMainThread:@selector(onStopCallMT) withObject:nil waitUntilDone:NO];  
}

-(void)selectorHideCallScrAnim{
   [self hideCallScreen:YES];
}
-(IBAction)hideCallScreen:(BOOL)anim{
   
   if(iCallScreenIsVisible && iCanHideNow){
      iCallScreenIsVisible=2;
      if(iDelayCallScreenHide){
         iDelayCallScreenHide=0;
         dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            sleep(8);
            if(iCallScreenIsVisible==2 && !calls.getCallCnt())
              [self performSelectorOnMainThread:@selector(selectorHideCallScrAnim) withObject:nil waitUntilDone:NO];
         });
         return;
      }
      iCanHideNow=0;
      
      [self tryHideAlertView];
      
      iDelayCallScreenHide = 0;
      
      uiCanShowModalAt=getTickCount()+1000;
      
      UIDevice *device = [UIDevice currentDevice];
      device.proximityMonitoringEnabled = NO;;
     
      CTMutexAutoLock a(mutexCallManeger);
      if(callMngr && [CallManeger isVisibleOrShowningNow]){

         [self.navigationController setNavigationBarHidden:YES animated:NO];
         [[callMngr navigationController] popViewControllerAnimated:NO];
      }
      if(vvcToRelease && iVideoScrIsVisible){
         iVideoScrIsVisible=0;
         [vvcToRelease onHideVideoView];
         [vvcToRelease.navigationController popViewControllerAnimated:NO];
         iVideoScrIsVisible=0;
      }
      if(!second.isBeingDismissed){
         if(iVideoScrIsVisible)iVideoScrIsVisible=2;
         [second dismissViewControllerAnimated:anim completion:^(){
             dispatch_async(dispatch_get_main_queue(), ^{
                [ uiTabBar setFrame:CGRectMake(0, [Utilities utilitiesInstance].screenHeight - uiTabBar.frame.size.height, uiTabBar.frame.size.width,uiTabBar.frame.size.height)];
             });
          //  dialPadView.frame=dialPadViewFrame;
         }];

         [self tryStopCallScrTimer:1];
      }
      [self restoreEndCallBt];

      if(callMngr){
         [callMngr release];
         callMngr=nil;
      }
      
      iPrevCallLouspkrMode=iLoudSpkr;

      
      [self stopMotionDetect];
      
      iCallScreenIsVisible=0;
   }   
   [backToCallBT setHidden:YES];
}

-(void)onEndCallMT{
   [self checkCallMngrMT];
   [self onStopCallMT];
   [self checkBattery];
}

-(void)onEndCall{
   [self performSelectorOnMainThread:@selector(onEndCallMT) withObject:nil waitUntilDone:NO];  
}


-(void)endCallN:(CTCall*)c{
   iCanHideNow=1;
   iDelayCallScreenHide=0;
   if(c)strcpy(c->bufMsg,"Call ended");
   
   if(c)c->iEnded=1;
   [self updateRecents:c];
   if(c && c==calls.curCall){[uiCallInfo setText:@""];calls.curCall=NULL;}
   [self onEndCallMT];
   if(!c)return ;
   int cid=c->iCallId;
   
   //if(!cid)return;
   
   [self endCall_cid:cid];
}

-(void)endCall_cid:(int)cid{
   
   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      char buf[64];
      sprintf(&buf[0],"*e%u",cid);
      const char *x[2];
      x[0]="";
      x[1]=&buf[0];
      z_main(0,2,x);
   });
}

-(IBAction)endCallBt{
   
   [self init_or_reinitDTMF];
   iAnimateEndCall=0;
   [self endCallN:calls.curCall];
}



-(IBAction)chooseCallType{

   if(nr.text.length<1){
      [self setText:[NSString stringWithUTF8String:&szLastDialed[0]]];
      return ;
   }
   
   void *ph=getCurrentDOut();
   if(ph){
      int ret;
      if(findIntByServKey(ph,"iDisableVideo",&ret)>=0){
         if(ret>0){
            [self makeCall:'c'];
            return;
         }
      }

   }
   

   UIActionSheet *as = [[UIActionSheet alloc]initWithTitle:@"" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Call", @"Video Call",nil];
   as.tag=0;
   [as showFromTabBar:uiTabBar];
   [as release];
   
}

-(void)updateLedMT{
   int g_getCap(int &iIsCN, int &iIsVoice, int &iPrevAuthFail);
   int iIsCn,iIsVoice,iPrevAuthFail;
   int v=g_getCap(iIsCn,iIsVoice,iPrevAuthFail);
   static int pv=-1;
   static int previPrevAuthFail=-1;
   float fv=(float)v*0.005f+.35f;
#if 1
   if(previPrevAuthFail!=iPrevAuthFail || pv!=v){
      if(iPrevAuthFail){
         [iwLed setBackgroundColor:[UIColor colorWithRed:fv green:0 blue:0 alpha:1.0]];
      }
      else{
         [iwLed setBackgroundColor:[UIColor colorWithRed:0 green:fv blue:0 alpha:1.0] ];
      }
      pv=v;
      previPrevAuthFail=iPrevAuthFail;
   }
#else
   if(iPrevAuthFail){
      if(previPrevAuthFail!=iPrevAuthFail){
         previPrevAuthFail=iPrevAuthFail;
         [iwLed setBackgroundColor:[UIColor colorWithRed:1.0 green:0 blue:0 alpha:1.0] ];
         pv=-1;
      }
   }
   else if(pv!=v){
      pv=v;
      [iwLed setBackgroundColor:[UIColor colorWithRed:0 green:fv blue:0 alpha:1.0] ];
      previPrevAuthFail=-1;
   }
#endif
   
   
}



-(void)updateCallDurMT{
      
   CTCall *c=calls.curCall;
   
   //UIApplication.sharedApplication.applicationState == UIApplicationStateActive
   
   if(c && !iIsInBackGround && !isZRTPInfoVisible() && !lbVolumeWarning.hidden){
      if(!isPlaybackVolumeMuted())[lbVolumeWarning setHidden:YES];
   }
   
   if(c && c->iActive && c->uiStartTime && !isZRTPInfoVisible() ){
      if(c->iEnded>=3){c->iEnded++;if(c->iEnded>5)[self onStopCallMT];return;}
      if(c->iEnded==2 && c->iRecentsUpdated) {c->iEnded=3;} 
      
      if(iVideoScrIsVisible)return;
      
      if(iIsInBackGround)return;
      
      int d=c->iTmpDur;
      int m=d/60;
      int s=d-m*60;
      
    // jjj printf("t=%02d:%02d\n",m,s);
      NSString *ns=[NSString stringWithFormat:@"%02d:%02d",m,s];
      [uiDur setText:ns];
#ifdef T_TEST_MAX_JIT_BUF_SIZE
      if(iAudioBufSizeMS){//TODO restore default 3000
         char buf[32];
         char bufms[32];
         sprintf(bufms,"bufms%d",iAudioBufSizeMS);
         int r = getMediaInfo(c->iCallId,bufms,&buf[0],31);
      }
 #endif
      
      static const int *piShowGeekStrip = (const int *)findGlobalCfgKey("iShowGeekStrip");
      
      
      if((piShowGeekStrip && *piShowGeekStrip)){
         char buf[64];
         int r=getMediaInfo(c->iCallId,"codecs",&buf[0],63);
         if(r<0)r=0;
#ifdef T_TEST_MAX_JIT_BUF_SIZE
         if(iAudioBufSizeMS){
            //10 = 1000 msec,25 = 2500 msec, 
            r+=snprintf(&buf[r],63-r," d%02d",iAudioBufSizeMS/100);
         }
#endif
         if(r>0)[uiMediaInfo setText:[NSString stringWithUTF8String:&buf[0]]];
      }
      
      if(1){
         char buf[32];
         strcpy(buf,"ico_antena_");
         static char cc;
         int r=getMediaInfo(c->iCallId,"bars",&buf[11],31-11);//11=strlen("ico_antena_" or buf);
         // puts(buf);
         if(r==1){
            static int iX=0;
            iX++;
            if(buf[11]!='0'){
               //TODO fix
               if(strcmp(c->bufSecureMsg,"Connecting...")==0){strcpy(c->bufSecureMsg,"");[self refreshZRTP:c];}
            }
            if((cc!=buf[11]) || (iX&7)==1){
               cc=buf[11];
               UIImage *a=[UIImage imageNamed:[NSString stringWithUTF8String:&buf[0]]];
               //[b setBackgroundImage:bti forState:UIControlStateNormal];
               [btAntena setImage:nil forState:UIControlStateNormal];
               [btAntena setImage:a forState:UIControlStateNormal];
               
            }
         }
      }

      

      if(c->iZRTPShowPopup){
         c->iZRTPShowPopup=0;
         [self showZRTPErrorPopup:c];
      }

      if(0)
      {
         void freemem_to_log();
         freemem_to_log();
      }
   }
   
}

-(void)callThreadCB:(int)i{
   //TODO test audio without this   
   CTCall *c=calls.curCall;
   
   
   if(c && c->iActive && c->uiStartTime && (!iVideoScrIsVisible || c->iEnded)){
      int d = get_time()-c->uiStartTime;
      if(d!=c->iTmpDur ){
         c->iTmpDur = d;
         [self performSelectorOnMainThread:@selector(updateCallDurMT) withObject:nil waitUntilDone:FALSE];
      }
   }
}

-(void)callThreadLedCB{
   if(iIsInBackGround || [CallManeger isVisibleOrShowningNow] || isZRTPInfoVisible())return;
   
   CTCall *c=calls.curCall;
   
   if(c && c->iActive && c->uiStartTime && (!iVideoScrIsVisible || c->iEnded)){

      [self updateLedMT];
        //-- [self performSelectorOnMainThread:@selector(updateLedMT) withObject:nil waitUntilDone:FALSE];
      
   }
}

#define T_ALERT_TF_NEW

-(void)showExetendedZRTPWarnPopup:(CTCall *)c{

   CTEditBuf<1024> b;
   CTEditBuf<1024> bDescr;
   translateZRTP_errMsg(c->zrtpWarning, &b, &bDescr);
   
   NSString *ns=toNSFromTB(&b);
   ns=[ns stringByAppendingString:@"\n\nDescription:\n"];
   ns=[ns stringByAppendingString:toNSFromTB(&bDescr)];
   
   if(c->zrtpWarning.getLen()>8 && c->zrtpWarning.getChar(0)=='s' && c->zrtpWarning.getChar(7)==':'){
      NSString *toNSFromTBN(CTStrBase *b, int N);
     // ns=[ns stringByAppendingString:@"\n\nError code: "];
      ns=[ns stringByAppendingString:@"\n\n"];
//      ns=[ns stringByAppendingString:toNSFromTBN(&c->zrtpWarning, 7)];
      ns=[ns stringByAppendingString:toNSFromTB(&c->zrtpWarning)];
   }
   
   UIAlertView *av = [[UIAlertView alloc] initWithTitle:T_TRNS("ZRTP security message")
                                                message:ns
                                               delegate:nil
                                      cancelButtonTitle:@"Ok"
                                      otherButtonTitles:nil];
   [av show];
   [av release];
}

UIAlertView *prevAlertView=nil;

-(void)tryHideAlertView{
   if(!prevAlertView || prevAlertView.tag!=3)return;//is not ZRTP peer setter
   
   
   [prevAlertView dismissWithClickedButtonIndex:prevAlertView.cancelButtonIndex animated:YES];
   
   prevAlertView=nil;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
   NSLog(@"alertView %ld %ld",buttonIndex, alertView.tag);
   
   long long ll  = (long long)alertView;ll&=0xffffffff;
   
   if(alertView.tag &&  alertView.tag==ll){
      CTCall *c=calls.curCall;
      if(c && buttonIndex!=alertView.cancelButtonIndex){
         [self showExetendedZRTPWarnPopup:c];
      }
      return;
   }
   
#if defined(T_ALERT_TF_NEW)
   if(alertView.tag==3)prevAlertView=nil;
   if(alertView.tag!=3 || buttonIndex==alertView.cancelButtonIndex)return;
   UITextField *tf=[alertView textFieldAtIndex:0];
#else
   if(buttonIndex==alertView.cancelButtonIndex)return;
   UITextField *tf=(UITextField*)alertView.tag;
#endif
   if(!tf)return;
   CTCall *c=calls.curCall;
   
   if(c){
      if([tf.text length]>0){
        // [verifySAS setHidden:YES];
         c->iShowVerifySas=0;
         const char *p=[tf.text UTF8String];
         c->zrtpPEER.setText(p);
         
         c->iShowWarningForNSec=0;
         c->zrtpWarning.reset();
         
         char buf[128];
         snprintf(buf,127,"*z%u %s",c->iCallId,p);
         const char *x[]={"",&buf[0]};
         z_main(0,2,x);
         [self refreshZRTP:c];
         
         if(iSASConfirmClickCount){
            iSASConfirmClickCount[0]++;
            if(iSASConfirmClickCount[0]<T_SAS_NOVICE_LIMIT*2){
               void t_save_glob();
               t_save_glob();
            }
         }
      }
   }
   
}


-(void)showZRTPErrorPopup:(CTCall *)c{
   if(!c || c->iEnded || !c->iInUse)return;
   if(c->iZRTPPopupsShowed>1 || [CallManeger isVisibleOrShowningNow])return;
   
   int iSDES=0;
   
   if(c->zrtpWarning.getLen()>8){
      
      CTStr zrtpCode((unsigned short*)c->zrtpWarning.getText(), 8);
      
      if (zrtpCode=="s2_c007:" || zrtpCode=="s2_c051:")
         return;
      
      iSDES = isSDESSecure(c->iCallId, 0);
      
   }
   
   c->iZRTPPopupsShowed++;//should i reset this flag when it is secure
  
   CTEditBuf<1024> b;
   CTEditBuf<1024> bDescr;
   translateZRTP_errMsg(c->zrtpWarning, &b, &bDescr);
   
 //  UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"ZRTP error description"
   //                                             message:toNSFromTB(&b)
   
   avZRTPWarning = [[UIAlertView alloc] initWithTitle: T_TRNS("Security Warning")
                                                   message:toNSFromTB(&b)
                                                  delegate:self
                                         cancelButtonTitle:@"Ok"
                                         otherButtonTitles:nil];
   if(bDescr.getLen()){
      [avZRTPWarning addButtonWithTitle:T_TRNS("Show details")];
   }
   avZRTPWarning.tag=(long long)avZRTPWarning;
   /*
    [alertView setTitle:@"new title"];
    [alertView setMessage:@"new message"];
    */
   [avZRTPWarning show];
   [avZRTPWarning release];
}

-(IBAction)showSasPopupText{
   CTCall *c=calls.curCall;
   if(!c)return;
   /*
    You should verbally compare the authentication code with your partner. If it doesn’t match, it indicates the presence of a wiretapper.
    */
   NSString *e32 = T_TRNS("You should verbally compare this authentication code with your partner. If it doesn’t match, it indicates the presence of a wiretapper.");
   
   UIAlertView *alert = [[UIAlertView alloc] initWithTitle:T_TRNS("How to detect a wiretapper")
                                                   message:e32//c->bufSAS[4]==0?e32:eW
                                                  delegate:nil
                                         cancelButtonTitle:@"Ok"
                                         otherButtonTitles:nil];
   [alert show];
   [alert release];
   
}

-(IBAction)showSecureView{
   CTCall *c=calls.curCall;
   int cid=c?c->iCallId:0;
   if(!cid)return;
   
   if(c->iShowVerifySas && iCanShowSAS_verify==0 && c->zrtpPEER.getLen()==0){
      iCanShowSAS_verify=1;
      [self updateZRTP_infoMT:c];
      return ;
   }
   
   NSArray *bundle = [[NSBundle mainBundle] loadNibNamed:@"ZRTP_info"
                                                   owner:self options:nil];
   ZRTPInfoView *v=NULL;
   for (id object in bundle) {
      if ([object isKindOfClass:[ZRTPInfoView class]])
         v = (ZRTPInfoView *)object;
   }   
   
   if(!v)return;
   
   [v onReRead:cid pEng:c->pEng peer:&c->zrtpPEER sas:&c->bufSAS[0]];
   v.center=second.view.center;
   [second.view addSubview: v];
   
   v.tag=1001;
   

}
-(IBAction)onAntenaClick:(id)sender{
//   iCanShowMediaInfo=!iCanShowMediaInfo;
   
   static int *piShowGeekStrip = (int *)findGlobalCfgKey("iShowGeekStrip");
   
   if(piShowGeekStrip) {
      piShowGeekStrip[0]=!piShowGeekStrip[0];
      
      void t_save_glob();
      t_save_glob();
   }

   
   [uiMediaInfo setHidden:!(piShowGeekStrip && piShowGeekStrip[0])];
#ifdef T_TEST_MAX_JIT_BUF_SIZE
   if(iCanShowMediaInfo){
      iAudioBufSizeMS+=800;
      if(iAudioBufSizeMS>=3500)iAudioBufSizeMS=500;

   }
#endif
   
   
}

-(void)checkQwertyKeypad:(int)iAddingText{
   return;
   if(iAddingText || nr.text.length>0){
      [btQwerty setHidden:YES];
      
   }
   else{
      [btQwerty setHidden:NO];
   }
}

-(IBAction)hideQwertyKeypad{
   [btShowCSDPad setHidden:YES];
   [btQwerty setHidden:NO];
   [nr resignFirstResponder];
}

-(IBAction)showQwertyKeypad{
   [btQwerty setHidden:YES];
   [btShowCSDPad setHidden:NO];
   [nr becomeFirstResponder];
}

-(IBAction)showInCallKeyPad:(id)sender{
   // keyPadInCall 
   
   keyPadInCall.hidden=YES;
   iAnimatingKeyPadInCall=1;
  //-- [self setEndCallBT:1 wide:0];
   [UIView transitionWithView:viewCSMiddle
                     duration:1.0
                      options:UIViewAnimationOptionTransitionFlipFromLeft//UIViewAnimationOptionTransitionCurlUp
                   animations:^{
                      iAnimatingKeyPadInCall=2;
                      infoPanel.hidden=YES;
                      view6pad.hidden = YES;
                      fPadView.hidden = YES;
                      keyPadInCall.hidden = NO;
                      [self setEndCallBT:0 wide:0];
                   }
                   completion:^(BOOL finished){
                      [infoPanel setHidden:YES];
                      [view6pad setHidden:YES];
                      [fPadView setHidden:YES];
                      [keyPadInCall setHidden:NO];
                      [btHideKeypad setHidden:NO];
                      [self setEndCallBT:0 wide:0];
                      iAnimatingKeyPadInCall=0;
                   }];
}

-(void)showInCall6Pad{
   // keyPadInCall
   CTCall *c=calls.curCall;
   int iWideEndCall=0;
   if(c && c->mustShowAnswerBT()){
      [answer setHidden:NO];
      [self setEndCallBT:0 wide:0];
   }
   else {
      iWideEndCall=1;
      
   }
   iAnimatingKeyPadInCall=1;
   
   [UIView transitionWithView:viewCSMiddle
                     duration:1.0
                      options:UIViewAnimationOptionTransitionFlipFromLeft//UIViewAnimationOptionTransitionCurlUp
                   animations:^{
                      iAnimatingKeyPadInCall=2;
                      infoPanel.hidden=NO;//new
                      view6pad.hidden = NO;
                      keyPadInCall.hidden = YES;
                      btHideKeypad.hidden=YES;
                      fPadView.hidden=NO;
                      if(iWideEndCall)[self setEndCallBT:0 wide:1];
                   }
                   completion:^(BOOL finished){
                      [infoPanel setHidden:NO];
                      [view6pad setHidden:NO];
                      [fPadView setHidden:NO];
                      
                      [keyPadInCall setHidden:YES];
                      [btHideKeypad setHidden:YES];
                      if(iWideEndCall)[self setEndCallBT:0 wide:1];
                      iAnimatingKeyPadInCall=0;
                   }];
}


-(IBAction)hideKeypad:(id)sender{
   [btHideKeypad setHidden:YES];
   [self showInCall6Pad]; 
   
}

-(IBAction)switchToVideo:(id)sender{
   [self showVideoScr:1 call:calls.curCall];
}

-(void) checkMedia:(CTCall*)c charp:(const char*)charp intv:(int)intv{
   if(!c)return;
   
   int iIsAudio=intv==5 && strncmp(charp,"audio",5)==0;

   c->iIsVideo=!iIsAudio;
   
   if(c!=calls.curCall && !c->iIsInConferece)return;
   
   if(iIsAudio){
      if(vvcToRelease && iVideoScrIsVisible){
         if(!calls.videoCallsActive(c)){
            dispatch_async(dispatch_get_main_queue(), ^(void) {
               if(!vvcToRelease.isBeingDismissed && iVideoScrIsVisible){
                  iVideoScrIsVisible=0;
                  [vvcToRelease.navigationController popViewControllerAnimated:YES];
               }
            });
         }
      }
   }
   else if(!iVideoScrIsVisible){
      dispatch_async(dispatch_get_main_queue(), ^(void) {
         [self showVideoScr:0 call:c];
      });      
   }
}


#pragma mark - Provisioning

-(void)showProvScreen{
    
    // SSO
    UIStoryboard *sbProv = [UIStoryboard storyboardWithName:@"Prov" bundle:nil];
    Prov *provVC = [sbProv instantiateInitialViewController];    
    provVC.delegate = self;
    
    [self needsDisplayProvisioningController:provVC animated:NO];
}


-(void)checkProvValues{
   
   [cfgBT setHidden:NO];
   return;
   /*
   int iHideCfg=-1;
   findIntByServKey(NULL,"iHideCfg",&iHideCfg);
   if(iHideCfg==1){
      
      iCfgOn=0;
      [cfgBT setHidden:1];
   }
   else {
      iCfgOn=1;
      [cfgBT setHidden:0];
   }
   */
}


#pragma mark - Provisioning Window

- (void)setupAndDisplayProvisioningWindow {
    
//    if (self.cachedWindow == self.window) return;
    if (self.provWindow && self.provWindow == self.window) return;
    
    self.cachedWindow = self.window;
    _cachedWindow.hidden = YES;
    
    self.provWindow = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    UIStoryboard *sbProv = [UIStoryboard storyboardWithName:@"Prov" bundle:nil];
    Prov *provVC = [sbProv instantiateInitialViewController];
    provVC.delegate = self;
    
    SCContainerVC *rootVC = [[[SCContainerVC alloc] initWithViewController:provVC] autorelease];
    rootVC.view.frame = _provWindow.bounds;
    self.provRootVC = rootVC;        
    
    self.provWindow.rootViewController = rootVC;
    self.window = _provWindow;
    [self.window makeKeyAndVisible];
}

- (void)cleanupProvisioningAndDisplayAppWindowWithCompletion:(void (^)())completion {
    
    _cachedWindow.hidden = NO;
    _cachedWindow.alpha = 0.0;
    
    [UIView animateWithDuration:1. animations:^{
        
        self.window = _cachedWindow;
        [self.window makeKeyAndVisible];    
        
        _cachedWindow.alpha = 1.0;
        _provWindow.alpha = 0.0;
        
    } completion:^(BOOL finished) {
        
        self.provRootVC = nil;
        self.provWindow = nil;        
        self.cachedWindow = nil;        
        
        if (completion) {
            completion();
        }
    }];
}


//----------------------------------------------------------------------
#pragma mark - SCProvisioningDelegate Methods
//----------------------------------------------------------------------

- (void)provisioningDidFinish {
    
    [self cleanupProvisioningAndDisplayAppWindowWithCompletion:^{
        
        //orig onProvResponce: method code, here in completion block
        void t_init_glob();
        t_init_glob();
        [self checkProvValues];
        
        const char *xr[]={"",":reg",":onka",":onforeground"};//
        int z_main_init(int argc, const char* argv[]);
        z_main_init(4,xr);
        
        setPhoneCB(&fncCBRet,self);
    }];
}

- (void)needsDisplayProvisioningController:(UIViewController*)vc animated:(BOOL)animated {
    // Do not try to switch to vc if already the active vc
    if (_provRootVC.activeVC == vc) {
        return;
    }
    [_provRootVC presentVC:vc animationOption:UIViewAnimationOptionTransitionCrossDissolve duration:0.15];
}

- (void)viewControllerDidCancelCreate:(UIViewController *)vc {
    [self showProvScreen];
}

//----------------------------------------------------------------------
// End SCProvisioningDelegate 
//----------------------------------------------------------------------


-(void)showVideoScr:(int)iCanSend call:(CTCall*)c{
   
   //CTCall *c=calls.curCall;
   if(!c)c=calls.curCall;
   if(!c)return;
   
   if( (!c->bufSAS[0] || c->iShowVerifySas) || iVideoScrIsVisible)return;
   iVideoScrIsVisible=1;
   
   if(![AppDelegate isAudioDevConnected])
      [self switchAR:1];
   
   
   VideoViewController *vvc;

   vvc =[[VideoViewController alloc]initWithNibName:@"VideoViewController" bundle:nil];
   
   [vvc setCall:c canAutoStart:iCanSend iVideoScrIsVisible:&iVideoScrIsVisible a:self];
   [[uiCallVC navigationController] pushViewController:vvc animated:YES];
   
   if(vvcToRelease){
      [vvcToRelease release];
   }
   vvcToRelease=vvc;
}

-(IBAction)switchAddCall:(id)sender{
   iDelayCallScreenHide=0;
   iCanHideNow=1;
   [self hideCallScreen:YES];
   iCanHideNow=0;
   [backToCallBT setHidden:NO];
   
}

-(IBAction)switchMute:(id)sender{
 
   [self muteMic:-1];
   
}

-(void)muteMic:(int)s{
   UIButton *b=muteBT;
   static int prev=5; 
   if(s==-1){s=!prev;}
   if(s){
      UIImage *bti=[UIImage imageNamed:@"bt_dial_down.png"];
      [b setBackgroundImage:bti forState:UIControlStateNormal];
      b.accessibilityLabel = @"mute selected";
    //  [b setTitle:@"unmute" forState:UIControlStateNormal];
      const char *x[]={"",":mute 1"};
      z_main(0,2,x);
      iOnMute=1;
   }
   else{
      [b setBackgroundImage:[UIImage imageNamed:@"bt_dial_up.png"] forState:UIControlStateNormal];
      b.accessibilityLabel = @"mute";
     //-- [b setTitle:@"mute" forState:UIControlStateNormal];
      const char *x[]={"",":mute 0"};
      z_main(0,2,x);
      iOnMute=0;
   }  
   prev=s;
}

-(void)checkVolumeWarning{
   
   [lbVolumeWarning setHidden:isPlaybackVolumeMuted()?NO:YES];
}

-(void)switchAR:(int)loud{
   [self _switchAR:loud];
   if(isPlaybackVolumeMuted())[lbVolumeWarning setHidden:NO];
}

-(void)_switchAR:(int)loud{
   
   UIButton *b=switchSpktBt;
   int setAudioRoute(int iLoudSpkr);
   int  ret=setAudioRoute(loud);
   if(ret<0){
      if(ret==-560557673){
        ret=setAudioRoute(!loud);
         NSLog(@"try fix setAudioRoute()== %d %c%c%c%c" ,ret,(-ret)&0xff,((-ret)>>8)&0xff,((-ret)>>16)&0xff,((-ret)>>24)&0xff);
      }
      if(ret<0){
         NSString *ns=[NSString stringWithFormat:@"ret %d %c%c%c%c" ,ret,(-ret)&0xff,((-ret)>>8)&0xff,((-ret)>>16)&0xff,((-ret)>>24)&0xff];
        // [uiCallInfo setText:ns];
      }
   }
   static int iPrev=-1;
   iLoudSpkr=ret;
   if(iPrev==ret)return;
   iPrev=iLoudSpkr;
   
   [self fncCBOnRouteChange:NULL];
   /*
   if(ret){
      UIImage *bti=[UIImage imageNamed:@"fpad_bt_3_down.png"];
      [b setBackgroundImage:bti forState:UIControlStateNormal];
   }
   else{
      [b setBackgroundImage:nil forState:UIControlStateNormal];
   }
   */
   
}

static void _fncCBOnRouteChange(void *routePtr, void *ptrUserData){
   AppDelegate *s=(AppDelegate*)ptrUserData;
   [s fncCBOnRouteChange:routePtr];
}

-(void)initRoutingBT:(UIView*)v{
   static int iAddObs=1;
   if(!iAddObs)return;
   for (UIView *view in v.subviews) {
      if ([view isKindOfClass:[UIButton class]]) {
         
         UIButton *airplayButton=(UIButton*)view;
         [view retain];
         [airplayButton addObserver:self forKeyPath:@"alpha" options:NSKeyValueObservingOptionNew context:nil];

      }
   }
}

-(int)isRoutingBTVisible:(UIView*)v{
   for (UIView *view in v.subviews) {
      if ([view isKindOfClass:[UIButton class]]) {
         
         static int iAddObs=1;
         UIButton *airplayButton=(UIButton*)view;
         if(iAddObs){
            [view retain];
            iAddObs=0;
            [airplayButton addObserver:self forKeyPath:@"alpha" options:NSKeyValueObservingOptionNew context:nil];
         }
         
        // [airplayButton addObserver:self forKeyPath:@"alpha" options:NSKeyValueObservingOptionNew context:nil];
         return airplayButton.alpha > 0.9;
      }
   }
   return 0;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
   if (![object isKindOfClass:[UIButton class]])
      return;
   
   float f = [[change valueForKey:NSKeyValueChangeNewKey] floatValue] ;
   static int iVisible=-1;
   int v = f>0.9;
   if (iVisible!=v )
   {
      iVisible=v;
      [self fncCBOnRouteChange:NULL];
   }
}

-(void)fncCBOnRouteChange:(void *)routePtr{
   int isLoudspkrInUse(void);
   int isBTAvailable(void);
   int isBTUsed(void);
   int isHeadphonesOrBT(void);
   
   if(isLoudspkrInUse()){
      iLoudSpkr=1;
      UIImage *bti=[UIImage imageNamed:@"bt_dial_down.png"];
      [switchSpktBt setBackgroundImage:bti forState:UIControlStateNormal];
      switchSpktBt.accessibilityLabel = @"speaker selected";
      
      if(iCallScreenIsVisible){
         [UIDevice currentDevice].proximityMonitoringEnabled = YES;
      }
   }
   else{
      iLoudSpkr=0;
      UIImage *bti=[UIImage imageNamed:@"bt_dial_up.png"];
      [switchSpktBt setBackgroundImage:bti forState:UIControlStateNormal];
      switchSpktBt.accessibilityLabel = @"speaker";
      
      if(isHeadphonesOrBT()){
         [UIDevice currentDevice].proximityMonitoringEnabled = NO;
      }
      else if(iCallScreenIsVisible){
         [UIDevice currentDevice].proximityMonitoringEnabled = YES;
      }
      
   }
   
   MPVolumeView *v=(MPVolumeView*)[switchSpktBt viewWithTag:55011];
   if(!v)return;
   [self initRoutingBT:v];
   
   NSString *ns = [[UIDevice currentDevice] model];
   
   int iIsIphone = (ns && [ns isEqualToString:@"iPhone"]);

   if(isBTUsed() || ([self isRoutingBTVisible:v] && (!iIsIphone || isBTAvailable()))){
      v.frame = CGRectMake(switchSpktBt.bounds.origin.x+15,switchSpktBt.bounds.origin.y,switchSpktBt.bounds.size.width-15,switchSpktBt.bounds.size.height);
      [switchSpktBt setImage:nil forState:UIControlStateNormal];
      [switchSpktBt setTitle:@"" forState:UIControlStateNormal];
      v.alpha=1.0;
   }
   else{
      [switchSpktBt setImage:[UIImage imageNamed:@"ico_speaker.png"] forState:UIControlStateNormal];
     //-- [switchSpktBt setTitle:@"speaker" forState:UIControlStateNormal];
      v.frame = CGRectMake(0,0,1,1);
      v.alpha=0.0;
   }

}

-(IBAction)switchSpkr:(id)sender{
   

   /*
    BT -> EAR //jo no loudspkr nevar zinaat uz ko paarsleegsies, ka ir BT var skaidri zinaat ka var iesleegt EAR
    EAR->LOUD_SPKR
    LOUD_SPKR->BT
    */
   
  // MPVolumeSettingsAlertShow();
  // return;
   /*
   if(!iLoudSpkr){
      int isBT = 2==[AppDelegate isAudioDevConnected];
      if(isBT){
         int switchToEarpiece();
         switchToEarpiece();
         return;
      }
   }
    */
   /*
   
   AVAudioSession *s = [AVAudioSession sharedInstance] ;
   
   NSLog(@"idelay=%f",[s inputLatency]);
   NSLog(@"odelay=%f",[s outputLatency]);
   
   
   // Get array of current audio outputs (there should only be one)
   NSArray *outputs = [[AVAudioSession sharedInstance] outputDataSources];//.c.outputs;
   
   int c=outputs.count;

   for(int i=0;i<c;i++){
      NSString *portName = [[outputs objectAtIndex:i] portName];
      
      NSLog(@"ports %d %@",i,portName);
   }
    */
   

//   return;
   
   iLoudSpkr=!iLoudSpkr;
   [self switchAR:iLoudSpkr];
   
}

- (IBAction)chatBtnClick:(id)sender {
    
    NSString * contactUsername = calls.curCall->getUsernameFromCall();
    
    [self switchAddCall:nil];
    UITabBarController *tabBarContrller = (UITabBarController *)self.window.rootViewController;
    tabBarContrller.selectedIndex = 4;
    
    NSString *userName = [[Utilities utilitiesInstance] removePeerInfo:contactUsername lowerCase:NO];
    userName = [[Utilities utilitiesInstance] addPeerInfo:userName lowerCase:NO];
    
    [[Utilities utilitiesInstance] assignSelectedRecentWithContactName:userName];
    UINavigationController *navigationViewC = (UINavigationController *)tabBarContrller.selectedViewController;
    
    BOOL shouldPresentChatViewC = YES;
    for (UIViewController * viewC in navigationViewC.viewControllers) {
        if([viewC isKindOfClass:[ChatViewController class]])
        {
            shouldPresentChatViewC = NO;
        }
    }
    
    if(shouldPresentChatViewC)
    {
        UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Chat" bundle:nil];
        UIViewController *chatViewController = [storyBoard instantiateViewControllerWithIdentifier:@"ChatViewController"];
        [navigationViewC pushViewController:chatViewController animated:YES];
    }

    [uiTabBar selectSeperatorWithTag:4];

}


-(int)callScrVisible{return  iCallScreenIsVisible;}

-(void)dontAllowCurCallChangeUntilVerifySas{
   NSLog(@"dontAllowCurCallChangeUntilVerifySas");;
   
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
   
   NSLog(@"actionSheet %d",buttonIndex);
   
   if([actionSheet cancelButtonIndex]==buttonIndex)return;

   if(actionSheet.tag){
      
      int iAccId=accountIdByIndex[buttonIndex];
      
      void *p=getAccountByID(iAccId,1);
      if(p){
         [self setOutgoingAccount:p];
      }
      
      return;
   }
   
   [self makeCall:(buttonIndex==0?'c':'v')];
}

- (void)actionSheetCancel:(UIActionSheet *)actionSheet{ }

-(void)setOutgoingAccount:(void*)eng{
   
   if(eng==NULL)eng=getCurrentDOut();
   if(!eng){
      [curServiceLB setText:@"!"];
      return;
   }
   int setCurrentDOut(void *eng);
   setCurrentDOut(eng);
   
   const char *p=sendEngMsg(eng,"isON");
   
   int ok=(p && strcmp(p,"yes")==0);
   int not_ok=!ok && (!p || strcmp(p,"no")==0);
   
#define RED_MSG_AND_ERR_LIMIT_SEC 10
   
   
   UIColor *col=ok?[UIColor greenColor]:((not_ok &&  secSinceAppStarted()>RED_MSG_AND_ERR_LIMIT_SEC)?[UIColor redColor]:[UIColor grayColor]);
   
   const char *all_on=sendEngMsg(NULL,"all_online");
   
   int iAllOn=all_on && strcmp(all_on,"true")==0;
   
   char bufInfo[1024]; bufInfo[0]=0;
   
   if(not_ok){
      p = sendEngMsg(eng,"regErr");
      if(p && p[0]){
         strcpy(bufInfo,p);
      }
   }
   else {
      strcpy(bufInfo,getAccountTitle(eng));
   }
   
   if(!iAllOn && secSinceAppStarted()>RED_MSG_AND_ERR_LIMIT_SEC){
      strcat(bufInfo," !");
   }
   
   static int iFirstTime=1;
   if(iFirstTime){
      iFirstTime=0;
      const char *_nr = sendEngMsg(eng,"cfg.nr");
      if(!(_nr && _nr[0])){
         [self showQwertyKeypad];
      }
   }
   
   if(!not_ok){
      const char *_un = sendEngMsg(eng,"cfg.un");
      if(_un && _un[0]){
         int iIsSC=0;
         if(strcasecmp(bufInfo, "silentcircle")==0){
            bufInfo[0]=0;
            iIsSC=1;
         }
         else
            strcat(bufInfo,"\n");
         
         strcat(bufInfo,_un);
         const char *_nr = sendEngMsg(eng,"cfg.nr");
         if(_nr && _nr[0]){
            strcat(bufInfo,iIsSC ? "\n" : ", ");
            int iLen = strlen(bufInfo);
            fixNR(_nr, &bufInfo[iLen],sizeof(bufInfo)-iLen-1);
         }
      }
   }

   [curServiceLB setText:[NSString stringWithUTF8String:&bufInfo[0]]];
   
   [curServiceLB setTextColor:col];
}

- (void)willPresentActionSheet:(UIActionSheet *)actionSheet {
   /*
   if(actionSheet.tag==0)return;
  
    //crashes on iOS8
   UIButton *bt=[[actionSheet valueForKey:@"_buttons"] objectAtIndex:actionSheet.tag-1];
   if(bt)
      [bt setImage:[UIImage imageNamed:@"ico_call_out2.png"] forState:UIControlStateNormal];
*/
}

-(IBAction)showSelectAccount{
   int iAccounts=2;//TODO getRealCnt
   void *pp[20];
   for(int i=0;i<20;i++){
      pp[i]=getAccountByID(i,1);
      if(pp[i])iAccounts++;else break;
   }
   if(iAccounts<2){
      if(iAccounts==1){
         [self setOutgoingAccount:pp[0]];
      }
      return;
   }
   
   //http://stackoverflow.com/questions/6130475/adding-images-to-uiactionsheet-buttons-as-in-uidocumentinteractioncontroller
   
   UIActionSheet *as = [[UIActionSheet alloc]initWithTitle:@"Select Account" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
   // [as 
   // as
   int iCurSel=0;
   
   char prevLabel[96];
   char curLabel[96];
   int n=0;
   
   void *pcdo=getCurrentDOut();
   
   for(int i=0;i<iAccounts;i++){
      if(pp[i]){
         
         const char *p=sendEngMsg(pp[i],"name");

         char* findSZByServKey(void *pEng, const char *key);
         char* pNr=findSZByServKey(pp[i], "nr");
         
         char bufz[5];bufz[0]=0;
         if(!pNr)pNr=&bufz[0];
         if(!pNr[0])pNr=findSZByServKey(pp[i], "un");
         if(!pNr)pNr=&bufz[0];
         
         const char *p2=sendEngMsg(pp[i],"isON");
         int iIsOn=p2 && strcmp(p2,"yes")==0;
         
         NSString *ns;

         if(iIsOn)
            ns=[NSString stringWithFormat:@"%s %s \U0001F30D",p,pNr];
         else
            ns=[NSString stringWithFormat:@"%s %s \U0001F4F5",p,pNr];
         
         
         snprintf(&curLabel[0],95,"%s%s",p,pNr);
         if(i && strcmp(prevLabel,curLabel)==0)
            continue;//will not show redundant account
         
         strcpy(prevLabel,curLabel);
         
         
         if(pp[i]==pcdo){
            iCurSel=n;
            //260F
            ns= [NSString stringWithFormat:@"%@ \U0001F4DE",ns];//U+1F4F1
//            ns= [NSString stringWithFormat:@"%@ \U0000260E",ns];
         }
         accountIdByIndex[[as addButtonWithTitle:ns]]=i;
         n++;
      }
      else break;
   }
   int ii=[as addButtonWithTitle:@"Cancel"];
   [as setCancelButtonIndex:ii];
   
   as.backgroundColor = [UIColor blackColor];
   as.tintColor = [UIColor whiteColor];
   
   as.tag=1+iCurSel;
   [as showFromTabBar:uiTabBar];
   [as release];
}

-(IBAction)askZRTP_cache_name_top{
   CTCall *c=calls.curCall;
   if(!c)return;
   if(!c->zrtpPEER.getLen())return;
   int match = c->nameFromAB==&c->zrtpPEER;
   if(!match)return;
   if(!btChangePN.isHidden)return;
   
   [self askZRTP_cache_name_f:0];
}

-(IBAction)askZRTP_cache_name{
   CTCall *c=calls.curCall;
   if(!c)return;
   
   int iUseNameFromPB=0;
   
   if(c->nameFromAB.getLen() && !(c->nameFromAB==&c->zrtpPEER))
   {
      iUseNameFromPB = c->sipDispalyNameEquals(c->zrtpPEER);
   }
   
   [self askZRTP_cache_name_f:iUseNameFromPB];
}

-(void)askZRTP_cache_name_f:(int)iUseNameFromPB{

   CTCall *c=calls.curCall;
   
   if(c && c->iShowEnroll){
     // [verifySAS setHidden:YES];
      c->iShowEnroll=0;
      c->iShowVerifySas=0;
      char buf[32];
      sprintf(&buf[0],"*t%u",c->iCallId);
      const char *x[2]={"",&buf[0]};
      z_main(0,2,x);
      [self refreshZRTP:c];
      return;
   }
   
   if(!c)return ;
   
   [self dontAllowCurCallChangeUntilVerifySas];
   //TODO if sev
   NSString *ns=[NSString stringWithFormat:@"%s:\n\"%s\"\n\n%s",T_TR("Compare with partner"), &c->bufSAS[0],T_TR("and enter partner's name here")];
   
   UIAlertView *dialog = [[UIAlertView alloc] initWithTitle:ns
                                                    message:@" \n " 
                                                   delegate:self 
                                          cancelButtonTitle:T_TRNS("Later")
                                          otherButtonTitles:T_TRNS("Confirm"),nil];
   
   
   
#if defined(T_ALERT_TF_NEW)

   dialog.alertViewStyle = UIAlertViewStylePlainTextInput;dialog.tag=3;[dialog becomeFirstResponder];
   UITextField *tf=[dialog textFieldAtIndex:0];
   tf.autocorrectionType=UITextAutocorrectionTypeYes;
   tf.autocapitalizationType=UITextAutocapitalizationTypeWords;
   if(tf){
      CTEditBase *e=&c->zrtpPEER;
      if(iUseNameFromPB){
         e=&c->nameFromAB;
      }
      else if(!e->getLen() && c->nameFromAB.getLen()){
         int v;
         if(::getCallInfo(c->iCallId,"media.zrtp.nomitm",&v)==0 && v==1){
            e=&c->nameFromAB;
         }
      }
      tf.text=toNSFromTB(e);
      [tf setTextAlignment:NSTextAlignmentCenter];
   }
   
   [dialog show];
   prevAlertView = dialog;
   [dialog release];
#else
   
   //textFieldAtIndex
   UITextField *nameField = [[UITextField alloc] initWithFrame:CGRectMake(20.0, 50.0+45.0, 245.0, 28.0)];
   [nameField setBackgroundColor:[UIColor whiteColor]];
   
   nameField.text=toNSFromTB(&c->zrtpPEER);
   [nameField setTextAlignment:UITextAlignmentCenter];
   
   [dialog addSubview:nameField];
   //CGAffineTransform moveUp = CGAffineTransformMakeTranslation(0.0, 100.0);
   // [dialog setTransform: moveUp];
   dialog.tag=(int)nameField;
   
   [dialog show];
   [dialog release];
   
   [nameField becomeFirstResponder];
   
   [nameField release];
#endif
}
-(void)showVerifyBT{
   
   if(!verifySAS.isHidden)return;
   
   CGRect originalFrame = verifySAS.frame;
   verifySAS.frame = CGRectMake(originalFrame.origin.x, originalFrame.origin.y
                                , originalFrame.size.width, 1);
   [verifySAS setHidden:NO];
   
   [UIView animateWithDuration:0.5 animations:^{verifySAS.frame = originalFrame;}];
   
}

-(void)refreshZRTP:(CTCall *)c{

   if(c && c==calls.curCall && c->iInUse && c->pEng && !c->iEnded){
      dispatch_async(dispatch_get_main_queue(), ^(void) {
         [self updateZRTP_infoMT:c];
         if(!c->iActive && !c->iEnded && zrtpPanel.isHidden){
            [self showZRTPPanel:1];
            const char *pr = T_TR("Ringing");
            if(strncmp(c->bufMsg,pr, strlen(pr))==0){//??????
               NSString *ci=[NSString stringWithUTF8String:&c->bufMsg[0]];
               [uiDur setText:ci];
            }
         }
         
      });
      
   }
}

-(int)selfCheck_comp_calls{

   return 0;
}

-(void)engCB{
   
   if(iIsInBackGround)return;
   [self updateLogTab];
}

NSTimer *_updateTimer=nil;


-(void)refreshCallScr{
   
   [self callThreadLedCB];
   
   static int c=0;c++;
   if(c<8)return;
   
   [self callThreadCB:900];
   c=0;
   
   static int shouldHideAt = 0;
   
   if(!calls.getCallCnt() && [self callScrVisible] ){
      if(shouldHideAt==0)shouldHideAt = get_time();
      else if(shouldHideAt<get_time()){
         shouldHideAt=0;
         [self tryStopCallScrTimer:0];
         iCanHideNow=1;
         [self performSelectorOnMainThread:@selector(onEndCall) withObject:nil waitUntilDone:TRUE];
      }
   }
   else shouldHideAt=0;
   
}

-(void)tryStartCallScrTimer{
   
   dispatch_async(dispatch_get_main_queue(), ^(void) {
      if(!calls.getCallCnt()  || (_updateTimer && [_updateTimer isValid]))return;
      
      if (_updateTimer) [_updateTimer invalidate];
      
      NSTimeInterval hz = 1./20.;
      
      _updateTimer = [NSTimer
                      scheduledTimerWithTimeInterval:hz
                      target:self
                      selector:@selector(refreshCallScr)
                      userInfo:nil
                      repeats:YES
                      ];
   });
}

-(void)tryStopCallScrTimer:(int)force{
   if(!force && calls.getCallCnt())return;
   dispatch_async(dispatch_get_main_queue(), ^(void) {
      if(!force && calls.getCallCnt())return;
      if (_updateTimer) {
         [_updateTimer invalidate];
         _updateTimer = nil;
      }
   });
   
}

#pragma mark - Invites

-(void) sendEmailInvite:(NSString*) email
{
	if (![MFMailComposeViewController canSendMail]) {
		UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Unable to open Mail" message:@"Mail is not configured on this device." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil] autorelease];
		[alert show];
		return;
	}
		
	MFMailComposeViewController* controller = [[MFMailComposeViewController alloc] init];
    controller.mailComposeDelegate = (id <MFMailComposeViewControllerDelegate>)self;
    [controller setToRecipients:@[email]];
    controller.subject = @"Let's Talk Securely with Silent Phone";
    [controller setMessageBody:@"Hi let's talk securely with Silent Phone. \n"
                                "Install it for iOS or Android here: https://silentcircle.com/invite"
                        isHTML:NO];
    
    [recentsController presentViewController:controller animated:YES completion:NULL];
	[controller release];
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    
//    if (result == MFMailComposeResultSent)
//    {
//  //      NSLog(@"email sent");
//    }
    
    [recentsController dismissViewControllerAnimated:YES completion:NULL];
}

-(void) sendSMS:(NSString*)phoneNumber message:(NSString *)message
{
    if (![MFMessageComposeViewController canSendText]) {
		UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Unable to send SMS" message:@"SMS messages are not supported on this device." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil] autorelease];
		[alert show];
		return;
	}
	MFMessageComposeViewController *controller = [[[MFMessageComposeViewController alloc] init] autorelease];
	controller.messageComposeDelegate = (id <MFMessageComposeViewControllerDelegate>)self;
	controller.recipients = @[phoneNumber];

	if ([message length] > 0)
		controller.body = message;
	
	[recentsController presentViewController:controller animated:YES completion:NULL];
 }

- (void)sendSMSInvite:(NSString *)phoneNumber {
	[self sendSMS:phoneNumber  message: @"Hi let's talk securely with Silent Phone. Install it for iOS or Android here: https://silentcircle.com/invite"];
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result
{
    
//    switch (result) {
//        case MessageComposeResultCancelled:
//            NSLog(@"Cancelled");
//            break;
//        case MessageComposeResultFailed:
//            NSLog(@"Failed");
//            break;
//        case MessageComposeResultSent:
//            NSLog(@"Send");
//            break;
//        default:
//            break;
//    }
    
    [recentsController dismissViewControllerAnimated:YES completion:NULL];
}

@end

#pragma mark - 

class CRESET_SEC_STEATE{
public:
   CRESET_SEC_STEATE(void *ret, void *ph, int iCallID, int iIsVideo, CTCall *c)
   :ret(ret),ph(ph),iCallID(iCallID),iIsVideo(iIsVideo),c(c){
   }
   void *ret;
   void *ph;
   int iCallID;
   int iIsVideo;
   CTCall *c;
};

void checkSDES(CTCall *c, void *ret, void *ph, int iCallID, int msgid){
   if(!c || c->iEnded)return ;
   
   int iSDESSecure=0;
   int iErr=0;
   int iVideo=0;
  
   switch(msgid){
      case CT_cb_msg::eZRTPErrA: iSDESSecure=::isSDESSecure(iCallID, 0);iErr=1;break;
      case CT_cb_msg::eZRTPErrV: iSDESSecure=::isSDESSecure(iCallID, 1);iErr=1;iVideo=1;break;
      case CT_cb_msg::eZRTPMsgV: iVideo=1;
      case CT_cb_msg::eZRTPMsgA:
         if(strcmp(iVideo? c->bufSecureMsgV :c->bufSecureMsg,"ZRTP Error")==0)
            iErr=1;
         
         if(!iErr)return ;
         
         iSDESSecure=::isSDESSecure(iCallID, iVideo);
         
         break;
         
      default:
         return;
   }
   if(!iSDESSecure)return ;
   
   if(c->iReplaceSecMessage[iVideo])return;
   c->iReplaceSecMessage[iVideo]=1;
   
   CRESET_SEC_STEATE *rs = new CRESET_SEC_STEATE(ret,ph,iCallID, iVideo,c);
   
   void startThX(int (cbFnc)(void *p),void *data);
   int resetSecStateTH(void *p);
   startThX(resetSecStateTH, rs);

   return ;
}

int resetSecStateTH(void *p){
   
   CRESET_SEC_STEATE *rs = (CRESET_SEC_STEATE*)p;
   for(int i=0;i<5;i++){
      sleep(1);
      if(!rs || !rs->c || rs->c->iEnded || rs->c->iCallId!=rs->iCallID)return 0;
   }
   
   int iSDESSecure=::isSDESSecure(rs->iCallID, rs->iIsVideo);
   if(!iSDESSecure)return 0;
   
   fncCBRet(rs->ret, rs->ph, rs->iCallID,
            rs->iIsVideo? CT_cb_msg::eZRTPMsgV : CT_cb_msg::eZRTPMsgA,
            "SECURE SDES", 0);
   return 0;
}


#pragma mark - engine callback

int fncCBRet(void *ret, void *ph, int iCallID, int msgid, const char *psz, int iSZLen){

   
   AppDelegate *s=(AppDelegate*)ret;
   
   if(!s || s->iExiting)return 0;
   
   CTCall *pc_old=s->calls.curCall;
   CTCall *c=[s findCallById:iCallID];
   CTCall *pc=s->calls.curCall;
   char _buf[128];
   //try to translate message should i do it here???
   if(psz && iSZLen>0){
      switch(msgid){
         case CT_cb_msg::eZRTPMsgV:
         case CT_cb_msg::eZRTPMsgA:
         case CT_cb_msg::eNewMedia:
         case CT_cb_msg::eZRTP_peer:
         case CT_cb_msg::eZRTP_peer_not_verifed:
         case CT_cb_msg::eZRTP_sas:
         case CT_cb_msg::eCalling:
         case CT_cb_msg::eIncomCall:
          case CT_cb_msg::eMsg:
            break;
         default:
            
            const char *n_psz = T_TRL(psz, iSZLen);
            if(n_psz!=psz){
               iSZLen=0;
               psz = n_psz;
               printf("[t=%s]\n",n_psz);
            }else if(psz){
               printf("[t-fail=%.*s]\n",iSZLen,psz);
            }
      }
   }

   int iLen=0;
   const char *p="";
   { 
      
      switch(msgid){
          case CT_cb_msg::eMsg:
          {
              NSString *nsChatMsg = [NSString stringWithUTF8String:psz];
              //NSLog(@"New msg: %@",nsChatMsg);
              [[NSNotificationCenter defaultCenter] postNotificationName:@"newChatMessageAsNS" object:nsChatMsg];
              //[NSNotification notificationWithName:@"newChatMessageAsNS" object:nsChatMsg];
          }
              //GO!! receive message
              break;
         case CT_cb_msg::eNewMedia:
            [s checkMedia:c charp:psz intv:iSZLen];
            break;
         case CT_cb_msg::eEnrroll:
            if(!c)break;
            c->iShowVerifySas=0;
            c->iShowEnroll=1;
            [s refreshZRTP:c];
            
            break;
         case CT_cb_msg::eZRTP_peer_not_verifed:
            if(!c)break;
            c->iShowVerifySas=1;
            if(psz)
               c->zrtpPEER.setText(psz);
            [s refreshZRTP:c];
            
            //[s performSelectorOnMainThread:@selector(showVerifyBT) withObject:nil waitUntilDone:FALSE];
            //if name set peer name
            break;
         case CT_cb_msg::eZRTP_peer:
            if(!c)break;
            if(!psz){
               c->iShowVerifySas=1;
            }
            else{
               c->zrtpPEER.setText(psz);
            }
            [s refreshZRTP:c];
            break;
         case CT_cb_msg::eZRTPMsgV:
            if(!c)break;
            if(psz)strcpy(c->bufSecureMsgV,psz);
            [s refreshZRTP:c];
            break;
         case CT_cb_msg::eZRTPMsgA:
            if(!c)break;
            if(psz)strcpy(c->bufSecureMsg,psz);
            [s refreshZRTP:c];
            break;
         case CT_cb_msg::eZRTPErrV:
            if(!c)break;
            strcpy(c->bufSecureMsgV,T_TR("ZRTP Error"));
            c->iIsZRTPError=2;
            if(psz){
               c->zrtpWarning.setText(psz);
               c->iZRTPShowPopup=2;
            }
            [s refreshZRTP:c];
            break;
         case CT_cb_msg::eZRTPErrA:
            if(!c)break;
            strcpy(c->bufSecureMsg,T_TR("ZRTP Error"));
            c->iIsZRTPError=1;
            
         case CT_cb_msg::eZRTPWarn:
            if(!c)break;
            if(psz){
               printf("[w=%s]",psz);
               c->zrtpWarning.setText(psz);
               c->iZRTPShowPopup=1;
            }
            [s refreshZRTP:c];
            break;
         case CT_cb_msg::eZRTP_sas:
            if(!c)break;
            if(psz)strcpy(c->bufSAS,psz);
            [s refreshZRTP:c];
            break;
         case CT_cb_msg::eSIPMsg:
            p=psz;
            iLen=iSZLen;
            break;
            
         case CT_cb_msg::eRinging:
            if(!c){
               [s endCall_cid:iCallID];
               break;
            }
            c->findAssertedName();
            p=T_TR("Ringing");
            break;
         case CT_cb_msg::eCalling:
            p=T_TR("Calling...");
            s->iCanShowSAS_verify=0;
          //  c=s->calls.curCall;
            //if(!c)break;
            if(!c || c->iCallId){//callid should not be empty here and must be !c
               c = s->calls.findCallByNumberAndNoCallID(psz, iSZLen);
               if(!c) {
                  [s endCall_cid:iCallID];
               }
               if(!c)break;
               
            }
            c->pEng=ph;
          //  printf("[==========callid=%d]",c->iCallId);
            c->iCallId=iCallID;
            c->setPeerName(psz, iSZLen);
            
            break;
         case CT_cb_msg::eEndCall:
            if(!c)break;
            if(!c->iEnded){
               c->iEnded=2;
               void vibrateOnce();vibrateOnce();
            }
            s->iDelayCallScreenHide = c->iSipHasErrorMessage;
            
            c->iDontAddMissedCall = psz && strcasecmp(psz, "Call completed elsewhere")==0;
            if(!c || !c->iSipHasErrorMessage)p=T_TR("Call ended");
            
            [s updateRecents:c];
            [s onStopCall];
            
            break;
         case CT_cb_msg::eStartCall:
            if(!c){
               [s endCall_cid:iCallID];
               break;
            }
            if(c){
               
               if(!c->bufSecureMsg[0]){strcpy(c->bufSecureMsg,T_TR("Connecting..."));[s refreshZRTP:c];}
               p=" ";//Call is active";
               c->iActive=2;
               if(!c->uiStartTime)c->uiStartTime=(unsigned int)get_time();
               if(c==s->calls.curCall){
                  dispatch_async(dispatch_get_main_queue(), ^(void) {
                     [s showZRTPPanel:1];
                     [s checkCallMngrMT];
                  });
               }
               else 
               {
                  [s checkCallMngr];
               }
               c->findAssertedName();
               if(s->iCallScreenIsVisible){
                  //void checkThread(AppDelegate *s);checkThread(s);
                  [s tryStartCallScrTimer];
               }
               
            }
            break;
         case CT_cb_msg::eError:
         {
            if(s->calls.curCall && !s->calls.curCall->iCallId){
               c=s->calls.curCall;
               p=psz;
            }
            else if(psz && c)p=psz;
            else{
               
               p=sendEngMsg(ph,NULL);
            }
            if(c)c->iSipHasErrorMessage=1;
            //if(curCall->)
         }
      }
      
      checkSDES(c, ret,ph,iCallID,msgid);
      
      if(msgid==CT_cb_msg::eIncomCall){
         s->iCanShowSAS_verify=0;
         c=[s getEmptyCall:0];
         if(!c){
            //TODO add missedCall
            [s endCall_cid:iCallID];
            return 0;
         }
         int vc=isVideoCall(iCallID);
         if(vc)p=T_TR("Incoming Video Call");else p=T_TR("Incoming call");
         
         {
            char bufRet3[128];
            int lp=getCallInfo(iCallID,"getPriority", bufRet3,127);
            if(lp>0){
               bufRet3[0]=toupper(bufRet3[0]);
               c->incomCallPriority.setText(bufRet3,lp);
               snprintf(_buf,sizeof(_buf),"%s\r\n(%s)",p,bufRet3);
               p=&_buf[0];
            }
         }
         if(pc_old && pc_old->iEnded)
            s->calls.setCurCall(c);
         
         c->pEng=ph;
         c->iCallId=iCallID;
         c->iIsIncoming=1;
         c->iShowVideoSrcWhenAudioIsSecure=vc;
         c->setPeerName(psz, iSZLen);
         c->findAssertedName();
         
      }
      
      if(c && (msgid == CT_cb_msg::eCalling || msgid==CT_cb_msg::eIncomCall)){
         getCallInfo(iCallID, "callid", c->szSIPCallId, sizeof(c->szSIPCallId)-1);
      }
      
      if(p && p[0] && c){

         if(iLen<1)iLen=strlen(p);
         if(iLen>=sizeof(c->bufMsg))iLen=sizeof(c->bufMsg)-1;
         
         strncpy(c->bufMsg,p,iLen);
         c->bufMsg[iLen]=0;
         //if(c->bufMsg[0]<' ')c->bufMsg[0]=' ';
         //if(c->bufMsg[1]<' ')c->bufMsg[1]=' ';
         
         if((c && pc==c) || s->calls.getCallCnt()==0){
            NSString *ns=NULL;
            ns=[[NSString alloc]initWithUTF8String:&c->bufMsg[0]];
            [s->uiCallInfo performSelectorOnMainThread:@selector(setText:) withObject:ns waitUntilDone:FALSE];
            [ns release];
         }
         
         NSLog(@"msg=:[%.*s]:",iLen,p);
         
      }
      if(msgid==CT_cb_msg::eIncomCall && c){
         dispatch_async(dispatch_get_main_queue(), ^(void) {
            [s incomingCall:c];
         });
      }
   }

   
   
   
   if(!s->iIsInBackGround && c)[s checkCallMngr];//TODO else resync cm
   
   if(!c && msgid!=CT_cb_msg::eReg && msgid!=CT_cb_msg::eEndCall){
      //endCall
   }
   
   [s engCB];
   
   if(!c && !s->iIsInBackGround){
      if(msgid==CT_cb_msg::eReg || msgid==CT_cb_msg::eError )
         [s performSelectorOnMainThread:@selector(setOutgoingAccount:) withObject:nil waitUntilDone:FALSE];
   }
   else{
      //TODO check updateScreen Thread
   }
   
   NSLog(@"msg %d ",msgid);
   void freemem_to_log();
   freemem_to_log();
   return 0;
}
/*
int isAudioDevConnected(){
   return [AppDelegate isAudioDevConnected];
}
*/
void callToApp(const char *dst){
    AppDelegate *a = (AppDelegate*)[UIApplication sharedApplication].delegate;
    [a callTo:'c' dst:dst];
}

void endCallToApp(const char *dst){
    AppDelegate *a = (AppDelegate*)[UIApplication sharedApplication].delegate;
    CTCall * c= a->calls.findCallByNumber(dst);
    [a endCallN:c];
}



#pragma mark - config

NSString *toNS(char *p);

static const int translateType[]={CTSettingsCell::eUnknown,CTSettingsCell::eOnOff,CTSettingsCell::eEditBox,CTSettingsCell::eInt,CTSettingsCell::eInt, CTSettingsCell::eSecure,CTSettingsCell::eUnknown};

static const int translateTypeInt[]={-1,1,0,1,1,0,-1,-1};

void startThX(int (cbFnc)(void *p),void *data);
typedef struct{
   CTList *l;
   AppDelegate *s;
}_saveCfgFromListTh;

int saveCfgFromListTh(void *p){
   _saveCfgFromListTh *ptr=(_saveCfgFromListTh*)p;
   CTList *l=ptr->l;
   AppDelegate *s=ptr->s;
   
   
   if(iCfgOn==2)//user must not change un or pwd or serv
   {
      const char *xu[]={"",":beforeCfgUpdate",":waitOffline"};
      z_main(0,3,xu);
      usleep(100*1000);
   }
   
   
   CTSettingsItem *i=(CTSettingsItem*)l->getNext();
   while(i){
      i->save(NULL);
      i=(CTSettingsItem*)l->getNext(i);
   }
   l->removeAll();
   usleep(100*1000);
   
   void t_save_glob();//TODO if title change save
   t_save_glob();
   
   [s checkBattery];
   
   const char *xr[]={"",":afterCfgUpdate"};
   z_main(0,2,xr);
   delete ptr;

   return 0;
}

void saveCfgFromList(CTList *l, AppDelegate *s){
   _saveCfgFromListTh *p=new _saveCfgFromListTh;
   p->l=l;
   p->s=s;
   startThX(saveCfgFromListTh,p);
}
void addChooseKey(CTList *l, const char *key, NSString *label);
CTList * addSection(CTList *l, NSString *hdr, NSString *footer, const char *key=NULL);

void setValueByKey(CTSettingsItem *i, const char *key, NSString *label){
   
   CTSettingsCell *sc=&i->sc;
   char *opt=NULL;
   int iType;
   int iSize;
   
   {
      char bufTmp[64];
      int iKeyLen=strlen(key);
      void *ret=findCfgItemByServiceKey(pCurService, (char*)key, iSize, &opt, &iType);
      
      /*
       printf("[key=%s %p sz%d t=%d ",key,ret,iSize,iType);
       if(ret){
       if(iType==1 || iType==3)printf("v=%d",*(int*)ret);
       if(iType==2)printf("v=%s",ret);
       }
       printf("]\n");
       */
      bufTmp[0]=0;
      
      if(ret){
         
         sc->iType=translateType[iType];
         sc->iPhoneEngineType=iType;;
         sc->iIsInt=translateTypeInt[iType];
         
         if(opt){strncpy(sc->bufOptions,opt,sizeof(sc->bufOptions));sc->bufOptions[sizeof(sc->bufOptions)-1]=0;}
         
         if(sc->iType==CTSettingsCell::eInt || sc->iType==CTSettingsCell::eOnOff){
            sprintf(bufTmp,"%d",*(int*)ret);
            ret=&bufTmp[0];
         }
         if(sc->bufOptions[0]){
            sc->iType=CTSettingsCell::eChoose;
         }
         
         if(i->sc.iType==CTSettingsCell::eChoose){
            static int iRecursiveSkip=0;
            if(!iRecursiveSkip){
               iRecursiveSkip=1;
               CTList *l = i->parent;
               i->root = new CTList();
               l = addSection(i->root,T_TRNS("Choose"),NULL);
               //char bufTmp[sizeof(i->sc.bufOptions)+1];
               //strncpy(bufTmp,i->sc.bufOptions,sizeof(i->sc.bufOptions));bufTmp[sizeof(bufTmp)-1]=0;
               char *bufTmp=opt;
               int pos=0;
               int iPrevPos=0;
               int iLast=0;
               while(!iLast){
                  if(bufTmp[pos]==',' || bufTmp[pos]==0){
                     if(bufTmp[pos]==0)iLast=1;
                     //bufTmp[pos]=0;
                     addChooseKey(l,key,[NSString stringWithFormat:@"%.*s",pos-iPrevPos, &bufTmp[iPrevPos]]);
                     iPrevPos=pos+1;
                  }
                  pos++;
               }
               iRecursiveSkip=0;
            }
            
         }

         if(sc->value)[sc->value release];
         sc->value=[[NSString alloc]initWithUTF8String:(const char *)ret];
      }
     
      //  else sc->value=nil;
      
      sc->setLabel(label);
      strcpy(sc->key,key);
      sc->iKeyLen=iKeyLen;
      sc->pCfg=pCurCfg;
      sc->pEng=pCurService;
   }
   
}

CTList * addSection(CTList *l, NSString *hdr, NSString *footer, const char *key){
   if(!l)return NULL;
   CTSettingsItem *i = new CTSettingsItem(l);
   l->addToTail(i);
   CTList *nl = i->initSection(hdr,footer);

   if(key){
      strcpy(i->sc.key,key);
      i->sc.iKeyLen=strlen(key);
   }
   i->sc.pCfg=pCurCfg;
   i->sc.pEng=pCurService;
   nl->pUserStorage=l;
  // i->parent=
   return nl;
}

CTList * addNewLevel(CTList *l, NSString *lev, int iIsCodec=0){
   if(!l)return NULL;
   CTSettingsItem *i=new CTSettingsItem(l);
   l->addToTail(i);
   l=i->initNext(lev);
   if(iIsCodec)i->sc.iType=CTSettingsCell::eCodec;
   i->sc.pCfg=pCurCfg;
   i->sc.pEng=pCurService;
   return l;
}

void addChooseKey(CTList *l, const char *key, NSString *label){
   CTSettingsItem *i=new CTSettingsItem(l);
   l->addToTail(i);
   setValueByKey(i,key,label);
   i->sc.iType=CTSettingsCell::eRadioItem;
}


void addReorderKey(CTList *l, const char *key, NSString *label){
   CTSettingsItem *i=new CTSettingsItem(l);
   l->addToTail(i);
   setValueByKey(i,key,label);
   i->sc.iType=CTSettingsCell::eReorder;
  // i->sc.iReleaseLabel=iReleaseLabel;
}

void addCodecKey(CTList *l, const char *key, NSString *hdr, NSString *footer){
   if(!l)return;
   l=addSection(l,hdr,footer,key);
#if 1
   char *opt=NULL;
   int iType;
   int iSize;
   void *ret=findCfgItemByServiceKey(pCurService, (char*)key, iSize, &opt, &iType);
   if(ret && ((char*)ret)[0]){
      char bufTmp[256];
      strcpy(bufTmp,(char*)ret);
      int pos=0;
      int iPrevPos=0;
      int iLast=0;
      
      while(!iLast){
         if(pos>=iSize || bufTmp[pos]=='.' || bufTmp[pos]==',' || bufTmp[pos]==0){
            if(pos>=iSize  || bufTmp[pos]==0)iLast=1;
            bufTmp[pos]=0;
            if(isdigit(bufTmp[iPrevPos])){
               const char *codecID_to_sz(int id);
               const char *pid=codecID_to_sz(atoi(&bufTmp[iPrevPos]));
               if(pid)
                  addReorderKey(l,key,[NSString stringWithUTF8String:pid]);
            }
            else{
               addReorderKey(l,key,[NSString stringWithUTF8String:&bufTmp[iPrevPos]]);
            }
            iPrevPos=pos+1;
         }
         pos++;
      }
      
   }

#endif
   
}

CTSettingsItem* addItemByKey(CTList *l, const char *key, NSString *label){
   if(!l)return NULL;
   CTSettingsItem *i=new CTSettingsItem(l);
   l->addToTail(i);
   i->section = (CTList*)l->pUserStorage;
   setValueByKey(i,key,label);
   return i;
}

int onDeleteAccount(void *pSelf, void *pRetCB){
   CTSettingsItem *it=(CTSettingsItem*)pSelf;
   if(!it || !it->sc.pEng)return -1;
   
   sendEngMsg(it->sc.pEng,"delete");
   //   it->sc.b
   
   
   return 0;
}

CTList * addSectionP(CTList *l, NSString *hdr, NSString *footer, const char *key=NULL){
 //  if(!iCfgOn || !l)return NULL;
   return addSection(l, hdr, footer, key);
}

CTSettingsItem* addItemByKeyP(CTList *l, const char *key, NSString *label){
  // if(!iCfgOn || !l)return NULL;
   return addItemByKey(l, key, label);
}
CTList * addNewLevelP(CTList *l, NSString *lev, int iIsCodec=0){
  // if(!iCfgOn || !l)return NULL;
   return addNewLevel(l ,lev, iIsCodec);
}

int switchOnSDES_ZRTP(void *pSelf, void *pRetCB){
   CTSettingsItem *x;
   CTSettingsItem *it=(CTSettingsItem*)pSelf;
   if(!it)return -1;
   
   const char *p=it->getValue();
   if(p[0]=='0')return 0;
   
   
   CTList *l=(CTList *)it->parent;
   if(!l)return -2;
   
   x=(CTSettingsItem *)l->findItem((void*)"iSDES_On", sizeof("iSDES_On")-1);
   if(x)x->setValue("1");//inv

   x=(CTSettingsItem *)l->findItem((void*)"iZRTP_On", sizeof("iZRTP_On")-1);
   if(x)x->setValue("1");//inv
   
   return 2;
}

int switchOfTunneling(void *pSelf, void *pRetCB)
{
   CTSettingsItem *x;
   CTSettingsItem *it=(CTSettingsItem*)pSelf;
   if(!it)return -1;
   
   const char *p=it->getValue();
   if(p[0]=='1')return 0;
   
   
   CTList *l=(CTList *)it->parent;
   if(!l)return -2;
   
   x=(CTSettingsItem *)l->findItem((void*)"iZRTPTunnel_On", sizeof("iZRTPTunnel_On")-1);
   if(x)x->setValue("0");//inv
   
   return 2;
}

CTList *addAcount(CTList *l, const char *name, int iDel){
   
   CTSettingsItem *i;
   CTList *n=addNewLevel(l,[[NSString alloc]initWithUTF8String:name]);
   CTSettingsItem *ac=(CTSettingsItem *)l->getLTail();
   ac->sc.iCanDelete=iDel;
   ac->sc.onDelete=onDeleteAccount;
   
   CTList *x=addSectionP(n,@"Server settings",NULL);
   
   addItemByKey(x,"szTitle",@"Account title");
   CTSettingsItem *ii=addItemByKey(x,"iAccountIsDisabled",@"Enabled");
   if(ii)ii->sc.iInverseOnOff=1;
   
   CTList *s=addSection(n,@"",NULL);
   
   addItemByKeyP(s,"un",@"User name");
   addItemByKeyP(s,"pwd",@"Password");
   addItemByKeyP(s,"tmpServ",@"Domain");
   addItemByKey(s,"nick",@"Display name");
   
   
   s=addSectionP(n,@"",NULL);
   CTList *adv=addNewLevelP(s,@"Advanced");
   
   s=addSection(adv,@"ZRTP",NULL);
   i=addItemByKey(s,"iZRTP_On",@"Enable ZRTP");i->sc.onChange=switchOfTunneling;
   i=addItemByKey(s,"iSDES_On",@"Enable SDES");i->sc.onChange=switchOfTunneling;
   i=addItemByKey(s,"iZRTPTunnel_On",@"Enable ZRTP tunneling");i->sc.onChange=switchOnSDES_ZRTP;
   
   s=addSection(adv,@"",NULL);
   addItemByKey(s,"nr",@"SIP user-ID");
   
   s=addSection(adv,@"Network",NULL);
   addItemByKey(s,"szSipTransport",@"SIP transport");
   addItemByKey(s,"uiExpires",@"Reregistration time(s)");
   addItemByKey(s,"bufpxifnat",@"Proxy");//TODO outgoing 
   
   addItemByKey(s,"iSipPortToBind",@"SIP Port");
   addItemByKey(s,"iRtpPort",@"RTP Port");
   
   
   
   addItemByKey(s,"iSipKeepAlive",@"Send SIP keepalive");
   addItemByKey(s,"iUseStun",@"Use STUN");
   addItemByKey(s,"bufStun",@"STUN server");
   addItemByKey(s,"iUseOnlyNatIp",@"Use device IP only");
   
   
   
   s=addSection(adv,@"Media",NULL);
   i=addItemByKey(s,"iCanUseP2Pmedia",@"Use media relay");i->sc.iInverseOnOff=1;//disables enables ice
   
   addItemByKey(s,"bufTMRAddr",@"TMR server");
   
   addItemByKey(s,"iResponseOnlyWithOneCodecIn200Ok",@"One codec in 200OK");
   addItemByKey(s,"iPermitSSRCChange",@"Allow SSRC change");
   
   s=addSection(adv,@"Audio",NULL);
   CTList *l2;
   CTList *s2;
   CTList *cod;
   //--------------------->>----
   l2=addNewLevel(s,@"WIFI");
   s2=addSection(l2,@"",NULL);
   cod=addNewLevel(s2,@"Codecs",1);
   
   addCodecKey(cod,"szACodecs",@"Enabled",NULL);
   addCodecKey(cod,"szACodecsDisabled",@"Disabled",NULL);
   
   addItemByKey(s2,"iPayloadSizeSend",@"RTP Packet size(ms)");
   addItemByKey(s2,"iUseVAD",@"Use SmartVAD®");
   //---------------------<<-----
   //---------------------
   l2=addNewLevel(s,@"3G");
   s2=addSection(l2,@"",NULL);
   cod=addNewLevel(s2,@"Codecs",1);
   
   addCodecKey(cod,"szACodecs3G",@"Enabled",NULL);
   addCodecKey(cod,"szACodecsDisabled3G",@"Disabled",NULL);
   
   addItemByKey(s2,"iPayloadSizeSend3G",@"RTP Packet size(ms)");
   addItemByKey(s2,"iUseVAD3G",@"Use SmartVAD®");
   
   
   
   
   //   l2=addNewLevel(s,@"If bad network(TODO)");

   
   // addItemByKey(s,"iUseAEC",@"Use software EC");
   
   s=addSection(adv,@"Video",NULL);
   
   CTSettingsItem *liv=addItemByKey(s,"iDisableVideo",@"Video call");//TODO rename
   if(liv)liv->sc.iInverseOnOff=1;
   addItemByKey(s,"iCanAttachDetachVideo",@"Can Add Video");
   
   addItemByKey(s,"iVideoKbps",@"Max Kbps");
   addItemByKey(s,"iVideoFrameEveryMs",@"Frame Interval(ms)");
   addItemByKey(s,"iVCallMaxCpu",@"Max CPU usage %");//TODO can change in call
   
   
  /*
   s=addSection(adv,@"",NULL);
   addItemByKey(s,"szUA",@"SIP user agent");
   addItemByKey(s,"szUASDP",@"SDP user agent");
   */
   
   s=addSection(adv,@"",NULL);
   addItemByKey(s,"iDebug",@"Debug");
   liv=addItemByKey(s,"bCreatedByUser",@"Can reprovision");
   
   if(liv)liv->sc.iInverseOnOff=1;
   
   addItemByKey(s,"iDisableDialingHelper",@"Disable Dialer Helper");
   
   
//   addItemByKey(s,"iIsTiViServFlag",@"Is Tivi server?");
   
   return n;
}



int onChangeSHA384(void *pSelf, void *pRetCB){
   
   CTSettingsItem *x;
   CTSettingsItem *it=(CTSettingsItem*)pSelf;
   if(!it)return -1;
   
   const char *p=it->getValue();
   if(p[0]=='1')return 0;
   
   
   CTList *l=(CTList *)it->parent;
   if(!l)return -2;
   
   x=(CTSettingsItem *)it->findInSections((void*)"iDisableECDH384", sizeof("iDisableECDH384")-1);
   if(x)x->setValue("0");//inv
   
   x=(CTSettingsItem *)it->findInSections((void*)"iDisableBernsteinCurve3617", sizeof("iDisableBernsteinCurve3617")-1);
   if(x)x->setValue("0");//inv
   
   return 2;
}

int onChangeAES256(void *pSelf, void *pRetCB){
   
   CTSettingsItem *x;
   CTSettingsItem *it=(CTSettingsItem*)pSelf;
   if(!it)return -1;
   
   const char *p=it->getValue();
   if(p[0]=='1')return 0;
   
   
   CTList *l=(CTList *)it->parent;
   if(!l)return -2;
   
   x=(CTSettingsItem *)it->findInSections((void*)"iDisableECDH384", sizeof("iDisableECDH384")-1);
   if(x)x->setValue("0");//inv

   x=(CTSettingsItem *)it->findInSections((void*)"iDisableBernsteinCurve3617", sizeof("iDisableBernsteinCurve3617")-1);
   if(x)x->setValue("0");//inv
   
   return 2;
}

int onChangeNist(void *pSelf, void *pRetCB){

   CTSettingsItem *it=(CTSettingsItem*)pSelf;
   if(!it)return -1;
   CTSettingsItem *x;
   
   const char *p=it->getValue();
   if(!p)return 0;
   if(p[0]=='0')return 0;
   

   int *v;
   
   
   const char *str[]={"iDisableTwofish","iDisableSkein","iDisableSkeinHash","iDisableBernsteinCurve25519","iDisableBernsteinCurve3617"
       ,"iEnableSHA384","iDisableAES256" ,NULL};//enable384hash and enable256keysize
   for(int i=0;;i++){
      if(!str[i])break;
      x=(CTSettingsItem *)it->findInSections((void*)str[i], strlen(str[i]));
      if(x)x->setValue("1");//label is inveresed inv
 
      v=(int *)findGlobalCfgKey(str[i]);
      if(v && strcmp(str[i],"iEnableSHA384")==0)*v=1;else
      if(v)*v=0;
      
      
   }
   /*
   x=(CTSettingsItem *)it->findInSections((void*)"iDisableTwofish", sizeof("iDisableTwofish")-1);
   if(x)x->setValue("1");//inv
   v=(int *)findGlobalCfgKey("iDisableTwofish");
   if(v)*v=0;
   
   v=(int *)findGlobalCfgKey("iDisableSkein");
   if(v)*v=0;;
   x=(CTSettingsItem *)it->findInSections((void*)"iDisableSkein", sizeof("iDisableSkein")-1);
   if(x)x->setValue("1");//inv
   
   x=(CTSettingsItem *)it->findInSections((void*)"iDisableSkeinHash", sizeof("iDisableSkeinHash")-1);
   if(x)x->setValue("1");//non inv
   
   v=(int *)findGlobalCfgKey("iDisableSkeinHash");
   if(v)*v=0;;
   
   */

//   v=(int *)findGlobalCfgKey("iDisableSkein");//auth
  // if(v)*v=res;

   return 2;
}


int onChange386(void *pSelf, void *pRetCB){
   CTSettingsItem *x;
   CTSettingsItem *it=(CTSettingsItem*)pSelf;
   if(!it)return -1;
   
   const char *p=it->getValue();
   if(p[0]=='0')return 0;
   

   
   x=(CTSettingsItem *)it->findInSections((void*)"iEnableSHA384", sizeof("iEnableSHA384")-1);
   if(x)x->setValue("1");
   
   x=(CTSettingsItem *)it->findInSections((void*)"iDisableAES256", sizeof("iDisableAES256")-1);
   if(x)x->setValue("1");//label is inversed

   return 2;
}

int onChangePref2K(void *pSelf, void *pRetCB){
   CTSettingsItem *it=(CTSettingsItem*)pSelf;
   CTSettingsItem *x;
   if(!it)return -1;   
   
   const char *p=it->getValue();
   if(p[0]=='0')return 0;
   
   
   CTList *l=(CTList *)it->parent;
   if(!l)return -2;
   
   
   x=(CTSettingsItem *)it->findInSections((void*)"iDisableDH2K", sizeof("iDisableDH2K")-1);
   if(x)x->setValue("1");//label is inversed
   return 2;
}
int onChangeDis2K(void *pSelf, void *pRetCB){
   CTSettingsItem *it=(CTSettingsItem*)pSelf;
   CTSettingsItem *x;
   if(!it)return -1;
   
   const char *p=it->getValue();
   if(p[0]=='1')return 0;
   
   CTList *l=(CTList *)it->parent;
   if(!l)return -2;
   
   
   x=(CTSettingsItem *)it->findInSections((void*)"iPreferDH2K", sizeof("iPreferDH2K")-1);
   if(x)x->setValue("0");//label is inversed
   return 2;
}

int onChangeGlob(void *pSelf, void *pRetCB){
   CTSettingsItem *it=(CTSettingsItem*)pSelf;
   if(!it)return -1;
   
   char *p=(char*)it->getValue();
   int v=0;
   int iSize=0;
   p = it->tryConvertStrIntPTR(p, iSize, &v);
   //tryConvertStrIntPTR
   
   for(int i=0;i<20;i++){
      void *a=getAccountByID(i,1);
      if(!a)continue;
      void *c=getAccountCfg(a);
      setCfgValue(p,iSize,c,&it->sc.key[0],it->sc.iKeyLen);
   }

   return 0;
}


static void loadAccountSection(CTList *l){
   CTList *as=addSection(l,@" ",@"");
   CTList *ac=addNewLevel(as,@"Accounts");
   CTList *n=addSection(ac,@"Enabled",@"");
   
   int cnt=0;
   
   for(int i=0;i<20;i++){
      pCurService=getAccountByID(cnt,1);
      if(pCurService){
         cnt++;
         pCurCfg=getAccountCfg(pCurService);
         addAcount(n,getAccountTitle(pCurService),1);
      }
   }
   
   cnt=0;
   for(int i=0;i<20;i++){
      pCurService=getAccountByID(cnt,0);
      
      if(pCurService){
         if(!cnt)n=addSection(ac,@"Disabled",NULL);
         cnt++;
         pCurCfg=getAccountCfg(pCurService);
         addAcount(n,getAccountTitle(pCurService),1);
      }
   }
   
   //TODO check can we add new account
   if(iCfgOn!=2){
      pCurService=NULL;
      pCurCfg=NULL;
      return;
   }
   
   
   int canAddAccounts();
   
   if(canAddAccounts()){
      n=addSection(ac,NULL,NULL);
      
      void *getEmptyAccount();
      int createNewAccount(void *pSelf, void *pRet);
      
      pCurService=getEmptyAccount();
      
      if(pCurService){
         pCurCfg=getAccountCfg(pCurService);
         CTList *rr=addAcount(n,"New",0);
         if(rr){
            CTSettingsItem *ri=(CTSettingsItem *)n->getLTail();
            if(ri){
               ri->sc.pRetCB=NULL;
               ri->sc.onChange=createNewAccount;
            }
         }
      }
   }
   
   pCurService=NULL;
   pCurCfg=NULL;
}

int onChangeRingtone(void *pSelf, void *pRetCB){
   
   CTSettingsItem *it=(CTSettingsItem*)pSelf;
   if(!it)return -1;
   
   const char *p=it->getValue();
   if(!p)return 0;

   playTestRingTone(getRingtone(p));

   return 4|2;
}

int onClickTermsOfService(void *pSelf, void *pRetCB){
   // http://accounts.silentcircle.com/terms #SP-580
   
   NSURL *url = [NSURL URLWithString:@"http://accounts.silentcircle.com/terms"];
   [[UIApplication sharedApplication] openURL:url];

   return 0;
}

int onClickPrivacyStatement(void *pSelf, void *pRetCB){
   //https://silentcircle.com/privacy #SP-582
   
   NSURL *url = [NSURL URLWithString:@"https://silentcircle.com/privacy"];
   [[UIApplication sharedApplication] openURL:url];
   return 0;
}

static CTSettingsItem* addItemByKeyF(CTList *l, const char *key, NSString *label, NSString *footer){
   
   CTList *n=addSection(l,NULL,footer);
   CTSettingsItem *i=addItemByKey(n,key,label);
   
   return i;
}

static void addUserInterfaceSettings(CTList *pref){
   //CTList *n;

   CTList *ui=addSection(pref,NULL,NULL);
   CTList *ui2=addNewLevel(ui,T_TRNS("User Interface"));
   
   addItemByKeyF(ui2,"iKeepScreenOnIfBatOk",T_TRNS("Desktop phone mode"), T_TRNS("Disables sleep while connected to external power and running in foreground."));//keep screen on while charging and battery > 50%
   
   
   addItemByKeyF(ui2,"szRecentsMaxHistory",T_TRNS("Keep Recents"),NULL);
   addItemByKeyF(ui2,"szMessageNotifcations",T_TRNS("Message Notifications"),NULL);
   
   int canEnableDialHelper(void);
   
   if(canEnableDialHelper()){
      addItemByKeyF(ui2,"iEnableDialHelper",T_TRNS("Enable Dialing Helper"),NULL);
      addItemByKeyF(ui2,"szDialingPrefCountry",T_TRNS("Dialing preference"),NULL);
   }
   
   
   addItemByKeyF(ui2,"iAudioUnderflow",@"Audio underflow tone",@"Plays low tone if no media packets are arriving from network. Indicates network problems.");

   addItemByKeyF(ui2,"iShowRXLed",@"Show RX LED",@"Traffic indicator light for incoming media packets.");
   
   if(iCfgOn>=1){
      addItemByKeyF(ui2,"iEnableAirplay",@"Airplay During Calls",@"Allow Airplay during Call Screen. Recommended for demos only.");
      
   }
}

static void addFWSettings(CTList *pref){
   //CTList *n;
   
   CTList *ui=addSection(pref,NULL,NULL);
   CTList *ui2=addNewLevel(ui,T_TRNS("Firewall traversal"));
   if(iCfgOn==2){
      addItemByKeyF(ui2,"iForceFWTraversal",T_TRNS("Force FW Traversal"), T_TRNS("Will use only TCP for RTP media. Not recomended to use in production"));
   }
   addItemByKeyF(ui2,"iEnableFWTraversal",T_TRNS("Enable FW Traversal"), T_TRNS("Will enable TCP for RTP media"));
}

static void addSecSettings(CTList *pref){
   
   CTSettingsItem *it;
   CTList *n;
   
   CTList *zp=addSection(pref,NULL,NULL);
   n=addNewLevel(zp,T_TRNS("Security"));

   if(iCfgOn==1){
      pCurService = getAccountByID(0,1);//pCurService must be valid before using addItemByKey (non global)
      pCurCfg = getAccountCfg(pCurService);//pCurCfg must be valid before using addItemByKey (non global)
      it=addItemByKeyF(n,"iCanUseP2Pmedia",@"Use media relay", @"Always use media relay server, to conceal remote party's location. Adds latency.");
      it->sc.iInverseOnOff=1;//disables enables ice
      if(it)it->sc.onChange=onChangeGlob;//change setting for all accounts
      
      pCurCfg=NULL;pCurService=NULL;
   }

   it=addItemByKeyF(n,"iPreferNIST",T_TRNS("Prefer Non-NIST Suite"),T_TRNS("Always prefer non-NIST algorithms if available: Twofish, Skein, and Bernstein curves."));it->sc.iInverseOnOff=1;
   if(it)it->sc.onChange = onChangeNist;
   
   it=addItemByKeyF(n,"iDisable256SAS",T_TRNS("SAS word list"),T_TRNS("Authentication code is displayed as special words instead of letters and numbers."));
   if(it)it->sc.iInverseOnOff=1;
    

    if([Utilities utilitiesInstance].isLockEnabled)
    {
        it=addItemByKeyF(n,"setPassLock",T_TRNS("Set Password lock"),T_TRNS("Lock Chat and Recents tabs with password"));
        if(it)
        {
            it->sc.passLock = 1;
            it->sc.iType = CTSettingsCell::eOnOff;
            NSString *value = [[NSUserDefaults standardUserDefaults] valueForKey:@"lockKey"];
            if(value)
            {
                it->sc.value = @"1";
            }
            else
            {
                it->sc.value = @"0";
            }
        }

    }
}

static void addZRTPSettings(CTList *pref){
   
   CTSettingsItem *it;
   CTList *n;
   
   CTList *zp=addSection(pref,NULL,NULL);
   n=addNewLevel(zp,@"ZRTP");
   
   CTList *top =addSection(n,NULL,NULL);
   CTList *publ=addSection(n,NULL,NULL);
   CTList *symmetricAlgoritms=addSection(n,NULL,NULL);
   CTList *mac=addSection(n,NULL,NULL);
   
   it=addItemByKey(publ,"iDisableBernsteinCurve3617",@"ECDH-414");if(it){it->sc.iInverseOnOff=1;it->sc.onChange=onChange386;}
   it=addItemByKey(publ,"iDisableBernsteinCurve25519",@"ECDH-255");if(it)it->sc.iInverseOnOff=1;

   
   it=addItemByKeyP(publ,"iDisableECDH384",@"NIST ECDH-384");
   if(it)it->sc.onChange=onChange386;
   if(it)it->sc.iInverseOnOff=1;
   
   it=addItemByKeyP(publ,"iDisableECDH256",@"NIST ECDH-256");
   if(it)it->sc.iInverseOnOff=1;
   
   it=addItemByKeyP(publ,"iDisableDH2K",@"DH-2048");
   if(it)it->sc.onChange=onChangeDis2K;
   if(it)it->sc.iInverseOnOff=1;
   
   it=addItemByKeyP(publ,"iPreferDH2K",@"Prefer DH-2048");
   if(it)it->sc.onChange=onChangePref2K;
   
   it=addItemByKeyP(symmetricAlgoritms,"iDisableAES256",@"256-bit cipher key");
   if(it)it->sc.iInverseOnOff=1;
   if(it)it->sc.onChange=onChangeAES256;
   
   it=addItemByKeyP(symmetricAlgoritms,"iEnableSHA384",@"384-bit hash");
   if(it)it->sc.onChange=onChangeSHA384;
   
   it=addItemByKeyP(symmetricAlgoritms,"iDisableTwofish",@"Twofish");
   if(it)it->sc.iInverseOnOff=1;
   
   it=addItemByKey(symmetricAlgoritms,"iDisableSkeinHash",@"Skein");if(it)it->sc.iInverseOnOff=1;

   
   
   
   it=addItemByKey(top,"iPreferNIST",@"Prefer Non-NIST Suite");
   if(it)it->sc.onChange=onChangeNist;
   if(it)it->sc.iInverseOnOff=1;
   
   it=addItemByKey(top,"iDisable256SAS",@"SAS word list");
   if(it)it->sc.iInverseOnOff=1;


   
   it=addItemByKeyP(mac,"iDisableSkein",@"SRTP Skein-MAC");
   if(it)it->sc.iInverseOnOff=1;
   
   CTList *sn=addSectionP(n,@"Use with caution",NULL);
   it=addItemByKey(sn,"iClearZRTPCaches",@"Clear caches");
   if(it)it->sc.iType=it->sc.eButton;
}

static void addAboutSection(CTList *l){
   CTList *n;
   n=addSection(l,NULL,NULL);
   CTList *about=addNewLevel(n,T_TRNS("About"));
   
   n=addSection(about,T_TRNS("Build"),NULL);
   NSString* nsB = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
   NSString* nsV = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
   //
   const char *getZRTP_Build(void);
   addItemByKey(n,"*abc", [NSString stringWithFormat:@"%@ (%@) %s",nsV,nsB,getZRTP_Build() ]);
   
   CTList *sn=addSection(about,NULL,NULL);
   CTSettingsItem *it;
   
  //  #SP-580,  #SP-582
   
   it=addItemByKey(sn,"*tos",@"Terms Of Service");
   if(it){
      it->sc.iType=it->sc.eButton;
      it->sc.iIsLink=1;
      it->sc.onChange=onClickTermsOfService;
   }
   
   it=addItemByKey(sn,"*priv",@"Privacy Statement");
   if(it){
      it->sc.iType=it->sc.eButton;
      it->sc.iIsLink=1;
      it->sc.onChange=onClickPrivacyStatement;
   }
   
}


void loadSettings(CTList *l){

   CTList *n;
   
   if(iCfgOn!=2){
      /*
      CTSettingsItem *it;
      pCurService = getAccountByID(0,1);//pCurService must be valid before using addItemByKey
      pCurCfg = getAccountCfg(pCurService);//pCurCfg must be valid before using addItemByKey
      n=addSection(l,@" ",NULL);
      it=addItemByKey(n,"nick",@"Display name");
      if(it)it->sc.onChange=onChangeGlob;//change setting for all accounts
      pCurService=0;pCurCfg=0;
       */
   }
   else{
      loadAccountSection(l);
   }
   

   if(iCfgOn==2){
      n=addSection(l,NULL,NULL);
      CTList *pref=addNewLevel(n,T_TRNS("Preferences"));

      addZRTPSettings(pref);
      addUserInterfaceSettings(pref);
      {
         CTSettingsItem *it;
         CTList *n=addSection(pref,NULL,NULL);
         it=addItemByKey(n,"szRingTone",T_TRNS("Ringtone"));
         if(it)it->sc.onChange=onChangeRingtone;
      }
      addFWSettings(l);
      
   }
   else{
      addSecSettings(l);
      addUserInterfaceSettings(l);
      {
         CTSettingsItem *it;
         CTList *n=addSection(l,NULL,NULL);
         it=addItemByKey(n,"szRingTone",T_TRNS("Ringtone"));
         if(it)it->sc.onChange=onChangeRingtone;
      }
      //if(iCfgOn==1)
         addFWSettings(l);
   }
   addAboutSection(l);
 
}

#pragma mark - call screen monitoring thread

static int iThreads=0;
static int iThreadIsStarting=0;

void* callMonitorThread(void* data)
{
   
   if(iThreadIsStarting>0)iThreadIsStarting--;
   iThreads++;
   int iThreadID=iThreads;
   AppDelegate *p=(AppDelegate*)data;
   
   int iShowRXLed=0;
   int *pi=(int*)findGlobalCfgKey("iShowRXLed");
   if(pi)iShowRXLed=*pi;

   NSAutoreleasePool* tempPool = [[NSAutoreleasePool alloc] init];
   
   int i2Threads=0;
   int cnt=0;
   
   if(iThreads>1){
      for(int i=0;i<5;i++){
         
         usleep(200*1000);
         if(iThreads==1)break;
      }
   }
   
   static const int *piShowGeekStrip = (const int *)findGlobalCfgKey("iShowGeekStrip");
   
   int n=0;
   while(1){
      if(!p->iIsInBackGround && (iShowRXLed ||  (piShowGeekStrip && *piShowGeekStrip))){
         [p callThreadLedCB];
         usleep(20*1000);
         n++;
         if(n<40)continue;
         n=0;
      }
      int cs=p->calls.getCallCnt();
      if(!cs && cnt>4)break;
      [p callThreadCB:900];
      cnt++;
      if(iThreads>1){
         i2Threads++;
         if(i2Threads>10 && iThreadID==iThreads)break;
         usleep(5000);
      }
      else{
         i2Threads=0;
      }
   }
   
   
   if(iThreads==1){
      int i;
      
      for(i=0;[p callScrVisible] && i<3;i++){
         usleep(600*1000);
         
      }
      
      if([p callScrVisible] && !p->calls.getCallCnt()){
         
         p->iCanHideNow=1;
         [p performSelectorOnMainThread:@selector(onEndCall) withObject:nil waitUntilDone:TRUE];
      }
   }
   
   iThreads--;
   
   [tempPool drain];
   
   return NULL;
}

void LaunchThread(AppDelegate *c)
{
   // Create the thread using POSIX routines.
   //return;
   
   if(iThreadIsStarting)return;
   iThreadIsStarting++;
   pthread_attr_t  attr;
   pthread_t       posixThreadID;
   int             returnVal;
   
   returnVal = pthread_attr_init(&attr);
   assert(!returnVal);
   returnVal = pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
   assert(!returnVal);
   
   int     threadError = pthread_create(&posixThreadID, &attr, &callMonitorThread, c);
   
   returnVal = pthread_attr_destroy(&attr);
   assert(!returnVal);
   
   if (threadError != 0)
   {
      iThreadIsStarting=0;
   }
}

void checkThread(AppDelegate *s){
   if(iThreads==0){
      LaunchThread(s);
   }
}

void exitShowApp(const char *msg){
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(2);
        dispatch_async(dispatch_get_main_queue(), ^{
           
           UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Important!!!"
                                                                       message:[NSString stringWithUTF8String: tg_translate(msg,0)]
                                                                preferredStyle:UIAlertControllerStyleAlert];
           
           [ac retain];
           
           [ac addAction:[UIAlertAction actionWithTitle:T_TRNS("Ok")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action){
                                                   exit(0);
                                                   [ac release];
                                                }]];

           AppDelegate *app = (AppDelegate*)[UIApplication sharedApplication].delegate;
           
           UIViewController *vc = app.window.rootViewController;
           
           [vc presentViewController:ac animated:YES completion:nil];
                          
           /*
            UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Important!!!"
                                                           message:[NSString stringWithUTF8String:msg]
                                                          delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Ok", nil];
            
            [alert show];
            app.window.userInteractionEnabled = NO;
            [app.window setHidden:YES];
            */
        });
        
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            sleep(2);
            void t_onEndApp();
            t_onEndApp();
            sleep(30);
            exit(0);
        });
    });
    
    
}

