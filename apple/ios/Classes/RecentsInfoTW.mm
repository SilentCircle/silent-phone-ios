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
const char *tg_translate(const char *key, int iKeyLen);
#define T_TR(_T_KEY) tg_translate(_T_KEY, sizeof(_T_KEY)-1)
#define T_TRL(_T_KEY, _T_KL) tg_translate(_T_KEY, _T_KL)
#define T_TRNS(_T_KEY) [NSString stringWithUTF8String:tg_translate(_T_KEY, sizeof(_T_KEY)-1)]

#import <QuartzCore/CALayer.h>

#import "RecentsInfoTW.h"
#import "CallLogPopup.h"
#import "DBManager.h"
#import "Recents.h"
#import "SP_FastContactFinder.h"
#import "UICellController.h"
#import "Utilities.h"
#import "AppDelegate.h"

#define kAddContactIimageSize 30

@interface RecentsInfoTW ()

@end

CTRecentsItem *getByIdxAndMarker(CTList *l, int idx, void* iMarker);
NSString *toNSFromTB(CTStrBase *b);
NSString *toNSFromTBN(CTStrBase *b, int N);
void insertDateTime(CTEditBase *e, int iTime ,int iTimeOrDayOnly);
void insertDateTime(char  *buf, int iTime ,int iTimeOrDayOnly);
void insertDateFriendly(CTEditBase  *e, int iTime ,int iInsertToday);
const char* sendEngMsg(void *pEng, const char *p);
int addToFavorites(CTRecentsItem *i, void *fav, int iFind);

NSString *checkNrPatterns(NSString *ns);

NSString *translateServ(CTEditBase *b){

   char bufTmp[128];
   //int getText(char *p, int iMaxLen, CTStrBase *ed);
   bufTmp[0]='.';
   bufTmp[1]='t';
   bufTmp[2]=' ';
   bufTmp[3]=0;
   
   getText(&bufTmp[3],125,b);
   const char *p=sendEngMsg(NULL,&bufTmp[0]);
   if(p && p[0]){
      return [NSString stringWithUTF8String:p];
   }
   return toNSFromTB(b);                         
   
  
}

@implementation RecentsInfoTW

