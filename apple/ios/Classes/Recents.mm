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
#import "Recents.h"
#import "UICellController.h"
#import "SettingsController.h"
#import "AppDelegate.h"
#import "RecentsInfoTW.h"

#import "SP_FastContactFinder.h"


const char *tg_translate(const char *key, int iKeyLen);
#define T_TR(_T_KEY) tg_translate(_T_KEY, sizeof(_T_KEY)-1)
#define T_TRL(_T_KEY, _T_KL) tg_translate(_T_KEY, _T_KL)
#define T_TRNS(_T_KEY) [NSString stringWithUTF8String:tg_translate(_T_KEY, sizeof(_T_KEY)-1)]

int disableABookLookup();

NSString *toNSFromTB(CTStrBase *b);
NSString *toNSFromTBN(CTStrBase *b, int N);
NSString *checkNrPatterns(NSString *ns);

static  NSString *toNS(CTEditBase *b, int N=0){
   if(N)return toNSFromTBN(b,N);
   return toNSFromTB(b);
}

CTRecentsItem *getByIdxAndMarker(CTList *l, int idx, void* iMarker){
   
   return ((CTRecentsList*)l)->getByIdxAndMarker(idx,iMarker);
   
}


void CTRecentsAdd::add(int iDir,CTStrBase *nameFromABorSIP, char *p, char *pCallId, int iDur, const char *serv){
   //it is safe to set pointer only because we are reusing call object, and are not releasing-cleannig immediately
   iThisDir=iDir;
   iThisDur=iDur;
   pThisPeer=p;
   pThisServ=serv;
   pThisNameFromABorSIP = nameFromABorSIP;
   pThisCallId=pCallId;
}

CTRecentsAdd* CTRecentsAdd::addMissed(CTStrBase *nameFromABorSIP,char *p, char *pCallId, int iDur, const char *serv){
   CTRecentsAdd *n=new CTRecentsAdd();
   n->add(CTRecentsItem::eMissed,nameFromABorSIP,p,pCallId,0,serv);
   
   return n;
}
CTRecentsAdd* CTRecentsAdd::addDialed(CTStrBase *nameFromABorSIP,char *p, char *pCallId, int iDur, const char *serv){
   CTRecentsAdd *n=new CTRecentsAdd();
   n->add(CTRecentsItem::eDialed,nameFromABorSIP,p,pCallId,iDur,serv);
   return n;
}
CTRecentsAdd* CTRecentsAdd::addReceived(CTStrBase *nameFromABorSIP,char *p, char *pCallId, int iDur, const char *serv, int iAnsweredSomewhereElse){
   CTRecentsAdd *n=new CTRecentsAdd();
   n->iAnsweredSomewhereElse = iAnsweredSomewhereElse;
   n->add(CTRecentsItem::eReceived,nameFromABorSIP,p,pCallId,iDur,serv);
   return n;
}

int isSameNr(const char *p, int l, const char *p2, int l2){
   
   //last 7 is same
   l--;
   l2--;
   char tmp1[128];
   char tmp2[128];
   if(l>127 || l2>127)return 0;
   
   int o1=0;
   int o2=0;
   const char *lp=p+l;
   int iNotDigits=0;
   
   while(*lp && l>=0){
      while(l>=0 && !isalnum(*lp)){lp--;l--;}
      if(l<0 || !*lp)break;
      tmp1[o1]=*lp;
      o1++;
      if(!isdigit(*lp))iNotDigits++;
      lp--;l--;
   }
   lp=p2+l2;
   l=l2;
   
   while(*lp && l>=0){
      while(l>=0 && !isalnum(*lp)){lp--;l--;}
      if(l<0 || !*lp)break;
      tmp2[o2]=*lp;
      o2++;
      if(!isdigit(*lp))iNotDigits++;
      lp--;l--;
   }
   tmp1[o1]=0;
   tmp2[o2]=0;

   if(iNotDigits || o1<7 || o2<7)return o1==o2 && strncmp(tmp1,tmp2,o1)==0;
   
   return strncmp(tmp1,tmp2,min(min(o1,o2),7))==0;
}
#if 0
unsigned int crc32(const void *ptr, size_t cnt);

int setPersonName(ABRecordRef person, CTEditBase *name){
   //  
   CFStringRef first,last;
   
   first = (CFStringRef)ABRecordCopyValue(person, kABPersonFirstNameProperty);
   last = (CFStringRef)ABRecordCopyValue(person, kABPersonLastNameProperty);
   NSString *f=(NSString*)first;
   NSString *l=(NSString*)last;
//   NSLog(@"name[%@,%@]",f,l);
   //name->setLen(0);
   if(f){
      name->setText([f UTF8String]);
      if(l)name->addChar(' ');
      CFRelease(first);
   }
   if(l){
      //- (void)getCharacters:(unichar *)buffer range:(NSRange)aRange;
#if 1
      name->addText([l UTF8String]);//[l length]);
#else
      for(int i=0;i<[l length];i++){name->addChar([l characterAtIndex:i]);}
#endif
      CFRelease(last);
   }
   
   if(name->getLen()<1){
      CFStringRef cn = (CFStringRef)ABRecordCopyValue(person, kABPersonOrganizationProperty);
      if(cn){
         l=(NSString*)cn;
         name->setText([l UTF8String]);
         CFRelease(cn);
      }
   }
   
   return 0;
}

