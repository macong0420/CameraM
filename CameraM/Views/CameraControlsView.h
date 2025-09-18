//
//  CameraControlsView.h
//  CameraM
//
//  Created by 马聪聪 on 2025/9/18.
//

#import <UIKit/UIKit.h>

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

// 相机控制
- (void)didTapFlashButton;
- (void)didTapGridButton;
- (void)didTapSwitchCameraButton;
- (void)didTapFrameWatermarkButton;
- (void)didTapSettingsButton;
- (void)didTapFilterButton;

// 专业控制
- (void)didChangeExposure:(float)value;

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
- (void)updateAspectRatioMask:(CameraAspectRatio)ratio;
- (void)updateAspectRatioSelection:(CameraAspectRatio)ratio;

// 横屏适配接口
- (void)updateLayoutForOrientation:(CameraDeviceOrientation)orientation;

@end

NS_ASSUME_NONNULL_END