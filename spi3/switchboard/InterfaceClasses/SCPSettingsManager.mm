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
//
//  SCPSettingsManager.m
//  SPi3
//
//  Created by Eric Turner on 11/1/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//
#include <string.h>

#import "SCPSettingsManager.h"
#import "SCPSettingsManager+Advanced.h"

#import "ChatUtilities.h"
#import "CTListBase.h"
#import "Prov.h"
#import "ProviderDelegate.h"
#import "SCFileManager.h"
#import "SCPCallbackInterface.h"
#import "SCPTranslateDefs.h"
#import "SCPNotificationKeys.h"
#import "SCPNotificationKeys.h"
#import "SCSAudioManager.h"
#import "SCPPasscodeManager.h"
#import "SCSConstants.h"
#import "SCSFeatures.h"
#import "SettingsCell.h"
#import "UserService.h"


//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelError;
//#endif

static NSString *kSettingsVersionPref = @"SettingsVersion";
#define SETTINGS_VERSION    @"1.0"

//static CTList *sList = NULL;
void *pCurCfg=NULL;
void *pCurService=NULL;
static int iCfgOn = 0;

extern void *findGlobalCfgKey(const char *key);
extern const char *getTexttone(const char *p);

// forward declarations
static BOOL desktopModeClick(SCSettingsItem *setting);

BOOL onChangeGlob(SCSettingsItem *setting);
BOOL onChangeNist(SCSettingsItem *setting);
BOOL onChangeCallKit(SCSettingsItem *setting);

BOOL onChangeTexttone(SCSettingsItem *setting);
BOOL onChangeRingtone(SCSettingsItem *setting);
BOOL onClickWipeAllData(SCSettingsItem *setting);
BOOL onClickTermsOfService(SCSettingsItem *setting);
BOOL onClickPrivacyStatement(SCSettingsItem *setting);

// SettingsViewController+LockAlert
extern BOOL onSetPassLock(SCSettingsItem *setting);

@implementation SCPSettingsManager

+ (instancetype)shared
{
	static id instance;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [self new];
	});
	return instance;
}

- (NSArray *)allSections {
	if (!_allSections)
		[self _loadSettings];
	return _allSections;
}


+(void )setCfgLevel:(int)newLevel{
	iCfgOn = newLevel;
//	if(sList){
//		delete sList;
//		sList = NULL;
//	}
}

+ (int)getCfgLevel {
	return iCfgOn;
}

extern void t_save_glob();

- (void)save {
	for (SCSettingsItem *setting in _allSections)
		[setting save];
	
	t_save_glob();
    
    // reload all (some settings are depending on values of other settings)
    [self _loadSettings];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kSCSDidSaveConfigNotification object:self userInfo:nil];
}

+(void)saveSettings {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if(iCfgOn==2) { //user must not change un or pwd or serv
            [Switchboard doCmd:@":beforeCfgUpdate"];
            [Switchboard doCmd:@":waitOffline"];
            usleep(100*1000);
        }
        
		[[SCPSettingsManager shared] save];
        [Switchboard doCmd:@":afterCfgUpdate"];
    });
}

// call this method once at launch to make sure settings are up-to-date
+ (void)setup {
    uint32_t onVal = 1, onInvertedVal = 0;

#if DEBUG
    // debug settings are forced on every time
    setCfgValue((char *)&onVal, 4, pCurCfg, (char *)"iShowAxoErrorMessages", strlen("iShowAxoErrorMessages"));
#endif

    NSString *version = [[NSUserDefaults standardUserDefaults] objectForKey:kSettingsVersionPref];
    if (!version) {
        // Issue #136 - force deprecated settings
        setCfgValue((char *)&onInvertedVal, 4, pCurCfg, (char *)"iPreferNIST", strlen("iPreferNIST"));
        setCfgValue((char *)&onInvertedVal, 4, pCurCfg, (char *)"iDisable256SAS", strlen("iDisable256SAS"));
        setCfgValue((char *)&onVal, 4, pCurCfg, (char *)"iAudioUnderflow", strlen("iAudioUnderflow"));
        setCfgValue((char *)&onVal, 4, pCurCfg, (char *)"iShowRXLed", strlen("iShowRXLed"));
        setCfgValue((char *)&onVal, 4, pCurCfg, (char *)"iEnableFWTraversal", strlen("iEnableFWTraversal"));
        t_save_glob(); // note: this won't do anything if nothing has changed
        
        // record that we did this
        [[NSUserDefaults standardUserDefaults] setObject:SETTINGS_VERSION forKey:kSettingsVersionPref];
    }
    return;
}

extern void *findCfgItemByServiceKey(void *ph, char *key, int &iSize, char **opt, int *type); // Tivi

