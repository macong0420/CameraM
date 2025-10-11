//
//  CMPermissionManager.m
//  CameraM
//

#import "CMPermissionManager.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@implementation CMPermissionManager

+ (instancetype)sharedManager {
    static CMPermissionManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[CMPermissionManager alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Photo Library

- (CMPermissionStatus)photoLibraryAuthorizationStatus {
    PHAuthorizationStatus status;
    if (@available(iOS 14, *)) {
        status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelReadWrite];
    } else {
        status = [PHPhotoLibrary authorizationStatus];
    }

    return [self convertPHAuthorizationStatus:status];
}

- (void)requestPhotoLibraryPermission:(CMPermissionHandler)completion {
    if (@available(iOS 14, *)) {
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite
                                                   handler:^(PHAuthorizationStatus status) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion([self convertPHAuthorizationStatus:status]);
                }
            });
        }];
    } else {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion([self convertPHAuthorizationStatus:status]);
                }
            });
        }];
    }
}

- (BOOL)isPhotoLibraryAccessGranted {
    CMPermissionStatus status = [self photoLibraryAuthorizationStatus];
    return status == CMPermissionStatusAuthorized || status == CMPermissionStatusLimited;
}

- (CMPermissionStatus)convertPHAuthorizationStatus:(PHAuthorizationStatus)status {
    switch (status) {
        case PHAuthorizationStatusNotDetermined:
            return CMPermissionStatusNotDetermined;
        case PHAuthorizationStatusAuthorized:
            return CMPermissionStatusAuthorized;
        case PHAuthorizationStatusLimited:
            return CMPermissionStatusLimited;
        case PHAuthorizationStatusDenied:
            return CMPermissionStatusDenied;
        case PHAuthorizationStatusRestricted:
            return CMPermissionStatusRestricted;
    }
}

#pragma mark - Camera

- (CMPermissionStatus)cameraAuthorizationStatus {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    return [self convertAVAuthorizationStatus:status];
}

- (void)requestCameraPermission:(CMPermissionHandler)completion {
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
                             completionHandler:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                CMPermissionStatus status = granted ? CMPermissionStatusAuthorized : CMPermissionStatusDenied;
                completion(status);
            }
        });
    }];
}

- (BOOL)isCameraAccessGranted {
    return [self cameraAuthorizationStatus] == CMPermissionStatusAuthorized;
}

- (CMPermissionStatus)convertAVAuthorizationStatus:(AVAuthorizationStatus)status {
    switch (status) {
        case AVAuthorizationStatusNotDetermined:
            return CMPermissionStatusNotDetermined;
        case AVAuthorizationStatusAuthorized:
            return CMPermissionStatusAuthorized;
        case AVAuthorizationStatusDenied:
            return CMPermissionStatusDenied;
        case AVAuthorizationStatusRestricted:
            return CMPermissionStatusRestricted;
    }
}

#pragma mark - Helpers

- (void)showPermissionDeniedAlertForType:(NSString *)type
                      fromViewController:(UIViewController *)viewController {
    NSString *message = [NSString stringWithFormat:@"请在设置中允许CameraM访问%@。", type];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法访问"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
    [alert addAction:cancelAction];

    NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if ([[UIApplication sharedApplication] canOpenURL:settingsURL]) {
        UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:@"前往设置"
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *_Nonnull action) {
            [[UIApplication sharedApplication] openURL:settingsURL
                                              options:@{}
                                    completionHandler:nil];
        }];
        [alert addAction:settingsAction];
    }

    [viewController presentViewController:alert animated:YES completion:nil];
}

@end
