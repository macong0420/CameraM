//
//  CMConstants.m
//  CameraM
//

#import "CMConstants.h"

#pragma mark - UserDefaults Keys

NSString *const kCMWatermarkConfigurationStorageKey = @"com.cameram.watermark.configuration";
NSString *const kCMLensSelectionStorageKey = @"com.cameram.lens.selection";
NSString *const kCMFlashModeStorageKey = @"com.cameram.flash.mode";
NSString *const kCMGridVisibilityStorageKey = @"com.cameram.grid.visibility";
NSString *const kCMResolutionModeStorageKey = @"com.cameram.resolution.mode";

#pragma mark - Error Domains

NSString *const kCMBusinessControllerErrorDomain = @"com.cameram.business";
NSString *const kCMCameraManagerErrorDomain = @"com.cameram.camera";
NSString *const kCMPermissionManagerErrorDomain = @"com.cameram.permission";

#pragma mark - UI Constants

const CGFloat CMModeSelectorWidth = 60.0f;
const NSTimeInterval CMDefaultAnimationDuration = 0.3;
const NSTimeInterval CMQuickAnimationDuration = 0.2;
const NSTimeInterval CMFlashEffectDuration = 0.1;
const CGFloat CMCaptureButtonSize = 70.0f;
const CGFloat CMControlButtonSize = 44.0f;
const CGFloat CMTopControlsHeight = 80.0f;
const CGFloat CMBottomControlsHeight = 150.0f;
