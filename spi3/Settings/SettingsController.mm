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
#import "SettingsController.h"
#import "SCPSettingsManager.h"
#import "UICellController.h"
#import "SCPCallbackInterface.h"
#import "SCSAudioManager.h"
#import "SCPNotificationKeys.h"
#import "SCPPasscodeManager.h"
#import "MWSPinLockScreenVC.h"
#import "SCSEnums.h"

CTSettingsItem *findSection(CTList *l, int section){
   CTSettingsItem *item=(CTSettingsItem*)l->getLRoot();
   while(item){
      // CTList *n=item->nextLevel();
      if(item->isSection()){
         if(!section){
            return item;
         }
         section--;
      }
      item=(CTSettingsItem*)l->getNext(item);
   }
   return NULL;
}

CTSettingsItem *findRItem(CTList *l, int row){
   CTSettingsItem *item;
   item=(CTSettingsItem*)l->getLRoot();
   while(item){
      if(!row){
         return item;
      }
      row--;
      item=(CTSettingsItem*)l->getNext(item);
   }
   return NULL;
}

CTSettingsItem *findSItem(CTList *l, NSIndexPath *indexPath){
   CTSettingsItem *item;
   item=findSection(l,(int)indexPath.section);
   if(!item|| !item->root)return NULL;
   l=item->root;
   return findRItem(l,(int)indexPath.row);
}

CTSettingsItem *findSItem(CTList *l, int section, int row){
   CTSettingsItem *item;
   item=findSection(l,section);
   if(!item|| !item->root)return NULL;
   l=item->root;
   return findRItem(l,row);
}


int countSections(CTList *l){
   return l->countVisItems();
}

int countItemsInSection(CTList *l, int section){
   CTSettingsItem *s=findSection(l,section);
   if(!s || !s->root)return 0;
   return s->root->countVisItems();
}


//10/31/15 - moved from .h
@interface SettingsController()<UITableViewDelegate , UITableViewDataSource, UITextFieldDelegate, MWSPinLockScreenDelegate> {
    SCPSettingsManager *settingsManager;
}

@property (nonatomic, retain) NSString *savedPasscode;
@property (nonatomic, retain) UITableView *prevTView;
@property (nonatomic) CTSettingsItem *chooseItem;
@property (nonatomic, retain) NSString *enteredPassword;
@property (nonatomic, retain) UISwitch *lockKeySwitch;
-(void)setLevelTitle:(NSString*)name;
-(void)setList:(CTList *)newList;
@end


@implementation SettingsController
{
    int iTView_was_visible;
    
    SettingsController *nextView;
    CTList *list;
    CTSettingsItem *chooseItem;
    UICellController *selectedCell;
    
    UITextField *activeTF;
    UITableView *prevTView;
    NSString *levelTitle;
    
    int passwordAlertState;
    enum passWordState
    {
        pDone = 0,
        pEnterPassword = 1,
        pRepeatPassword = 2,
        pDoneSetting = 3, // meaning password is set to on
        pEditDelay = 4,
    };
    
    scsPasscodeScreenState _passcodeState;
    MWSPinLockScreenVC *_activeLockScreenVC;
}

@synthesize prevTView,chooseItem;

- (void)dealloc
{    
	[nextView release];
	[super dealloc];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
	self.title = levelTitle;//@"Level 1";
}

-(void)setLevelTitle:(NSString*)name{
   levelTitle=name;
   self.title = name;
}

-(void)setList:(CTList *)newList{
   list=newList;
   [self.tableView reloadData];
}

