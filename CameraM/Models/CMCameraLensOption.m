//
//  CMCameraLensOption.m
//  CameraM
//
//  Created by 自动生成 on 2025/9/23.
//

#import "CMCameraLensOption.h"

@implementation CMCameraLensOption

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (instancetype)optionWithIdentifier:(NSString *)identifier
                          displayName:(NSString *)displayName
                            zoomFactor:(CGFloat)zoomFactor
                        deviceUniqueID:(NSString *)deviceUniqueID {
    CMCameraLensOption *option = [[self alloc] initWithIdentifier:identifier
                                                       displayName:displayName
                                                         zoomFactor:zoomFactor
                                                     deviceUniqueID:deviceUniqueID];
    return option;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                       displayName:(NSString *)displayName
                         zoomFactor:(CGFloat)zoomFactor
                     deviceUniqueID:(NSString *)deviceUniqueID {
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _displayName = [displayName copy];
        _zoomFactor = zoomFactor;
        _deviceUniqueID = [deviceUniqueID copy];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    NSString *identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"] ?: @"lens.default";
    NSString *name = [coder decodeObjectOfClass:[NSString class] forKey:@"displayName"] ?: @"1x";
    CGFloat zoom = [coder containsValueForKey:@"zoomFactor"] ? [coder decodeDoubleForKey:@"zoomFactor"] : 1.0;
    NSString *deviceID = [coder decodeObjectOfClass:[NSString class] forKey:@"deviceUniqueID"] ?: @"";
    return [self initWithIdentifier:identifier
                         displayName:name
                           zoomFactor:zoom
                       deviceUniqueID:deviceID];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.identifier forKey:@"identifier"];
    [coder encodeObject:self.displayName forKey:@"displayName"];
    [coder encodeDouble:self.zoomFactor forKey:@"zoomFactor"];
    [coder encodeObject:self.deviceUniqueID forKey:@"deviceUniqueID"];
}

- (id)copyWithZone:(NSZone *)zone {
    return [[CMCameraLensOption allocWithZone:zone] initWithIdentifier:self.identifier
                                                           displayName:self.displayName
                                                             zoomFactor:self.zoomFactor
                                                         deviceUniqueID:self.deviceUniqueID];
}

- (BOOL)isEqual:(id)object {
    if (self == object) { return YES; }
    if (![object isKindOfClass:[CMCameraLensOption class]]) { return NO; }
    CMCameraLensOption *other = (CMCameraLensOption *)object;
    return [self.identifier isEqualToString:other.identifier] &&
           fabs(self.zoomFactor - other.zoomFactor) < 0.001f &&
           ((self.deviceUniqueID.length == 0 && other.deviceUniqueID.length == 0) || [self.deviceUniqueID isEqualToString:other.deviceUniqueID]);
}

- (NSUInteger)hash {
    return self.identifier.hash ^ @(round(self.zoomFactor * 10.0f)).unsignedIntegerValue ^ self.deviceUniqueID.hash;
}

@end
