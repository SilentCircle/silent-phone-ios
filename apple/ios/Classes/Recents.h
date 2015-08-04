
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
   CTRecentsAdd(){iThisDur=iThisDir=0;pThisPeer=NULL;pThisServ=NULL;pThisNameFromABorSIP=NULL;iAnsweredSomewhereElse=0;}
   void add(int iDir,CTStrBase *nameFromABorSIP, char *p, int iDur, const char *serv);
public:
   static CTRecentsAdd* addMissed(CTStrBase *nameFromABorSIP, char *p, int iDur, const char *serv);
   static CTRecentsAdd* addDialed(CTStrBase *nameFromABorSIP, char *p, int iDur, const char *serv);
   static CTRecentsAdd* addReceived(CTStrBase *nameFromABorSIP, char *p, int iDur, const char *serv,int iAnsweredSomewhereElse=0);
   int iThisDir,iThisDur;
   char *pThisPeer;
   const char *pThisServ;
   CTStrBase *pThisNameFromABorSIP;
   int iAnsweredSomewhereElse;
   
};

class CTRecentsList;
@class RecentsInfoTW;
class CTRecentsItem;

@interface RecentsViewController : UITableViewController < 
UITextFieldDelegate,
   ABPeoplePickerNavigationControllerDelegate,
																 ABPersonViewControllerDelegate,
															     ABNewPersonViewControllerDelegate,
												                 ABUnknownPersonViewControllerDelegate
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
}
//@property (nonatomic, assign) IBOutlet UICellController *editableTableViewCell;
@property (nonatomic, assign) IBOutlet UIRecentCell *recentTableViewCell;


-(void)showPeoplePickerController;
//-(void)showPersonViewController;
-(void)showNewPersonViewController;
-(void)showUnknownPersonViewController;
-(void)showUnknownPersonViewControllerNS:(NSString *)ns;
-(void)addToRecents:(CTRecentsAdd*) r;
-(int)findContactByEB:(CTEditBase *)peer outb:(CTEditBase *)name;
//-(NSData *)getImageData:(int)p_id;
-(void)resetBadgeNumber:(bool)bResetToZero;

-(void)showPersonVCard:(CTRecentsItem*)i;
-(void)saveRecents;
-(void)loadRecents;



@end
