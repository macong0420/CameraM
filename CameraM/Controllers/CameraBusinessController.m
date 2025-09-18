//
//  CameraBusinessController.m
//  CameraM
//
//  Created by 马聪聪 on 2025/9/18.
//

#import "CameraBusinessController.h"

@interface CameraBusinessController () <CameraManagerDelegate>

@property (nonatomic, strong) CameraManager *cameraManager;
@property (nonatomic, strong) UIImage *latestCapturedImage;
@property (nonatomic, assign) BOOL isGridLinesVisible;

@end

@implementation CameraBusinessController

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupCameraManager];
        _isGridLinesVisible = NO;
    }
    return self;
}

#pragma mark - 私有方法

- (void)setupCameraManager {
    self.cameraManager = [CameraManager sharedManager];
    self.cameraManager.delegate = self;
}

#pragma mark - 状态查询接口

- (CameraResolutionMode)currentResolutionMode {
    return self.cameraManager.currentResolutionMode;
}

- (FlashMode)currentFlashMode {
    return self.cameraManager.currentFlashMode;
}

- (BOOL)isUltraHighResolutionSupported {
    return self.cameraManager.isUltraHighResolutionSupported;
}

#pragma mark - 相机控制接口

- (void)setupCameraWithPreviewView:(UIView *)previewView completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    [self.cameraManager setupCameraWithPreviewView:previewView completion:completion];
}

- (void)startSession {
    [self.cameraManager startSession];
}

- (void)stopSession {
    [self.cameraManager stopSession];
}

- (void)cleanup {
    [self.cameraManager cleanup];
}

#pragma mark - 拍摄控制

- (void)capturePhoto {
    [self.cameraManager capturePhoto];
}

- (void)switchCamera {
    [self.cameraManager switchCamera];
}

- (void)switchResolutionMode {
    CameraResolutionMode currentMode = self.cameraManager.currentResolutionMode;
    CameraResolutionMode newMode = (currentMode == CameraResolutionModeStandard) ? CameraResolutionModeUltraHigh : CameraResolutionModeStandard;
    
    if (newMode == CameraResolutionModeUltraHigh && !self.cameraManager.isUltraHighResolutionSupported) {
        return; // 不支持高分辨率
    }
    
    [self.cameraManager switchResolutionMode:newMode];
}

- (void)switchFlashMode {
    FlashMode currentMode = self.cameraManager.currentFlashMode;
    FlashMode nextMode;
    
    switch (currentMode) {
        case FlashModeAuto:
            nextMode = FlashModeOn;
            break;
        case FlashModeOn:
            nextMode = FlashModeOff;
            break;
        case FlashModeOff:
            nextMode = FlashModeAuto;
            break;
    }
    
    [self.cameraManager switchFlashMode:nextMode];
}

#pragma mark - 对焦和曝光

- (void)focusAtPoint:(CGPoint)screenPoint withPreviewLayer:(AVCaptureVideoPreviewLayer *)previewLayer {
    // 转换屏幕坐标到设备坐标
    CGPoint devicePoint = [previewLayer captureDevicePointOfInterestForPoint:screenPoint];
    [self.cameraManager focusAtPoint:devicePoint];
}

- (void)setExposureCompensation:(float)value {
    [self.cameraManager setExposureCompensation:value];
}

#pragma mark - 网格线状态管理

- (void)toggleGridLines {
    self.isGridLinesVisible = !self.isGridLinesVisible;
}

- (BOOL)isGridLinesVisible {
    return _isGridLinesVisible;
}

#pragma mark - CameraManagerDelegate

- (void)cameraManager:(CameraManager *)manager didChangeState:(CameraState)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL shouldEnable = (state == CameraStateRunning);
        
        if ([self.delegate respondsToSelector:@selector(shouldUpdateCaptureButtonEnabled:)]) {
            [self.delegate shouldUpdateCaptureButtonEnabled:shouldEnable];
        }
    });
}

- (void)cameraManager:(CameraManager *)manager didCapturePhoto:(UIImage *)image withMetadata:(NSDictionary *)metadata {
    // 保存最新照片
    self.latestCapturedImage = image;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(didCapturePhoto:withMetadata:)]) {
            [self.delegate didCapturePhoto:image withMetadata:metadata];
        }
        
        if ([self.delegate respondsToSelector:@selector(shouldShowCaptureFlashEffect)]) {
            [self.delegate shouldShowCaptureFlashEffect];
        }
    });
}

- (void)cameraManager:(CameraManager *)manager didFailWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(didFailWithError:)]) {
            [self.delegate didFailWithError:error];
        }
    });
}

- (void)cameraManager:(CameraManager *)manager didChangeResolutionMode:(CameraResolutionMode)mode {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(didChangeResolutionMode:)]) {
            [self.delegate didChangeResolutionMode:mode];
        }
    });
}

- (void)cameraManager:(CameraManager *)manager didChangeFlashMode:(FlashMode)mode {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(didChangeFlashMode:)]) {
            [self.delegate didChangeFlashMode:mode];
        }
    });
}

@end