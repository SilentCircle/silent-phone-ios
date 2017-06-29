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
#import "SettingsViewController.h"
#import "SettingsViewController+Passcode.h"
#import "SCPSettingsManager.h"
#import "SettingsCell.h"
#import "SCPCallbackInterface.h"
#import "SCSAudioManager.h"


@interface SettingsViewController()
@property (nonatomic, retain) UITableView *prevTView;
//@property (nonatomic) CTSettingsItem *chooseItem;

//-(void)setLevelTitle:(NSString*)name;
@end


@implementation SettingsViewController
{
    int iTView_was_visible;
    
    SettingsViewController *nextView;
    BOOL bIsChooser;

//	CTSettingsItem *chooseItem;
//    SettingsCell *selectedCell;
    
//    UITextField *activeTF;
    UITableView *prevTView;
    NSString *levelTitle;
}

@synthesize prevTView;//,chooseItem;

- (void)awakeFromNib
{
    [super awakeFromNib];
    
	self.title = levelTitle;//@"Level 1";
}

- (void)setRoot:(SCSettingsItem *)root {
    _root = root;
    [self setItems:root.items];
    
    levelTitle = root.label;
    self.title = root.label;

	[self setEditing:[root isEditable]];
    //		nextView.chooseItem = i;
    //		[nextView setItems:setting.items];
    //		[nextView setLevelTitle:setting.label];
    //		[nextView setEditing:[setting isEditable]];
}

//-(void)setLevelTitle:(NSString*)name{
//   levelTitle=name;
//   self.title = name;
//}

- (void)setItems:(NSObject *)items {
    if ([items isKindOfClass:[NSArray class]])
        _sectionList = [[NSArray alloc] initWithArray:(NSArray *)items];
    else if ([items isKindOfClass:[NSDictionary class]]) {
        // pull out the keys (the display values) and order them leaving "default" on top
        NSArray *sortedItems = [[(NSDictionary *)items allKeys] sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            NSString *s1 = (NSString *)obj1;
            NSString *s2 = (NSString *)obj2;
//            NSString *v1 = [(NSDictionary *)items objectForKey:s1];
//            NSString *v2 = [(NSDictionary *)items objectForKey:s1];

            if ([@"Default" isEqualToString:s1])
                return NSOrderedAscending;
            else if ([@"Default" isEqualToString:s2])
                return NSOrderedDescending;
            else
                return [s1 compare:s2 options:NSCaseInsensitiveSearch];
        }];
        _sectionList = [[NSArray alloc] initWithArray:sortedItems];
    } else {
        NSLog(@"SettingsViewController: invalid items");
        return;
    }
    bIsChooser = ( ([_sectionList count] > 0)
                  && ([[_sectionList firstObject] isKindOfClass:[NSString class]]) );
//	[self.tableView reloadData];
}

#pragma mark UIViewController delegates