- (void)reloadPasscodeList {
    
    int v = (int)[[SCPPasscodeManager sharedManager] doesPasscodeExist];
    
    CTSettingsItem* x = (CTSettingsItem*)[SCPSettingsManager
                                          settingsItemByKey:@"iUsePasscode"];
    
    if(x)
        x->sc.setLabel(v? NSLocalizedString(@"Turn Passcode Off", nil): NSLocalizedString(@"Turn Passcode On", nil));
    
    x =(CTSettingsItem*)[SCPSettingsManager
                         settingsItemByKey:@"iChangePasscode"];
    
    if(x)
        x->iVisible=v;
    
    x  =(CTSettingsItem*)[SCPSettingsManager
                          settingsItemByKey:@"iPasscodeEnableTouchID"];
    
    if(x)
        x->iVisible=v;
    
    x =(CTSettingsItem*)[SCPSettingsManager
                         settingsItemByKey:@"szPasscodeTimeout"];
    if(x)
        x->iVisible=v;
    
    x =(CTSettingsItem*)[SCPSettingsManager
                         settingsItemByKey:@"iPasscodeEnableWipe"];
    if(x) {
        
        x->iVisible=v;
        x->sc.value = ([[SCPPasscodeManager sharedManager] isWipeEnabled] ? @"1" : @"0");
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

//DebugLogging:
- (void) showDebugLoggingViewController{
    
    int debugLoggingEnabled(void);
    if(!debugLoggingEnabled()){
        NSString *title = NSLocalizedString(@"Enable Debug Mode", nil);
        NSString *errMsg = NSLocalizedString(@"Please enable debug logging before reporting issue and sending logs", nil);
        [self showError:title andErrorMessage:errMsg];
        return;
    }
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Logging" bundle:nil];
    UIViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:@"LoggingViewController"];
    [self.navigationController pushViewController:viewController animated:YES];
    
}
-(void)showError:(NSString *)title andErrorMessage:(NSString *)errMsg{
    UIAlertController * alert=   [UIAlertController
                                  alertControllerWithTitle:title
                                  message:errMsg
                                  preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* ok = [UIAlertAction
                         actionWithTitle:NSLocalizedString(@"OK", nil)
                         style:UIAlertActionStyleDefault
                         handler:^(UIAlertAction * action)
                         {
                             [alert dismissViewControllerAnimated:YES completion:nil];
                             
                         }];
    [alert addAction:ok];
    [self presentViewController:alert animated:YES completion:nil];
}
//DebugLogging ended


#pragma mark UIViewController delegates

- (void)viewDidLoad 
{
	[super viewDidLoad];
    
   iTView_was_visible=0;
    passwordAlertState = 0;
 
    if(!prevTView && [SCPSettingsManager getCfgLevel] == 2) {
        
        [self.navigationItem.rightBarButtonItem setEnabled:!prevTView];

        UIBarButtonItem *saveBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                       target:self
                                                                                       action:@selector(saveSettings)];
        
        self.navigationItem.rightBarButtonItem = saveBarButton;
    }
    
    if (list == NULL) {

        CTList *sList = (CTList *)[SCPSettingsManager settingsList];
        [self setList:sList];
    }
    
}

- (void)viewDidDisappear:(BOOL)animated{
   iTView_was_visible=0;
   
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                name:UIKeyboardWillShowNotification
                                              object:nil];
   
   // Register notification when the keyboard will be hide
   [[NSNotificationCenter defaultCenter] removeObserver:self
                                                name:UIKeyboardWillHideNotification
                                              object:nil];
   
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                 name:kSCSPasscodeShouldShowNewPasscode
                                               object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kSCSPasscodeShouldShowEditPasscode
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                 name:kSCSPasscodeShouldRemovePasscode
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kSCSPasscodeShouldEnableWipe
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kSCSPasscodeShouldDisableWipe
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kSCSPasscodeDidUnlock
                                                  object:nil];
    
   if(self.chooseItem && self.chooseItem->sc.iType==CTSettingsCell::eChoose){
       [SPAudioManager stopTestRingtone];
   }
   
   BOOL saveCfg = !prevTView && !chooseItem && !self.parentViewController;
   
    NSLog(@"should save here? %@ parentVC: %@",saveCfg? @"yes":@"no", NSStringFromClass([self.parentViewController class]));
    
   if(saveCfg){
      [Switchboard doCmd:@":s"];
      NSLog(@"parentVC: %@", NSStringFromClass([self.parentViewController class]));
      [SCPSettingsManager saveSettings];//we have to release the old sList
   }
    
    [super viewDidDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

   iTView_was_visible=0;
}

- (void)viewDidAppear:(BOOL)animated
{
   [super viewDidAppear:animated];
   iTView_was_visible=1;
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(keyboardWillShow:)
                                                name:UIKeyboardWillShowNotification
                                              object:nil];
   
   // Register notification when the keyboard will be hide
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(keyboardWillHide:)
                                                name:UIKeyboardWillHideNotification
                                              object:nil];
   
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(showNewPasscode)
                                                 name:kSCSPasscodeShouldShowNewPasscode
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(showEditPasscode)
                                                 name:kSCSPasscodeShouldShowEditPasscode
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(removePasscode)
                                                 name:kSCSPasscodeShouldRemovePasscode
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(toggleWipe:)
                                                 name:kSCSPasscodeShouldEnableWipe
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(toggleWipe:)
                                                 name:kSCSPasscodeShouldDisableWipe
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(passcodeManagerDidUnlock)
                                                 name:kSCSPasscodeDidUnlock
                                               object:nil];
}

#pragma mark - Passcode Notifications

- (void)passcodeManagerDidUnlock {
    
    if(_activeLockScreenVC)
        [_activeLockScreenVC updateLockScreenStatus];
}

