//
//  RMInstructionView.h
//  Romo
//

#import <UIKit/UIKit.h>
#import "RMParameter.h"

@class RMAction;

#define actionViewHeight 142
#define actionViewYGap (actionViewHeight + 8.0)

@protocol RMActionViewDelegate;

@interface RMActionView : UIView

@property (nonatomic, weak) id<RMActionViewDelegate> delegate;

/** This view crops to the shape of the blue bubble when collapsed, full-screen when expanded */
@property (nonatomic, strong) UIView *contentView;

/** Title of this action, e.g. "Drive forward" */
@property (nonatomic, copy) NSString *title;

/** Subtitle of this action, e.g. "75% speed" */
@property (nonatomic, copy) NSString *subtitle;

/** This action's position in the script */
@property (nonatomic) int number;

/** If relevant, the paramter values for this action */
@property (nonatomic, strong) NSArray *parameters;

/** Shows a glow around the action view */
@property (nonatomic, getter=isGlowing) BOOL glowing;

@property (nonatomic) BOOL allowsDeletingActions;

/**
 When false, shows a collapsed bubble view
 When true, shows a full-screen editor for the action
 */
@property (nonatomic, getter=isEditing) BOOL editing;

@property (nonatomic, getter=isHighlighted) BOOL highlighted;

/** Whether we disallow parameter editing */
@property (nonatomic, getter=isLocked) BOOL locked;

/** Builds the proper view for the given title */
- (RMActionView *)initWithTitle:(NSString *)title;

- (void)startAnimating;
- (void)stopAnimating;

- (void)willLayoutForEditing:(BOOL)editing;
- (void)didLayoutForEditing:(BOOL)editing;

@end

@protocol RMActionViewDelegate <NSObject>

- (void)actionViewDidDelete:(RMActionView *)actionView;
- (void)actionViewDidTouchConfirm:(RMActionView *)actionView;
- (void)actionView:(RMActionView *)actionView didDragByOffset:(CGPoint)offset fromOrigin:(CGPoint)origin;
- (void)actionView:(RMActionView *)actionView didEndDragging:(CGPoint)offset fromOrigin:(CGPoint)origin;
- (void)toggleEditingForActionView:(RMActionView *)actionView;

@end