SCSettingsItem *SETTING_ITEM(NSString *key, NSString *label, SettingType type, NSObject *defaultVal, SettingFlags flags, NSString *footer, SettingChangeCallback changeCallback, NSString *header) {
	// note: default value can be confusing/opposite when using SettingFlag_Inverse
	// temporarily using a dictionary
	SCSettingsItem *setting = [SCSettingsItem new];
	setting.key = key;
	setting.label = label ? NSLocalizedString(label, nil) : nil;
	setting.type = type;
	setting.defaultVal = defaultVal;
	setting.flags = flags;
	setting.footer = footer ? NSLocalizedString(footer, nil) : nil;
	setting.callback = changeCallback;
	setting.header = header ? NSLocalizedString(header, nil) : nil;
	
	// give the setting it's initial value
	char *opt = NULL;
    int iType, iSize;
	char *tiviDefault = (char *)findCfgItemByServiceKey(pCurService, (char *)[key cStringUsingEncoding:NSUTF8StringEncoding], iSize, &opt, &iType);
    if (type == SettingType_Bool) {
        BOOL bDefault = [(NSNumber *)defaultVal boolValue];
        if (tiviDefault)
            bDefault = (*(uint32_t *)tiviDefault > 0); // tiviDefault is an int (4-bytes)
        else if (flags & SettingFlag_Inverse)
            bDefault = !bDefault;
        setting.value = [NSNumber numberWithBool:bDefault];
    } else {
        if ( (tiviDefault) && (tiviDefault[0]) )
            setting.value = [[NSString alloc] initWithUTF8String:(const char *)tiviDefault];
        else
            setting.value = defaultVal;
    }
    
	setting.pCfg = pCurCfg;
	return setting;
}

SCSettingsItem *SETTING_TEXT(NSString *key, NSString *label) {
    return SETTING_ITEM(key, label, SettingType_Text);
}

- (void)_loadSettings {
    _allSections = nil;
    _sectionMap = nil;
    _settingsMap = nil;
    
	if (iCfgOn == 2)
        [self initAdvancedSettings]; // in SCPSettingsManager+Advanced
	
//	[self addSection:@"Security" withSettings:[SCPSettingsManager securitySettings]];
	[self addSection:@"Passcode" withSettings:[SCPSettingsManager passcodeSettings]];
	[self addSection:@"User Interface" withSettings:[SCPSettingsManager userInterfaceSettings]];
	[self addSection:@"Notifications" withSettings:[SCPSettingsManager notificationSettings]];
	[self addSection:@"Sounds" withSettings:[SCPSettingsManager ringtoneSettings]];
// removed per Issue #136
//	[self addSection:@"Firewall traversal" withSettings:[SCPSettingsManager firewallSettings]];
}

- (void)addSection:(NSString *)sectionName withSettings:(NSArray *)settingsList {
	SCSettingsItem *sectionRoot = [SCSettingsItem new];
	sectionRoot.key = sectionName;
	sectionRoot.label = NSLocalizedString(sectionName, nil);
	sectionRoot.type = SettingType_Root;
	sectionRoot.items = settingsList;
	
	if (!_allSections)
		_allSections = [[NSMutableArray alloc] initWithObjects:sectionRoot, nil];
	else
		[_allSections addObject:sectionRoot];
	
	if (!_sectionMap)
		_sectionMap = [[NSMutableDictionary alloc] initWithCapacity:10];
	[_sectionMap setObject:settingsList forKey:sectionName];
	
	if (!_settingsMap)
		_settingsMap = [[NSMutableDictionary alloc] initWithCapacity:[settingsList count]];
	
	for (SCSettingsItem *setting in settingsList) {
		if (!setting.key)
			continue;
		[_settingsMap setObject:setting forKey:setting.key];
	}
}

- (SCSettingsItem *)settingForKey:(NSString *)key {
	if (!_settingsMap)
		[self _loadSettings];
	return[_settingsMap objectForKey:key];
}

- (NSObject *)valueForKey:(NSString *)key {
    SCSettingsItem *setting = [self settingForKey:key];
    if (!setting)
        return nil;
    if (!setting.value)
        return setting.defaultVal;
    
    return setting.value;
}

#pragma mark - Settings Rewritten
/*
+ (NSArray *)securitySettings {
	NSMutableArray *securitySettings = [NSMutableArray arrayWithArray:@[
			SETTING_ITEM(@"iPreferNIST", @"Prefer Non-NIST Suite", SettingType_Bool, @YES, SettingFlag_Inverse, @"Always prefer non-NIST algorithms if available: Twofish, Skein, and Bernstein curves.", onChangeNist)
			,SETTING_ITEM(@"iDisable256SAS", @"SAS word list", SettingType_Bool, @YES, SettingFlag_Inverse, @"Authentication code is displayed as special words instead of letters and numbers.")
			,SETTING_ITEM(@"*wipe", @"Wipe Silent Phone", SettingType_Button, nil, SettingFlag_IsLink, @"Clear application data and log out.", onClickWipeAllData)
																		]];
	if([ChatUtilities utilitiesInstance].isLockEnabled) {
		NSString *defaultVal = [[NSUserDefaults standardUserDefaults] valueForKey:@"lockKey"];
		[securitySettings addObject:SETTING_ITEM(@"setPassLock", @"Set Password lock", SettingType_Bool, defaultVal ? @YES : @NO, 0, @"Lock Chat and Recents tabs with password", onSetPassLock)];
	}
	if(iCfgOn==1) {
		// add this one to the top of the list
		//		pCurService = [Switchboard accountAtIndex:0 isActive:YES];
		//		pCurCfg = getAccountCfg(pCurService);//pCurCfg must be valid before using addItemByKey (non global)
		[securitySettings insertObject:SETTING_ITEM(@"iCanUseP2Pmedia", @"Use media relay", SettingType_Bool, @NO, SettingFlag_Inverse, @"Always use media relay server, to conceal remote party's location. Adds latency.", onChangeGlob) atIndex:0];
		//		pCurCfg=NULL;pCurService=NULL;
	}
	return securitySettings;
}
*/

