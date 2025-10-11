//
//  CMSettingsStorage.m
//  CameraM
//

#import "CMSettingsStorage.h"
#import "CMConstants.h"
#import "../Models/CMWatermarkConfiguration.h"

@implementation CMSettingsStorage

+ (instancetype)sharedStorage {
    static CMSettingsStorage *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[CMSettingsStorage alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Watermark Configuration

- (void)saveWatermarkConfiguration:(CMWatermarkConfiguration *)configuration {
    if (!configuration) {
        return;
    }

    NSError *archiveError = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:configuration
                                         requiringSecureCoding:YES
                                                         error:&archiveError];
    if (data && !archiveError) {
        [[NSUserDefaults standardUserDefaults] setObject:data
                                                  forKey:kCMWatermarkConfigurationStorageKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else if (archiveError) {
        NSLog(@"⚠️ [CMSettingsStorage] Failed to save watermark configuration: %@",
              archiveError.localizedDescription);
    }
}

- (CMWatermarkConfiguration *)loadWatermarkConfiguration {
    NSData *storedData = [[NSUserDefaults standardUserDefaults]
                          objectForKey:kCMWatermarkConfigurationStorageKey];
    if (!storedData) {
        return nil;
    }

    NSError *unarchiveError = nil;
    CMWatermarkConfiguration *storedConfig = [NSKeyedUnarchiver
        unarchivedObjectOfClass:[CMWatermarkConfiguration class]
                       fromData:storedData
                          error:&unarchiveError];

    if (unarchiveError) {
        NSLog(@"⚠️ [CMSettingsStorage] Failed to load watermark configuration: %@",
              unarchiveError.localizedDescription);
        return nil;
    }

    return storedConfig;
}

#pragma mark - Camera Settings

- (void)saveFlashMode:(FlashMode)mode {
    [[NSUserDefaults standardUserDefaults] setInteger:mode
                                               forKey:kCMFlashModeStorageKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (FlashMode)loadFlashModeWithDefault:(FlashMode)defaultMode {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:kCMFlashModeStorageKey] == nil) {
        return defaultMode;
    }

    NSInteger rawValue = [defaults integerForKey:kCMFlashModeStorageKey];
    FlashMode storedMode = (FlashMode)rawValue;

    if (storedMode < FlashModeAuto || storedMode > FlashModeOff) {
        return defaultMode;
    }

    return storedMode;
}

- (void)saveResolutionMode:(CameraResolutionMode)mode {
    [[NSUserDefaults standardUserDefaults] setInteger:mode
                                               forKey:kCMResolutionModeStorageKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (CameraResolutionMode)loadResolutionModeWithDefault:(CameraResolutionMode)defaultMode {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:kCMResolutionModeStorageKey] == nil) {
        return defaultMode;
    }

    NSInteger rawValue = [defaults integerForKey:kCMResolutionModeStorageKey];
    return (CameraResolutionMode)rawValue;
}

- (void)saveGridVisibility:(BOOL)visible {
    [[NSUserDefaults standardUserDefaults] setBool:visible
                                            forKey:kCMGridVisibilityStorageKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)loadGridVisibilityWithDefault:(BOOL)defaultValue {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:kCMGridVisibilityStorageKey] == nil) {
        return defaultValue;
    }

    return [defaults boolForKey:kCMGridVisibilityStorageKey];
}

#pragma mark - Lens Selection

- (void)saveLensIdentifier:(NSString *)identifier {
    if (identifier.length == 0) {
        [self clearLensIdentifier];
        return;
    }

    [[NSUserDefaults standardUserDefaults] setObject:identifier
                                               forKey:kCMLensSelectionStorageKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)loadLensIdentifier {
    return [[NSUserDefaults standardUserDefaults]
            stringForKey:kCMLensSelectionStorageKey];
}

- (void)clearLensIdentifier {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kCMLensSelectionStorageKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
