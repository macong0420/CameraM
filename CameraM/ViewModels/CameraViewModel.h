#import <Foundation/Foundation.h>
#import "../Managers/CameraManager.h"

NS_ASSUME_NONNULL_BEGIN

@class CameraBusinessController;

@interface CMCameraControlDisplayState : NSObject

@property (nonatomic, copy) NSString *resolutionText;
@property (nonatomic, assign) BOOL resolutionHighlighted;
@property (nonatomic, copy) NSString *flashText;
@property (nonatomic, assign) BOOL flashHighlighted;

@end

@interface CameraViewModel : NSObject

- (instancetype)initWithBusinessController:
    (CameraBusinessController *)businessController NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) CameraBusinessController *businessController;

- (CMCameraControlDisplayState *)currentControlDisplayState;

@end

NS_ASSUME_NONNULL_END