// NOTE: these are in SettingsViewController+Passcode
extern BOOL passcodeChanged(SCSettingsItem *setting);
extern BOOL passcodeWipeChanged(SCSettingsItem *setting);
extern BOOL passcodeEdited(SCSettingsItem *setting);

+ (NSArray *)passcodeSettings {
	SCPPasscodeManager *passcodeManager = [SCPPasscodeManager sharedManager];
	BOOL touchIDsupported = [passcodeManager supportsTouchID];
	BOOL passcodeExists = [passcodeManager doesPasscodeExist];
	
	NSMutableArray *passcodeSettings = [NSMutableArray arrayWithArray:@[
			SETTING_ITEM(@"iUsePasscode", passcodeExists ? @"Turn Passcode Off" : @"Turn Passcode On", SettingType_Button, @NO, 0, @"When enabled, lock Silent Phone UI after your phone locks or you leave the app.", passcodeChanged)
			,SETTING_ITEM(@"iChangePasscode", @"Change Passcode", SettingType_Button, @YES, passcodeExists ? 0 : SettingFlag_Hidden, nil, passcodeEdited)
																		]];
	
	if(touchIDsupported)
		[passcodeSettings addObject:SETTING_ITEM(@"iPasscodeEnableTouchID", @"Touch ID", SettingType_Bool, @NO, passcodeExists ? 0 : SettingFlag_Hidden, @"Touch ID will be required every time the app launches or becomes active.")];
	
	SCSettingsItem *timeoutSetting = SETTING_ITEM(@"szPasscodeTimeout", @"Require Passcode", SettingType_Menu, @"1 minute", passcodeExists ? 0 : SettingFlag_Hidden);
	timeoutSetting.items = @[@"Immediately", @"10 seconds", @"30 seconds", @"1 minute", @"2 minutes", @"5 minutes", @"15 minutes", @"30 minutes"];
	[passcodeSettings addObjectsFromArray:@[
			timeoutSetting
			,SETTING_ITEM(@"iPasscodeEnableWipe", @"Wipe Data", SettingType_Bool, @NO, passcodeExists ? 0 : SettingFlag_Hidden, [NSString stringWithFormat:NSLocalizedString(@"Wipe all data on Silent Phone after %d failed passcode attempts.", nil), SCP_PASSCODE_MAX_WIPE_ATTEMPTS], passcodeWipeChanged)
											]];
	
	return passcodeSettings;
}

+ (NSArray *)userInterfaceSettings {
	NSMutableArray *uiSettings = [NSMutableArray arrayWithCapacity:20];
	[uiSettings addObject:SETTING_ITEM(@"iKeepScreenOnIfBatOk", @"Desktop phone mode", SettingType_Bool, @NO, 0, @"Disables sleep while connected to external power and running in foreground.", desktopModeClick)]; //keep screen on while charging and battery > 50%
	
	extern int canEnableDialHelper(void);
	if(canEnableDialHelper()) {
		[uiSettings addObject:SETTING_ITEM(@"iEnableDialHelper", @"Enable Dialing Helper", SettingType_Bool, @YES)];

        // lookup default
#ifdef __APPLE__
        extern const char *getSystemCountryCode(void);
        const char *lang = getSystemCountryCode();
#else
        extern const char *getPrefLang(void);
        const char *lang = getPrefLang();
#endif
        extern const char *getCountryByID(const char *);
        const char *defaultCountry = getCountryByID(lang);
        if ( (!defaultCountry) || (!defaultCountry[0]) )
            defaultCountry = "USA";
        
        SCSettingsItem *countrySetting = SETTING_ITEM(@"szDialingPrefCountry", @"Dialing preference", SettingType_Menu, [NSString stringWithCString:defaultCountry encoding:NSUTF8StringEncoding]);
        
        extern const char *getDialingPrefCountryList();
        const char *c_countryCSV = getDialingPrefCountryList();
        NSString *countryCSV = [NSString stringWithCString:c_countryCSV encoding:NSUTF8StringEncoding];
        countrySetting.items = [countryCSV componentsSeparatedByString:@","];
        
        [uiSettings addObject:countrySetting];
	}
	
// removed per Issue #136
//	[uiSettings addObject:SETTING_ITEM(@"iAudioUnderflow", @"Dropout tone", SettingType_Bool, @YES, 0, @"Plays low tone if no media packets are arriving. If heard often, you or your partner may want to change networks.")];
//	[uiSettings addObject:SETTING_ITEM(@"iShowRXLed", @"Show RX LED", SettingType_Bool, @YES, 0, @"Traffic indicator light for incoming media packets.")];
	
	if(iCfgOn>=1)
		[uiSettings addObject:SETTING_ITEM(@"iEnableAirplay", @"Airplay During Calls", SettingType_Bool, @NO, 0, @"Allow Airplay during Call Screen. Recommended for demos only.")];
	
	
	[uiSettings addObject:SETTING_ITEM(@"iShowAxoErrorMessages", @"Show all errors", SettingType_Bool, @NO, 0, @"Minor software errors that don't affect your experience are hidden by default")];
	
	if(iCfgOn>=1)
		[uiSettings addObject:SETTING_ITEM(@"iDontSendDeliveryNotifications", @"Send Delivery Notifications", SettingType_Bool, @NO, SettingFlag_Inverse, @"For Testing Only")];
	
	if ([ProviderDelegate isSupported])
		[uiSettings addObject:SETTING_ITEM(@"iDisableCallKit", @"Native Call Screen support", SettingType_Bool, @YES, SettingFlag_Inverse | SettingFlag_ChangeReloadsAll, @"Provides a better call integration with your phone. You can disable it if you want to hide your call history from the native Phone app.", onChangeCallKit)];
	
	return uiSettings;
}

