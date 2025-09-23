//
//  WatermarkPanelView.h
//  CameraM
//
//  Created by Generated on 2025/9/18.
//

#import <UIKit/UIKit.h>
#import "CMWatermarkConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@class WatermarkPanelView;

@protocol WatermarkPanelViewDelegate <NSObject>

- (void)watermarkPanelDidRequestDismiss:(WatermarkPanelView *)panel;
- (void)watermarkPanel:(WatermarkPanelView *)panel didUpdateConfiguration:(CMWatermarkConfiguration *)configuration;

@end

@interface WatermarkPanelView : UIView

@property (nonatomic, weak) id<WatermarkPanelViewDelegate> delegate;
@property (nonatomic, strong, readonly) CMWatermarkConfiguration *configuration;

- (void)applyConfiguration:(CMWatermarkConfiguration *)configuration animated:(BOOL)animated;
- (void)setPanelEnabled:(BOOL)enabled animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
