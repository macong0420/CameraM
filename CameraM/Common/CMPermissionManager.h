//
//  CMPermissionManager.h
//  CameraM
//
//  统一权限管理
//

#import <Foundation/Foundation.h>
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CMPermissionStatus) {
    CMPermissionStatusNotDetermined,
    CMPermissionStatusAuthorized,
    CMPermissionStatusLimited,
    CMPermissionStatusDenied,
    CMPermissionStatusRestricted
};

typedef void(^CMPermissionHandler)(CMPermissionStatus status);

@interface CMPermissionManager : NSObject

+ (instancetype)sharedManager;

#pragma mark - Photo Library

- (CMPermissionStatus)photoLibraryAuthorizationStatus;
- (void)requestPhotoLibraryPermission:(CMPermissionHandler)completion;
- (BOOL)isPhotoLibraryAccessGranted;

#pragma mark - Camera

- (CMPermissionStatus)cameraAuthorizationStatus;
- (void)requestCameraPermission:(CMPermissionHandler)completion;
- (BOOL)isCameraAccessGranted;

#pragma mark - Helpers

- (void)showPermissionDeniedAlertForType:(NSString *)type
                      fromViewController:(UIViewController *)viewController;

@end

NS_ASSUME_NONNULL_END