+ (NSArray *)notificationSettings {
	SCSettingsItem *displayStyleSetting = SETTING_ITEM(@"szMessageNotifcations", @"Display Style", SettingType_Menu, @"Notification only");
	displayStyleSetting.items = @[@"Notification only", @"Sender only", @"Message and Sender"];
	NSArray *notifSettings = @[
		   SETTING_ITEM(@"iShowMessageNotifications", @"Background Notifications", SettingType_Bool, @YES)
		   , displayStyleSetting
							   ];
	return notifSettings;
}

static NSDictionary *_kRingtoneOptions = @{@"Default": @"ring"
                                          ,@"Retro": @"ring_retro"
                                          ,@"On Site": @"cisco"
                                          ,@"Take a Memo": @"trimline"
                                          ,@"The Victorian": @"european_major_third"
                                          ,@"Touch Base": @"v120"
                                          ,@"Bright Idea": @"piano_arpeg"
                                          ,@"Coronation": @"fanfare"
                                          ,@"Delta": @"jazz_sax_in_the_subway"
                                          ,@"Intuition": @"dance_synth"
                                          ,@"Seafarer's Call": @"foghorn"
                                          ,@"Titania": @"flute_with_echo"
                                          ,@"Two Way Street": @"oboe"
                                          ,@"WhisperZ": @"piccolo_flutter"
                                          ,@"Whole In Time": @"whole_in_time"
                                          };


+ (NSArray *)ringtoneSettings {
	NSDictionary *textToneOptions = @{@"Default": @"default"
								  ,@"Aurora": @"sms_alert_aurora"
								  ,@"Bamboo": @"sms_alert_bamboo"
								  ,@"Circles": @"sms_alert_circles"
								  ,@"Complete": @"sms_alert_complete"
								  ,@"Hello": @"sms_alert_hello"
								  ,@"Input": @"sms_alert_input"
								  ,@"Keys": @"sms_alert_keys"
								  ,@"Note": @"sms_alert_note"
								  ,@"Popcorn": @"sms_alert_popcorn"
								  ,@"Synth": @"sms_alert_synth"
                                  };
    
    SCSettingsItem *settingTextTone = SETTING_ITEM(@"szTextTone", @"Text Tone", SettingType_Menu, @"default", SettingFlag_DontPopChooser, nil, onChangeTexttone);
    settingTextTone.items = textToneOptions;
    
    SCSettingsItem *settingRingTone = SETTING_ITEM(@"szRingTone", @"Ringtone", SettingType_Menu, @"ring", SettingFlag_DontPopChooser, nil, onChangeRingtone);
    settingRingTone.items = _kRingtoneOptions;
		  
    NSArray *ringtoneSettings = @[settingTextTone, settingRingTone];
    
    // if call kit is enabled, provide the option to use native ringtone
	if ([ProviderDelegate isEnabled])
		ringtoneSettings = [ringtoneSettings arrayByAddingObject:SETTING_ITEM(@"iEnableNativeRingtone", @"Enable Native Ringtone", SettingType_Bool, @NO, 0, @"If enabled, incoming calls will use the native user selected ringtone (Sounds > Ringtone) rather than the selected ringtone from above.\n\nEmergency calls will still use the Silent Phone emergency tone.")];
	
	return ringtoneSettings;
}

+ (NSString *)getRingtone:(NSString *)displayName {
    if (!displayName) {
        SCSettingsItem *setting = [[SCPSettingsManager shared] settingForKey:@"szRingTone"];
        displayName = [setting stringValue];
    }
    return [_kRingtoneOptions objectForKey:displayName];
}

+ (NSArray *)firewallSettings {
	NSMutableArray *fwSettings = [NSMutableArray arrayWithCapacity:2];
	
	if (iCfgOn==2)
		[fwSettings addObject:SETTING_ITEM(@"iForceFWTraversal", @"Force FW Traversal", SettingType_Bool, @NO, 0, @"Will use only TCP for RTP media. Not recomended to use in production.")];
	
	[fwSettings addObject:SETTING_ITEM(@"iEnableFWTraversal", @"Enable FW Traversal", SettingType_Bool, @YES, 0, @"Will enable TCP for RTP media")];
	
	return fwSettings;
}

@end


static BOOL desktopModeClick(SCSettingsItem *setting) { // (void *pSelf, void *pRetCB){
    [[NSNotificationCenter defaultCenter] postNotificationName:kSCSDidSaveConfigNotification object:[SCPSettingsManager shared]];
    return NO;
}