- (void)showEditPasscode {
    
    SCPPasscodeManager *passcodeManager = [SCPPasscodeManager sharedManager];
    _passcodeState = ePasscodeScreenStateEditing;
    
    NSString *oldPasscodeTitle = NSLocalizedString(@"Enter your old passcode", nil);
    NSString *newPasscodeTitle = NSLocalizedString(@"Enter a new passcode", nil);
    
    MWSPinLockScreenVC *lockScreen = [[MWSPinLockScreenVC alloc] initWithLabelTitle:oldPasscodeTitle
                                                                         completion:^(MWSPinLockScreenVC *pinLockScreenVC, NSString *passcode) {
                                                                             
                                                                             if(_passcodeState == ePasscodeScreenStateEditing) {
                                                                                 
                                                                                 if([passcodeManager evaluatePasscode:passcode error:nil]) {
                                                                                     
                                                                                     _passcodeState = ePasscodeScreenNewPasscode;
                                                                                 
                                                                                     [pinLockScreenVC setLabelTitle:newPasscodeTitle
                                                                                                          clearDots:YES];
                                                                                 }
                                                                                 else {
                                                                                     
                                                                                     _passcodeState = ePasscodeScreenStateEditing;
                                                                                     
                                                                                     [pinLockScreenVC setUserInteractionEnabled:![passcodeManager isPasscodeLocked]];
                                                                                     [pinLockScreenVC animateInvalidEntryResponseWithText:nil
                                                                                                                               completion:^{ [pinLockScreenVC updateLockScreenStatus]; }];
                                                                                 }
                                                                             }
                                                                             // We do not allow user to enter the same new passcode as the old one
                                                                             else if(_passcodeState == ePasscodeScreenNewPasscode &&
                                                                                     [passcodeManager evaluatePasscode:passcode calculateFailedAttempts:NO error:nil]) {
                                                                                 
                                                                                 _passcodeState = ePasscodeScreenNewPasscode;
                                                                                 
                                                                                 [pinLockScreenVC animateInvalidEntryResponseWithText:NSLocalizedString(@"Enter a different passcode", nil)
                                                                                                                           completion:^{
                                                                                     
                                                                                     [pinLockScreenVC setLabelTitle:newPasscodeTitle
                                                                                                          clearDots:YES];
                                                                                 }];
                                                                             }
                                                                             else
                                                                                 [self newPasscodeLogic:pinLockScreenVC
                                                                                             firstLabel:newPasscodeTitle
                                                                                               passcode:passcode];
                                                                         }];
    lockScreen.delegate                 = self;
    lockScreen.passcodeManager          = passcodeManager;
    lockScreen.modalPresentationStyle   = UIModalPresentationOverFullScreen;
    lockScreen.modalTransitionStyle     = UIModalTransitionStyleCrossDissolve;
    
    _activeLockScreenVC = lockScreen;

    [self presentViewController:lockScreen
                       animated:YES
                     completion:^{
                         [lockScreen updateLockScreenStatus];
                     }];
}

- (void)showNewPasscode {
    
    BOOL hasPasscode = [[SCPPasscodeManager sharedManager] doesPasscodeExist];
    
    if(hasPasscode) {
        
        [self showEditPasscode];
        return;
    }
    
    _passcodeState = ePasscodeScreenNewPasscode;
    
    NSString *enterPasscodeTitle = NSLocalizedString(@"Enter a passcode", nil);
    
    MWSPinLockScreenVC *lockScreen = [[MWSPinLockScreenVC alloc] initWithLabelTitle:enterPasscodeTitle
                                                                         completion:^(MWSPinLockScreenVC *pinLockScreenVC, NSString *passcode) {
                                                                             [self newPasscodeLogic:pinLockScreenVC
                                                                                         firstLabel:enterPasscodeTitle
                                                                                           passcode:passcode];
                                                                         }];
    lockScreen.delegate                 = self;
    lockScreen.modalPresentationStyle   = UIModalPresentationOverFullScreen;
    lockScreen.modalTransitionStyle     = UIModalTransitionStyleCrossDissolve;

    [self presentViewController:lockScreen
                       animated:YES
                     completion:nil];
}

- (void)newPasscodeLogic:(MWSPinLockScreenVC *)pinLockScreenVC firstLabel:(NSString *)firstLabel passcode:(NSString *)passcode {
 
    if(_passcodeState == ePasscodeScreenNewPasscode) {
        
        _savedPasscode = [passcode retain];
        _passcodeState = ePasscodeScreenVerifyPasscode;
        
        [pinLockScreenVC setLabelTitle:NSLocalizedString(@"Verify your new passcode", nil)
                             clearDots:YES];
    }
    else if(_passcodeState == ePasscodeScreenVerifyPasscode) {
        
        if([passcode isEqualToString:_savedPasscode]) {
            
            [[SCPPasscodeManager sharedManager] setPasscode:passcode];
            
            [pinLockScreenVC dismissViewControllerAnimated:YES completion:^{
                _activeLockScreenVC = nil;
                [self reloadPasscodeList];
            }];
        }
        else {
            
            _passcodeState = ePasscodeScreenNewPasscode;
            
            [pinLockScreenVC animateInvalidEntryResponseWithText:NSLocalizedString(@"Passcodes did not match", nil)
                                                      completion:^{
                                                          
                [pinLockScreenVC setLabelTitle:firstLabel
                                     clearDots:YES];
            }];
        }
        
        [_savedPasscode release];
    }
}

