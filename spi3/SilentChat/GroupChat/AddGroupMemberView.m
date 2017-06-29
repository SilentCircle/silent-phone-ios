//
//  AddGroupMemberView.m
//  SPi3
//
//  Created by Gints Osis on 03/01/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//
#import "AddGroupMemberView.h"
#import "UIImage+ApplicationImages.h"
#import "UIColor+ApplicationColors.h"
#import "GroupMemberView.h"
#import "ChatUtilities.h"
/*
 Group member selection control
 Uses scrollview and sequential view hierarchy on it
 
 Use public function getAllMemberNames to get array of added contactnames
 */
@implementation AddGroupMemberView
{
    UIScrollView *scrollView;
    UILabel *networkErrorLabel;
    
    
    // datasource
    NSMutableArray<GroupMemberView *> *members;
}
// spacing between member view's
static NSInteger const kMemberSpacing = 5;
-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self == [super initWithCoder:aDecoder])
    {
        scrollView = [[UIScrollView alloc] initWithFrame:self.frame];
        [self addSubview:scrollView];
        scrollView.delegate = self;
        [scrollView setScrollEnabled:YES];
        
        scrollView.isAccessibilityElement = YES;
        scrollView.accessibilityLabel = @"No contacts added yet";
    }
    return self;
}
static NSInteger const kRemoveMemberIconSize = 20;
static NSInteger const kMemberViewVerticalInset = 12;
static NSInteger const kContactNameInset = 12;
/*
 Add new GroupMemberView and adjust the scrollview contentsize and offset
 
 @return boolean indicating wether the contact was added or it existed before and wasn't added
 */
-(BOOL)addMember:(RecentObject *)recent
{
    [scrollView setFrame:self.frame];
    NSString *addContactName = [[ChatUtilities utilitiesInstance] removePeerInfo:recent.contactName lowerCase:NO];
    for (GroupMemberView *view in members)
    {
        NSString *viewContactName = [[ChatUtilities utilitiesInstance] removePeerInfo:view.recentObject.contactName lowerCase:NO];
        if ([viewContactName isEqualToString:addContactName])
        {
            return NO;
        }
    }
    NSString *contactName = addContactName;
    NSString *displayName = nil;
    
    if (recent.abContact)
    {
        displayName = recent.abContact.fullName;
    } else
    {
        displayName = recent.displayName;
    }
    /*
     Construction of groupMemberview with uilabel and imageview
     */
    UITextView *contactNameTextView = [UITextView new];
    [contactNameTextView setBackgroundColor:[UIColor clearColor]];
    contactNameTextView.text = [[ChatUtilities utilitiesInstance] firstNameFromFullName:displayName];
    
    contactNameTextView.textContainer.maximumNumberOfLines = 1;
    [contactNameTextView.layoutManager textContainerChangedGeometry:contactNameTextView.textContainer];
    
    contactNameTextView.isAccessibilityElement = YES;
    contactNameTextView.accessibilityLabel = recent.displayName;
    [contactNameTextView setFont:[UIFont fontWithName:@"HelveticaNeue" size:15.0]];
    [contactNameTextView setTextColor:[UIColor whiteColor]];
    [contactNameTextView setUserInteractionEnabled:NO];
    
    GroupMemberView *backgroundView = [[GroupMemberView alloc] initWithFrame:contactNameTextView.frame];
    
    
    // we have to create new recent here because reference to the one passed here can change because of indexpath in tableview from which it is passed
    
    // Recreated recent will find the avatar image locally from existing recent
    RecentObject *newRecent = [[RecentObject alloc] init];
    newRecent.contactName = recent.contactName;
    newRecent.displayName = recent.displayName;
    backgroundView.recentObject = newRecent;
    backgroundView.clipsToBounds = NO;
    [backgroundView setBackgroundColor:[UIColor addedMemberBackgroundColor]];
    UIImageView *removeImageView = [[UIImageView alloc] initWithImage:[UIImage removeMemberIcon]];
    [backgroundView addSubview:removeImageView];
    [backgroundView addSubview:contactNameTextView];
    
    UITapGestureRecognizer *backgroundTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapMember:)];
    [backgroundView addGestureRecognizer:backgroundTap];
    
    if (!members)
    {
        members = [NSMutableArray new];
    }
    
    backgroundView.contactNameTextView = contactNameTextView;
    backgroundView.removeImageView = removeImageView;
    
    [members addObject:backgroundView];
    
    if ([self.delegate respondsToSelector:@selector(didAddMemberName:)])
    {
        [self.delegate didAddMemberName:contactName];
    }
    
    
    
    [scrollView addSubview:backgroundView];
    
    self.accessibilityElements = members;
    
    [self setFramesOnMemberView:backgroundView animate:YES didAdd:YES];
    
    return YES;
}