BOOL onChangeNist(SCSettingsItem *setting) { //(void *pSelf, void *pRetCB){
    
    //    CTSettingsItem *it=(CTSettingsItem*)pSelf;
    //    if(!it)return -1;
    //    CTSettingsItem *x;
    
    //    const char *p=it->getValue();
    //    if(!p)return 0;
    //    if(p[0]=='0')return 0;
    
    if ( (!setting.value) || (![setting.value isKindOfClass:[NSString class]]) )
        return NO;
    
    const char *p = [(NSString *)setting.value cStringUsingEncoding:NSUTF8StringEncoding];
    if (p[0] == '0')
        return NO;
    
    NSArray *options = @[@"iDisableTwofish",@"iDisableSkein",@"iDisableSkeinHash",@"iDisableBernsteinCurve25519",@"iDisableBernsteinCurve3617"
                         ,@"iEnableSHA384",@"iDisableAES256"];//enable384hash and enable256keysize
    
    for (NSString *option in options) {
        SCSettingsItem *optionSetting = [setting findItem:option];
        optionSetting.value = @YES; // these are reversed
        
        const char *str = [option cStringUsingEncoding:NSUTF8StringEncoding];
        int *v = (int *)findGlobalCfgKey(str);
        if (v)
            *v = (strcmp(str, "iEnableSHA384") == 0);
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
    
    return YES;
}

BOOL onChangeCallKit(SCSettingsItem *setting) {//void *pSelf, void *pRetCB){(void *pSelf, void *pRetCB) {
    // EA: this method isn't actually doing anything!
    BOOL allowCallKit = [setting boolValue];
    
    //    CTSettingsItem *it=(CTSettingsItem*)pSelf;
    //
    //    if (!it)
    //        return -1;
    //
    //    const char *p=it->getValue();
    //
    //    if (!p)
    //        return 0;
    //
    //    BOOL allowCallKit = (p[0] == '1');
    
    NSLog(@"%s %d", __PRETTY_FUNCTION__, allowCallKit);
    
    return YES;// 2;
}

/*
//Not local ////////////////////////////////////////////////////////////

void* getAccountCfg(void *eng);
const char *getAccountTitle(void *pS);
void *findGlobalCfgKey(const char *key);
//const char * getRingtone(const char *p);

// From Release.cpp
//int canAddAccounts(){return 1;}
int canAddAccounts();

////////////////////////////////////////////////////////////////////////

static const int translateType[]={CTSettingsCell::eUnknown,CTSettingsCell::eOnOff,CTSettingsCell::eEditBox,CTSettingsCell::eInt,CTSettingsCell::eInt, CTSettingsCell::eSecure,CTSettingsCell::eUnknown};
static const int translateTypeInt[]={-1,1,0,1,1,0,-1,-1};



static void loadAccountSection(CTList *l);
CTList * addSection(CTList *l, NSString *hdr, NSString *footer, const char *key=NULL);
CTList * addNewLevel(CTList *l, NSString *lev, int iIsCodec=0);
CTList * addNewLevelP(CTList *l, NSString *lev, int iIsCodec=0);
void addChooseKey(CTList *l, const char *key, NSString *label);
void addReorderKey(CTList *l, const char *key, NSString *label);
CTSettingsItem* addItemByKey(CTList *l, const char *key, NSString *label);
CTSettingsItem* addItemByKeyF(CTList *l, const char *key, NSString *label);
//static void addSecSettings(CTList *pref);
CTList * addSectionP(CTList *l, NSString *hdr, NSString *footer, const char *key=NULL);
//static void addZRTPSettings(CTList *pref);
void addCodecKey(CTList *l, const char *key, NSString *hdr, NSString *footer);
//static void addUserInterfaceSettings(CTList *pref);
//static void addPasscodeSettings(CTList *pref);
//static void addNotificationSettings(CTList *pref);
//static void addRingtoneSettings(CTList *pref);
//static void addFWSettings(CTList *pref);


CTList *addAcount(CTList *l, const char *name, int iDel);

void setValueByKey(CTSettingsItem *i, const char *key, NSString *label);

int onDeleteAccount(void *pSelf, void *pRetCB);
int onChangeSHA384(void *pSelf, void *pRetCB);
int onChangeAES256(void *pSelf, void *pRetCB);

#if HAS_DATA_RETENTION
int onChangeLocalDR(void *pSelf, void *pRetCB);
int onChangeRemoteDR(void *pSelf, void *pRetCB);
#endif // HAS_DATA_RETENTION
//int onChangeCallKit(void *pSelf, void *pRetCB);
int onChange386(void *pSelf, void *pRetCB);
int onChangePref2K(void *pSelf, void *pRetCB);
int onChangeDis2K(void *pSelf, void *pRetCB);

int switchOfTunneling(void *pSelf, void *pRetCB);
int switchOnSDES_ZRTP(void *pSelf, void *pRetCB);

void loadSettings(CTList *l){
    
    CTList *n;
    
    if(iCfgOn!=2){
//         CTSettingsItem *it;
//         pCurService = getAccountByID(0,1);//pCurService must be valid before using addItemByKey
//         pCurCfg = getAccountCfg(pCurService);//pCurCfg must be valid before using addItemByKey
//         n=addSection(l,@" ",NULL);
//         it=addItemByKey(n,"nick",@"Display name");
//         if(it)it->sc.onChange=onChangeGlob;//change setting for all accounts
//         pCurService=0;pCurCfg=0;
    }
    else{
        loadAccountSection(l);
    }
    
    
    if(iCfgOn==2){
        n=addSection(l,NULL,NULL);
        CTList *pref=addNewLevel(n,NSLocalizedString(@"Preferences",nil));
        
        addZRTPSettings(pref);
        addUserInterfaceSettings(pref);
		addNotificationSettings(pref);
        addRingtoneSettings(pref);
        addFWSettings(l);
    }
    else{
        addSecSettings(l);
        addPasscodeSettings(l);
        addUserInterfaceSettings(l);
		addNotificationSettings(l);
        addRingtoneSettings(l);
        addFWSettings(l);
    }
    addAboutSection(l);
}

static void loadAccountSection(CTList *l){
    CTList *as=addSection(l,@" ",@"");
    CTList *ac=addNewLevel(as,@"Accounts");
    CTList *n=addSection(ac,@"Enabled",@"");
    
    int cnt=0;
    
    for(int i=0;i<20;i++){
//                pCurService=getAccountByID(cnt,1);
        pCurService = [Switchboard accountAtIndex:cnt isActive:YES];
        if(pCurService){
            cnt++;
            pCurCfg=getAccountCfg(pCurService);
            const char *title = [[Switchboard titleForAccount:pCurService] UTF8String];
//            addAcount(n,getAccountTitle(pCurService),1);
            addAcount(n,title,1);
        }
    }
    
    cnt=0;
    for(int i=0;i<20;i++){
//        pCurService=getAccountByID(cnt,0);
        pCurService=[Switchboard accountAtIndex:cnt isActive:NO];
        
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
    
    
    if(canAddAccounts()){
        n=addSection(ac,NULL,NULL);
        
        int createNewAccount(void *pSelf, void *pRet);
//        void *getEmptyAccount();
//        pCurService=getEmptyAccount();
        pCurService = [Switchboard emptyAccount];
        
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

CTList * addSection(CTList *l, NSString *hdr, NSString *footer, const char *key){
    if(!l)return NULL;
    CTSettingsItem *i = new CTSettingsItem(l);
    l->addToTail(i);
    CTList *nl = i->initSection(hdr,footer);
    
    if(key){
        strcpy(i->sc.key,key);
        i->sc.iKeyLen=(uint32_t)strlen(key);
    }
    i->sc.pCfg=pCurCfg;
    i->sc.pEng=pCurService;
    nl->pUserStorage=l;
    // i->parent=
    return nl;
}

CTList * addNewLevel(CTList *l, NSString *lev, int iIsCodec){
    if(!l)return NULL;
    CTSettingsItem *i=new CTSettingsItem(l);
    l->addToTail(i);
    l=i->initNext(lev);
    if(iIsCodec)i->sc.iType=CTSettingsCell::eCodec;
    i->sc.pCfg=pCurCfg;
    i->sc.pEng=pCurService;
    return l;
}

CTList * addNewLevelP(CTList *l, NSString *lev, int iIsCodec){
    // if(!iCfgOn || !l)return NULL;
    return addNewLevel(l ,lev, iIsCodec);
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

CTSettingsItem* addItemByKey(CTList *l, const char *key, NSString *label){
    if(!l)return NULL;
    CTSettingsItem *i=new CTSettingsItem(l);
    l->addToTail(i);
    i->section = (CTList*)l->pUserStorage;
    setValueByKey(i,key,label);
    return i;
}

static CTSettingsItem* addItemByKeyF(CTList *l, const char *key, NSString *label, NSString *footer){
    
    CTList *n=addSection(l,NULL,footer);
    CTSettingsItem *i=addItemByKey(n,key,label);
    
    return i;
}

CTSettingsItem* addItemByKeyP(CTList *l, const char *key, NSString *label){
    // if(!iCfgOn || !l)return NULL;
    return addItemByKey(l, key, label);
}
CTList * addSectionP(CTList *l, NSString *hdr, NSString *footer, const char *key){
    //  if(!iCfgOn || !l)return NULL;
    return addSection(l, hdr, footer, key);
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
*/

#if 0 // not currently supported -- under development -- moving to Advanced category
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
    i=addItemByKey(s,"iDoNotRandomizePort",@"Randomize RTP Port");if(i)i->sc.iInverseOnOff=1;
   
    
    
    
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

void setValueByKey(CTSettingsItem *i, const char *key, NSString *label){
    
    CTSettingsCell *sc=&i->sc;
    char *opt=NULL;
    int iType;
    int iSize;
    
    {
        char bufTmp[64];
        int iKeyLen=(uint32_t)strlen(key);
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
                    l = addSection(i->root,NSLocalizedString(@"Choose", nil),NULL);
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
            
//            if(sc->value)[sc->value release];
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

int onDeleteAccount(void *pSelf, void *pRetCB){
    CTSettingsItem *it=(CTSettingsItem*)pSelf;
    if(!it || !it->sc.pEng)return -1;
    
//    sendEngMsg(it->sc.pEng,"delete");
    [Switchboard sendEngMsg:it->sc.pEng msg:@"delete"];
    
    return 0;
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

#if HAS_DATA_RETENTION
int onChangeLocalDR(void *pSelf, void *pRetCB) {
    CTSettingsItem *it=(CTSettingsItem*)pSelf;
    if (!it)
        return -1;
    
    const char *p=it->getValue();
    if (!p)
        return 0;

    // turn on or off data retention as appropriate
    BOOL bBlockDR = (p[0]=='1');
    [Switchboard configureDataRetention:bBlockDR blockRemote:[UserService currentUserBlocksRemoteDR]];
    
    if ( (bBlockDR) && ([UserService currentUser].drEnabled) ) {
        // user is normally subject to DR, provide warning but is blocking
        UIAlertController *alertC = [UIAlertController
                                      alertControllerWithTitle:NSLocalizedString(@"Information", nil)
                                      message:NSLocalizedString(@"Your organization has a policy of retaining data about your communication, however you have blocked Silent Phone from retaining this data. Communication is now prohibited.  To restore communication either unset \"Block data retention\" in Silent Phone settings or ask your organization's administrator to remove your data retention policy.", nil)
                                      preferredStyle:UIAlertControllerStyleAlert];        
        UIAlertAction *ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleCancel handler:nil];
        [alertC addAction:ok];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[[UIApplication sharedApplication] topMostViewController] presentViewController:alertC animated:YES completion:nil];
        });
    }
    return 2;
}

