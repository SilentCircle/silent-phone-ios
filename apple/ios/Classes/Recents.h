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

#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>

@class UICellController;
@class SettingsController;
@class UIRecentCell;
@class AppDelegate;

class CTEditBase;
class CTStrBase;

class CTRecentsAdd{
protected:
   CTRecentsAdd(){iThisDur=iThisDir=0;pThisPeer=NULL;pThisServ=NULL;pThisNameFromABorSIP=NULL;iAnsweredSomewhereElse=0;pThisCallId=NULL;}
   void add(int iDir,CTStrBase *nameFromABorSIP, char *p, char *pCallId, int iDur, const char *serv);
public:
   static CTRecentsAdd* addMissed(CTStrBase *nameFromABorSIP, char *p, char *pCallId, int iDur, const char *serv);
   static CTRecentsAdd* addDialed(CTStrBase *nameFromABorSIP, char *p, char *pCallId, int iDur, const char *serv);
   static CTRecentsAdd* addReceived(CTStrBase *nameFromABorSIP, char *p, char *pCallId, int iDur, const char *serv,int iAnsweredSomewhereElse=0);
   int iThisDir,iThisDur;
   char *pThisPeer;
   const char *pThisServ;
   CTStrBase *pThisNameFromABorSIP;
   int iAnsweredSomewhereElse;
   char *pThisCallId;
   
};

class CTRecentsList;
@class RecentsInfoTW;
class CTRecentsItem;
class CTCall;

@interface RecentsViewController : UITableViewController < 
	UITextFieldDelegate
	,UIActionSheetDelegate
	,ABPeoplePickerNavigationControllerDelegate
	,ABPersonViewControllerDelegate
	,ABNewPersonViewControllerDelegate
	,ABUnknownPersonViewControllerDelegate
	,UINavigationControllerDelegate>
{
   CTRecentsList *rl;
   
   IBOutlet UITableView* tw_test; 
   IBOutlet UIBarButtonItem *clearAll;
   IBOutlet UIBarButtonItem *editBt;
   IBOutlet UIToolbar *uiTB;
   IBOutlet AppDelegate *appDelegate;
   
   IBOutlet UITabBarItem *uiTabBarItem;
   
   int iRecentsLoaded;

   
 //  ABAddressBookRef g_addressBook;
  // NSArray *g_people;

   NSString *tmpSet;
   NSDateFormatter *dateformater;
	
	NSString *_actionSheetContactS;
	NSString *_newContactS;
//	ABRecordRef _abRecordForExistingContact;
}

//@property (nonatomic, assign) IBOutlet UICellController *editableTableViewCell;
@property (nonatomic, assign) IBOutlet UIRecentCell *recentTableViewCell;


-(void)showPeoplePickerController;
//-(void)showPersonViewController;
-(void)showNewPersonViewController:(ABRecordRef)aContact;
-(void)showEditPersonViewController:(ABRecordRef)aContact completion:(void (^)(void))completion;
-(void)showUnknownPersonViewControllerNS:(NSString *)ns;
-(void)addToRecents:(CTRecentsAdd*) r;
-(void)addToRecentsCall:(CTCall*) c; //this will delete CTCall
-(int)findContactByEB:(CTEditBase *)peer outb:(CTEditBase *)name;
//-(NSData *)getImageData:(int)p_id;
-(void)resetBadgeNumber:(bool)bResetToZero;

-(void)showPersonVCard:(CTRecentsItem*)i;
-(void)saveRecents;
-(void)loadRecents;



@end