- (void)viewDidLoad 
{
	[super viewDidLoad];
    
   iTView_was_visible=0;
//    passwordAlertState = 0;
 
    if(!prevTView && [SCPSettingsManager getCfgLevel] == 2) {
        
        [self.navigationItem.rightBarButtonItem setEnabled:!prevTView];

        UIBarButtonItem *saveBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                       target:self
                                                                                       action:@selector(saveSettings)];
        
        self.navigationItem.rightBarButtonItem = saveBarButton;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	iTView_was_visible=0;

    if (!prevTView) // refresh root view on each appearance
        [self setItems:[[SCPSettingsManager shared] allSections]];
    
    [self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	iTView_was_visible=1;
/* This is for Geek View
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardWillShow:)
												 name:UIKeyboardWillShowNotification
											   object:nil];
	
	// Register notification when the keyboard will be hide
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardWillHide:)
												 name:UIKeyboardWillHideNotification
											   object:nil];
*/
	[self registerPasscodeNotifications];
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
	
	[self unregisterPasscodeNotifications];
	
//   if(self.chooseItem && self.chooseItem->sc.iType==CTSettingsCell::eChoose){
    if (bIsChooser)
       [SPAudioManager stopTestRingtone];
//   }
   
   BOOL saveCfg = !prevTView && !bIsChooser && !self.parentViewController;
   
    NSLog(@"should save here? %@ parentVC: %@",saveCfg? @"yes":@"no", NSStringFromClass([self.parentViewController class]));
    
   if(saveCfg){
      [Switchboard doCmd:@":s"];
      NSLog(@"parentVC: %@", NSStringFromClass([self.parentViewController class]));
      [SCPSettingsManager saveSettings];//we have to release the old sList
   }
    
    [super viewDidDisappear:animated];
}

#pragma mark - UITableViewDataSource, UITableViewDelegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (!_sectionList)
        return 0;
    if (bIsChooser)
        return 1;
	return [_sectionList count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (bIsChooser)
        return NSLocalizedString(@"Choose", nil);
    
	SCSettingsItem *sectionRoot = [_sectionList objectAtIndex:section];
	if (!sectionRoot)
		return @"Error";
	if ([sectionRoot isHidden])
		return nil;
//	if ([sectionRoot.visibleItems count] == 0)
//		return @"";
	return sectionRoot.header ? sectionRoot.header : @"";
//   CTSettingsItem *i=findSection(list,(int)section);
//   if(!i)return @"Error";
//   if(!i->iVisible || !countItemsInSection(list,(int)section))return @"";
//   NSString *l = i->sc.getLabel();
//   return l?l:@"";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section{
    if (bIsChooser)
        return nil;
    
	SCSettingsItem *sectionRoot = [_sectionList objectAtIndex:section];
	if (!sectionRoot)
		return @"Error";
	if ([sectionRoot isHidden])
		return nil;
	//	if ([sectionRoot.visibleItems count] == 0)
	//		return @"";
	return sectionRoot.footer ? sectionRoot.footer : @"";
//   CTSettingsItem *i=findSection(list,(int)section);
//   if(!i)return @"Error";
//   if(!i->iVisible || !countItemsInSection(list,(int)section))return @"";
//   NSString *f = i->sc.getFooter();
//   return f?f:@"";
}

/*
 - (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section;
 - (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section;
 */

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	//countItemsInSection
	if (!_sectionList)
		return 0;
    if (bIsChooser)
        return [_sectionList count];
	SCSettingsItem *sectionRoot = [_sectionList objectAtIndex:section];
	if ([sectionRoot isHidden])
		return 0;
	
	return 1;
//	return [sectionRoot.visibleItems count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *kCellIdentifierDefault = @"c1";
// TODO: support editable fields
//	static NSString *kCellIdentifierEditable = @"c1Editable";
	static NSString *kCellIdentifierSwitch = @"c1Switch";
// TODO: support reorder
//	static NSString *kCellIdentifierReorder = @"c1Reorder";

	if (!_sectionList)
		return nil;

    if (bIsChooser) {
        SettingsCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifierDefault];
        if (cell == nil)
            cell = [[SettingsCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kCellIdentifierDefault];
        return cell;
    }
    
    
    
	SCSettingsItem *setting = [_sectionList objectAtIndex:indexPath.section];
//	SCSettingsItem *setting = [[sectionRoot visibleItems] objectAtIndex:indexPath.row];
	
//	CTSettingsItem *i=findSItem(list,indexPath);
	//   myTableView=tableView;
	iTView_was_visible=1;
	
	//    NSLog(@"cell %p l=%p %@ tw=%@", i, list, indexPath, tableView);
	
	UITableViewCellStyle s = UITableViewCellStyleValue1;
	
	NSString *c=kCellIdentifierDefault;
	switch (setting.type) {
		case SettingType_Bool:
			c=kCellIdentifierSwitch;
			break;
		// TODO: support reorder
		// TODO: support editable fields
		default:
			break;
	}
/*
	switch(i->sc.iType){
		case CTSettingsCell::eReorder:
			c=kCellIdentifierReorder;
			break;
		case CTSettingsCell::eOnOff:
			c=kCellIdentifierSwitch;
			break;
		case CTSettingsCell::eSecure:
		case CTSettingsCell::eEditBox:
		case CTSettingsCell::eInt:
			c=kCellIdentifierEditable;
			break;
	}
*/
	SettingsCell *cell = [tableView dequeueReusableCellWithIdentifier:c];
	
	if (cell == nil)
	{
		cell = [[SettingsCell alloc] initWithStyle:s reuseIdentifier:c];// autorelease];
		if (setting.type == SettingType_Bool) {
			cell.uiSwitch=[[UISwitch alloc] initWithFrame:CGRectZero];
			cell.accessoryView = cell.uiSwitch;
			cell.uiSwitch.enabled = ![setting isDisabled];
//			[cell.uiSwitch release];
		}
/* TODO: implement editable fields
		else if(i->sc.iType==CTSettingsCell::eEditBox || i->sc.iType==CTSettingsCell::eInt || i->sc.iType==CTSettingsCell::eSecure){
			SettingsCell *xCell = cell;
			
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
 */
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (bIsChooser) {
        NSString *label = [_sectionList objectAtIndex:indexPath.row];
        if ( (_root) && ([[_root stringValue] isEqualToString:label]) )
            cell.accessoryType =UITableViewCellAccessoryCheckmark;
        else
            cell.accessoryType = UITableViewCellAccessoryNone;
        
        cell.detailTextLabel.text = @"";
        cell.textLabel.text = NSLocalizedString(label, nil);
        return;
    }
    
	SCSettingsItem *setting = [_sectionList objectAtIndex:indexPath.section];
//	SCSettingsItem *setting = [[sectionRoot visibleItems] objectAtIndex:indexPath.row];

	cell.detailTextLabel.text=nil;
	
	if ( (setting.items) && ( (setting.type == SettingType_Menu) || (setting.type == SettingType_Root) ) )
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

	// TODO: support radio items (checkmarks)
//	if(i->root && (i->sc.iType==CTSettingsCell::eNextLevel || i->sc.iType==CTSettingsCell::eChoose || i->sc.iType==CTSettingsCell::eCodec) ){
//		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
//	}
//	else if(i->sc.iType==CTSettingsCell::eRadioItem){
//		if(chooseItem && [chooseItem->sc.value isEqualToString :i->sc.getLabel()])
//			cell.accessoryType =UITableViewCellAccessoryCheckmark;
//		else
//			cell.accessoryType = UITableViewCellAccessoryNone;
//	}
	else
		cell.accessoryType = UITableViewCellAccessoryNone;
	
//	cell.showsReorderControl=YES;
	cell.selectionStyle= UITableViewCellSelectionStyleNone;

//	[cell setSI:i newTW:tableView];
	
	switch (setting.type) {
		case SettingType_Button:
			cell.selectionStyle= UITableViewCellSelectionStyleBlue;
			if ([setting isLink])
				cell.textLabel.textColor = [UIColor blueColor];
			break;
		case SettingType_Bool: {
			SettingsCell *settingsCell = (SettingsCell *)cell;
			settingsCell.uiSwitch.tag = indexPath.row+indexPath.section*100; // magic number
            BOOL bValue = [setting boolValue];
            if (setting.flags & SettingFlag_Inverse)
                bValue = !bValue;
			[settingsCell.uiSwitch setOn:bValue];
			[settingsCell.uiSwitch addTarget:self action:@selector(onOnOffChange:) forControlEvents:UIControlEventValueChanged];
			settingsCell.uiSwitch.enabled = ![setting isDisabled];
			break;
		}
		default:
			break;
			
// NYI:
//		case CTSettingsCell::eRadioItem:
//		case CTSettingsCell::eReorder:
//			break;
			
/* TODO: support editable cells
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
*/
	}
//	i->sc.tw  = tableView;
//	i->sc.pRet=cell;
	
	if ( ((setting.type == SettingType_Menu) || (setting.type == SettingType_Root))
            && ([setting.value isKindOfClass:[NSString class]]) ) {
        NSString *displayValue = [setting stringValue];
//        if ( (setting.items) && ([setting.items isKindOfClass:[NSDictionary class]]) )
//            displayValue = [(NSDictionary *)setting.items objectForKey:displayValue];
        
        cell.detailTextLabel.text = NSLocalizedString(displayValue, nil);
    } else
		cell.detailTextLabel.text = @"";
	
	cell.textLabel.text = setting.label ? NSLocalizedString(setting.label, nil) : @"Err";
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
	
    if (bIsChooser) {
        NSString *prevVal = [_root stringValue];
        _root.value = [_sectionList objectAtIndex:indexPath.row];
//        _root.value = [(NSDictionary *)_root.items objectForKey:valueKey];
        
        if (_root.callback)
            [_root performCallback];

        if ([prevVal isEqualToString:[_root stringValue]])
            return; // value didn't change

        [_root save];
        
//        chooseItem->sc.value =[i->sc.getLabel() copy];
//        int ret=0;
//        if(i->sc.onChange){
//            puts("onChange radio");
//            ret=i->callOnChange();
//        }
//        else if(chooseItem->sc.onChange){
//            puts("onChange Choose");
//            ret=chooseItem->callOnChange();
//        }
//        chooseItem->save(chooseItem->sc.pCfg);
        
        // chooseItem->setValue(i->sc.getLabel().UTF8String);
        
        int idx = 0;
        for (NSString *rowLabel in _sectionList) {
            if ([rowLabel isEqualToString:prevVal]) {
                SettingsCell *prevCell = (SettingsCell *)[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:indexPath.section]];
                prevCell.accessoryType = UITableViewCellAccessoryNone;
                break;
            }
            idx++;
        }
        
//        SettingsCell *cell=(SettingsCell *)chooseItem->sc.pRet;
//        [cell.detailTextLabel setText:i->sc.getLabel()];
        
        SettingsCell *c = [tableView cellForRowAtIndexPath:indexPath];//(SettingsCell*)i->sc.pRet;
        c.accessoryType = UITableViewCellAccessoryCheckmark;
        
        if ((_root.flags & SettingFlag_DontPopChooser) == 0)
            [[self navigationController] popViewControllerAnimated:YES];
//        if((ret & 4)==0) [[self navigationController] popViewControllerAnimated:YES];
//        if((ret & 2))[tableView reloadData];

        return;
    }
    
	SCSettingsItem *setting = [_sectionList objectAtIndex:indexPath.section];
//	SCSettingsItem *setting = [[sectionRoot visibleItems] objectAtIndex:indexPath.row];
	if (!setting)
		return;
	
    //DebugLogging: comparing key to check if "Send Debug Logs" is selected or not.
    //"Send Debug Logs" may not be able to be created as eButton and implement onClick() to launch
    //DebugLoggingViewController in SettingsManager class like "Terms Of Service" which is webview.
    //key: "iSendDebugLogs"
	if ([setting.key isEqualToString:@"iSendDebugLogs"]) {
        [self showDebugLoggingViewController];
        return;
    }
    
//   selectedCell=(SettingsCell*)i->sc.pRet;

	// TODO: REVISIT THIS
	if ( (setting.callback) && (setting.type != SettingType_Menu) && (setting.type != SettingType_Bool) ) {
		BOOL bReloadData = [setting performCallback];
//		[tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
		if (bReloadData)
			[tableView reloadData];
		return;
	}
	
//   printf("[i=%p type=%d]",i , i? i->sc.iType:-1);
	
	if (setting.items) {
		nextView=[[SettingsViewController alloc]initWithStyle:UITableViewStyleGrouped];
// EA: what is this pointer?
		nextView->prevTView=tableView;
//		nextView.chooseItem = i;
//		[nextView setItems:setting.items];
//		[nextView setLevelTitle:setting.label];
//		[nextView setEditing:[setting isEditable]];
        [nextView setRoot:setting];
		[[self navigationController] pushViewController:nextView animated:YES];
		return;
	}
	
	switch (setting.type) {
		case SettingType_Button:
			setting.value = @YES;
			break;
/*
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
				
				SettingsCell *cell=(SettingsCell *)chooseItem->sc.pRet;
				[cell.detailTextLabel setText:i->sc.getLabel()];
				
				SettingsCell *c=(SettingsCell*)i->sc.pRet;
				c.accessoryType = UITableViewCellAccessoryCheckmark;
				
				
				
				if((ret & 4)==0) [[self navigationController] popViewControllerAnimated:YES];
				if((ret & 2))[tableView reloadData];
				
				
			}
*/
		default:
			break;
	}
    
    if (setting.callback)
        [setting performCallback];
}