int onChangeRemoteDR(void *pSelf, void *pRetCB) {
    CTSettingsItem *it=(CTSettingsItem*)pSelf;
    if (!it)
        return -1;
    
    const char *p=it->getValue();
    if (!p)
        return 0;
    
    // turn on or off data retention as appropriate
    BOOL bBlockDR = (p[0]=='1');
    [Switchboard configureDataRetention:[UserService currentUserBlocksLocalDR] blockRemote:bBlockDR];
    return 2;
}
#endif // HAS_DATA_RETENTION

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
#endif

/* not used
BOOL onChangeGlob(SCSettingsItem *setting) {
	if ( (!setting.value) || (![setting.value isKindOfClass:[NSString class]]) )
		return NO;
	const char *p = [(NSString *)setting.value cStringUsingEncoding:NSUTF8StringEncoding];
	
//    int v=0;
//    int iSize=0;
//    p = it->tryConvertStrIntPTR(p, iSize, &v);
    //tryConvertStrIntPTR
	
	const char *key = [setting.key cStringUsingEncoding:NSUTF8StringEncoding];
	if ( (!key) || (!key[0]) )
		return NO;
	
	int keyLen = (int)strlen(key);
	int iSize = 4; // BOOL
	
    for (int i=0;i<20;i++){
        void *a = [Switchboard accountAtIndex:i isActive:YES];
        if(!a)
			continue;
		
		// EA: yikes!! get rid of this here
        void *c=getAccountCfg(a);
        setCfgValue((char *)p, iSize, c, (char *)key, keyLen);
    }
    
    return NO;
}
*/