- (void)toggleWipe:(NSNotification *)notification {
    
    BOOL shouldEnable = [notification.name isEqualToString:kSCSPasscodeShouldEnableWipe];
    
    SCPPasscodeManager *passcodeManager = [SCPPasscodeManager sharedManager];
    
    NSString *enterPasscodeTitle = NSLocalizedString(@"Enter passcode", nil);
    
    MWSPinLockScreenVC *lockScreen = [[MWSPinLockScreenVC alloc] initWithLabelTitle:enterPasscodeTitle
                                                                         completion:^(MWSPinLockScreenVC *pinLockScreenVC, NSString *passcode) {
                                                                             
                                                                             if([passcodeManager evaluatePasscode:passcode error:nil]) {
                                                                                 
                                                                                 if(shouldEnable)
                                                                                     [Switchboard doCmd:@"set cfg.iPasscodeEnableWipe=1"];
                                                                                 else
                                                                                     [Switchboard doCmd:@"set cfg.iPasscodeEnableWipe=0"];
                                                                                 
                                                                                 [Switchboard doCmd:@":s"];

                                                                                 [pinLockScreenVC dismissViewControllerAnimated:YES completion:^{
                                                                                     
                                                                                     _activeLockScreenVC = nil;
                                                                                     
                                                                                     [self reloadPasscodeList];
                                                                                 }];
                                                                             }
                                                                             else {
                                                                                 [pinLockScreenVC setUserInteractionEnabled:![passcodeManager isPasscodeLocked]];
                                                                                 [pinLockScreenVC animateInvalidEntryResponseWithText:nil
                                                                                                                           completion:^{ [pinLockScreenVC updateLockScreenStatus]; }];
                                                                             }
                                                                         }];
    lockScreen.delegate                 = self;
    lockScreen.passcodeManager          = passcodeManager;
    lockScreen.modalPresentationStyle   = UIModalPresentationOverFullScreen;
    lockScreen.modalTransitionStyle     = UIModalTransitionStyleCrossDissolve;
    
    _activeLockScreenVC = lockScreen;
    
    [self presentViewController:lockScreen
                       animated:YES
                     completion:^{ [lockScreen updateLockScreenStatus]; }];
}

- (void)removePasscode {
    
    SCPPasscodeManager *passcodeManager = [SCPPasscodeManager sharedManager];
    
    NSString *enterPasscodeTitle = NSLocalizedString(@"Enter passcode", nil);

    MWSPinLockScreenVC *lockScreen = [[MWSPinLockScreenVC alloc] initWithLabelTitle:enterPasscodeTitle
                                                                         completion:^(MWSPinLockScreenVC *pinLockScreenVC, NSString *passcode) {
        
                                                                             if([passcodeManager evaluatePasscode:passcode error:nil]) {
                                                                                 
                                                                                 BOOL passcodeDeleted = [passcodeManager deletePasscode];
                                                                                 
                                                                                 [pinLockScreenVC dismissViewControllerAnimated:YES completion:^{
                                                                                     
                                                                                     _activeLockScreenVC = nil;
                                                                                     
                                                                                     if(passcodeDeleted)
                                                                                         [self reloadPasscodeList];
                                                                                     else
                                                                                         [self showError:NSLocalizedString(@"Error", nil)
                                                                                         andErrorMessage:NSLocalizedString(@"Error while removing passcode. Try again.", nil)];
                                                                                 }];
                                                                             }
                                                                             else {
                                                                                 [pinLockScreenVC setUserInteractionEnabled:![passcodeManager isPasscodeLocked]];
                                                                                 [pinLockScreenVC animateInvalidEntryResponseWithText:nil
                                                                                                                           completion:^{ [pinLockScreenVC updateLockScreenStatus]; }];
                                                                             }
                                                                         }];
    lockScreen.delegate                 = self;
    lockScreen.passcodeManager          = passcodeManager;
    lockScreen.modalPresentationStyle   = UIModalPresentationOverFullScreen;
    lockScreen.modalTransitionStyle     = UIModalTransitionStyleCrossDissolve;

    _activeLockScreenVC = lockScreen;
    
    [self presentViewController:lockScreen
                       animated:YES
                     completion:^{
                         [lockScreen updateLockScreenStatus];
                     }];
}

#pragma mark - MWSPinLockScreenDelegate

- (void)lockScreenSelectedCancel:(MWSPinLockScreenVC *)pinLockScreenVC {
    
    [pinLockScreenVC dismissViewControllerAnimated:YES completion:^{
        
        _activeLockScreenVC = nil;

        [self reloadPasscodeList];
    }];
}

#pragma mark - UITableViewDelegate

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
   
   CTSettingsItem *i=findSection(list,(int)section);
   if(!i)return @"Error";
   if(!i->iVisible || !countItemsInSection(list,(int)section))return @"";
   NSString *l = i->sc.getLabel();
   return l?l:@"";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section{
   CTSettingsItem *i=findSection(list,(int)section);
   if(!i)return @"Error";
   if(!i->iVisible || !countItemsInSection(list,(int)section))return @"";
   NSString *f = i->sc.getFooter();
   return f?f:@"";
}

