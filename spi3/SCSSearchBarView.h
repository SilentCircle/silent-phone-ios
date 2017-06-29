//
//  SCSSearchBarView.h
//  SPi3
//
//  Created by Gints Osis on 27/04/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>
@protocol SCSSearchBarViewDelegate<NSObject>
@optional
- (void) didTapClearSearchButton;
- (void) searchTextDidChange:(NSString *) searchText;
@end


/*
 SearchBar for SearchViewController
 UIView containing searchTextField and clear button for searchViewController
 */
@interface SCSSearchBarView : UIView<UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UITextField *searchTextField;
@property (weak, nonatomic) IBOutlet UIButton *clearButton;
- (IBAction)clearButtonTap:(id)sender;
@property (weak, nonatomic) IBOutlet UIImageView *clearImageView;

@property (nonatomic, weak) id<SCSSearchBarViewDelegate> delegate;

- (void) clearSearch;
@property (nonatomic, strong) NSString *searchPlaceHolder;
@end
