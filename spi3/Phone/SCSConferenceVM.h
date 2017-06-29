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
//  SCSConferenceVM.h
//  SPi3
//
//  Created by Eric Turner on 2/20/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UiKit/UIKit.h>

@protocol SCSConferenceDelegate <NSObject, UITableViewDelegate>
@optional
- (void)updateInProgressAccessibility;
- (BOOL)accessibilityPerformMagicTap;
@end

@protocol SCSCallNavDelegate;

/**
 * This class is a ViewModel for the call conferencing feature, in the
 * MVVM pattern, i.e., Model--View--ViewModel. In contrast to the 
 * conventional MVC pattern espoused by Apple, this view model 
 * mediates between a static data model (M) and the view layer which
 * includes view and view controller.
 *
 * This view model serves as datasource and delegate for the "view
 * collection" of the Conferencing feature, i.e., both UITableView and
 * UICollectionView "view collections" are supported by this class.
 *
 * (Note that throughout the documentation, "view collection" is the
 * abstract description of the collectionView or tableView.)
 *
 * This class implements an event queue for updating the view collection
 * for changes in state. The input "signals" are:
 * - SCPIncomingCallNotification
 * - SCPCallStateDidChangeNotification
 * - SCPZRTPDidUpdateNotification
 * - SCPCallDidEndNotification
 * which come from SCPCallManager, which bridges call events from the
 * Tivi engine into ObjC. And user-driven changes, for example pressing
 * the answer or end call buttons on a cell, or dragging a call cell
 * between sections.
 *
 * "Blocking" events, such as the user dragging a call cell, cause
 * SCSBlockOperation block instances to defer execution by storing them
 * in the private deferredOpsQueue array until blocking is complete.
 *
 * (SCSBlockOperation is a private NSBlockOperation subclass defined near
 * the top of the implementation file.)
 *
 * Note that a reload with animation operation must also block so that
 * we don't try to reload with animation while an animated reload is
 * already occurring.
 *
 * Two flags are implemented to track blocking state:
 * - isReloading
 * - isReordering
 *
 * isReloading:  A KVO listener is implemented on the isReloading property.
 * When the property value changes, if both isReloading and isReordering
 * are false, the listener invokes the fireDeferredOperations method.
 *
 * isReordering: this flag is set when the user begins dragging a call
 * cell, and cleared when the drag is finished. This flag prevents a
 * reload operation for an incoming call while the user is changing the
 * state of the view collection.
 *
 * 
 * ### History
 * This documents a first implementation. Several immediate refinements
 * are possible:
 * * More selective reloading for update and reload events:
 *   Reload events are:
 *   - new incoming (unanswered) and outgoing (ended) calls, to be 
 *     displayed in the inProgress section
 *   - user-driven moves:
 *     - between conference and private sections by dragging,
 *     - into and out of inProgress section by answering/ending call
 *
 *   Improvement:
 *   Currently, for every (animated) reload event, the nested arrays 
 *   datasource is completely reconstructed with the SCPCall objects 
 *   from SCPCallManager. Then the deltas are calculated for insertions
 *   and deletions to/from the several sections. Then the collection is
 *   reloaded in an animation block.
 *
 *   It might be better to reload only changed sections. For example,
 *   dragging is only permitted between Private and Conference sections.
 *   It may be possible to reload the inProgress section for incoming
 *   and outgoing calls while dragging.
 *
 *
 * * Better filtering of call state from state change signal:
 *   Incoming call, call ended, and zrtp update, notifications (signals)
 *   are straightforward. But call state update is rather nebulous.
 *   Not all SCPCallStateDidChangeNotifications are relevant from the 
 *   view collection perspective. 
 *
 *   Unfortunately, the current implementation of SCPCall does not 
 *   provide rich introspection into its state. Filtering appropriate to
 *   the view collection could be implemented in this class, or
 *   (preferrably) the SCPCall instance could exposed a fine-grained
 *   state interface.
 */

@interface SCSConferenceVM : NSObject
<UITableViewDelegate, UITableViewDataSource,
UICollectionViewDelegate, UICollectionViewDataSource>

@property (weak, nonatomic) id<SCSCallNavDelegate> navDelegate;
@property (weak, nonatomic) UITableView *tableView;
@property (weak, nonatomic) UICollectionView *collectionView;

-(instancetype)initWithTableView:(UITableView *)tv;
-(instancetype)initWithCollectionView:(UICollectionView *)cv;

/**
 * These methods are invoked in the viewWillAppear: and viewWillDisappear
 * methods of the view controller for which this class instance is a
 * viewModel.
 *
 * Note that this class has no view and does not keep reference to the
 * controller class which instantiates it.
 */
-(void)prepareToBecomeActive;
-(void)prepareToBecomeInactive;

@end