/*
 - (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section;
 - (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section;
 */

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
   CTSettingsItem *i=findSItem(list,indexPath);
   
   return (i && i->sc.iType==CTSettingsCell::eReorder)?YES:NO;
   
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath{
   
   CTSettingsItem *src=findSItem(list,sourceIndexPath);
   if(!src)return;
   if(sourceIndexPath.section==destinationIndexPath.section){
      if(sourceIndexPath.row==destinationIndexPath.row)return;
      CTSettingsItem *s=findSection(list,(int)destinationIndexPath.section);
      CTList *l=s->root;
      
      {
         int iAfter=(int)destinationIndexPath.row;
         //if(iAfter>0)iAfter--;
         
         CTSettingsItem *after=findRItem(l,iAfter);
         if(after && destinationIndexPath.row<sourceIndexPath.row)after=(CTSettingsItem *)l->getPrev(after);
         
         l->remove(src,0);
         //  after=(CTSettingsItem *)l->findItem(after);
         if(destinationIndexPath.row==0){
            l->addToRoot(src);
         }
         else 
            if(!after){
               if(sourceIndexPath.row>destinationIndexPath.row)
                  l->addToRoot(src);
               else
                  l->addToTail(src);
               
            }
            else l->addAfter(after,src);
      }
      
      
   }
   else{
      CTList *l=src->parent;
      CTSettingsItem *dst=findSection(list,(int)destinationIndexPath.section);
      if(!dst || !dst->root)return;
      CTList *dl=dst->root;

      CTSettingsItem *c=findSItem(list,destinationIndexPath);
   
      l->remove(src,0);
      if(c)c=(CTSettingsItem *)c->parent->getPrev(c);
      if(c){
        dl->addAfter(c, src);
      }
      else {
         if(destinationIndexPath.row>=dl->countVisItems()){
            dl->addToTail(src);
         }
         else dl->addToRoot(src);
      }
      src->parent=dl;
      
   }
}


- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
   return NO;
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath{
   return YES;//(indexPath.section==3)?NO:YES;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return list?countSections(list):0;//countItemsInSection;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return list?countItemsInSection(list,(int)section):0;//[listContent count];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
   CTSettingsItem *i=findSItem(list,indexPath);
   if(!i)return;
   printf("[delete]");
   if(i->sc.onDelete){
      i->sc.onDelete(i,i->sc.pRetCB);
   }
   CTList *r=i->parent;
   if(r)
      r->remove(i);
   
   [tableView reloadData];
   printf("[del ok %p]",r);
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath{

   CTSettingsItem *i=findSItem(list,indexPath);
   
   if(i && i->sc.iCanDelete){
      return UITableViewCellEditingStyleDelete;
   }
   return UITableViewCellEditingStyleNone;

}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
   
   CTSettingsItem *i=findSItem(list,indexPath);
   if(!i)return;
    
    //DebugLogging: comparing key to check if "Send Debug Logs" is selected or not.
    //"Send Debug Logs" may not be able to be created as eButton and implement onClick() to launch
    //DebugLoggingViewController in SettingsManager class like "Terms Of Service" which is webview.
    //key: "iSendDebugLogs"
    if(strcmp(i->sc.key, "iSendDebugLogs") == 0){
        [self showDebugLoggingViewController];
        return;
    }
    
   selectedCell=(UICellController*)i->sc.pRet;
   
    if(i){
        
        if(i->sc.onChange && i->sc.iType!=CTSettingsCell::eRadioItem  && i->sc.iType!=CTSettingsCell::eChoose && i->sc.iType!=CTSettingsCell::eOnOff){

            int ret= i->callOnChange();
            
            if((ret & 2))
                [tableView reloadData];

            if(ret)
                return;
        }
    }
   printf("[i=%p type=%d]",i , i? i->sc.iType:-1);
   
   if(!i || !i->root){
      if(i && i->sc.iType==CTSettingsCell::eButton){
         [i->sc.value release];
         i->sc.value=[[NSString alloc ] initWithString:@"1"];
         return;
      }
      else if(i && i->sc.iType==CTSettingsCell::eRadioItem){

         chooseItem->sc.value =[i->sc.getLabel() copy];
         int ret=0;
         if(i->sc.onChange){
            puts("onChange radio");
            ret=i->callOnChange();
         }
         else if(chooseItem->sc.onChange){
            puts("onChange Choose");
            ret=chooseItem->callOnChange();
         }
          chooseItem->save(chooseItem->sc.pCfg);
 
         // chooseItem->setValue(i->sc.getLabel().UTF8String);
         
         UICellController *cell=(UICellController *)chooseItem->sc.pRet;
         [cell.detailTextLabel setText:i->sc.getLabel()];
         
         UICellController *c=(UICellController*)i->sc.pRet;
         c.accessoryType = UITableViewCellAccessoryCheckmark;
         
         

         if((ret & 4)==0) [[self navigationController] popViewControllerAnimated:YES];
         if((ret & 2))[tableView reloadData];

         
      }
      return;
   }
    
   nextView=[[SettingsController alloc]initWithStyle:UITableViewStyleGrouped];
   nextView->prevTView=tableView;
   nextView.chooseItem=i;
   [nextView setList:i->root];
   [nextView setLevelTitle:i->sc.getLabel()];
   if(i->sc.iType==CTSettingsCell::eCodec)
     [nextView setEditing:YES];

	[[self navigationController] pushViewController:nextView animated:YES];
    
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
   
   CTSettingsItem *i=findSItem(list,indexPath);
//   myTableView=tableView;
   iTView_was_visible=1;
    
//    NSLog(@"cell %p l=%p %@ tw=%@", i, list, indexPath, tableView);
   
   static NSString *kCellIdentifier=@"c1";
   static NSString *kCellIdentifierE=@"c1E";
   static NSString *kCellIdentifierSw=@"c1Sw";
   static NSString *kCellIdentifierC=@"c1Codec";
   
   NSString *c=kCellIdentifier;
   UITableViewCellStyle s=UITableViewCellStyleValue1;
   
   switch(i->sc.iType){
      case CTSettingsCell::eReorder:
         c=kCellIdentifierC;
         break;
      case CTSettingsCell::eOnOff:
         c=kCellIdentifierSw;
         break;
      case CTSettingsCell::eSecure:
      case CTSettingsCell::eEditBox:
      case CTSettingsCell::eInt:
         c=kCellIdentifierE;
         break;
   }
   
	UICellController *cell = [tableView dequeueReusableCellWithIdentifier:c];
   
	if (cell == nil)
	{
		cell = [[[UICellController alloc] initWithStyle:s reuseIdentifier:c] autorelease];
      if(i->sc.iType==CTSettingsCell::eOnOff){

         cell.uiSwitch=[[UISwitch alloc] initWithFrame:CGRectZero];
         cell.accessoryView = cell.uiSwitch;
         [cell.uiSwitch release];
      }
      else if(i->sc.iType==CTSettingsCell::eEditBox || i->sc.iType==CTSettingsCell::eInt || i->sc.iType==CTSettingsCell::eSecure){
         UICellController *xCell = cell;
         
         UITextField *textField = [[UITextField alloc] init];
         xCell.textField=textField;

         textField.tag = indexPath.row+indexPath.section*100;//+ indexPath.row;
         // Add general UITextAttributes if necessary
         textField.returnKeyType=UIReturnKeyDone;
         textField.enablesReturnKeyAutomatically = NO;
         textField.autocorrectionType = UITextAutocorrectionTypeNo;
         textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
         //[textField setText:@"x"];
      //   [xCell.contentView addSubview:textField];
         cell.accessoryView = textField;
         [textField release];
         cell=xCell;
         //textField.frame=cell.detailTextLabel.frame;
      }
  	}
   cell.detailTextLabel.text=nil;
   

   if(i->root && (i->sc.iType==CTSettingsCell::eNextLevel || i->sc.iType==CTSettingsCell::eChoose || i->sc.iType==CTSettingsCell::eCodec) ){
      cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
   }
   else if(i->sc.iType==CTSettingsCell::eRadioItem){
      if(chooseItem && [chooseItem->sc.value isEqualToString :i->sc.getLabel()])
         cell.accessoryType =UITableViewCellAccessoryCheckmark;
      else
         cell.accessoryType = UITableViewCellAccessoryNone;
   }
   cell.showsReorderControl=YES;
   cell.selectionStyle= UITableViewCellSelectionStyleNone;
  // cell.vi
   //tableView.allowsSelection=NO;
   [cell setSI:i newTW:tableView];
   
   switch(i->sc.iType){
      case CTSettingsCell::eButton:
         cell.selectionStyle= UITableViewCellSelectionStyleBlue;
         //cell.highlighted = YES;// [UIColor blueColor];
         if(i->sc.iIsLink)cell.textLabel.textColor = [UIColor blueColor];
         break;
         
      case CTSettingsCell::eRadioItem:
      case CTSettingsCell::eReorder:
         break;
    
         
       case CTSettingsCell::eOnOff: {
         cell.uiSwitch.tag = indexPath.row+indexPath.section*100;
         const char *value = i->getValue();
         [cell.uiSwitch setOn:((value)&&(value[0]!='0'))];
         [cell.uiSwitch addTarget:self action:@selector(onOnOffChange:) forControlEvents:UIControlEventValueChanged];
         cell.uiSwitch.enabled = !i->sc.iIsDisabled;
         // cell.uiSwitch.frame=CGRectMake(0.f,0.f,44.f,320.f);
         break;
       }
      case CTSettingsCell::eInt:
         cell.textField.keyboardType = UIKeyboardTypeNumberPad;
      case CTSettingsCell::eSecure:
         if(i->sc.iType==CTSettingsCell::eSecure){
            cell.textField.keyboardType = UIKeyboardTypeDefault;
            cell.textField.secureTextEntry=YES;
         }
      case CTSettingsCell::eEditBox:
         if(i->sc.iType==CTSettingsCell::eEditBox){
            cell.textField.keyboardType = UIKeyboardTypeDefault;
         }
         if(i->sc.iType!=CTSettingsCell::eSecure){
            cell.textField.secureTextEntry=NO;
         }
         [self configureCellE:cell atIndexPath:indexPath];

         if(i->sc.value)[cell.textField  setText:i->sc.value];
         
         cell.textField.tag=indexPath.row+indexPath.section*100;
         
         
         break;


   }
   i->sc.tw  = tableView;
   i->sc.pRet=cell;
   if(i->sc.iType==CTSettingsCell::eNextLevel || i->sc.iType==CTSettingsCell::eChoose || i->sc.iType==CTSettingsCell::eCodec){
      if(i->sc.value)cell.detailTextLabel.text=i->sc.value;
   }
   else if(cell.detailTextLabel)cell.detailTextLabel.text=@"";
	

	cell.textLabel.text = i->sc.getLabel()?i->sc.getLabel():@"Err";
   
	return cell;
}

