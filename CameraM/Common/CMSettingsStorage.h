//
//  CMSettingsStorage.h
//  CameraM
//
//  统一设置存储管理
//

#import <Foundation/Foundation.h>
#import "../Managers/CameraManager.h"

NS_ASSUME_NONNULL_BEGIN

@class CMWatermarkConfiguration;

@interface CMSettingsStorage : NSObject

+ (instancetype)sharedStorage;

#pragma mark - Watermark Configuration

- (void)saveWatermarkConfiguration:(CMWatermarkConfiguration *)configuration;
- (CMWatermarkConfiguration * _Nullable)loadWatermarkConfiguration;

#pragma mark - Camera Settings

- (void)saveFlashMode:(FlashMode)mode;
- (FlashMode)loadFlashModeWithDefault:(FlashMode)defaultMode;

- (void)saveResolutionMode:(CameraResolutionMode)mode;
- (CameraResolutionMode)loadResolutionModeWithDefault:(CameraResolutionMode)defaultMode;

- (void)saveGridVisibility:(BOOL)visible;
- (BOOL)loadGridVisibilityWithDefault:(BOOL)defaultValue;

#pragma mark - Lens Selection

- (void)saveLensIdentifier:(NSString * _Nullable)identifier;
- (NSString * _Nullable)loadLensIdentifier;
- (void)clearLensIdentifier;

@end

NS_ASSUME_NONNULL_END