class CTListItemIndexNR: public CListItem{
   ABRecordRef person;
   char bufNR[64-8];
   int iOutLen;
public:
   int idx;
   static unsigned int getCRC(const char *nr, int iLen, char *out, int *iOutLen){
      if(iLen>=*iOutLen)iLen=*iOutLen;
      
      iLen--;
      
      int iNotDigits=0;
      const char *lp=nr+iLen;
      int o1=0;
      
      while(*lp && iLen>=0){
         while(iLen>=0 && !isalnum(*lp) && *lp!='@' && *lp!='.'){lp--;iLen--;}
         if(iLen<0 || !*lp)break;
         out[o1]=*lp;
         o1++;
         if(!isdigit(*lp))iNotDigits++;
         lp--;iLen--;
      }
      out[o1]=0;
      
      
      *iOutLen=o1;
      
      
      if(iNotDigits || o1<7)return crc32(out,o1);
      
      return crc32(out,min(o1,7));
      
   }
   CTListItemIndexNR(const char *nr, int iLen, ABRecordRef p,  int idx)
   :person(p),idx(idx){
      
      iOutLen=sizeof(bufNR)-1;
      iItemId=(int)getCRC(nr,iLen,&bufNR[0],&iOutLen);
      
   }
   
   ABRecordRef getPerson(){return person;}//
   
   int isItem(void *p, int iSize){
      if(iSize!=sizeof(_SEARCH))return 0;
      _SEARCH *s=(_SEARCH*)p;
      if(s->crc!=iItemId)return 0;
      if(s->nr.iLen==iOutLen){
         return memcmp(s->nr.buf, bufNR, iOutLen)==0;
      }
      if((s->nr.iLen>iOutLen && (s->nr.iLen+1!=iOutLen)) || s->nr.iLen<7 || iOutLen<7)return 0;
      
      for(int i=0;i<s->nr.iLen;i++)
         if(isalpha(s->nr.buf[i]))
            return 0;
      
      return memcmp(s->nr.buf, bufNR, min(iOutLen,min(s->nr.iLen,7)))==0;
   }
   typedef struct{
      unsigned int crc;
      struct{
         char buf[64];
         int iLen;
      }nr;
      
   }_SEARCH;
   
};

void t_ABExternalChangeCallback(ABAddressBookRef addressBook, CFDictionaryRef info, void *context);

int isSPURL(const char *p, int &l){
   
#define SP "silentphone:"
#define SP_LEN (sizeof(SP)-1)
   
    //TODO case insens
   if(strncmp(p,SP,SP_LEN)==0){
      l-=SP_LEN;
      p+=SP_LEN;
      if(l>2 && p[0]=='/' && p[1]=='/'){
         l-=2;
         return SP_LEN+2; 
      }
      return SP_LEN;
   }
#undef SP
#undef SP_LEN
   
#define SP "sip:"
#define SP_LEN (sizeof(SP)-1)
   
   //TODO case insens
   if(strncmp(p,SP,SP_LEN)==0){
      l-=SP_LEN;
      p+=SP_LEN;
      if(l>2 && p[0]=='/' && p[1]=='/'){
         l-=2;
         return SP_LEN+2; 
      }
      return SP_LEN;
   }
   return 0;
}

class CTContactFinder{
   //10, 1024, 1023
   enum{eShift=10,eListCnt=(1<<eShift),eAnd=eListCnt-1};
   
   int iInitOk;
   
   CTList lists[eListCnt];
   
   void loadPerson(int idx, ABRecordRef person, ABPropertyID property){
      
      
      ABMultiValueRef phones =ABRecordCopyValue(person, property);
      
      
      int iPhoneCnt=ABMultiValueGetCount(phones);
      
      for(CFIndex i = 0; i < iPhoneCnt; i++) {
         
         CFStringRef m=(CFStringRef)ABMultiValueCopyValueAtIndex(phones, i);
         
         NSString* mobile=(NSString*)m;
         
         const char *p=[mobile UTF8String];
      //   int l=[mobile length];
         int l = strlen(p);//[mobile length]; [mobile length]; is returning char count, i need byte count.
         p+=isSPURL(p,l);

         CTListItemIndexNR *n=new CTListItemIndexNR(p,l,person,idx);
         lists[n->iItemId&eAnd].addToRoot(n);
       
         CFRelease(m);
      }
      CFRelease(phones);
   }
   void rel(){
      if(!iInitOk)return;
      iInitOk=0;
      for(int i=0;i<eListCnt;i++){
         lists[i].removeAll();
      }
      [people release];
      people=NULL;
      ABAddressBookRegisterExternalChangeCallback(ab,t_ABExternalChangeCallback,this);
      CFRelease(ab);
      ab=NULL;
      
      
   }   
   unsigned int setupSearch(CTListItemIndexNR::_SEARCH &s, const char *nr, int iLen){
     // printf("[search=(%.*s) ]",iLen,nr);

      s.nr.iLen=sizeof(s.nr.buf);
      s.crc = CTListItemIndexNR::getCRC(nr,iLen,s.nr.buf,&s.nr.iLen);
      return s.crc;
   }
   
   NSArray *people;
public:
   ABAddressBookRef ab;
   int iHasChanges;
   
   CTContactFinder(){iHasChanges=0;iInitOk=0;ab=nil;people=nil;}
   ~CTContactFinder(){rel();}
   
   void reset(){
      rel();
      load();
   }
   