-(NSString *)toNSFromRI:(CTEditBase *)b  ri:(CTRecentsItem *)i{
   
   b->reset();
   
   //time
   
   
   //duration
   if(i->uiDuration>0){
      int m=i->uiDuration/60;
      int h=m/60;
      if(h){
         //2h 30 minutes
         b->addInt(h,"%d h ");
         b->addInt(m-h*60,"%2d ");
         b->addText(T_TR("minutes"));
      }
      else if(m){b->addInt(m,"%2d ");b->addText(T_TR("minutes"));}
      else {b->addInt((int)i->uiDuration,"%2d ");b->addText(T_TR("seconds"));}
   }
   else{
      if(i->iAnsweredSomewhereElse){
         b->addText(T_TR("Answered elsewhere"));//Answered elsewhere
      }
      else if(i->iDir==i->eMissed){
         b->addText("     ",4);
         b->addText(T_TR("Missed"));
      }
      else if(i->iDir==i->eDialed){
         b->addText(T_TR("Canceled"));
      }
      //TODO i->iAnsweredSomewhereElse
   }
   
   b->addChar(' ');
   int iAdd = 14-b->getLen();
   
   if(iAdd>0)b->addText("                   ", iAdd);
   
   NSDate *date = [NSDate dateWithTimeIntervalSince1970:i->uiStartTime];
   NSString *s = [dateformater stringFromDate:date];
   b->addText(s.UTF8String);
   
   //insertDateFriendly(b,(int)i->uiStartTime,0);
   
   return toNSFromTB(b);
   
}
- (BOOL) hasAlpha:(NSString *)text
{
    NSCharacterSet *s = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"];
    NSRange r = [text rangeOfCharacterFromSet:s];
    return r.location != NSNotFound;
}
 - (void) viewWillAppear:(BOOL)animated
{
   
   const char *getPrefLang(void);
   dateformater =[[NSDateFormatter alloc] init];
   [dateformater setLocale:[NSLocale localeWithLocaleIdentifier:
                            [NSString stringWithUTF8String:getPrefLang()]]];
   [dateformater setDateStyle:kCFDateFormatterLongStyle];//set current locale
   [dateformater setTimeStyle:kCFDateFormatterShortStyle];
   [dateformater setDoesRelativeDateFormatting:YES];
   
   self.edgesForExtendedLayout=UIRectEdgeNone;
  // self.extendedLayoutIncludesOpaqueBars=NO;
   self.automaticallyAdjustsScrollViewInsets=NO;
   
   [super viewWillAppear:animated];
   
   self.navigationController.navigationBar.barTintColor = [UIColor darkGrayColor];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
   [self.navigationController setNavigationBarHidden:NO animated:animated];
   
   UIButton *uiBt=(UIButton*)[self.view viewWithTag:10];
   [uiBt setTitle:T_TRNS("Add to Favorites") forState:UIControlStateNormal];
    
   NSString *name = item->szPeerAssertedUsername[0] ? [NSString stringWithUTF8String:item->szPeerAssertedUsername] : toNSFromTB(&item->peerAddr);
    NSString *un =[[Utilities utilitiesInstance] removePeerInfo:name lowerCase:YES];
    
    if([self hasAlpha:un])
    {
        UIButton *rightButtonWithImage = [UIButton buttonWithType:UIButtonTypeCustom];
        [rightButtonWithImage setFrame:CGRectMake(0,0,kAddContactIimageSize,kAddContactIimageSize)];
        rightButtonWithImage.userInteractionEnabled = YES;
        [rightButtonWithImage.imageView setContentMode:UIViewContentModeScaleAspectFit];
        [rightButtonWithImage setImage:[UIImage imageNamed:@"ChatBubbleButton.png"] forState:UIControlStateNormal];
        [rightButtonWithImage addTarget:self action:@selector(openChatWithThisUser:) forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *rightBarButton = [[UIBarButtonItem alloc] initWithCustomView:rightButtonWithImage];
        self.navigationItem.rightBarButtonItem = rightBarButton;
       
        [btInviteToSC setHidden:YES];
    }
    //else TODO: [btInviteToSC setHidden:check_is_SC_customer];
    
    [[Utilities utilitiesInstance] setTabBarHidden:NO];

}

- (void)viewDidUnload
{

 [super viewDidUnload];
 [self.navigationController setNavigationBarHidden:YES animated:NO];


}
-(void)fillData:(CTRecentsItem*)i list:(CTList*)list{
   
   iItemsInList=0;
   lastList=list;
   item=i;

   int iKeepHistoryFor = keepHistoryFor();
   int t = get_time();
   
   CTRecentsItem *r=(CTRecentsItem *)list->getNext(NULL,1);
   while(r){
      if(i && !r->isTooOld(t, iKeepHistoryFor) && i->isSameRecord(r)){
         
         r->iTmpMarker=self;
         iItemsInList++;
      }
      else if(r->iTmpMarker==self)r->iTmpMarker=0;
      
      r=(CTRecentsItem *)list->getNext(r,1);
   }
   
 //  array=[NSArray alloc]objectAtIndex:1
}
-(IBAction)showVCard:(id)sender{
   [recents showPersonVCard:item];
   [SP_FastContactFinder needsUpdate];
}

-(IBAction)addToFavorites:(id)sender{
   
   
   addToFavorites(item,NULL,0);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kSilentPhoneFavoriteAddedNotification"
                                                        object:nil];
    
   UIButton *b=(UIButton*)[self.view viewWithTag:10]; 
   if(b){
      [b setHidden:YES];
   }
   

}
-(void)setViewData:(RecentsViewController*)rec item:(CTRecentsItem*)i list:(CTList*)list im:(UIImage*)im{
   
   recents=rec; 
  
   img=(UIImageView*)[self.view viewWithTag:1]; 
   lbName=(UILabel*)[self.view viewWithTag:2]; 
   lbNr=(UILabel*)[self.view viewWithTag:3]; 
   lbService=(UILabel*)[self.view viewWithTag:4]; 
   
    UIButton *b=(UIButton*)[self.view viewWithTag:10]; 
   if(b){
      [b setHidden:addToFavorites(i,NULL,1)?YES:NO];
         
   }

   lbName.text=toNSFromTB(&i->name);
   i->findAT_char();

   int iLCmp=i->peerAddr.getLen()-i->iAtFoundInPeer-1;
   
   if(iLCmp>3 && i->lbServ.getLen()==iLCmp && 
      memcmp(i->lbServ.getText(),i->peerAddr.getText()+i->iAtFoundInPeer+1,iLCmp*2)==0){

      lbNr.text=checkNrPatterns(toNSFromTBN(&i->peerAddr,i->iAtFoundInPeer));
   }
   else{
      lbNr.text=checkNrPatterns(toNSFromTB(&i->peerAddr));
   }
   
   UIImageView *flw=(UIImageView *)[self.view viewWithTag:301];
   if(flw){
      int findCSC_C_S(const char *nr, char *szCountry, char *szCity, char *szID, int iMaxLen);
      char bufC[64],szCity[64],sz2[64];
      if(findCSC_C_S(lbNr.text.UTF8String, &bufC[0], &szCity[0], &sz2[0],64)>0){
         strcat(sz2,".png");
         UIImage *im=[UIImage imageNamed: [NSString stringWithUTF8String:&sz2[0]]];
         lbNr.center=CGPointMake(lbNr.center.x+28,lbNr.center.y);
         [flw setImage:im];
      }
      else{
         
         [flw setImage:nil];
      }
   }
   
   lbService.text=translateServ(&i->lbServ);
   if(!im && (!i->name.getLen() || i->iABChecked==1)){
      im=[UIImage imageNamed: @"ico_user_plus.png"];
   }
   
   if(im){
      img.image=nil;
      img.image=im;
      CALayer *l=img.layer;
      l.shadowOffset = CGSizeMake(0, 3);
      l.shadowRadius = 5.0;
      l.shadowColor = [UIColor blackColor].CGColor;
      l.shadowOpacity = 0.8;

   }

   [self fillData:i list:list];
   
}