BOOL onChangeTexttone(SCSettingsItem *setting) {//void *pSelf, void *pRetCB){
	if ( (!setting.value) || (![setting.value isKindOfClass:[NSString class]]) )
		return NO;
	
	const char *p = [(NSString *)setting.value cStringUsingEncoding:NSUTF8StringEncoding];
    const char *textTone = getTexttone(p);
    
    if(!textTone)
        return 0;
    
    if(strcmp(textTone, "default") == 0)
        [SPAudioManager playSound:@"received"
                           ofType:@"wav"
                          vibrate:NO];
    else
        [SPAudioManager playSound:[NSString stringWithCString:textTone
						 encoding:NSUTF8StringEncoding]
						   ofType:@"caf"
                          vibrate:NO];
	return YES;
//    return 4|2;
}

BOOL onChangeRingtone(SCSettingsItem *setting) {//void *pSelf, void *pRetCB){
	if ( (!setting.value) || (![setting.value isKindOfClass:[NSString class]]) )
		return NO;
    
    NSString *ringToneFileName = [SCPSettingsManager getRingtone:[setting stringValue]];
    [SPAudioManager playTestRingtone:ringToneFileName];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRingtoneDidChangeNotification
                                                            object:[SCPSettingsManager shared]];
    });
	
	return YES;
//    return 4|2;
}

/* moved to SCSContainerController
BOOL onClickWipeAllData(SCSettingsItem *setting) {//void *pSelf, void *pRetCB){
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSCPWipeAllDataNotification
                                                        object:[SCPSettingsManager shared]];

    return NO;
}
*/

BOOL onClickTermsOfService(SCSettingsItem *setting) {//void *pSelf, void *pRetCB){
    // http://accounts.silentcircle.com/terms #SP-580
    [[UIApplication sharedApplication] openURL:[ChatUtilities buildWebURLForPath:kTermsURLPath]];
    
    return NO;
}