   int load(){
      if(iInitOk)return 0; 
      iInitOk=1;
      ab = ABAddressBookCreate();
      if(!ab){iInitOk=0;return -1;}
      
      ABAddressBookRegisterExternalChangeCallback(ab,t_ABExternalChangeCallback,this);
      iHasChanges=0;
      people = (NSArray *) ABAddressBookCopyArrayOfAllPeople(ab);
      if ( people){
         int c=[people count];
         for (int i=0; i<c; i++ )
         {
            ABRecordRef person = (ABRecordRef)[people objectAtIndex:i];
            loadPerson(i,person,kABPersonPhoneProperty);
            loadPerson(i,person,kABPersonURLProperty);
            
         }
         
      }
      else iInitOk=0;
      
      return 0;
      
   }
   
   ABRecordRef getPersonByIdx(int i){
      if(!people)return NULL;
      
      int c=[people count];
      if(i>=c)return NULL;
      
      return (ABRecordRef)[people objectAtIndex:i];
   }
   
   int findPerson(CTEditBase *e, const char *nr, int iLen){
      if(iHasChanges)reset();else load();
      int i;
      int iDigits=0;
 
      
      char buf[128];
      if(iLen>127)iLen=127;
      
      int iNewLen=0;
      int iClean=1;
      
      //iDigits+=iClean && !!isdigit(nr[i]);
      for(i=0;i<iLen;i++){
         if(!isascii(nr[i]))continue;
         if(nr[i]=='@' || isalpha(nr[i]))iClean=0;
         if(isdigit(nr[i]) || nr[i]=='+' || !iClean){buf[iNewLen]=nr[i];iNewLen++; }
      }
      buf[iNewLen]=0;iLen=iNewLen;nr=&buf[0];
      


      unsigned int crc;
      
      CTListItemIndexNR *ret;
      
      CTListItemIndexNR::_SEARCH s;
      
      crc=setupSearch(s,nr,iLen);
      
      ret=(CTListItemIndexNR*)lists[crc&eAnd].findItem(&s,sizeof(s));
      
      if(!ret){
         
         
         for(i=0;i<128;i++){
            
            iDigits+=isdigit(nr[i]);
            
            if(nr[i]=='@' || !nr[i]){
               printf("digits=%d \n",iDigits);
               
               if(iDigits==10){
                  //try to add US country code 1
                  char bufTmp[256];
                  int l = snprintf(bufTmp, sizeof(bufTmp),"1%.*s",iLen,nr);
                  crc=setupSearch(s,&bufTmp[0],l);
                  ret=(CTListItemIndexNR*)lists[crc&eAnd].findItem(&s,sizeof(s));
                  if(ret)break;//found
                  
               }
               
               crc=setupSearch(s,&nr[0],i);
               ret=(CTListItemIndexNR*)lists[crc&eAnd].findItem(&s,sizeof(s));
               if(!ret && iDigits==11){
                  crc=setupSearch(s,&nr[1+(nr[0]=='+')],10);
                  ret=(CTListItemIndexNR*)lists[crc&eAnd].findItem(&s,sizeof(s));
               }
               
               break;
            }

         }
      }
      if(!ret && iLen>1 && nr[0]=='+'){
         crc=setupSearch(s,&nr[1],iLen-1);
         ret=(CTListItemIndexNR*)lists[crc&eAnd].findItem(&s,sizeof(s));
      }
      if(!ret)return -2;
      setPersonName(ret->getPerson(),e);
      return ret->idx;
   }
};

void t_ABExternalChangeCallback(ABAddressBookRef addressBook, CFDictionaryRef info, void *context){
   CTContactFinder *f=(CTContactFinder*)context;
   if(f)f->iHasChanges++;
}

CTContactFinder contactFinder;

#endif

// Height for the Edit Unknown Contact row
#define kUIEditUnknownContactRowHeight 81.0

@implementation RecentsViewController
@synthesize recentTableViewCell;


#pragma mark Load views


#define LOADMI nil
#define LOADDI [UIImage imageNamed: @"ico_call_out2.png"]
#define LOADRI [UIImage imageNamed: @"ico_call_in2.png"]

- (void)viewDidLoad 
{
	[super viewDidLoad];
   
   rl = CTRecentsList::sharedRecents();
   iRecentsLoaded=0;
   
   tw_test.rowHeight=57;//recentTableViewCell.frame.size.height;
   
   [self enableClearAll:NO];
   
   editBt.title=T_TRNS("Edit");
   self.navigationItem.title = T_TRNS("Recents");
   
   UISegmentedControl *seg = (UISegmentedControl*)[self.view viewWithTag:301];
   
   [seg setTitle:T_TRNS("All") forSegmentAtIndex:0];
   [seg setTitle:T_TRNS("Missed") forSegmentAtIndex:1];
   
   const char *getPrefLang(void);
    dateformater =[[NSDateFormatter alloc] init];
   [dateformater setLocale:[NSLocale localeWithLocaleIdentifier:
                            [NSString stringWithUTF8String:getPrefLang()]]];
   [dateformater setDateStyle:kCFDateFormatterMediumStyle];//set current locale
   [dateformater setTimeStyle:kCFDateFormatterNoStyle];
   [dateformater setDoesRelativeDateFormatting:YES];
//   NSDate *date = [NSDate dateWithTimeIntervalSince1970:get_time()];
  // NSString *s = [dateformater stringFromDate:date];
  // NSLog(@"date %@",s);
}


