#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "../Managers/CameraManager.h"

NS_ASSUME_NONNULL_BEGIN

@protocol CMCaptureSessionServicing <NSObject>

@property (nonatomic, weak, nullable) id<CameraManagerDelegate> delegate;

@property (nonatomic, readonly) CameraState currentState;
@property (nonatomic, readonly) CameraPosition currentPosition;
@property (nonatomic, readonly) CameraResolutionMode currentResolutionMode;
@property (nonatomic, readonly) FlashMode currentFlashMode;
@property (nonatomic, readonly) CameraAspectRatio currentAspectRatio;
@property (nonatomic, readonly) CameraDeviceOrientation currentDeviceOrientation;
@property (nonatomic, readonly) BOOL isUltraHighResolutionSupported;
@property (nonatomic, readonly) NSArray<CMCameraLensOption *> *availableLensOptions;
@property (nonatomic, readonly) CMCameraLensOption *currentLensOption;
@property (nonatomic, readonly) AVCaptureVideoPreviewLayer *previewLayer;

- (void)setupCameraWithPreviewView:(UIView *)previewView
                        completion:(void (^)(BOOL success,
                                             NSError *_Nullable error))completion;
- (void)startSession;
- (void)stopSession;
- (void)cleanup;

- (void)startDeviceOrientationMonitoring;
- (void)stopDeviceOrientationMonitoring;

- (void)capturePhoto;
- (void)switchCamera;
- (void)switchResolutionMode:(CameraResolutionMode)mode;
- (void)switchFlashMode:(FlashMode)mode;
- (void)switchAspectRatio:(CameraAspectRatio)ratio;
- (void)switchToLensOption:(CMCameraLensOption *)lensOption;
- (void)focusAtPoint:(CGPoint)devicePoint;
- (void)setExposureCompensation:(float)value;

- (CGRect)cropRectForAspectRatio:(CameraAspectRatio)ratio inImageSize:(CGSize)imageSize;
- (UIImage *)cropImage:(UIImage *)image toAspectRatio:(CameraAspectRatio)ratio;
- (CGRect)previewRectForAspectRatio:(CameraAspectRatio)ratio inViewSize:(CGSize)viewSize;
- (CGRect)activeFormatPreviewRectInViewSize:(CGSize)viewSize;
- (CGFloat)aspectRatioValueForRatio:(CameraAspectRatio)ratio
                    inOrientation:(CameraDeviceOrientation)orientation;

- (void)saveImageToPhotosLibrary:(UIImage *)image
                        metadata:(nullable NSDictionary *)metadata
                       completion:(void (^)(BOOL success,
                                            NSError *_Nullable error))completion;

@end

@interface CMCaptureSessionService : NSObject <CMCaptureSessionServicing>

- (instancetype)initWithCameraManager:(CameraManager *)manager NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

