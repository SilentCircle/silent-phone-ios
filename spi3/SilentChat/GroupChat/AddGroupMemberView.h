//
//  AddGroupMemberView.h
//  SPi3
//
//  Created by Gints Osis on 03/01/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "RecentObject.h"
/*
 Protocol for removal or addition of members to scrollview
 */
@protocol GroupMemberViewDelegate<NSObject>
-(void) didRemoveMemberName:(NSString *) contactName;
-(void) didAddMemberName:(NSString *) contactName;
@end
@interface AddGroupMemberView : UIView<UIScrollViewDelegate>
/*
 Add member to scrollview
 @param recent - RecentObject to add
 
 @return did add successfully, returns NO if contactname exists
 */
-(BOOL) addMember:(RecentObject *) recent;
/*
 Remove contactname from scrollView
 @param recent - RecentObject to remove
 */
-(void) removeMember:(RecentObject *) recent;
/*
 Public getter for current RecentObjects in the list
 */
-(NSArray <RecentObject*>*) getAllMembers;
/*
 Check if contact name exists in scrollview
 */
-(BOOL) existMember:(NSString *) contactName;

-(void) updateFrames;

/*
 Shows network error label covering entire view
 */
-(void)showNetworkError;

-(void) hideNetworkError;


/*
 Changes width to the scrollview to be the same as passed view
 Usually called from viewWillTransitionToSize:
 */
-(void) transitionScrollViewToSize:(CGSize) size;
@property (nonatomic, assign) id <GroupMemberViewDelegate> delegate;
@end
