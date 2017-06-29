//
//  scsContactTypeSearchVM.h
//  SPi3
//
//  Created by Gints Osis on 02/02/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

//Contacts
#import "SCSGlobalContactSearch.h"

//DataSource
#import "RecentObject.h"

//#import "MGSwipeTableCell.h"
#import "SCSContactTVCell.h"

#import "SCSEnums.h"

/*
 ABOUT:
 View model for Search tableView's
 
 Serves as dataSource and delegate for assigned tableview

 Shows tableview of SCSChatSectionObject's sections of RecentObject's
 First section is always searched text section if text is being searched
 Second section is directory search if it exists
 Third section is existing conversation search results if it exists
 Bottom section is always AddressBook results
 
 Every section addition or removal happens in serial queue to avoid tableview update collisions
 
 Uses single selection and multiple selection modes. In multi selection mode there is a plus icon added in place of timestamp and rotating fade animation is played each time user select's or deselect's the cell
 When user taps to select a cell a check is done for all other cells to see if they contain same contactname. And same animation is played on other cells indicating that the same contactname is selected
 
 Assigned tableview's scrollViewWillBeginDragging: delegate method can be used to tell the containing viewcontroller to stop search and close the keyboard
 
 This class uses scsContactType enum to assign contact kind in grouped array. This enum is very similar to SCSGlobalContactSearchFilter enum but with extra scsContactTypeSearch option
 To avoid confusion in GlobalSearch class we parse SCSGlobalContactSearchFilter to scsContactType enum and vice versa
 Globally scsContactType is used globally when using this class, SCSGlobalContactSearchFilter is used only in SCSglobalContactSearch class
 
 USAGE:
 Use initWithTableView: initializer to create instance of this object.
 
 To populate tableview with full lists of contact type use showFullListsOfContactType:filter
 
 Assign actionDelegate to receive touch events and swipe button taps
 
 To activate search for contact types and display different starting list when begining to search use activateSearchWithDefaultContactTypes:forContacTypes:
 
 
 To search string use searchText which will use filter types assigned when activating search
 */


/*
 Cell delegate for all actions available on cell
 */
@protocol SCSSearchVMActionDelegate <NSObject>
@optional
-(void) didTapRecentObject:(RecentObject *) recentObject;
-(void) didLongPressedRecentObject:(RecentObject *) recentObject;
-(void) didTapCallButtonOnRecentObject:(RecentObject *) recentObject;
-(void) didTapSaveContactsButtonOnRecentObject:(RecentObject *) recentObject;
-(void) didTapDeleteButtonOnRecentObject:(RecentObject *) recentObject;
-(void) didTapDeleteButtonOnGroupRecent:(RecentObject *) recentObj;

-(void) didAddRecentObjectToSelection:(RecentObject *) recentObject ofType:(scsContactType)contactType;
-(void) didRemoveRecentObjectFromSelection:(RecentObject *) recentObject;

-(void) scrollViewWillBeginDragging:(UIScrollView *)scrollView;

@end

@interface scsContactTypeSearchVM : NSObject<UITableViewDelegate, UITableViewDataSource,SCSGlobalContactSearchDelegate,SCSContactTVCellDelegate>

/*
 Designated initializer
 */
-(instancetype)initWithTableView:(UITableView *)tableView;

/*
 Populate tableview with full lists of contact type
 
 Does searching of passed filters on globalSearcher
 Doesn't display directory as full list since we can't search empty strings in directory
 */
-(void) showFullListsOfContactType:(scsContactType) type;


// SEARCH

/*
 Activate search
 
 @param displayType  contact types for which to show full list prior to begin searching
 @param searchtype  contact types to search in
 */
-(void)activateSearchforTypes:(scsContactType) searchType andDisplayFullListsOfTypes:(scsContactType)displayType;

/*
 Clean all search records and display full lists of passed filter

 */
-(void)deactivateSearchAndShowContactTypes:(scsContactType) displayType;

/*
 Search globalContactSearch instance with filter passed in activateSearchWithDefaultContactTypes:displayFilter:searchFilter
 */
- (void)searchText:(NSString*)text;

/**
 Sections on which to hide headers when search is not active
 */
@property (nonatomic) scsContactType hiddenHeaders;

/*
 Should swipe delegate calculate swipe buttons
 */
@property (nonatomic) BOOL isSwipeEnabled;

// MULTISELECTION:

/*
 If enabled timestamp on cell is replaced with plus icon 
 Each tap on cells animate the plussbutton to appear or dissapear depending of addition or removal of contact
 */
@property (nonatomic) BOOL isMultiSelectEnabled;

/*
 Array of selected REcentObject's in multiSelection
 If multiSelection is disabled this array is nil
 */
@property (nonatomic, strong) NSMutableArray <RecentObject *>* selectedContacts;

/*
 Force remove of RecentObject containing passed contactname
 Used in groupMember View where some other view can remove RecentObject's from tableview
 */
-(void)shouldRemoveContactNameFromSelection:(NSString *) contactName;

/*
 Array of contacts to exclude from displaying
 When Global search returns with results each result matched on this array is removed before displaying
 Used in group member addition when some members already exist in group
 */
@property (nonatomic) NSMutableArray *alreadyAddedContacts;


/*
 Flag of full lists being displayed right now
 */
@property (nonatomic) scsContactType displayedFullLists;

/*
 Is search mode active
 If search is not active and GlobalSearch returns with directory results those results are ignored
 */
@property (nonatomic, readonly) BOOL isSearchActive;


/**
 Should we hide number conversation results
 */
@property (nonatomic) BOOL shouldDisableNumbers;


// Delegate for cell actions
@property (nonatomic,assign) id<SCSSearchVMActionDelegate> actionDelegate;



//HELPERS:

/*
 Returns cell from tableview for passed recentObject
 */
-(SCSContactTVCell *)getCellFromRecentObject:(RecentObject *)recent;

/*
 Returns RecentObject by indexPath of given cell
 */
-(RecentObject *) getRecentObjectFromCell:(SCSContactTVCell *) cell;

/*
 Boolean flag indicating wether tableview's datasource contains any items
 When tableview row count changes this object will post 
 */
-(BOOL) isTableViewEmpty;

@end