- (IBAction)openChatWithThisUser:(id)sender {
    // Rest of chatting interface resides in Chat.storyboard
    // Instantiate the storyboard and open first viewcontroller
    NSString *userName = toNSFromTB(&item->peerAddr);
    NSString *name = toNSFromTB(&item->name);
    if(item->szPeerAssertedUsername[0]){
       userName = [NSString stringWithUTF8String:&item->szPeerAssertedUsername[0]];
    }
   
    NSString *displayName;
    if(name.length > 0)
    {
        displayName = name;
    }
    else
    {
        displayName = userName;
    }
    [[Utilities utilitiesInstance] assignSelectedRecentWithContactName:userName];
    UIStoryboard *chatStoryBoard = [UIStoryboard storyboardWithName:@"Chat" bundle:nil];
    UIViewController *chatViewController = [chatStoryBoard instantiateViewControllerWithIdentifier:@"ChatViewController"];
    [self.navigationController pushViewController:chatViewController animated:YES];
}

- (IBAction)inviteTapped:(id)sender {
	if ([lbNr.text length] == 0)
		return;
	
	[(AppDelegate *)[UIApplication sharedApplication].delegate sendSMSInvite:lbNr.text];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
   return 1;//3;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {

   return T_TRNS("All");
   
   /*
   NSString *ns=@"Incoming";
   if(section==1)ns=@"Outgoing";
   else if(section==2)ns=@"Missed";
   
   return ns;
    */
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return iItemsInList;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"CellRecentsInfo";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
   CTEditBuf<128> b;
   if (cell == nil)
   {
      cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
   }
   cell.showsReorderControl=NO;
   
   CTRecentsItem *i=getByIdxAndMarker(lastList,(int)indexPath.row,self);
   if(!i){cell.textLabel.text=@"";cell.tag=0;cell.imageView.image=nil; return cell;}
   
   cell.textLabel.minimumScaleFactor=.5;
   cell.textLabel.adjustsFontSizeToFitWidth=YES;
   cell.textLabel.text = [self toNSFromRI:&b ri:i];
   
   cell.accessoryType = i->haveCallLog() ?  UITableViewCellAccessoryDetailButton: UITableViewCellAccessoryNone;

   cell.tag=indexPath.row;
   
   if(i->iAnsweredSomewhereElse){
      cell.imageView.image=nil;
      [cell.textLabel setTextColor:[UIColor blackColor]];
   }
   else if(i->iDir==i->eMissed){
      cell.imageView.image=nil;
      [cell.textLabel setTextColor:[UIColor redColor]];
      //[UIImage imageNamed: @"ico_missed.png"];
   }
   else if(i->iDir==i->eDialed){
      cell.imageView.image=[UIImage imageNamed: @"ico_call_out.png"];
      [cell.textLabel setTextColor:[UIColor blackColor]];
   }
   else if(i->iDir==i->eReceived){
      cell.imageView.image=[UIImage imageNamed: @"ico_call_in.png"];
      [cell.textLabel setTextColor:[UIColor blackColor]];
   }


    return cell;
}


- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
   return NO;
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath{
   return YES;
}
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath{
   
   return UITableViewCellEditingStyleDelete;//Insert;
}

//show delete when swipe left
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
   
   CTRecentsItem *i=getByIdxAndMarker(lastList,(int)indexPath.row,self);
   if(i)lastList->remove(i);
   
   CTRecentsItem *n=getByIdxAndMarker(lastList,0,self);
   if(n)
      [self fillData:n list:lastList];
   else {
      n=getByIdxAndMarker(lastList,1,self);
      if(n)[self fillData:n list:lastList];
      else [self fillData:nil list:lastList];
   }
      
   
   [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
   

}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath{

   CTRecentsItem *i=getByIdxAndMarker(lastList,(int)indexPath.row,self);
   
   if(i && i->haveCallLog()){
      
      [CallLogPopup popupLogMessage:i vc:self];
   }
}

- (void)dealloc {
   [super dealloc];
}
@end
