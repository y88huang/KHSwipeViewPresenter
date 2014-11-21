//
//  KHSwipeViewPresenter.h
//  KHSwipeViewPresenter
//
//  Created by Ken Huang on 2014-11-15.
//  Copyright (c) 2014 Ken Huang. All rights reserved.
//

#import <UIKit/UIKit.h>
@class KHSwipeViewPresenter;
@protocol KHSwipeViewPresenterDelegate <NSObject>

- (void)KHSwipeViewPresenterDidSwipeOut: (KHSwipeViewPresenter *)viewPresenter;

@end
@interface KHSwipeViewPresenter : UIView

@property (strong, nonatomic) UIView *contentView;
@property (strong, readonly, nonatomic) UIScrollView *scrollView;
@property (weak, nonatomic) id <KHSwipeViewPresenterDelegate> delegate;

//setting property
@property (nonatomic) BOOL enableSwipeToDelete; //default no.

- (void)setRightPanelButtons:(NSArray *)buttons;

@end