- (void)viewWillAppear:(BOOL)animated{
   [super viewWillAppear: animated];
   
   [self resetBadgeNumber:true];
   
   [self loadRecents];
   
   
}

-(void)loadRecents{
   
   if(!iRecentsLoaded){
      iRecentsLoaded=1;
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
         usleep(1000);
         dispatch_async(dispatch_get_main_queue(), ^{
            rl->load(); //countItemsGrouped
            rl->countItemsGrouped();
            
            [tw_test reloadSections: [NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
         });
      });
   }else{
      dispatch_async(dispatch_get_main_queue(), ^{
         int i  = rl->countVisItems();
         rl->countItemsGrouped();
         if(i != rl->countVisItems()){
           [tw_test reloadSections: [NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
         }
      });
      
   }
   
}


#pragma mark Unload views
- (void)viewDidUnload 
{
   //saveRL();
   delete rl;
   [dateformater release];
   dateformater = NULL;
   
}
-(void)saveRecents{
   //queve
   rl->save();
   puts("saveRecents");
   
}

-(void)setBadgeForRecents:(int)value{
    [[NSUserDefaults standardUserDefaults]  setValue:[NSString stringWithFormat:@"%d",value ] forKey:@"badgeNumberForRecents"];
   // int iv=[UIApplication sharedApplication].applicationIconBadgeNumber;
    if(value)
        [uiTabBarItem setBadgeValue:[NSString stringWithFormat:@"%d",value]];
    else [uiTabBarItem setBadgeValue:nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"updateAppBadge" object:nil];
}

-(int)getBadgeForRecents{
    NSString *badgeNumberStr = [[NSUserDefaults standardUserDefaults] objectForKey:@"badgeNumberForRecents"];
    int badgeNumber = 0;
    if(badgeNumberStr)
    {
        badgeNumber = [badgeNumberStr intValue];
    }
    return badgeNumber;
}

-(void)addToRecentsMT:(CTRecentsAdd*) r{

   if(!r)return;
   
   rl->load();
   
   CTRecentsItem *i = rl->add(r->iThisDir, r->pThisNameFromABorSIP,r->pThisPeer,"my",r->pThisServ,r->iThisDur,r->iAnsweredSomewhereElse);
   if(i && r->pThisCallId){
      strncpy(i->szSIPCallID, r->pThisCallId, sizeof(i->szSIPCallID)-1);
      i->szSIPCallID[sizeof(i->szSIPCallID)-1]=0;
   }
   [self onAddCall:r->iThisDir==CTRecentsItem::eMissed];
   
   delete r;
}
-(void)onAddCall:(BOOL)missed{
   
   rl->countItemsGrouped();
   
   if(missed){

       int badgeNumber = [self getBadgeForRecents];
       badgeNumber++;
       
       [self setBadgeForRecents:badgeNumber];

      [self saveRecents];
   }
   
   [tw_test reloadSections: [NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
   
}

-(void)addToRecentsCall:(CTCall*) c{
   dispatch_async(dispatch_get_main_queue(), ^(void) {
      void *getCurrentDOut(void);
      void* findCfgItemByServiceKey(void *ph, char *key, int &iSize, char **opt, int *type);
   
      const char *pServ="Unknown";
   
      if(!c->pEng)c->pEng=getCurrentDOut();
      
      if(c->pEng){
         int sz=0;
         char *pRet=(char*)findCfgItemByServiceKey(c->pEng, (char*)"tmpServ", sz, NULL, NULL);
         if(pRet && sz>0){
            pServ=pRet;
         }
         
      }
      char *_nr = &c->bufPeer[0];
      if(!_nr[0])_nr = &c->bufDialed[0];
      
      int len = (int)strlen(_nr);
      
      if(c->iIsIncoming && _nr[0]!='+' && _nr[0]!='0' && isdigit(_nr[0]) && len>6 && len+1<sizeof(c->bufDialed)){//hack all numbers should start with +
         memmove(_nr+1,_nr,len+1);
         _nr[0]='+';
      }
      
      rl->load();
      
      int dir ;
      unsigned int dur = get_time()-c->uiStartTime;
      
      if(c->iIsIncoming && !c->uiStartTime){
         if(c->iDontAddMissedCall){
            dir = CTRecentsItem::eReceived;
            //answered somewhere else
         }
         else{
            dir = CTRecentsItem::eMissed;
         }
      }
      else if(c->iIsIncoming){
         dir = CTRecentsItem::eReceived;
      }
      else{
         dir = CTRecentsItem::eDialed;
      }
      if(!c->uiStartTime)dur = 0;
      //add(int iDir, CTStrBase *nameFromABorSIP, const char *peer, const char *myAddr, const char *serv, unsigned int uiDuration, int iAnsweredSomewhereElse)
      CTRecentsItem *i = rl->add(dir, &c->nameFromAB, _nr,"my",pServ, dur, c->iDontAddMissedCall);
      
      if(i && c->szSIPCallId[0]){
         strncpy(i->szSIPCallID, c->szSIPCallId, sizeof(i->szSIPCallID)-1);
         i->szSIPCallID[sizeof(i->szSIPCallID)-1]=0;
      }
      if( i && c->szPeerAssertedUsername[0]){
         strncpy(i->szPeerAssertedUsername, c->szPeerAssertedUsername, sizeof(i->szPeerAssertedUsername)-1);
         i->szPeerAssertedUsername[sizeof(i->szPeerAssertedUsername)-1]=0;
      }
      printf("szPeerAssertedUsername=%s\n",i->szPeerAssertedUsername);
      
      [self onAddCall:dir == CTRecentsItem::eMissed];
   });
}

-(void)addToRecents:(CTRecentsAdd*) r{
   
   dispatch_async(dispatch_get_main_queue(), ^(void) {
      [self addToRecentsMT:r];
   });
}



#pragma mark Table view methods
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}
// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
   int r=rl->countItemsGrouped();
   return r;
}

-(void)resetBadgeNumber:(bool)bResetToZero{
   
   if(bResetToZero){
       [self setBadgeForRecents:0];
   }
   else {
       
       [self setBadgeForRecents:[self getBadgeForRecents]];
   }

}

-(IBAction)segment_pressed:(id)sender{
   UISegmentedControl *sc=(UISegmentedControl *)sender;
   int c;
   if(sc.selectedSegmentIndex==1){
      c=rl->activateMissed();
      [self resetBadgeNumber:true];
   }
   else
      c=rl->activateAll();
   
   [tw_test reloadSections: [NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
   
   [self enableClearAll:c && tw_test.isEditing];
   editBt.width=(tw_test.frame.size.width/6);//c?0.0:(320/6);
   
   
}

-(IBAction)clearAll_pressed{
   
   //TODO ask
   rl->removeCurrent();

   [tw_test reloadSections: [NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];

}


- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
   return NO;
   
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
   return NO;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath{
   return YES;
}

//show delete when swipe left
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
   rl->removeRecord(rl->getByIndex((int)indexPath.row));
   
   [tw_test reloadSections: [NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
   
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath{
   
   return UITableViewCellEditingStyleDelete;//Insert;
}



- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated{
   self.navigationController.hidesBottomBarWhenPushed=NO;
   if(viewController==self) {
      [self.navigationController setNavigationBarHidden:YES animated:animated];
      [tw_test reloadData];
      rl->save();
   }
   
}

-(void)showPersonVCard:(CTRecentsItem*)i{
   
   if(!i)return;
   
   if(!i->name.getLen() || i->iABChecked==1){
      [self showUnknownPersonViewControllerNS:toNS(&i->peerAddr)];
      return;
   }
   //sd
   //ABAddressBookRef addressBook = ABAddressBookCreate();
   
   NSString *ns=toNSFromTB(&i->name); 
   //ns 
	NSArray *people = (NSArray *)ABAddressBookCopyPeopleWithName([SP_FastContactFinder getAB], (CFStringRef)ns);
	if ((people != nil) && [people count])
	{
		ABRecordRef person = (ABRecordRef)[people objectAtIndex:0];
		[self showEditPersonViewController:person completion:nil];
	}
	
	
	[people release];
	//CFRelease(addressBook);
   
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath{
   
   CTRecentsItem *i=rl->getByIndex((int)indexPath.row);

	if(!i)return;

   self.navigationController.delegate=self;
   
   RecentsInfoTW *ri =[[RecentsInfoTW alloc]initWithNibName:@"RecentsInfo" bundle:nil];
   
   UIImage *img=nil;

   if(i->iABChecked==2)
   {
      i->iABChecked=0;
      int rec_id=[self findContactByID:i];
      if(rec_id>=0){
         NSLog(@"recid=%d",rec_id);
         img = [SP_FastContactFinder getPersonImage:rec_id];
         if(img)[img retain];
      }
   }
   rl->save();
   
   
   [ri setViewData:self item:i list:rl->getList() im:img];
   
   ri.hidesBottomBarWhenPushed=NO;
   [self.navigationController  pushViewController:ri animated:YES];
   [ri release];
   if(img)[img release];

   
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
   static NSString *CellIdentifier = @"CellRecents";
   UIRecentCell *aCell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

	if (aCell == nil)
	{
      [[NSBundle mainBundle] loadNibNamed:@"Recents" owner:self options:nil];
		aCell = recentTableViewCell;
		self.recentTableViewCell = nil;
	}
   CTRecentsItem *i=rl->getByIndex((int)indexPath.row);

   if(!i){
      aCell.lbFromNr.text=@"err";
      aCell.lbFromUN.text=@"err";
      aCell.lbDate.text=@"1.1.1";
      aCell.lbDur.text=@"0:01";
      return aCell;
   }
   else{
      [self findContactByID:i];
      
      
      void insertDateFriendly(char  *buf, int iTime ,int iTimeOrDayOnly);
      void insertDateTime(char  *buf, int iTime ,int iTimeOrDayOnly);
      char buf[32];
#if 0
      insertDateFriendly(&buf[0],(int)i->uiStartTime,0);
      if(strncmp(buf,"Yesterday ",10)==0)
         buf[9]=0;////@"05.04.2012";
      aCell.lbDate.text = [NSString stringWithUTF8String:&buf[0]];////@"05.04.2012";
#else
      int isToday(time_t iTime);
      NSDate *date = nil;
      if(isToday(i->uiStartTime)){
         [dateformater setDateStyle:kCFDateFormatterNoStyle];//set current locale
         [dateformater setTimeStyle:kCFDateFormatterShortStyle];
         date = [NSDate dateWithTimeIntervalSince1970:i->uiStartTime];
      }
      else{
         [dateformater setDateStyle:kCFDateFormatterMediumStyle];//set current locale
         [dateformater setTimeStyle:kCFDateFormatterNoStyle];
         date = [NSDate dateWithTimeIntervalSince1970:i->uiStartTime];
      }
      aCell.lbDate.text = [dateformater stringFromDate:date];
      
#endif
      
      int iHideSipDomain=1;
      
      i->findAT_char();
      int L=i->peerAddr.getLen();
      
      if(iHideSipDomain){
         L=i->iAtFoundInPeer;
      }
      
  //    NSLog(@"entry=[%@,%@,%d]", toNSFromTB(&i->name), toNSFromTB(&i->peerAddr),L);
      
      if(i->name.getLen()>0){
         NSString *nn=[NSString stringWithFormat:@"%@  %@",checkNrPatterns(toNS(&i->peerAddr,L)),translateServ(&i->lbServ)];
         aCell.lbFromNr.text=nn;
         aCell.lbFromUN.text=toNS(&i->name);
      }
      else{
         aCell.lbFromNr.text=translateServ(&i->lbServ);
         aCell.lbFromUN.text=checkNrPatterns(toNS(&i->peerAddr,L));
      }
      if(i->iDir==CTRecentsItem::eMissed || !i->uiDuration){
         aCell.lbDur.text=@" ";
      }
      else{
         sprintf(buf,"%02dmin%02ds",i->uiDuration/60,i->uiDuration%60);
         aCell.lbDur.text=[NSString stringWithUTF8String:&buf[0]];
      }
      UIImage *im=(i->iDir==i->eDialed?LOADDI:(i->iDir==i->eMissed?LOADMI:LOADRI));
      
      if(i->iDir==i->eMissed)[aCell.lbFromUN setTextColor:[UIColor redColor]];
      else [aCell.lbFromUN setTextColor:[UIColor blackColor]];
      aCell.imgRT.image=im;
      
   }
   i->cell=aCell;
   
   aCell.accessoryType = UITableViewCellAccessoryDetailButton;
   return aCell;
}



- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
   [tableView deselectRowAtIndexPath:indexPath animated:NO];
   
   CTRecentsItem *i=rl->getByIndex((int)indexPath.row);
   
   [appDelegate callToR:i];
}

-(void)enableClearAll:(BOOL) yesNo{

   clearAll.enabled=yesNo;
   clearAll.title=yesNo?T_TRNS("Clear"):@"     ";
   clearAll.width=(tw_test.frame.size.width/6);//yesNo?0.0:(320/6);
   
}

-(IBAction)setTBEditing{
   static int iEdit=1;
   
   [self enableClearAll:iEdit];
   
   editBt.title=iEdit?T_TRNS("Done"):T_TRNS("Edit");
   
   [tw_test setEditing:iEdit];
   
   iEdit=!iEdit;
}



#pragma mark TableViewDelegate method

#pragma mark Show all contacts
-(void)showPeoplePickerController
{
	ABPeoplePickerNavigationController *picker = [[ABPeoplePickerNavigationController alloc] init];
	picker.peoplePickerDelegate = self;
	[self presentViewController:picker animated:YES completion:^(){}];
	[picker release];
}


#pragma mark Display and edit a person

- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker {
   
   [self dismissViewControllerAnimated:YES completion:^(){}];
	if (_newContactS) {
		[_newContactS release];
		_newContactS = nil;
	}
}
// Called when users tap "Display and Edit Contact" in the application. Searches for a contact named "Appleseed" in 
// in the address book. Displays and allows editing of all information associated with that contact if
// the search is successful. Shows an alert, otherwise.
/*
-(NSData *)getImageData:(int)p_id{
   
   if(disableABookLookup())return NULL;
   
   
   

   NSData *imageData=NULL;
   ABRecordRef person = contactFinder.getPersonByIdx(p_id);
   if(person && ABPersonHasImageData(person)){
      
      imageData = (NSData *)ABPersonCopyImageDataWithFormat(person, kABPersonImageFormatThumbnail) ;
   }
   return imageData;
   
}
*/

-(int)findContactByEB_p:(CTEditBase *)peer outb:(CTEditBase *)name people:(NSArray*)people{ 
   //CTContactFinder
   
   if(disableABookLookup())return -1;
   
   int r =-1;
   
   NSString *n =  [SP_FastContactFinder findPerson:toNSFromTB(peer)idx:&r];
   
   if(n && r>=0){
      name->setText(n.UTF8String);
   }
   else{
      //must not clear the contents of the name , it contains a SIP-disp-name
      
    //  name->reset(); -- this is wrong, do not uncomment
   }

   return r;
   
}

-(int)findContactByEB:(CTEditBase *)peer outb:(CTEditBase *)name{

   if(disableABookLookup())return -1;
   
   int ret=[self findContactByEB_p:peer outb:name people:nil];
   return ret;
}

-(int)findContactByID:(CTRecentsItem*)item{
   if(item->iABChecked)return -1;
   
   if(disableABookLookup())return -1;
   
   item->iABChecked=1;;

   int r=[self findContactByEB_p:&item->peerAddr outb:&item->name people:nil];

   if(r>=0)item->iABChecked=2;
   return r;
}

#pragma mark Create a new person
// Called when users tap "Create New Contact" in the application. Allows users to create a new contact.
// aContact is optional, pass it to pre-fill some information
-(void)showNewPersonViewController:(ABRecordRef)aContact {
	ABNewPersonViewController *picker = [[ABNewPersonViewController alloc] init];
	picker.newPersonViewDelegate = self;
	if (aContact != nil)
		picker.displayedPerson = aContact;
	
	UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:picker];
	[self presentViewController:navigation animated:NO completion:^(){}];
	
	[picker release];
	[navigation release];	
}

-(void)showEditPersonViewController:(ABRecordRef)aContact completion:(void (^)(void))completion {
	ABPersonViewController *personVC = [[ABPersonViewController alloc] init];
	personVC.personViewDelegate = self;
	personVC.displayedPerson = aContact;
	personVC.allowsActions = NO;
	personVC.allowsEditing = YES;
	personVC.title = @"";
	
	// set back button as "Done" because we cannot cancel saved changes
	UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(cancelViewPerson:)];
	personVC.navigationItem.backBarButtonItem=bbi;
	[bbi release];
	personVC.navigationItem.hidesBackButton=NO;
	
	UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:personVC];
	[self presentViewController:navigation animated:YES completion:completion];
	
	[personVC release];
	[navigation release];
}

enum CallActionSheetOptions {
	// cancel = 0
	kActionSheet_SilentPhone = 1
	,kActionSheet_SMSInvite
	,kActionSheet_SMSMessage
	,kActionSheet_CreateContact
	,kActionSheet_ExistingContact
};

#pragma mark Add data to an existing person
// Called when users tap "Edit Unknown Contact" in the application.
-(void)showUnknownPersonViewControllerNS:(NSString *)ns
{
   CTEditBuf<128> b;
   CTEditBuf<128> o;
   b.setText([ns UTF8String], (int)[ns length]);
   
	BOOL alreadyContact = ([self findContactByEB:&b outb:&o] >= 0);
	_actionSheetContactS = [[NSString alloc] initWithString:ns]; // copy for action sheet
	
	UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Choose an option" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:nil];
	// add buttons after initialization to guarantee cancelButtonIndex == 0
	// make sure button ordering matches CallActionSheetOptions enum
	[actionSheet addButtonWithTitle:@"Call with Silent Phone"];
	[actionSheet addButtonWithTitle:@"Send SMS Invite"];
	[actionSheet addButtonWithTitle:@"Send SMS Message"];
	if (!alreadyContact) {
		[actionSheet addButtonWithTitle:@"Create New Contact"];
		[actionSheet addButtonWithTitle:@"Add to Existing Contact"];
	}
	[actionSheet showInView:self.view];
	// note: actionSheet released in delegate callback
}

#pragma mark - UIActionSheetDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet willDismissWithButtonIndex:(NSInteger)buttonIndex {
	if (buttonIndex == actionSheet.cancelButtonIndex) {
		[actionSheet release];
		[_actionSheetContactS release];
		_actionSheetContactS = nil;
		return; // cancelled
	}
	
	const char *p =[_actionSheetContactS UTF8String];
	extern int isPhone(const char *sz,int len);
	int iIsPh = isPhone(p, (int)_actionSheetContactS.length);
	BOOL bAddSipPrefix = (p && !iIsPh && strncmp(p,"sip:",4));
	
	switch (buttonIndex) {
		case kActionSheet_SilentPhone:
			[appDelegate callToCheckUS:'c' dst:p  eng:NULL];
			break;
		case kActionSheet_SMSInvite:
			[appDelegate sendSMSInvite:_actionSheetContactS];
			break;
		case kActionSheet_SMSMessage:
			[appDelegate sendSMS:_actionSheetContactS message:nil];
			break;
		case kActionSheet_CreateContact: {
			ABRecordRef aContact = ABPersonCreate();
			CFErrorRef error = NULL;
			ABMultiValueRef sip = ABMultiValueCreateMutable(kABMultiStringPropertyType);
			NSString *phoneS = bAddSipPrefix ? [NSString stringWithFormat:@"sip:%@", _actionSheetContactS] : _actionSheetContactS;
			BOOL didAdd = ABMultiValueAddValueAndLabel(sip, (__bridge CFTypeRef)phoneS, iIsPh ? kABOtherLabel : CFStringRef(@"Silent Circle"), NULL);
			if (didAdd) {
				ABRecordSetValue(aContact,iIsPh ? kABPersonPhoneProperty : kABPersonURLProperty, sip, &error);
				didAdd = (error == nil);
			}
			if (didAdd)
				[self showNewPersonViewController:aContact];
			else {
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
																message:@"Unable to create new contact"
															   delegate:nil
													  cancelButtonTitle:@"Cancel"
													  otherButtonTitles:nil];
				[alert show];
				[alert release];
			}
			CFRelease(sip);
			CFRelease(aContact);
			break;
		}
		case kActionSheet_ExistingContact: {
			_newContactS = [[NSString alloc] initWithString:_actionSheetContactS];
			[self showPeoplePickerController];
			break;
		}
	}
	[SP_FastContactFinder needsUpdate];
	
	[actionSheet release];
	[_actionSheetContactS release];
	_actionSheetContactS = nil;
}

- (void)cancelViewPerson:(id)unused
{
   [self dismissViewControllerAnimated:YES completion:^(){}];
}

//- (void)cancelAddPerson:(id)unused
//{
//   [self.parentViewController dismissViewControllerAnimated:YES completion:^(){}];
//}

#pragma mark ABPeoplePickerNavigationControllerDelegate methods
- (void)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker didSelectPerson:(ABRecordRef)person {
	if (_newContactS == nil)
		return;
	
	// this is an existing contact we're adding a property to
	// update existing contact with new phone or URL
	CFErrorRef error = nil;
	const char *p =[_newContactS UTF8String];
	extern int isPhone(const char *sz,int len);
	int iIsPh = isPhone(p, (int)_newContactS.length);
	BOOL bAddSipPrefix = (p && !iIsPh && strncmp(p,"sip:",4));
	NSString *valueS = bAddSipPrefix ? [NSString stringWithFormat:@"sip:%@", _newContactS] : _newContactS;

	BOOL didAdd = NO;
	if (iIsPh ) {
		ABMultiValueRef existingPhones = ABRecordCopyValue(person, kABPersonPhoneProperty);
		ABMultiValueRef allPhones = ABMultiValueCreateMutableCopy(existingPhones);
		didAdd = ABMultiValueAddValueAndLabel(allPhones, valueS, kABOtherLabel, NULL);
		if (didAdd) {
			ABRecordSetValue(person, kABPersonPhoneProperty, allPhones, &error);
			didAdd = (error == nil);
		}
	} else { // URL
		ABMultiValueRef existingURLs = ABRecordCopyValue(person, kABPersonURLProperty);
		ABMultiValueRef allURLs = ABMultiValueCreateMutableCopy(existingURLs);
		didAdd = ABMultiValueAddValueAndLabel(allURLs, valueS, CFStringRef(@"Silent Circle"), NULL);
		if (didAdd) {
			ABRecordSetValue(person, kABPersonURLProperty, allURLs, &error);
			didAdd = (error == nil);
		}
	}

	if (didAdd) {
		// save changes
		ABAddressBookSave(peoplePicker.addressBook, &error);
		didAdd = (error == nil);
	}
	
	// open person picker
	[peoplePicker dismissViewControllerAnimated:YES completion:^{
		if (didAdd) {
			[self showEditPersonViewController:person completion:nil];
			[SP_FastContactFinder needsUpdate];
			[appDelegate forceFindName];
		}
		else {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
															message:@"Unable to update contact"
														   delegate:nil
												  cancelButtonTitle:@"Cancel"
												  otherButtonTitles:nil];
			[alert show];
			[alert release];
		}
	}];

	[_newContactS release];
	_newContactS = nil;
}

// Does not allow users to perform default actions such as dialing a phone number, when they select a person property.

-(BOOL)tryCall:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier{
   
   
   if(property!=kABPersonPhoneProperty && property!=kABPersonURLProperty)return NO;
   
   NSLog(@"selected user contact data %d %d", property,kABPersonEmailProperty);

   NSString* phone = nil;
   ABMultiValueRef phoneNumbers = ABRecordCopyValue(person, property);
   
   NSString *abMultiValueIdentifier2Phone(ABMultiValueRef phoneNumbers, ABMultiValueIdentifier id);
   
   phone=abMultiValueIdentifier2Phone(phoneNumbers,identifier);
   if(!phone){
      CFRelease(phoneNumbers);
      return NO;
   }
   
   if(phone){
      
      [self dismissViewControllerAnimated:NO completion:^(){}];
      [appDelegate callToCheckUS:'c' dst:[phone UTF8String]  eng:NULL];
      
      [[self tabBarController]setSelectedIndex:3];
      
      CFRelease(phone);
   }
   CFRelease(phoneNumbers);
   
   return NO;
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person 
                                property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier
{
	return [self tryCall:person property:property identifier:identifier];
}

#pragma mark ABPersonViewControllerDelegate methods
// Does not allow users to perform default actions such as dialing a phone number, when they select a contact property.
- (BOOL)personViewController:(ABPersonViewController *)personViewController shouldPerformDefaultActionForPerson:(ABRecordRef)person 
                    property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifierForValue
{
	return  [self tryCall:person property:property identifier:identifierForValue];
}


#pragma mark ABNewPersonViewControllerDelegate methods
// Dismisses the new-person view controller. 
- (void)newPersonViewController:(ABNewPersonViewController *)newPersonViewController didCompleteWithNewPerson:(ABRecordRef)person
{
	[newPersonViewController dismissViewControllerAnimated:YES completion:^(){}];
	[SP_FastContactFinder needsUpdate];
	[appDelegate forceFindName];
}


#pragma mark ABUnknownPersonViewControllerDelegate methods
// Dismisses the picker when users are done creating a contact or adding the displayed person properties to an existing contact. 
- (void)unknownPersonViewController:(ABUnknownPersonViewController *)unknownPersonView didResolveToPerson:(ABRecordRef)person
{
	[self dismissViewControllerAnimated:YES completion:^(){}];
}


// Does not allow users to perform default actions such as emailing a contact, when they select a contact property.
- (BOOL)unknownPersonViewController:(ABUnknownPersonViewController *)personViewController shouldPerformDefaultActionForPerson:(ABRecordRef)person 
                           property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier
{
	return NO;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
   [textField resignFirstResponder];
   return NO;
}


-(IBAction)textFieldReturn:(id)sender
{
   [sender resignFirstResponder];
} 


#pragma mark Memory management
- (void)dealloc 
{
   // [tmpSet release];
   
   [super dealloc];
}

@end
//TODO class

