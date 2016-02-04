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
class CTSettingsItem;
class CTRecentsItem;

@interface UIRecentCell : UITableViewCell {

   @public CTRecentsItem *item;
}
@property (retain, nonatomic) IBOutlet UILabel *lbFromNr;
@property (retain, nonatomic) IBOutlet UILabel *lbFromUN;
@property (retain, nonatomic) IBOutlet UIImageView *imgRT;
@property (retain, nonatomic) IBOutlet UILabel *lbDate;
@property (retain, nonatomic) IBOutlet UILabel *lbDur;

@end




@interface UICellController : UITableViewCell {
   @public UITextField *textField;
   @public UISwitch *uiSwitch;
   @public CTSettingsItem *item;
   @public UITableView *tw;
   
}
-(void)setSI:(CTSettingsItem*)newItem newTW:(UITableView *)TW;

@property (nonatomic, retain) IBOutlet UITextField *textField;
@property (nonatomic, retain) IBOutlet UISwitch *uiSwitch;
@property (nonatomic,assign)  UITableView *tw;

@end


#define _T_WO_GUI
#include "../../../baseclasses/CTListBase.h"
#include "../../../baseclasses/CTEditBase.h"
#include "../../../tiviengine/CTRecentsItem.h"

class CTSettingsCell{
public:
   enum{eUnknown,eEditBox, eOnOff, eChoose, eInt, eSection, eCodec, eNextLevel,eReorder,eRadioItem, eSecure ,eButton,eLast};
   CTSettingsCell(){
     // iReleaseLabel=0;
      footer=NULL;
      label=NULL;
      reset();
   }
   
   ~CTSettingsCell(){
      reset();
   }
   
   void reset(){
      
      iType=eUnknown;
    //  if(iReleaseLabel && label)[label release];
      if(label)[label release];
      if(footer)[footer release];
      footer=NULL;
      label=NULL;
      //iReleaseLabel=0;
      value=NULL;
      key[0]=0;iKeyLen=0;
      bufOptions[0]=0;
      pRet=NULL;
      iPhoneEngineType=-1;
      pCfg=NULL;
      iIsInt=-1;
      iInverseOnOff=0;
       passLock = 0;
      onChange=NULL;
      pRetCB=NULL;
      iCanDelete=0;
      onDelete=NULL;
      pEng=NULL;
      iIsLink=0;
   }
   int iType;
   int iIsLink;
   int iIsInt;
   int iPhoneEngineType;
   int iInverseOnOff;//on off inversed logic
    int passLock;
   
   int iCanDelete;
   
   int (*onDelete)(void *pSelf, void *pRetCB);
   //if (ret 2) redraw this tableview
   //if (ret 4) dont go back (popViewControllerAnimated)
   int (*onChange)(void *pSelf, void *pRetCB);
   void *pRetCB;
   
   //int iReleaseLabel;
   
   NSString *value;
   char key[64];
   int iKeyLen;
   char bufOptions[256];

   NSString *getLabel(){return label;}
   void setLabel(NSString *n){
      if(label)[label release];
      if(n){
         //label =[[NSString alloc]initWithString:n];
         label=n;
         [label retain];
      }
   }
   
   NSString *getFooter(){return footer;}
   void setFooter(NSString *n){
      if(footer)[footer release];
      if(n){
        // footer = [[NSString alloc]initWithString:n];
         footer=n;
         [footer retain];
      }
   }
private:
   NSString *label;//TODO convert to CTEditBuf
   NSString *footer;//TODO convert to CTEditBuf
public:
   
   
   void *pRet;//UICellController
   void *pCfg;
   
   void *pEng;
   
};
int setCfgValue(char *pSet, int iSize, void *pCfg, char *key, int iKeyLen);

class CTSettingsItem: public CListItem{
public:
   //
   CTSettingsCell sc;
   CTList *root;
   CTList *parent;
   CTList *section;;
   
   CTSettingsItem *findInSections(void *p, int iSize){
      if(!parent)return NULL;
      CTSettingsItem *ret = (CTSettingsItem*)parent->findItem(p,iSize);
      if(ret)return ret;
 
      if(!section)return NULL;
      
      CTSettingsItem * i =(CTSettingsItem *) section->getLRoot();
      if(!i)return NULL;

      
      while(i){
         if(i->root){
            ret=(CTSettingsItem *)i->root->findItem(p,iSize);
            if(ret)return ret;
         }
        // puts(i->sc.key);
         i=(CTSettingsItem *)section->getNext(i);
      }

      return NULL;
   }
   
