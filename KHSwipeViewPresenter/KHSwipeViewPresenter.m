//
//  KHSwipeViewPresenter.m
//  KHSwipeViewPresenter
//
//  Created by Ken Huang on 2014-11-15.
//  Copyright (c) 2014 Ken Huang. All rights reserved.
//

#import "KHSwipeViewPresenter.h"
#import <UIKit/UIGestureRecognizerSubclass.h>

static const NSInteger kButtonMax = 4;
static const CGFloat kDeleteThreshold = 160.0f;  //distance from the min of right panel to the left end.
static const CGFloat kButtonWidth = 100.0f;
static const CGFloat kCloseThreshold = 80.0f;    //distance from the min of right panel to the right end.
static NSString *KHViewPresenterDraggedNotification = @"kViewPresenterDraggedNotification";

#pragma mark - Custom touchdown recognizer
@interface KHTouchDownRecognizer : UIGestureRecognizer
@end

@implementation KHTouchDownRecognizer

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    if (self.state == UIGestureRecognizerStatePossible) {
        self.state = UIGestureRecognizerStateRecognized;
    }
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    self.state = UIGestureRecognizerStateFailed;
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    self.state = UIGestureRecognizerStateFailed;
}
@end

//Overide UIView and UIScrollview to bypass touch.
#pragma mark - Subclass UIView and UIScrollView to by pass touch
@interface KHView : UIView
@end

@implementation KHView

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    for (UIView *view in self.subviews) {
        if (!view.hidden && view.alpha > 0 && view.userInteractionEnabled && [view pointInside:[self convertPoint:point toView:view] withEvent:event])
            return YES;
    }
    return NO;
}
@end

@interface KHScrollView : UIScrollView
@end

@implementation KHScrollView

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(!self.dragging)
    {
        [self.nextResponder touchesBegan:touches withEvent:event];
    }
    else{
        [super touchesBegan:touches withEvent:event];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (!self.dragging)
    {
        [self.nextResponder touchesEnded:touches withEvent:event];
    }
    else
    {
        [super touchesEnded:touches withEvent:event];
    }
}
@end

//Actual implementation.
@interface KHSwipeViewPresenter () <UIScrollViewDelegate>

@property (strong, nonatomic) UIScrollView *scrollView;
@property (strong, nonatomic) UIView *rightPanel;

@end

@implementation KHSwipeViewPresenter

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self configureViews];
        [self initDefault];
        [self registerNotificatoins];
    }
    return self;
}
#pragma mark - initalizing
//Default initializer, initialize the views' position.
- (void)configureViews
{
    //ContentView
    self.contentView = [[KHView alloc] initWithFrame:self.bounds];
    self.contentView.backgroundColor = [UIColor redColor];
    KHTouchDownRecognizer *touchDown = [[KHTouchDownRecognizer alloc] initWithTarget:self action:@selector(touchDownOnViewPresenter:)];
    [self.contentView addGestureRecognizer:touchDown];
    //ScrollView
    self.scrollView = [[KHScrollView alloc] initWithFrame:self.bounds];
    self.scrollView.backgroundColor = [UIColor blueColor];
    [self addSubview:self.scrollView];
   
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.scrollsToTop = NO;
    self.scrollView.delegate = self;
    [self.scrollView addSubview:self.contentView];
    self.rightPanel = [[UIView alloc] initWithFrame:self.bounds];
    [self.scrollView addSubview:self.rightPanel];
    self.rightPanel.backgroundColor = [UIColor greenColor];
}

//Initialize default setting
- (void)initDefault
{
    self.enableSwipeToDelete = YES;
}

#pragma mark - Layout subviews
- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect frame = self.bounds;
    self.scrollView.contentOffset = CGPointMake(CGRectGetWidth(frame), 0.0f);
    self.contentView.frame = CGRectMake(CGRectGetWidth(frame), 0.0f, CGRectGetWidth(frame), CGRectGetHeight(frame));
    self.scrollView.frame = frame;
    self.scrollView.contentSize = CGSizeMake(CGRectGetWidth(frame) * 3.0f, CGRectGetHeight(frame));
    self.rightPanel.frame = CGRectMake(CGRectGetWidth(frame) * 2.0f, 0.0f, CGRectGetWidth(frame), CGRectGetHeight(frame));
    [self layoutButtonsForView:self.rightPanel];
}

