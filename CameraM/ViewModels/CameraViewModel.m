#import "CameraViewModel.h"
#import "../Controllers/CameraBusinessController.h"

@implementation CMCameraControlDisplayState
@end

@interface CameraViewModel ()

@property (nonatomic, strong, readwrite)
    CameraBusinessController *businessController;

@end

@implementation CameraViewModel

- (instancetype)initWithBusinessController:
    (CameraBusinessController *)businessController {
  NSParameterAssert(businessController);
  self = [super init];
  if (self) {
    _businessController = businessController;
  }
  return self;
}

- (CMCameraControlDisplayState *)currentControlDisplayState {
  CMCameraControlDisplayState *state =
      [[CMCameraControlDisplayState alloc] init];

  CameraResolutionMode mode = self.businessController.currentResolutionMode;
  state.resolutionText = (mode == CameraResolutionModeUltraHigh) ? @"48MP"
                                                                 : @"12MP";
  state.resolutionHighlighted = (mode == CameraResolutionModeUltraHigh);

  FlashMode flashMode = self.businessController.currentFlashMode;
  switch (flashMode) {
  case FlashModeAuto:
    state.flashText = @"AUTO";
    break;
  case FlashModeOn:
    state.flashText = @"ON";
    break;
  case FlashModeOff:
    state.flashText = @"OFF";
    break;
  }
  state.flashHighlighted = (flashMode == FlashModeOn);

  return state;
}

@end