/* TODO: implement this
#pragma UITableView editing
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	SCSettingsItem *sectionRoot = [_sectionList objectAtIndex:indexPath.section];
	SCSettingsItem *setting = [[sectionRoot visibleItems] objectAtIndex:indexPath.row];
	if (!setting)
		return NO;
	
	return [setting canReorder];
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
*/

#pragma mark - Private

- (void)saveSettings {
    
    [SCPSettingsManager saveSettings];
    
    [self.navigationController popToRootViewControllerAnimated:YES];
}

-(IBAction)onOnOffChange:(id)v {
    UISwitch *sw = (UISwitch *)v;
    NSInteger section = sw.tag/100;
    //	NSInteger row = sw.tag % 100;
    
    SCSettingsItem *setting = [_sectionList objectAtIndex:section];
    //	SCSettingsItem *setting = [[sectionRoot visibleItems] objectAtIndex:row];
    
    if (!setting)
        return;
    
    BOOL bValue = [sw isOn];
    if (setting.flags & SettingFlag_Inverse)
        bValue = !bValue;
    setting.value = (bValue) ? @YES : @NO;

    /* 04.14.17 ET - comment calls to removed Rong Li code
    if ([setting.key isEqualToString:@"iEnableDebugLogging"]) {
        extern int debugLoggingEnabled(void);
        if (debugLoggingEnabled())
            [[SCPSettingsManager shared] startRepeatingLoggingTask];
        else
            [[SCPSettingsManager shared] stopRepeatingLoggingTask];
    }
    */
    
    if (setting.callback)
        [setting performCallback];
    
    [setting save];
}