#pragma mark setButtons
- (void)addButton:(UIButton *)button toView:(UIView *)view
{
    NSInteger buttonCount = [view.subviews count];
    
    if (buttonCount >= kButtonMax)  //if too many buttons, no effect.
    {
        return;
    }
    
    CGFloat origin = buttonCount * kButtonWidth;
    button.frame = CGRectMake(origin, 0.0f, kButtonWidth, CGRectGetHeight(view.bounds));
    [view addSubview:button];
}

- (void)setButtons:(NSArray *)buttons forView:(UIView *)view
{
    for (UIButton *button in view.subviews) //clean all the subviews.
    {
        [button removeFromSuperview];
    }
    
    for (UIButton *button in buttons) //add all the buttons.
    {
        [self addButton:button toView:view];
    }
}

- (void)setRightPanelButtons:(NSArray *)buttons
{
    [self setButtons:buttons forView:self.rightPanel];
}

- (void)layoutButtonsForView:(UIView *)view
{
    CGFloat offset = 0.0;
    for (UIButton *button in view.subviews)
    {
        CGRect rect = CGRectMake(offset, 0.0, kButtonWidth, CGRectGetHeight(view.bounds));
        button.frame = rect;
        offset += kButtonWidth;
    }
}

#pragma mark - ScrollView delgate
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self postViewPresenterDraggedNotification];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
        CGFloat move = CGRectGetMinX(self.contentView.frame);
        //Error check First.
        if (kCloseThreshold + kDeleteThreshold >= move)
        {
            NSLog(@"[WARNING], kCloseThreshold + kDeleteThreshold must less than the width of the cell!");
        }
        else if (kCloseThreshold + kButtonWidth * self.rightPanel.subviews.count >= move)
        {
            NSLog(@"[WARNING], Right panel is within close threshold, disabling swip to delete");
            self.enableSwipeToDelete = NO;
        }
        NSLog(@"float is %f, move is %f",scrollView.contentOffset.x, move);
        //Dragging logic
        if ( self.enableSwipeToDelete && (scrollView.contentOffset.x > ( 2.0f * move - kDeleteThreshold)) )  //if delete dragging triggered.
        {
            [UIView animateWithDuration:0.2 animations:^{
                scrollView.contentOffset = CGPointMake(CGRectGetMaxX(self.contentView.frame), 0.0);
            } completion:^(BOOL finished) {
                [self.delegate KHSwipeViewPresenterDidSwipeOut:self];
            }];
        }
        else if (scrollView.contentOffset.x < move + kCloseThreshold)   //else if content offset within close range.
        {
            [self configureScrollViewOffset:move animated:YES];
        }
        else  //open
        {
            CGFloat offset = move + kButtonWidth * self.rightPanel.subviews.count;
            [self configureScrollViewOffset:offset animated:YES];
        }
}

//Disable deceleration.
-(void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView{
    [scrollView setContentOffset:scrollView.contentOffset animated:YES];
}

#pragma mark - Helpers
//helper, remove redundant code.
- (void)configureScrollViewOffset:(CGFloat)offset animated:(BOOL)animated
{
    if (animated)
    {
        [UIView animateWithDuration:0.2 animations:^{
            self.scrollView.contentOffset = CGPointMake(offset, 0.0);
        }];
    }
    else
    {
        self.scrollView.contentOffset = CGPointMake(offset, 0.0);
    }
}

- (void)resetSwipeViewPresenterAnimated:(BOOL)animated
{
     CGFloat move = CGRectGetMinX(self.contentView.frame);
    [self configureScrollViewOffset:move animated:animated];
}

- (BOOL)isClosed //return if the right panel is closed.
{
    CGFloat move = CGRectGetMinX(self.contentView.frame);
    return (self.scrollView.contentOffset.x == move);
}

#pragma mark - Notifications
- (void)registerNotificatoins
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewPresenterDragged:) name:KHViewPresenterDraggedNotification object:nil];
}

- (void)postViewPresenterDraggedNotification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:KHViewPresenterDraggedNotification object:self];
}

#pragma mark - overide responder chain.
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self postViewPresenterDraggedNotification];
    if (![self isClosed])
    {
        [self resetSwipeViewPresenterAnimated:YES];
        return;
    }
    [self.nextResponder touchesBegan:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.nextResponder touchesEnded:touches withEvent:event];
}

#pragma mark - selector
- (void)touchDownOnViewPresenter:(id)sender
{
    [self resetSwipeViewPresenterAnimated:YES];
}

- (void)viewPresenterDragged:(NSNotification *)sender
{
    KHSwipeViewPresenter *VP = (KHSwipeViewPresenter *)sender.object;
    if (VP != self && (VP.superview.superview.superview == self.superview.superview.superview))
    {
        [self resetSwipeViewPresenterAnimated:YES];
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
