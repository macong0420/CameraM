//
//  CMFilmLookOperations.h
//  CameraM
//
//  Created by OpenAI Assistant on 2024/4/6.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ARFilterOperation.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct {
  CGFloat startHue;
  CGFloat endHue;
  CGFloat hueShift;
  CGFloat saturationScale;
  CGFloat luminanceShift;
} CMHSLAdjustment;

FOUNDATION_EXPORT CMHSLAdjustment CMHSLAdjustmentMake(CGFloat startHue,
                                                       CGFloat endHue,
                                                       CGFloat hueShift,
                                                       CGFloat saturationScale,
                                                       CGFloat luminanceShift);

@interface NSValue (CMFilmAdjustments)
+ (instancetype)valueWithCMHSLAdjustment:(CMHSLAdjustment)adjustment;
- (CMHSLAdjustment)cm_HSLAdjustmentValue;
@end

@interface CMFilmColorMatrixOperation : NSObject <ARFilterOperation>
- (instancetype)initWithRedVector:(CIVector *)redVector
                      greenVector:(CIVector *)greenVector
                       blueVector:(CIVector *)blueVector
                       biasVector:(CIVector *)biasVector
                  toneCurvePoints:(NSArray<CIVector *> *)points
                    microContrast:(CGFloat)microContrast;
@end

@interface CMFilmHSLRemapOperation : NSObject <ARFilterOperation>
- (instancetype)initWithAdjustments:(NSArray<NSValue *> *)adjustments
                      cubeDimension:(NSUInteger)dimension
                      skinHueCenter:(CGFloat)skinHueCenter
                       skinHueWidth:(CGFloat)skinHueWidth
                 skinPreserveFactor:(CGFloat)skinPreserveFactor;
@end

@interface CMFilmGrainOperation : NSObject <ARFilterOperation>
- (instancetype)initWithIntensity:(CGFloat)intensity
                      shadowWeight:(CGFloat)shadowWeight
                   highlightWeight:(CGFloat)highlightWeight
                         grainScale:(CGFloat)grainScale
                         monochrome:(BOOL)monochrome;

@property (nonatomic, assign) CGFloat intensity;
@end

@interface CMFilmHalationOperation : NSObject <ARFilterOperation>
- (instancetype)initWithThreshold:(CGFloat)threshold
                          softness:(CGFloat)softness
                            radius:(CGFloat)radius
                         intensity:(CGFloat)intensity
                         tintColor:(UIColor *)tintColor;
@end

@interface CMFilmVignetteOperation : NSObject <ARFilterOperation>
- (instancetype)initWithIntensity:(CGFloat)intensity
                            radius:(CGFloat)radius
                            center:(CGPoint)center;
@end

NS_ASSUME_NONNULL_END