-(void)showNetworkError
{
    if (!networkErrorLabel.superview)
    {
        networkErrorLabel = [[UILabel alloc] init];
        networkErrorLabel.text = @"No network available";
        networkErrorLabel.translatesAutoresizingMaskIntoConstraints = NO;
        networkErrorLabel.font = [[ChatUtilities utilitiesInstance] getFontWithSize:16];
        [self addSubview:networkErrorLabel];
        
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-80-[networkErrorLabel]-0-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(networkErrorLabel)]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[networkErrorLabel]-0-|" options:NSLayoutFormatAlignAllCenterY metrics:nil views:NSDictionaryOfVariableBindings(networkErrorLabel)]];
    } else
    {
        networkErrorLabel.transform = CGAffineTransformMakeTranslation(20, 0);
        [UIView animateWithDuration:0.4 delay:0.0 usingSpringWithDamping:0.2 initialSpringVelocity:1.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            networkErrorLabel.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

-(void) hideNetworkError
{
    if (networkErrorLabel)
    {
        [networkErrorLabel removeFromSuperview];
    }
}

-(void) checkMemberViewForDisplayNameUpdate:(GroupMemberView *)addedMember
{
    RecentObject *memberRecent = addedMember.recentObject;
    if ([memberRecent.contactName isEqualToString:memberRecent.displayName] || !memberRecent.displayName)
    {
        [[ChatUtilities utilitiesInstance] getPrimaryAliasAndDisplayName:memberRecent.contactName completion:^(NSString *displayName, NSString *displayAlias) {
            if (displayName)
            {
                memberRecent.displayName = displayName;
            }
            if (displayAlias)
            {
                memberRecent.displayAlias = displayAlias;
            }
            for (GroupMemberView *memberView in members)
            {
                if ([memberView.recentObject isEqual:memberRecent])
                {
                    memberView.recentObject = memberRecent;
                    memberView.contactNameTextView.text = memberRecent.displayName;
                    [UIView animateWithDuration:0.1f animations:^{
                        [self setFramesOnMemberView:memberView animate:NO didAdd:NO];
                    }];
                    return;
                }
            }
        }];
    }
}

-(void) didTapMember:(UITapGestureRecognizer *) recognizer
{
    GroupMemberView *memberView = (GroupMemberView *)recognizer.view;
    [self removeMember:memberView.recentObject];
}
-(void)removeMember:(RecentObject *)recent
{
    NSString *recentContactName = [[ChatUtilities utilitiesInstance] removePeerInfo:recent.contactName lowerCase:NO];
    int removedIndex = 0;
    float removedViewWidth = 0;
    
    UIView *tappedView = nil;
    // find view to remove
    for (int i = 0; i<members.count; i++)
    {
        GroupMemberView *view = members[i];
        
        NSString *viewContactName = [[ChatUtilities utilitiesInstance] removePeerInfo:view.recentObject.contactName lowerCase:NO];
        
        if ([recentContactName isEqual:viewContactName])
        {
            removedViewWidth = view.frame.size.width;
            tappedView = view;
            [members removeObject:view];
            if ([self.delegate respondsToSelector:@selector(didRemoveMemberName:)])
            {
                [self.delegate didRemoveMemberName:viewContactName];
            }
            removedIndex = i;
            break;
        }
    }
    
    // animate existing member name out of view
    [UIView animateWithDuration:.1f animations:^{
        CGRect tappedViewFrame = tappedView.frame;
        tappedViewFrame.origin.y = self.frame.size.height;
        tappedView.frame = tappedViewFrame;
        tappedView.alpha = 0.0f;
    } completion:^(BOOL finished) {
        [tappedView removeFromSuperview];
        
        //compensate all view origins which exist after the removed view in members list
        [UIView animateWithDuration:0.1f animations:^{
            for (int i = removedIndex; i < members.count; i++)
            {
                UIView *view = members[i];
                CGRect viewFrame = view.frame;
                viewFrame.origin.x -= removedViewWidth + kMemberSpacing;
                view.frame = viewFrame;
            }
            // reset scrollview content size
            UIView *lastBackgroundView = members.lastObject;
            if (lastBackgroundView)
            {
                float newScrollViewWidth = lastBackgroundView.frame.origin.x + lastBackgroundView.frame.size.width + kMemberSpacing;
                [scrollView setContentSize:CGSizeMake(newScrollViewWidth, self.frame.size.height)];
            }
        } completion:^(BOOL finished) {
        }];
    }];
}
-(NSArray<RecentObject *> *)getAllMembers
{
    NSMutableArray *memberNames = [[NSMutableArray alloc] initWithCapacity:members.count];
    for (GroupMemberView *view in members)
    {
        [memberNames addObject:view.recentObject];
    }
    
    return memberNames;
}
-(BOOL)existMember:(NSString *)contactName
{
    contactName = [[ChatUtilities utilitiesInstance] removePeerInfo:contactName lowerCase:NO];
    for (GroupMemberView *view in members)
    {
        NSString *viewContactName = [[ChatUtilities utilitiesInstance] removePeerInfo:view.recentObject.contactName lowerCase:NO];
        if ([viewContactName isEqualToString:contactName])
        {
            return YES;
        }
    }
    return NO;
}

-(void) transitionScrollViewToSize:(CGSize) size
{
    CGRect scrollViewFrame = scrollView.frame;
    scrollViewFrame.size.width = size.width;
    scrollView.frame = scrollViewFrame;
}

-(void) updateFrames
{
    scrollView.frame = self.frame;
    for (GroupMemberView *memberView in members)
    {
        [self setFramesOnMemberView:memberView animate:NO didAdd:NO];
    }
}

/*
 Set frames for memberView and it's subviews
 contactNameLabel and removeImageView
 
 @param memberView - memberView for which to set or reset frames
 @param animate - should animate frame change
 @param didAdd - did this member was just added to scrollview or frame change is ment for existing memberView
 */
-(void) setFramesOnMemberView:(GroupMemberView *) memberView animate:(BOOL) animate didAdd:(BOOL) didAdd
{
    UITextView *contactNameTextView = memberView.contactNameTextView;
    UIImageView *removeImageView = memberView.removeImageView;
    
    [contactNameTextView sizeToFit];
    
    CGRect memberViewFrame = memberView.contactNameTextView.frame;
    memberViewFrame.size.width += kRemoveMemberIconSize + 15;
    memberViewFrame.size.height = self.frame.size.height - kMemberViewVerticalInset * 2;
    if (animate)
    {
        memberViewFrame.origin.y = self.frame.size.height;
    } else
    {
        memberViewFrame.origin.y = self.frame.size.height / 2 - memberViewFrame.size.height / 2;
    }
    
    int xOffset = kMemberSpacing;
    if (didAdd)
    {
        for (UIView *memberBackgroundView in members)
        {
            if (![memberBackgroundView isEqual:memberView])
            {
                xOffset += memberBackgroundView.frame.size.width + kMemberSpacing;

            }
        }
    } else
    {
        xOffset = memberView.frame.origin.x;
    }
    memberViewFrame.origin.x = xOffset;
    
    CGRect contactNameFrame = contactNameTextView.frame;
    contactNameFrame.origin.x = kContactNameInset;
    contactNameFrame.origin.y = memberViewFrame.size.height / 2 - contactNameFrame.size.height / 2;
    contactNameTextView.frame = contactNameFrame;
    
    CGRect removeImageViewFrame = memberView.removeImageView.frame;
    removeImageViewFrame.size.width = kRemoveMemberIconSize;
    removeImageViewFrame.size.height = kRemoveMemberIconSize;
    removeImageViewFrame.origin.x = contactNameTextView.frame.size.width + kContactNameInset;
    removeImageViewFrame.origin.y = memberViewFrame.size.height / 2 - kRemoveMemberIconSize / 2;
    removeImageView.frame = removeImageViewFrame;

    
    
    memberView.layer.cornerRadius = memberViewFrame.size.height / 2;
    memberView.frame = memberViewFrame;

    
    // set scrollview contentsize depending on this memberview's x origin and size
    float newScrollViewWidth = memberView.frame.origin.x + memberView.frame.size.width + kMemberSpacing;
    [scrollView setContentSize:CGSizeMake(newScrollViewWidth, self.frame.size.height)];
    

    if (!didAdd)
    {
        xOffset = memberView.frame.origin.x;
    }
    
    
    // scroll last added item in view
    [scrollView scrollRectToVisible:CGRectMake(xOffset, 0, self.frame.size.width, self.frame.size.height) animated:YES];
    
    if (didAdd && animate)
    {
        [UIView animateWithDuration:0.2f
                              delay:0.0f
             usingSpringWithDamping:0.5f
              initialSpringVelocity:1.0f
                            options:0 animations:^{
                                CGRect memberViewFrame = memberView.frame;
                                memberViewFrame.origin.y = self.frame.size.height / 2 - memberViewFrame.size.height / 2;
                                memberView.frame = memberViewFrame;
                            } completion:^(BOOL finished) {
                                [self checkMemberViewForDisplayNameUpdate:memberView];
                            }];
    } else
    {
        
        // If we are adjusting frames for existing memberView we need to recalculate all other memberView frames
        xOffset = kMemberSpacing;
        for (int i = 0; i<members.count; i++)
        {
            GroupMemberView *existingMemberView = members[i];
            CGRect existingMemberViewFrame = existingMemberView.frame;
            existingMemberViewFrame.origin.x = xOffset;
            xOffset+= existingMemberViewFrame.size.width + kMemberSpacing;
            existingMemberView.frame = existingMemberViewFrame;
        }
    }

    
}

@end
