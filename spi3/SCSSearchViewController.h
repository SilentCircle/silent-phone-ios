//
//  SCSSearchViewController.h
//  SPi3
//
//  Created by Stelios Petrakis on 21/02/2017.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RecentObject.h"
#import "SCSSearchBarView.h"
#import "SCSNewGroupChatView.h"

@protocol SCSTransitionDelegate;

@interface SCSSearchViewController : UIViewController

@property (weak, nonatomic) id<SCSTransitionDelegate> transitionDelegate;

/**
 Whether the tableview should show a 'New group conversation'
 on the top.
 
 YES to hide the button, NO otherwise. (Default value: NO)
 */
@property (nonatomic) BOOL disableNewGroupChatButton;

/**
 Whether swiping is allowed (for calls, add contact functionality)
 on the table view.
 
 YES to disable swipe, NO otherwise. (Default value: NO)
 */
@property (nonatomic) BOOL disableSwipe;

/**
 Controls whether the autocomplete search section will be shown.
 (e.g. we do not want to show this section in forwarding screen)
 
 YES to hide the autocomplete search section, NO otherwise. (Default value: NO)
 */
@property (nonatomic) BOOL disableAutocompleteSearch;

/**
 Controls whether the directory search section will be shown.
 (e.g. we do not want to show this section in forwarding screen)
 
 YES to hide the directory search section, NO otherwise. (Default value: NO)
 */
@property (nonatomic) BOOL disableDirectorySearch;

/**
 Controls whether the address book search section will be shown.
 (e.g. we do not want to show this section in forwarding screen)
 
 YES to hide the address book search section, NO otherwise. (Default value: NO)
 */
@property (nonatomic) BOOL disableAddressBook;

/**
 Only displays and searches through group conversations.
 */
@property (nonatomic) BOOL enableGroupConversations;

/**
 Only displays and searches no number conversations
 */
@property (nonatomic) BOOL disablePhoneNumberResults;

/**
 Block that gets called when a contact has been selected
 */
@property (nonatomic, copy) void (^doneBlock)(RecentObject *recentObject);


/**
 Button for new group chat composition view transition
 */
@property (strong, nonatomic) IBOutlet SCSNewGroupChatView *groupChatButtonView;

/**
 Search bar with textfield and clear button
 */
@property (nonatomic,strong) SCSSearchBarView *searchBar;


@end