/* THIS IS ALL FOR GEEK VIEW
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

- (IBAction)textFieldDidEndEditing:(UITextField *)textField
{
   [textField resignFirstResponder];
   activeTF=NULL;
	
	NSInteger section = textField.tag/100;
	NSInteger row = textField.tag % 100;
	SCSettingsItem *sectionRoot = [_sectionList objectAtIndex:section];
	SCSettingsItem *setting = [[sectionRoot visibleItems] objectAtIndex:row];
	
//   CTSettingsItem *i=findSItem (list, (int)textField.tag/100,textField.tag%100);
// EA: this is crazyness
   if(i && i->sc.pRet){
      SettingsCell *r=(SettingsCell*)i->sc.pRet;
      if(r->textField == textField){
         [i->sc.value release];
         
         i->sc.value=[[textField text]copy];
         i->testOnChange();
         //show save
      }
      else {NSLog(@"ch uitf");}
   }
 
	setting.value = textField.text;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string{
	NSString *nextString = [textField.text stringByReplacingCharactersInRange:range withString:string];
	
	if(nextString.length>60)return NO;
	
	NSInteger section = textField.tag/100;
	NSInteger row = textField.tag % 100;
	SCSettingsItem *sectionRoot = [_sectionList objectAtIndex:section];
	SCSettingsItem *setting = [[sectionRoot visibleItems] objectAtIndex:row];

	if ([setting isSecure])
		return YES;
	
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

- (void)configureCellE:(SettingsCell *)theCell atIndexPath:(NSIndexPath *)indexPath {
	
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

#pragma mark - Keyboard
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
*/

#pragma mark - Debugging
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

@end
