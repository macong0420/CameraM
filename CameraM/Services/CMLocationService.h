//
//  CMLocationService.h
//  CameraM
//
//  位置服务模块 - 从CameraManager拆分
//  职责: GPS定位、位置权限管理、位置有效性验证
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@class CMLocationService;

@protocol CMLocationServiceDelegate <NSObject>

@optional
- (void)locationService:(CMLocationService *)service
     didUpdateLocation:(CLLocation *)location;
- (void)locationService:(CMLocationService *)service
       didFailWithError:(NSError *)error;
- (void)locationService:(CMLocationService *)service
    didChangeAuthorizationStatus:(CLAuthorizationStatus)status;

@end

@interface CMLocationService : NSObject

@property (nonatomic, weak) id<CMLocationServiceDelegate> delegate;
@property (nonatomic, readonly, strong, nullable) CLLocation *latestLocation;
@property (nonatomic, readonly) BOOL isLocationServicesAvailable;

#pragma mark - Lifecycle

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (void)configure;
- (void)dealloc;

#pragma mark - Location Updates

- (void)startUpdatingLocation;
- (void)stopUpdatingLocation;

#pragma mark - Location Validation

- (BOOL)isValidLocation:(CLLocation * _Nullable)location;
- (NSDictionary * _Nullable)gpsDictionaryForLocation:(CLLocation * _Nullable)location;

@end

NS_ASSUME_NONNULL_END
