/*
 * @Author: 马聪聪 macong0420@126.com
 * @Date: 2025-09-24 17:02:01
 * @LastEditors: 马聪聪 macong0420@126.com
 * @LastEditTime: 2025-09-26 15:58:38
 * @FilePath: /CameraM/CameraM/Views/CameraControlsView.h
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
 */
//
//  CameraControlsView.h
//  CameraM
//
//  Created by 马聪聪 on 2025/9/18.
//

#import <UIKit/UIKit.h>
#import "CMWatermarkConfiguration.h"
#import "CMCameraLensOption.h"

NS_ASSUME_NONNULL_BEGIN

// 前向声明，引用CameraManager中的定义
@class CameraManager;
typedef NS_ENUM(NSInteger, CameraAspectRatio);
typedef NS_ENUM(NSInteger, CameraDeviceOrientation);

// UI事件代理协议
@protocol CameraControlsDelegate <NSObject>

@optional
// 拍摄相关
- (void)didTapCaptureButton;
- (void)didTapGalleryButton;
- (void)didSelectMode:(NSInteger)modeIndex;
- (void)didSelectAspectRatio:(CameraAspectRatio)ratio;
- (void)didTapResolutionMode;

// 相机控制
- (void)didTapFlashButton;
- (void)didTapGridButton;
- (void)didTapSwitchCameraButton;
- (void)didTapFrameWatermarkButton;
- (void)didTapSettingsButton;
- (void)didSelectLensOption:(CMCameraLensOption *)lensOption;

// 专业控制
- (void)didChangeExposure:(float)value;

// 水印设置
- (void)didUpdateWatermarkConfiguration:(CMWatermarkConfiguration *)configuration;
- (void)didChangeWatermarkPanelVisibility:(BOOL)isVisible;

// 预览交互
- (void)didTapPreviewAtPoint:(CGPoint)point;
- (void)didDoubleTapPreview;

// 设备方向变化
- (void)didChangeDeviceOrientation:(CameraDeviceOrientation)orientation;

@end

@interface CameraControlsView : UIView

@property (nonatomic, weak) id<CameraControlsDelegate> delegate;

// UI组件访问接口
@property (nonatomic, readonly) UIView *previewContainer;
@property (nonatomic, readonly) UIButton *captureButton;
@property (nonatomic, readonly) UIButton *flashButton;
@property (nonatomic, readonly) UIButton *gridButton;

// 状态更新接口
- (void)updateResolutionMode:(NSString *)modeText highlighted:(BOOL)highlighted;
- (void)updateFlashMode:(NSString *)modeText highlighted:(BOOL)highlighted;
- (void)updateFrameWatermarkStatus:(BOOL)enabled;
- (void)updateGalleryButtonWithImage:(UIImage * _Nullable)image;
- (void)showGridLines:(BOOL)show;
- (void)showFocusIndicatorAtPoint:(CGPoint)point;
- (void)setCaptureButtonLoading:(BOOL)isLoading;
- (void)setCaptureButtonEnabled:(BOOL)enabled;
- (void)updateAspectRatioMask:(CameraAspectRatio)ratio;
- (void)updatePreviewVideoRect:(CGRect)videoRect;
- (void)updateAspectRatioSelection:(CameraAspectRatio)ratio;
- (void)updateLensOptions:(NSArray<CMCameraLensOption *> *)lensOptions currentLens:(CMCameraLensOption * _Nullable)currentLens;
- (void)setResolutionModeEnabled:(BOOL)enabled;

// 横屏适配接口
- (void)updateLayoutForOrientation:(CameraDeviceOrientation)orientation;

// 水印
- (void)applyWatermarkConfiguration:(CMWatermarkConfiguration *)configuration;
- (void)presentWatermarkPanel;
- (void)dismissWatermarkPanel;
- (BOOL)isWatermarkPanelVisible;

@end

NS_ASSUME_NONNULL_END
