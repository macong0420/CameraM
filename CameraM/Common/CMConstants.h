//
//  CMConstants.h
//  CameraM
//
//  统一常量管理
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - UserDefaults Keys

// 水印配置
FOUNDATION_EXPORT NSString *const kCMWatermarkConfigurationStorageKey;

// 镜头选择
FOUNDATION_EXPORT NSString *const kCMLensSelectionStorageKey;

// 闪光灯模式
FOUNDATION_EXPORT NSString *const kCMFlashModeStorageKey;

// 网格线可见性
FOUNDATION_EXPORT NSString *const kCMGridVisibilityStorageKey;

// 分辨率模式
FOUNDATION_EXPORT NSString *const kCMResolutionModeStorageKey;

#pragma mark - Error Domains

FOUNDATION_EXPORT NSString *const kCMBusinessControllerErrorDomain;
FOUNDATION_EXPORT NSString *const kCMCameraManagerErrorDomain;
FOUNDATION_EXPORT NSString *const kCMPermissionManagerErrorDomain;

#pragma mark - UI Constants

// Mode Selector
FOUNDATION_EXPORT const CGFloat CMModeSelectorWidth;

// Animation Durations
FOUNDATION_EXPORT const NSTimeInterval CMDefaultAnimationDuration;
FOUNDATION_EXPORT const NSTimeInterval CMQuickAnimationDuration;
FOUNDATION_EXPORT const NSTimeInterval CMFlashEffectDuration;

// Control Sizes
FOUNDATION_EXPORT const CGFloat CMCaptureButtonSize;
FOUNDATION_EXPORT const CGFloat CMControlButtonSize;
FOUNDATION_EXPORT const CGFloat CMTopControlsHeight;
FOUNDATION_EXPORT const CGFloat CMBottomControlsHeight;

NS_ASSUME_NONNULL_END
