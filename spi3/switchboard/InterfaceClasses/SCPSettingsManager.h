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
//  SCPSettingsManager.h
//  SPi3
//
//  Created by Eric Turner on 11/1/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//
#import <Foundation/Foundation.h>

@class SCSettingsItem;

typedef BOOL (*SettingChangeCallback)(SCSettingsItem *setting);

typedef enum SettingType_t {
	SettingType_Unknown = 0
	,SettingType_Bool
	,SettingType_Button
	,SettingType_Label
	,SettingType_Menu
	,SettingType_Root
    ,SettingType_Text
} SettingType;

typedef uint16_t SettingFlags; // bitfield flags
const uint16_t SettingFlag_Inverse	= 0x0001;
const uint16_t SettingFlag_IsLink	= 0x0002;
//const uint16_t SettingFlag_PassLock = 0x0004;
const uint16_t SettingFlag_Hidden	= 0x0008;
const uint16_t SettingFlag_Disabled	= 0x0010;
const uint16_t SettingFlag_Editable	= 0x0020;
const uint16_t SettingFlag_Reorder	= 0x0040;
const uint16_t SettingFlag_Secure	= 0x0080;
const uint16_t SettingFlag_DontPopChooser = 0x0100;
const uint16_t SettingFlag_ChangeReloadsAll = 0x0200;

@interface SCSettingsItem : NSObject
@property (strong, nonatomic) NSString *key;
@property (strong, nonatomic) NSString *label;
@property (assign, nonatomic) SettingType type;
@property (strong, nonatomic) NSObject *defaultVal;
@property (assign, nonatomic) SettingFlags flags;
@property (strong, nonatomic) NSString *footer;
@property (assign, nonatomic) SettingChangeCallback callback;
@property (strong, nonatomic) NSString *header;
@property (strong, nonatomic) NSObject *items; // NSArray or NSDictionary
@property (strong, nonatomic) NSObject *value;

@property (assign, nonatomic) void *pCfg;

- (BOOL)boolValue;
- (NSString *)stringValue;
- (const char *)cStringValue:(uint32_t *)sizeP;

- (NSArray *)visibleItems;
- (SCSettingsItem *)findItem:(NSString *)key;
- (BOOL)performCallback;

- (BOOL)isDisabled;
- (BOOL)isEditable;
- (BOOL)isHidden;
- (void)setHidden:(BOOL)bHidden;
- (BOOL)isLink;
//- (BOOL)isPasslock;
- (BOOL)canReorder;
- (BOOL)isSecure;

- (void)save;

@end

extern SCSettingsItem *SETTING_ITEM(NSString *key, NSString *label, SettingType type, NSObject *defaultVal = nil, SettingFlags flags = 0x0000, NSString *footer = nil, SettingChangeCallback changeCallback = nil, NSString *header = nil);
extern SCSettingsItem *SETTING_TEXT(NSString *key, NSString *label);

@interface SCPSettingsManager : NSObject {
	NSMutableArray *_allSections;
	NSMutableDictionary *_sectionMap;
	NSMutableDictionary *_settingsMap;
}

+ (instancetype)shared;
+ (void)setup;

- (NSArray *)allSections;

+ (void)saveSettings;

+ (void )setCfgLevel:(int)newLevel;
+ (int)getCfgLevel;

- (void)addSection:(NSString *)sectionName withSettings:(NSArray *)settingsList;

- (SCSettingsItem *)settingForKey:(NSString *)key;
- (NSObject *)valueForKey:(NSString *)key;


@end
