//
//  CMLocationService.m
//  CameraM
//
//  位置服务模块实现
//

#import "CMLocationService.h"
#import <ImageIO/ImageIO.h>

@interface CMLocationService () <CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong, readwrite) CLLocation *latestLocation;

@end

@implementation CMLocationService

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        // 延迟初始化到configure调用
    }
    return self;
}

- (void)configure {
    if (![CLLocationManager locationServicesEnabled]) {
        NSLog(@"⚠️ [CMLocationService] Location services not available");
        return;
    }

    if (!self.locationManager) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        self.locationManager.distanceFilter = 3.0;
        self.locationManager.pausesLocationUpdatesAutomatically = YES;
    }

    CLAuthorizationStatus status = [self authorizationStatus];
    [self handleAuthorizationStatus:status];
}

- (void)dealloc {
    [self stopUpdatingLocation];
}

#pragma mark - Public Methods

- (void)startUpdatingLocation {
    if (!self.locationManager || ![CLLocationManager locationServicesEnabled]) {
        return;
    }

    CLAuthorizationStatus status = [self authorizationStatus];

    if (status == kCLAuthorizationStatusAuthorizedWhenInUse ||
        status == kCLAuthorizationStatusAuthorizedAlways
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 140000
        || status == kCLAuthorizationStatusAuthorized
#endif
    ) {
        [self.locationManager startUpdatingLocation];
    }
}

- (void)stopUpdatingLocation {
    if (!self.locationManager) {
        return;
    }
    [self.locationManager stopUpdatingLocation];
}

- (BOOL)isLocationServicesAvailable {
    return [CLLocationManager locationServicesEnabled];
}

#pragma mark - Location Validation

- (BOOL)isValidLocation:(CLLocation *)location {
    if (!location) {
        return NO;
    }
    if (location.horizontalAccuracy < 0.0) {
        return NO;
    }
    // 位置信息5分钟内有效
    NSTimeInterval age = fabs([location.timestamp timeIntervalSinceNow]);
    return age <= 300.0;
}

- (NSDictionary *)gpsDictionaryForLocation:(CLLocation *)location {
    if (![self isValidLocation:location]) {
        return nil;
    }

    NSMutableDictionary *gps = [NSMutableDictionary dictionary];
    CLLocationCoordinate2D coordinate = location.coordinate;

    // 经纬度
    double latitude = fabs(coordinate.latitude);
    double longitude = fabs(coordinate.longitude);
    gps[(NSString *)kCGImagePropertyGPSLatitude] = @(latitude);
    gps[(NSString *)kCGImagePropertyGPSLatitudeRef] =
        (coordinate.latitude >= 0.0) ? @"N" : @"S";
    gps[(NSString *)kCGImagePropertyGPSLongitude] = @(longitude);
    gps[(NSString *)kCGImagePropertyGPSLongitudeRef] =
        (coordinate.longitude >= 0.0) ? @"E" : @"W";

    // 海拔
    double altitude = location.altitude;
    gps[(NSString *)kCGImagePropertyGPSAltitude] = @(fabs(altitude));
    gps[(NSString *)kCGImagePropertyGPSAltitudeRef] = (altitude < 0.0) ? @1 : @0;

    // 时间戳
    static NSDateFormatter *dateFormatter = nil;
    static NSDateFormatter *timeFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateFormat = @"yyyy:MM:dd";
        dateFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];

        timeFormatter = [[NSDateFormatter alloc] init];
        timeFormatter.dateFormat = @"HH:mm:ss.SSS";
        timeFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        timeFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    });

    NSDate *timestamp = location.timestamp ?: [NSDate date];
    gps[(NSString *)kCGImagePropertyGPSDateStamp] =
        [dateFormatter stringFromDate:timestamp];
    gps[(NSString *)kCGImagePropertyGPSTimeStamp] =
        [timeFormatter stringFromDate:timestamp];

    // 精度
    if (location.horizontalAccuracy >= 0.0) {
        gps[(NSString *)kCGImagePropertyGPSDOP] =
            @(MAX(location.horizontalAccuracy, 1.0));
    }

    // 速度
    if (location.speed >= 0.0) {
        double speedKmh = location.speed * 3.6;
        gps[(NSString *)kCGImagePropertyGPSSpeed] = @(speedKmh);
        gps[(NSString *)kCGImagePropertyGPSSpeedRef] = @"K";
    }

    // 方向
    if (location.course >= 0.0) {
        gps[(NSString *)kCGImagePropertyGPSTrack] = @(location.course);
        gps[(NSString *)kCGImagePropertyGPSTrackRef] = @"T";
    }

    return [gps copy];
}

#pragma mark - Private Methods

- (CLAuthorizationStatus)authorizationStatus {
    if (@available(iOS 14.0, *)) {
        return self.locationManager.authorizationStatus;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [CLLocationManager authorizationStatus];
#pragma clang diagnostic pop
}

- (void)handleAuthorizationStatus:(CLAuthorizationStatus)status {
    switch (status) {
        case kCLAuthorizationStatusNotDetermined:
            [self.locationManager requestWhenInUseAuthorization];
            break;

#if __IPHONE_OS_VERSION_MIN_REQUIRED < 140000
        case kCLAuthorizationStatusAuthorized:
#endif
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            [self startUpdatingLocation];
            break;

        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted:
            [self stopUpdatingLocation];
            self.latestLocation = nil;
            break;

        default:
            break;
    }

    // 通知delegate
    if ([self.delegate respondsToSelector:@selector(locationService:didChangeAuthorizationStatus:)]) {
        [self.delegate locationService:self didChangeAuthorizationStatus:status];
    }
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    CLAuthorizationStatus status = [self authorizationStatus];
    [self handleAuthorizationStatus:status];
}

#if __IPHONE_OS_VERSION_MIN_REQUIRED < 140000
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (void)locationManager:(CLLocationManager *)manager
    didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    [self handleAuthorizationStatus:status];
}
#pragma clang diagnostic pop
#endif

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations {
    CLLocation *latest = locations.lastObject;
    if ([self isValidLocation:latest]) {
        self.latestLocation = latest;

        if ([self.delegate respondsToSelector:@selector(locationService:didUpdateLocation:)]) {
            [self.delegate locationService:self didUpdateLocation:latest];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error {
    NSLog(@"⚠️ [CMLocationService] Location update failed: %@", error.localizedDescription);

    if ([self.delegate respondsToSelector:@selector(locationService:didFailWithError:)]) {
        [self.delegate locationService:self didFailWithError:error];
    }
}

@end