#pragma mark - Private

- (void)saveSettings {
    
    [SCPSettingsManager saveSettings];
    
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
   
   if(activeTF){
      UITouch *touch = [[event allTouches] anyObject];
      if ([activeTF isFirstResponder] && [touch view] != activeTF) {
         [activeTF resignFirstResponder];
      }
   }
   [super touchesBegan:touches withEvent:event];
}

- (IBAction)textFieldDidBeginEditing:(UITextField *)textField
{
   activeTF = textField;
}

-(IBAction)onOnOffChange:(id)v{
   UISwitch *sw=(UISwitch*)v;
   CTSettingsItem *i=findSItem (list, (int)sw.tag/100,sw.tag%100);//(CTSettingsItem *)sw.tag;
   if(i){
      i->setValue([sw isOn]?"1":"0");
       //DebugLogging
       if(strcmp(i->sc.key, "iEnableDebugLogging") == 0){
           int debugLoggingEnabled(void);
           
           settingsManager = [SCPSettingsManager shared];
           if(debugLoggingEnabled()){
               [settingsManager startRepeatingLoggingTask];
           }else{
               [settingsManager stopRepeatingLoggingTask];
           }
       }
       //DebugLogging ended
   }
    
    if(i->sc.passLock == 1)
    {
        _lockKeySwitch = [sw retain];
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
    }
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
    [alert textFieldAtIndex:0].delegate = self;
    [alert show];
        [alert release];
    });
}

-(void) setPassWordWithAlertText:(NSString *) alertText andTag:(long) tag
{
    passwordAlertState = pEnterPassword;
    
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
        [alert release];
    });
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    NSString *thisPassword = [alertView textFieldAtIndex:0].text;
    NSString *passWord = [[NSUserDefaults standardUserDefaults] valueForKey:@"lockKey"];
    
    if (buttonIndex != [alertView cancelButtonIndex])
    {
        if(passwordAlertState == pEnterPassword)
        {
            // NO ARC !!
            _enteredPassword = [[NSString stringWithFormat:@"%@",thisPassword] retain];
            
            passwordAlertState = pRepeatPassword;
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
                [alert release];
            });
        } else if(passwordAlertState == pRepeatPassword)
        {
            
            if(![_enteredPassword isEqualToString:thisPassword])
            {
                [self setPassWordWithAlertText:NSLocalizedString(@"Password Mismatch", nil) andTag:alertView.tag];
            } else
            {
                [[NSUserDefaults standardUserDefaults] setValue:_enteredPassword forKey:@"lockKey"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                long currentTime = time(NULL);
                long timeDelay = 0;
                timeDelay = 5;
                NSDictionary *delayDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLong:currentTime],@"lockTime",[NSNumber numberWithLong:timeDelay],@"lockDelayTime",[NSNumber numberWithLong:0],@"isActive", nil];
                [[NSUserDefaults standardUserDefaults] setValue:delayDict forKey:@"lockTimeDict"];

                passwordAlertState = pDone;
                [_enteredPassword release];
            }
        }else if(passwordAlertState == pDoneSetting) // lock is active
        {
                switch (buttonIndex) {
                case 1:
                {
                    if([passWord isEqualToString:thisPassword])
                    {
                        [_lockKeySwitch setOn:NO animated:YES];
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
        } else if(passwordAlertState == pEditDelay)
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

            passwordAlertState = pDoneSetting;
        }
    } else
    {
        if(!passWord)
        {
            CTSettingsItem *i=findSItem (list, (int)alertView.tag/100,alertView.tag%100);
            i->sc.value = @"0";
            [_lockKeySwitch setOn:NO animated:NO];
            
        }
        passwordAlertState = pDone;
    }
}