   virtual int isItem(void *p, int iSize){
      return iSize && (sc.iKeyLen==iSize && memcmp(p,sc.key,iSize)==0);
      
   }
   const char *getValue(){
      if(sc.iType==CTSettingsCell::eOnOff && sc.iInverseOnOff)
      {
         const char *p=sc.value.UTF8String;
         return p[0]!='0'?"0":"1";
      }
      return sc.value.UTF8String;
   }
   int setValue(const char *p){
      if(!p)return -1;
      
      if(sc.value)[sc.value release];
      if(sc.iType== CTSettingsCell::eOnOff && sc.iInverseOnOff)
      {
         sc.value=[[NSString alloc ] initWithUTF8String:p[0]!='0'?"0":"1"];
      }
      else 
         sc.value=[[NSString alloc ] initWithUTF8String:p];
      
      testOnChange();
      return 0;
   }
   void testOnChange(){
      if(sc.onChange){
         int ret=sc.onChange(this,sc.pRetCB);
         if(ret==2){
            UICellController *c=(UICellController*)sc.pRet;
            if(c)[c->tw reloadData];
         }
      }
   }
   
   
   
   CTSettingsItem(CTList *p):CListItem(),sc(){
      root=NULL;
      parent=p;
      section=NULL;
   }
   CTList* initNext(NSString *ns){
      sc.iType=CTSettingsCell::eNextLevel;
      sc.setLabel(ns);
      root= new CTList();
      return root;
   }
   CTList* initSection(NSString *ns,NSString *footer=NULL){
      sc.iType=CTSettingsCell::eSection;
      sc.setLabel(ns);
      sc.setFooter(footer);
      root= new CTList();
      return root;
   }
   void saveChilds(void *pCfg){
      if(root){
         CTSettingsItem *i=(CTSettingsItem*)root->getNext();
         
         while(i){
            i->save(pCfg);
            i=(CTSettingsItem*)root->getNext(i);
         }
      }
   }
   void save(void *cfg){
      int iDbg=1;
      char *p=NULL;
      int iSize=0;
      if(sc.key[0]=='*')return;
      if(root && sc.key[0] && sc.iType==CTSettingsCell::eSection){
         
         char buf[128];
         buf[0]=0;
         
         CTSettingsItem *i=(CTSettingsItem*)root->getNext();
         
         int codecSZ_to_ID(const char *p);
         
         while(i){
            int v=codecSZ_to_ID([i->sc.getLabel() UTF8String]);
            iSize+=sprintf(&buf[iSize],"%d,",v);
            i=(CTSettingsItem*)root->getNext(i);
         }
         if(iSize)iSize--;
         p=&buf[0];
         buf[iSize]=0;
         
         if(p)NSLog(@"%s=[%s]",&sc.key[0],p);
         
         if(p  && sc.key[0])
            setCfgValue(p,iSize,sc.pCfg,&sc.key[0],sc.iKeyLen);
         return;
         
      }
      saveChilds(cfg);
      if(!sc.pRet)return;
   //dont use   UICellController *cc=(UICellController*)sc.pRet;
      int setCfgValue(char *pSet, int iSize, void *pCfg, char *key, int iKeyLen);
      int v=0;

      p=tryConvertStrIntPTR(p,iSize,&v);
      if(!p)return;

      if(iDbg){
         if(sc.iType==CTSettingsCell::eOnOff || sc.iType==CTSettingsCell::eInt || sc.iIsInt>0)NSLog(@"%s=%d",&sc.key[0],v);
         else if(p)NSLog(@"%s=%s",&sc.key[0],strcmp(sc.key,"pwd")?p:(p[0]?"*****":""));
      }
      cfg=sc.pCfg;
      if(p && sc.key[0])setCfgValue(p,iSize,sc.pCfg,&sc.key[0],sc.iKeyLen);
      
   }

   
   virtual ~CTSettingsItem(){
      if(root)delete root;
      root=NULL;
   }
   int isSection(){
      return (sc.iType==CTSettingsCell::eSection);
   }   
   CTList *nextLevel(){
      if(!root || sc.iType==CTSettingsCell::eSection)return NULL;
      return root;
   }
   
   char *tryConvertStrIntPTR(char *p, int &iSize, int *v){
      if(!sc.value )return NULL;
      const char *utf = [sc.value  UTF8String];
      if(!utf) return NULL;
      
      switch(sc.iType){
         case CTSettingsCell::eRadioItem:return NULL;
         case CTSettingsCell::eOnOff:
         case CTSettingsCell::eButton:
            iSize=4;*v=atoi([sc.value UTF8String]);
            p=(char*)v;
            break;
         case CTSettingsCell::eInt:
            *v=atoi([sc.value UTF8String]);
            iSize=4;
            p=(char*)v;
            break;
         case CTSettingsCell::eReorder:
            break;
         case CTSettingsCell::eChoose:
            p=(char*)[sc.value  UTF8String];
            iSize=(int)[sc.value length];
            if(sc.iIsInt>0){
               *v=atoi(p);
               iSize=4;
               p=(char*)v;
            }
            break;
         case CTSettingsCell::eEditBox:
         case CTSettingsCell::eSecure:
            p=(char*)[sc.value  UTF8String];
            iSize=(int)[sc.value length];
            break;
      }
      return p;
   }
};



