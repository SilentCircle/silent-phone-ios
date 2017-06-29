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
//  SCSConferenceTVC.m
//  SPi3
//
//  Created by Eric Turner on 11/14/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//

#import "SCSConferenceTVC.h"
#import "SCSCallNavDelegate.h"
#import "SCSConferenceVM.h"
#import "SCSFeatures.h"
//Categories
#import "UIImage+ApplicationImages.h"


#pragma mark - Logging
static BOOL const EVENT_LOG = NO;
static BOOL const ALL_LOGS = NO;

@interface SCSConferenceTVC () <SCSConferenceDelegate>
@property (weak, nonatomic) IBOutlet UINavigationBar *navBar;
@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) SCSConferenceVM *viewModel;
@end

@implementation SCSConferenceTVC


#pragma mark - Lifecycle

- (void)viewDidLoad {
    if (EVENT_LOG || ALL_LOGS) {
        NSLog(@"%s called", __PRETTY_FUNCTION__);
    }
    [super viewDidLoad];
    
    _viewModel = [[SCSConferenceVM alloc] initWithTableView:self.tableView];
    _viewModel.navDelegate = self.navDelegate;

    [self configureNavBar];
}

- (void)viewWillAppear:(BOOL)animated {
    if (EVENT_LOG || ALL_LOGS) {
        NSLog(@"%s called", __PRETTY_FUNCTION__);
    }
    [super viewWillAppear:animated];
    
    [_viewModel prepareToBecomeActive];
}

- (void)viewDidAppear:(BOOL)animated {
    if (EVENT_LOG || ALL_LOGS) {
        NSLog(@"%s called", __PRETTY_FUNCTION__);
    }
    [super viewDidAppear:animated];
    
    if ([_viewModel respondsToSelector:@selector(updateInProgressAccessibility)]) {
        [(id<SCSConferenceDelegate>)_viewModel updateInProgressAccessibility];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    if (EVENT_LOG || ALL_LOGS) {
        NSLog(@"%s called", __PRETTY_FUNCTION__);
    }
    [super viewWillDisappear:animated];
    
    [_viewModel prepareToBecomeInactive];
}

- (void)dealloc {
    NSLog(@"%s",__PRETTY_FUNCTION__);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Accessibility

-(BOOL) accessibilityPerformEscape
{
    [self handleBack:nil];
    
    return YES;
}

- (BOOL)accessibilityPerformMagicTap {
    
    if ([_viewModel respondsToSelector:@selector(accessibilityPerformMagicTap)])
        return [(id<SCSConferenceDelegate>)_viewModel accessibilityPerformMagicTap];
    
    return NO;
}

#pragma mark - Nav Bar Buttons

- (void)configureNavBar {
    UIBarButtonItem *bbtn = [[UIBarButtonItem alloc] initWithImage:[UIImage conversationsIcon]
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(handleBack:)];
    bbtn.accessibilityLabel = NSLocalizedString(@"conversations", nil);
    
    UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle:@""];
    navItem.backBarButtonItem = nil;
    navItem.leftBarButtonItem = bbtn;
    if ([SCSFeatures conferenceGridView]) {
        navItem.rightBarButtonItem = [self gridButton];
    }
    [_navBar setItems:@[navItem] animated:NO];
}

- (void)handleBack:(UIBarButtonItem*)bbtn {
    if ([_navDelegate respondsToSelector:@selector(switchToConversationsWithCall:)]) {
        [_navDelegate switchToConversationsWithCall:nil];
    }
}

#pragma mark - List View

- (UIBarButtonItem *)gridButton {
    UIImage *img = [UIImage imageNamed:@"gridView"];
    UIBarButtonItem *bbtn = [[UIBarButtonItem alloc] initWithImage:img
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(switchConferencingController)];
    bbtn.accessibilityLabel = NSLocalizedString(@"grid view", nil);
    return bbtn;
}

- (void)switchConferencingController {
    if ([_navDelegate respondsToSelector:@selector(switchFromConfVC:)]) {
        [_navDelegate switchFromConfVC:self];
    }
}


#pragma mark - SCSCallHandler Methods

- (void)prepareToBecomeActive{
    if (EVENT_LOG || ALL_LOGS) {
        NSLog(@"%s called", __PRETTY_FUNCTION__);
    }
    
    [super prepareToBecomeInactive];
}


#pragma mark - UIViewController Methods

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    NSLog(@"%s called", __PRETTY_FUNCTION__);
}

@end
