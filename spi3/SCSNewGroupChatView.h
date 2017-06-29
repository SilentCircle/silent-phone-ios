//
//  SCSNewGroupChatView.h
//  SPi3
//
//  Created by Gints Osis on 27/04/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//
/*
 UIView for new group chat button
 Delegates a tap on entire uiview 
 and simulates color change similar to UITableViewRowSelectionGray when tapped
 */
#import <UIKit/UIKit.h>

@protocol SCSNewGroupChatViewDelegate<NSObject>
@optional
- (void) didTapNewGroupChatButton;
@end
@interface SCSNewGroupChatView : UIView
@property (weak, nonatomic) IBOutlet UIView *backgroundView;
@property (nonatomic, weak) id<SCSNewGroupChatViewDelegate> delegate;

@end