-(void) presentDelayAlertViewWithTag:(long) tag
{
    passwordAlertState = pEditDelay;
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
    [alert release];
    });
}

/*
 
 // [cell.textField addTarget:self action:@selector(onTFChange:) forControlEvents:UIControlEventEditingDidEnd];
-(IBAction)onTFChange:(id)v{
   UITextField *sw=(UITextField*)v;
   CTSettingsItem *i=(CTSettingsItem *)sw.tag;
   if(i){
      puts("change----------");
      i->setValue(i->getValue());
   }
}
*/
- (IBAction)textFieldDidEndEditing:(UITextField *)textField
{
   
   [textField resignFirstResponder];
   activeTF=NULL;
   CTSettingsItem *i=findSItem (list, (int)textField.tag/100,textField.tag%100);
   if(i && i->sc.pRet){
      UICellController *r=(UICellController*)i->sc.pRet;
      if(r->textField == textField){
         [i->sc.value release];
         
         i->sc.value=[[textField text]copy];
         i->testOnChange();
         //show save
      }
      else {NSLog(@"ch uitf");}
   }
}


-(void) keyboardWillShow:(NSNotification *)note
{
   // Get the keyboard size
   if(iTView_was_visible!=1)return;
   
  // if(!tableView)return ;
   CGRect keyboardBounds;
   [[note.userInfo valueForKey:UIKeyboardFrameBeginUserInfoKey] getValue: &keyboardBounds];
   
   // Detect orientation
   UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
   CGRect frame = self.tableView.frame;
   
   // Start animation
   [UIView beginAnimations:nil context:NULL];
   [UIView setAnimationBeginsFromCurrentState:YES];
   [UIView setAnimationDuration:0.3f];
   
   // Reduce size of the Table view 
   if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown)
      frame.size.height -= keyboardBounds.size.height;
   else 
      frame.size.height -= keyboardBounds.size.width;
   
   // Apply new size of table view
   self.tableView.frame = frame;
   
   // Scroll the table view to see the TextField just above the keyboard
   if (activeTF)
   {
      CGRect textFieldRect = [self.tableView convertRect:activeTF.bounds fromView:activeTF];
      [self.tableView scrollRectToVisible:textFieldRect animated:NO];
   }
   
   [UIView commitAnimations];
}

-(void) keyboardWillHide:(NSNotification *)note
{
   // Get the keyboard size
   if(!self.tableView)return ;
   if(iTView_was_visible!=1)return;
   CGRect keyboardBounds;
   [[note.userInfo valueForKey:UIKeyboardFrameBeginUserInfoKey] getValue: &keyboardBounds];
   
   // Detect orientation
   UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
   CGRect frame = self.tableView.frame;
   
   [UIView beginAnimations:nil context:NULL];
   [UIView setAnimationBeginsFromCurrentState:YES];
   [UIView setAnimationDuration:0.3f];
   
   // Reduce size of the Table view 
   if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown)
      frame.size.height += keyboardBounds.size.height;
   else 
      frame.size.height += keyboardBounds.size.width;
   
   self.tableView.frame = frame;
   
   [UIView commitAnimations];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string{
   
   
   NSString *nextString = [textField.text stringByReplacingCharactersInRange:range withString:string];
   
   if(nextString.length>60)return NO;
   
   CTSettingsItem *si=findSItem (list, (int)textField.tag/100,textField.tag%100);//(CTSettingsItem *)textField.tag;
   
   if(si->sc.iType==CTSettingsCell::eSecure)return YES;
   
   NSCharacterSet *nonLettersNumbers = [[NSCharacterSet characterSetWithCharactersInString:@"qwertyuiopasdfghjklzxcvbnmABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890 -+.$!~*,:"] invertedSet];
   
   
   if ([nextString stringByTrimmingCharactersInSet:nonLettersNumbers].length != nextString.length) {
      return NO;
   }
   

   return YES;
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField {
   [textField resignFirstResponder];
   return YES;
}
-(IBAction)textFieldReturn:(id)sender
{
   activeTF=NULL;
   [sender resignFirstResponder];
} 


- (void)configureCellE:(UICellController *)theCell atIndexPath:(NSIndexPath *)indexPath {

   UITextField *textField =theCell.textField;
   // Position the text field within the cell bounds
   
   CGRect cellBounds = theCell.bounds;//bounds;
   CGFloat ch=CGRectGetHeight(cellBounds);
   CGFloat cw=[[UIScreen mainScreen] bounds].size.width;//CGRectGetWidth(cellBounds);
   //why do we see 320 for CGRectGetWidth(cellBounds) on ipad?

   CGRect aRect2 = CGRectMake(cw*.3f,0,cw*.65-10,ch);
   
   textField.frame = aRect2;
    
   textField.textAlignment=NSTextAlignmentRight;
   textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
   
   [textField setDelegate:self];
   
}





@end



