/*
 - (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section;
 - (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section;
 */
#import "SettingsController.h"
#import "UICellController.h"

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



@implementation SettingsController

@synthesize   prevTView,chooseItem;

- (void)dealloc
{

	[nextView release];
	[super dealloc];
}

- (void)awakeFromNib
{	
	self.title = levelTitle;//@"Level 1";
}

-(void)setLevelTitle:(NSString*)name{
   levelTitle=name;
   self.title = name;
}

-(void)setList:(CTList *)newList{
   list=newList;
   [self.tableView reloadData];
   //   list=new CTList();
   //return list;
}


#pragma mark UIViewController delegates

- (void)viewDidLoad 
{
	[super viewDidLoad];
   iTView_was_visible=0;
    passwordAlertState = 0;
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
   
   if(self.chooseItem && self.chooseItem->sc.iType==CTSettingsCell::eChoose){
      //puts("--------pop-----");
      void stopTestRingTone();//TODO FIX hack
      stopTestRingTone();
   }
   
}

- (void)viewWillAppear:(BOOL)animated
{
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
   
}


#pragma mark UITableView delegates


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
   
   CTSettingsItem *i=findSection(list,(int)section);
   if(!i)return @"Error";
   NSString *l = i->sc.getLabel();
   return l?l:@"";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section{
   CTSettingsItem *i=findSection(list,(int)section);
   if(!i)return @"Error";
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
   selectedCell=(UICellController*)i->sc.pRet;
   
   if(i){
      if(i->sc.onChange && i->sc.iType!=CTSettingsCell::eRadioItem  && i->sc.iType!=CTSettingsCell::eChoose){
         puts("onChange");
         i->sc.onChange(i,i->sc.pRetCB);
      }
      //TODO onClickMoveFromListToList
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
            ret=i->sc.onChange(i,i->sc.pRetCB);
         }
         else if(chooseItem->sc.onChange){
            puts("onChange Choose");
            ret=chooseItem->sc.onChange(chooseItem,chooseItem->sc.pRetCB);
         }
         
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
   nextView.prevTView=tableView;
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

         int swW=27;// ????? 
          
         CGRect r=CGRectMake(215,(44-swW)/2, 0, 0);
         cell.uiSwitch=[[UISwitch alloc] initWithFrame:r];// cell.bounds];
         cell.uiSwitch.center=CGPointMake(cell.bounds.size.width-cell.uiSwitch.frame.size.width/2-25,cell.center.y);
         cell.uiSwitch.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;

         [cell.contentView addSubview:cell.uiSwitch];
         
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
         [xCell.contentView addSubview:textField];
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
    
         
      case CTSettingsCell::eOnOff:
         cell.uiSwitch.tag = indexPath.row+indexPath.section*100;
         
         [cell.uiSwitch setOn:i->getValue()[0]!='0'];
         [cell.uiSwitch addTarget:self action:@selector(onOnOffChange:) forControlEvents:UIControlEventValueChanged];

        // cell.uiSwitch.frame=CGRectMake(0.f,0.f,44.f,320.f);
         
         break;
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
   i->sc.pRet=cell;
   if(i->sc.iType==CTSettingsCell::eNextLevel || i->sc.iType==CTSettingsCell::eChoose || i->sc.iType==CTSettingsCell::eCodec){
      if(i->sc.value)cell.detailTextLabel.text=i->sc.value;
   }
   else if(cell.detailTextLabel)cell.detailTextLabel.text=@"";
	

	cell.textLabel.text = i->sc.getLabel()?i->sc.getLabel():@"Err";
   
	return cell;
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
   }
    
    if(i->sc.passLock == 1)
    {
        _lockKeySwitch = [sw retain];
        if(sw.isOn)
        {
            [self setPassWordWithAlertText:@"Set Passcode" andTag:sw.tag];
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
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Passcode" message:@"Enter Passcode" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Turn Off",@"Change Passcode",[NSString stringWithFormat:@" Change Delay (%@)",delayString], nil];
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
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:alertText message:@"Enter New Passcode" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Next", nil];
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
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Passcode Lock" message:@"Reenter New Passcode" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Next", nil];
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
                [self setPassWordWithAlertText:@"Password Mismatch" andTag:alertView.tag];
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
                    [self setPassWordWithAlertText:@"Set new Passcode" andTag:alertView.tag];
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
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Passcode Delay" message:nil delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles:@"5 Seconds",@"15 Seconds",@"1 Minute",@"15 Minutes",@"1 Hour",@"4 Hours", nil];
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
   CGFloat cw=CGRectGetWidth(cellBounds);
   
   CGRect aRect2 = CGRectMake(cw*.3f,0,cw*.65-10,ch);
   
   textField.frame = aRect2;
   textField.textAlignment=NSTextAlignmentRight;
   textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
   
   [textField setDelegate:self];
   
}





@end