BOOL onClickPrivacyStatement(SCSettingsItem *setting) {//void *pSelf, void *pRetCB){
    //https://silentcircle.com/privacy #SP-582
    [[UIApplication sharedApplication] openURL:[ChatUtilities buildWebURLForPath:kPrivacyURLPath]];
    return NO;
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

@implementation SCSettingsItem
- (NSObject *)value {
	return (_value) ? _value : _defaultVal;
}

- (BOOL)boolValue {
	// TODO: do we consider Inverse here?
	if (!_value)
		return NO;
	if ([_value isKindOfClass:[NSNumber class]])
		return [(NSNumber *)_value boolValue];
	if ([_value isKindOfClass:[NSString class]])
		return ![(NSString *)_value isEqualToString:@"0"];
	return NO; // don't know what this is!
}

- (NSString *)stringValue {
    if (![_value isKindOfClass:[NSString class]])
        return nil;
    return (NSString *)_value;
}

- (const char *)cStringValue:(uint32_t *)sizeP {
	if ([_value isKindOfClass:[NSNumber class]]) {
		BOOL bValue = [(NSNumber *)_value boolValue];
		NSString *s = (bValue) ? @"1" : @"0";
        if (sizeP)
            *sizeP = 4;
		return [s cStringUsingEncoding:NSUTF8StringEncoding];
	}
	if ([_value isKindOfClass:[NSString class]]) {
		const char *p = [(NSString *)_value cStringUsingEncoding:NSUTF8StringEncoding];
        if (sizeP)
            *sizeP = (uint32_t)strlen(p);
		return p;
	}
	return nil;
}

- (NSArray *)visibleItems {
    if (![_items isKindOfClass:[NSArray class]])
        return nil;
    
	NSMutableArray *resultList = [NSMutableArray arrayWithCapacity:[(NSArray *)_items count]];
	for (SCSettingsItem *setting in (NSArray *)_items)
		if (![setting isHidden])
			[resultList addObject:setting];
	return resultList;
}

- (SCSettingsItem *)findItem:(NSString *)key {
    if ( (!_items) || (![_items isKindOfClass:[NSArray class]]) )
        return nil;
    NSArray *items = (NSArray *)_items;
    if ([items count] == 0)
		return nil;
	for (SCSettingsItem *item in items)
		if ([key isEqualToString:item.key])
			return item;
	return nil;
}

- (BOOL)isDisabled {
	return ((self.flags & SettingFlag_Disabled) != 0);
}

- (BOOL)isEditable {
	return ((self.flags & SettingFlag_Editable) != 0);
}

- (BOOL)isHidden {
	return ((self.flags & SettingFlag_Hidden) != 0);
}

- (void)setHidden:(BOOL)bHidden {
	if (bHidden)
		self.flags |= SettingFlag_Hidden;
	else
		self.flags = self.flags & ~SettingFlag_Hidden;
}

- (BOOL)isLink {
	return ((self.flags & SettingFlag_IsLink) != 0);
}

//- (BOOL)isPasslock {
//	return ((self.flags & SettingFlag_PassLock) != 0);
//}

- (BOOL)canReorder {
	return ((self.flags & SettingFlag_Reorder) != 0);
}

- (BOOL)isSecure {
	return ((self.flags & SettingFlag_Secure) != 0);
}

- (BOOL)performCallback {
	if (!_callback)
		return -1;
	
	return (*_callback)(self);
}

extern int setCfgValue(char *pSet, int iSize, void *pCfg, char *key, int iKeyLen);
extern void t_save_glob();

- (void)save {
	if ([_key hasPrefix:@"*"])
		return;
	
/* TODO: I DON'T UNDERSTAND THIS, WHAT'S IT FOR?
		char *p=NULL;
		int iSize=0;
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
			
			if(p)
				NSLog(@"%s=[%s]",&sc.key[0],p);
			
			if(p && _key) {
				setCfgValue(p,iSize,sc.pCfg,[_key cStringUsingEncoding:NSUTF8StringEncoding],sc.iKeyLen);
			}
			return;
			
		}
 */
    
    if ([_items isKindOfClass:[NSArray class]]) {
        for (NSObject *item in (NSArray *)_items) {
            if ([item isKindOfClass:[SCSettingsItem class]])
                 [(SCSettingsItem *)item save];
        }
    }
/* EA: ignoring all this for now
	if(!item.pRet)
		return;

	int v=0;
	
	p=tryConvertStrIntPTR(p,iSize,&v);
	if(!p)return;
	
	if(sc.iType==CTSettingsCell::eOnOff || sc.iType==CTSettingsCell::eInt || sc.iIsInt>0)
		NSLog(@"%s=%d",&sc.key[0],v);
	else if(p)
		NSLog(@"%s=%s",&sc.key[0],strcmp(sc.key,"pwd")?p:(p[0]?"*****":""));

	cfg=sc.pCfg;
	if(p && sc.key[0]){
		setCfgValue(p,iSize,sc.pCfg,&sc.key[0],sc.iKeyLen);
		if(!sc.pCfg){
			void t_save_glob();
			t_save_glob();
		}
	}
*/
	if ( (_key) && (_value) ) {
		const char *key = [_key cStringUsingEncoding:NSUTF8StringEncoding];
		int keyLen = (int)strlen(key);
        if (_type == SettingType_Bool) {
            // NOTE: bool's are stored as int's (4 bytes) in Tivi
            uint32_t bVal = [self boolValue] ? 1 : 0;
            setCfgValue((char *)&bVal, 4, self.pCfg, (char *)key, keyLen);
        } else {
            uint32_t iSize;
            const char *p = [self cStringValue:&iSize];
            setCfgValue((char *)p, iSize, self.pCfg, (char *)key, keyLen);
        }
		if (!self.pCfg)
			t_save_glob();
	}
    
    if (_flags & SettingFlag_ChangeReloadsAll)
        [[SCPSettingsManager shared] _loadSettings];
}

@end
