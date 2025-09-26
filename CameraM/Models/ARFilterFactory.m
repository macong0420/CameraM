//
//  ARFilterFactory.m
//  CameraM
//
//  Created by Generated on 2025/9/26.
//

#import "ARFilterFactory.h"
#import "ARClassicBWOperation.h"
#import "ARFilterDescriptor.h"
#import "ARFilterPipeline.h"
#import "CMFilmLookOperations.h"
#import <UIKit/UIKit.h>

static inline CGFloat CMFClamp(CGFloat value, CGFloat minValue, CGFloat maxValue) {
  return MIN(MAX(value, minValue), maxValue);
}

static ARFilterDescriptor *CMCreateLeicaColorFilter(
    NSString *identifier, NSString *name, UIColor *accent,
    NSArray<CIVector *> *toneCurve, CIVector *redVector, CIVector *greenVector,
    CIVector *blueVector, CIVector *biasVector, CGFloat microContrast,
    NSArray<NSValue *> *hslAdjustments, NSUInteger cubeDimension,
    CGFloat skinHueCenter, CGFloat skinHueWidth, CGFloat skinPreserveFactor,
    CGFloat grainIntensity, CGFloat grainShadowWeight,
    CGFloat grainHighlightWeight, CGFloat grainScale, BOOL grainMonochrome,
    CGFloat halationThreshold, CGFloat halationSoftness, CGFloat halationRadius,
    CGFloat halationIntensity, UIColor *halationTint,
    CGFloat vignetteIntensity, CGFloat vignetteRadius, CGPoint vignetteCenter,
    CGFloat filterIntensity) {

  NSMutableArray<id<ARFilterOperation>> *operations =
      [NSMutableArray array];

  if (redVector && greenVector && blueVector && toneCurve.count >= 2) {
    CMFilmColorMatrixOperation *color =
        [[CMFilmColorMatrixOperation alloc]
            initWithRedVector:redVector
                   greenVector:greenVector
                    blueVector:blueVector
                    biasVector:biasVector ?: [CIVector vectorWithX:0 Y:0 Z:0 W:0]
               toneCurvePoints:toneCurve
                 microContrast:microContrast];
    [operations addObject:color];
  }

  if (hslAdjustments.count > 0) {
    NSUInteger dimension = cubeDimension > 0 ? cubeDimension : 33;
    CMFilmHSLRemapOperation *hsl =
        [[CMFilmHSLRemapOperation alloc] initWithAdjustments:hslAdjustments
                                               cubeDimension:dimension
                                               skinHueCenter:skinHueCenter
                                                skinHueWidth:skinHueWidth
                                          skinPreserveFactor:skinPreserveFactor];
    [operations addObject:hsl];
  }

  CGFloat clampedGrainScale = MAX(grainScale, 0.1f);
  CMFilmGrainOperation *grain =
      [[CMFilmGrainOperation alloc] initWithIntensity:MAX(grainIntensity, 0.0f)
                                         shadowWeight:CMFClamp(grainShadowWeight, 0.0f, 1.0f)
                                      highlightWeight:CMFClamp(grainHighlightWeight, 0.0f, 1.0f)
                                            grainScale:clampedGrainScale
                                            monochrome:grainMonochrome];
  [operations addObject:grain];

  if (halationIntensity > 0.0f) {
    UIColor *tint = halationTint ?: [UIColor colorWithRed:1.0f
                                                   green:0.6f
                                                    blue:0.4f
                                                   alpha:1.0f];
    CMFilmHalationOperation *halation = [[CMFilmHalationOperation alloc]
        initWithThreshold:CMFClamp(halationThreshold, 0.0f, 1.0f)
                 softness:MAX(halationSoftness, 0.01f)
                   radius:MAX(halationRadius, 0.5f)
                intensity:CMFClamp(halationIntensity, 0.0f, 1.0f)
                tintColor:tint];
    [operations addObject:halation];
  }

  if (vignetteIntensity > 0.0f) {
    CMFilmVignetteOperation *vignette = [[CMFilmVignetteOperation alloc]
        initWithIntensity:CMFClamp(vignetteIntensity, 0.0f, 1.0f)
                     radius:MAX(vignetteRadius, 0.5f)
                     center:vignetteCenter];
    [operations addObject:vignette];
  }

  ARFilterPipeline *pipeline =
      [[ARFilterPipeline alloc] initWithOperations:operations];
  ARFilterDescriptor *descriptor =
      [ARFilterDescriptor descriptorWithId:identifier
                                      name:name
                                  pipeline:pipeline
                                accentColor:accent];
  descriptor.intensity = CMFClamp(filterIntensity, 0.0f, 1.0f);
  descriptor.grainIntensity = MAX(grainIntensity, 0.0f);

  return descriptor;
}

static ARFilterDescriptor *CMCreateLeicaBWFilter(
    NSString *identifier, NSString *name, UIColor *accent,
    CGFloat grainIntensity, CGFloat grainShadowWeight,
    CGFloat grainHighlightWeight, CGFloat grainScale, BOOL monochrome,
    BOOL highContrast, NSArray<CIVector *> *contrastCurve,
    CGFloat halationThreshold, CGFloat halationSoftness, CGFloat halationRadius,
    CGFloat halationIntensity, UIColor *halationTint,
    CGFloat vignetteIntensity, CGFloat vignetteRadius, CGPoint vignetteCenter,
    CGFloat filterIntensity) {

  NSMutableArray<id<ARFilterOperation>> *operations =
      [NSMutableArray arrayWithObject:[ARClassicBWOperation new]];

  if (highContrast && contrastCurve.count >= 2) {
    CIVector *identityVector = [CIVector vectorWithX:1 Y:1 Z:1 W:0];
    CMFilmColorMatrixOperation *contrast =
        [[CMFilmColorMatrixOperation alloc]
            initWithRedVector:identityVector
                   greenVector:identityVector
                    blueVector:identityVector
                    biasVector:[CIVector vectorWithX:0 Y:0 Z:0 W:0]
               toneCurvePoints:contrastCurve
                 microContrast:0.45f];
    [operations addObject:contrast];
  }

  CMFilmGrainOperation *grain =
      [[CMFilmGrainOperation alloc] initWithIntensity:MAX(grainIntensity, 0.0f)
                                         shadowWeight:CMFClamp(grainShadowWeight, 0.0f, 1.0f)
                                      highlightWeight:CMFClamp(grainHighlightWeight, 0.0f, 1.0f)
                                            grainScale:MAX(grainScale, 0.1f)
                                            monochrome:monochrome];
  [operations addObject:grain];

  if (halationIntensity > 0.0f) {
    UIColor *tint = halationTint ?: [UIColor colorWithWhite:1.0f alpha:1.0f];
    CMFilmHalationOperation *halation = [[CMFilmHalationOperation alloc]
        initWithThreshold:CMFClamp(halationThreshold, 0.0f, 1.0f)
                 softness:MAX(halationSoftness, 0.01f)
                   radius:MAX(halationRadius, 0.5f)
                intensity:CMFClamp(halationIntensity, 0.0f, 1.0f)
                tintColor:tint];
    [operations addObject:halation];
  }

  if (vignetteIntensity > 0.0f) {
    CMFilmVignetteOperation *vignette = [[CMFilmVignetteOperation alloc]
        initWithIntensity:CMFClamp(vignetteIntensity, 0.0f, 1.0f)
                     radius:MAX(vignetteRadius, 0.5f)
                     center:vignetteCenter];
    [operations addObject:vignette];
  }

  ARFilterPipeline *pipeline =
      [[ARFilterPipeline alloc] initWithOperations:operations];
  ARFilterDescriptor *descriptor =
      [ARFilterDescriptor descriptorWithId:identifier
                                      name:name
                                  pipeline:pipeline
                                accentColor:accent];
  descriptor.intensity = CMFClamp(filterIntensity, 0.0f, 1.0f);
  descriptor.grainIntensity = MAX(grainIntensity, 0.0f);

  return descriptor;
}

@implementation ARFilterFactory

+ (NSArray<ARFilterDescriptor *> *)defaultFilters {
  NSMutableArray<ARFilterDescriptor *> *filters =
      [NSMutableArray array];

  ARFilterPipeline *none = [[ARFilterPipeline alloc] initWithOperations:@[]];
  ARFilterDescriptor *original =
      [ARFilterDescriptor descriptorWithId:@"none" name:@"原片" pipeline:none];
  original.intensity = 1.0f;
  original.grainIntensity = 0.0f;
  [filters addObject:original];

  NSArray<CIVector *> *stdCurve = @[ [CIVector vectorWithX:0.0f Y:0.015f],
    [CIVector vectorWithX:0.22f Y:0.18f],
    [CIVector vectorWithX:0.50f Y:0.58f],
    [CIVector vectorWithX:0.78f Y:0.92f],
    [CIVector vectorWithX:1.0f Y:1.0f] ];
  NSArray<NSValue *> *stdAdjustments = @[
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(18.0f, 60.0f, 2.0f, 1.06f, 0.02f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(110.0f, 170.0f, -3.2f, 0.94f, -0.01f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(200.0f, 260.0f, 1.5f, 1.03f, 0.015f)]
  ];
  UIColor *stdAccent =
      [UIColor colorWithRed:0.82f green:0.18f blue:0.14f alpha:1.0f];
  UIColor *stdHalationTint =
      [UIColor colorWithRed:1.0f green:0.52f blue:0.38f alpha:1.0f];
  ARFilterDescriptor *leicaSTD = CMCreateLeicaColorFilter(
      @"leica_std", @"LEICA STD", stdAccent, stdCurve,
      [CIVector vectorWithX:1.06f Y:0.04f Z:0.0f W:0.0f],
      [CIVector vectorWithX:0.02f Y:0.98f Z:0.02f W:0.0f],
      [CIVector vectorWithX:0.0f Y:0.04f Z:0.95f W:0.0f],
      [CIVector vectorWithX:0.01f Y:0.0f Z:-0.012f W:0.0f], 0.32f, stdAdjustments,
      33, 38.0f, 55.0f, 0.62f, 0.35f, 0.85f, 0.32f, 1.6f, NO, 0.72f, 0.12f,
      14.0f, 0.24f, stdHalationTint, 0.58f, 0.88f, CGPointMake(0.5f, 0.52f),
      0.92f);
  [filters addObject:leicaSTD];

  NSArray<CIVector *> *vivCurve = @[ [CIVector vectorWithX:0.0f Y:0.0f],
    [CIVector vectorWithX:0.18f Y:0.16f],
    [CIVector vectorWithX:0.52f Y:0.64f],
    [CIVector vectorWithX:0.82f Y:0.98f],
    [CIVector vectorWithX:1.0f Y:1.0f] ];
  NSArray<NSValue *> *vivAdjustments = @[
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(10.0f, 50.0f, 1.5f, 1.15f, 0.03f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(60.0f, 120.0f, 0.5f, 1.12f, 0.02f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(190.0f, 260.0f, -2.0f, 1.08f, -0.01f)]
  ];
  UIColor *vivAccent =
      [UIColor colorWithRed:0.94f green:0.36f blue:0.16f alpha:1.0f];
  UIColor *vivHalationTint =
      [UIColor colorWithRed:1.0f green:0.48f blue:0.35f alpha:1.0f];
  ARFilterDescriptor *leicaVIV = CMCreateLeicaColorFilter(
      @"leica_viv", @"LEICA VIV", vivAccent, vivCurve,
      [CIVector vectorWithX:1.10f Y:0.02f Z:0.0f W:0.0f],
      [CIVector vectorWithX:0.02f Y:1.05f Z:0.03f W:0.0f],
      [CIVector vectorWithX:0.0f Y:0.05f Z:1.02f W:0.0f],
      [CIVector vectorWithX:0.02f Y:0.01f Z:-0.015f W:0.0f], 0.40f,
      vivAdjustments, 33, 36.0f, 48.0f, 0.58f, 0.38f, 0.80f, 0.35f, 1.4f, NO,
      0.70f, 0.10f, 16.0f, 0.28f, vivHalationTint, 0.50f, 0.90f,
      CGPointMake(0.5f, 0.50f), 0.95f);
  [filters addObject:leicaVIV];

  NSArray<CIVector *> *natCurve = @[ [CIVector vectorWithX:0.0f Y:0.01f],
    [CIVector vectorWithX:0.25f Y:0.24f],
    [CIVector vectorWithX:0.50f Y:0.55f],
    [CIVector vectorWithX:0.80f Y:0.92f],
    [CIVector vectorWithX:1.0f Y:1.0f] ];
  NSArray<NSValue *> *natAdjustments = @[
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(25.0f, 70.0f, 1.2f, 1.04f, 0.01f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(110.0f, 180.0f, -1.5f, 0.96f, -0.005f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(200.0f, 260.0f, 0.8f, 1.01f, 0.005f)]
  ];
  UIColor *natAccent =
      [UIColor colorWithRed:0.74f green:0.35f blue:0.24f alpha:1.0f];
  UIColor *natHalationTint =
      [UIColor colorWithRed:0.98f green:0.48f blue:0.32f alpha:1.0f];
  ARFilterDescriptor *leicaNAT = CMCreateLeicaColorFilter(
      @"leica_nat", @"LEICA NAT", natAccent, natCurve,
      [CIVector vectorWithX:1.03f Y:0.02f Z:0.0f W:0.0f],
      [CIVector vectorWithX:0.01f Y:1.0f Z:0.01f W:0.0f],
      [CIVector vectorWithX:0.0f Y:0.03f Z:0.97f W:0.0f],
      [CIVector vectorWithX:0.005f Y:0.0f Z:-0.005f W:0.0f], 0.28f,
      natAdjustments, 33, 40.0f, 60.0f, 0.70f, 0.28f, 0.75f, 0.25f, 1.8f,
      NO, 0.74f, 0.10f, 14.0f, 0.18f, natHalationTint, 0.45f, 0.95f,
      CGPointMake(0.5f, 0.50f), 0.88f);
  [filters addObject:leicaNAT];

  NSArray<CIVector *> *bleCurve = @[ [CIVector vectorWithX:0.0f Y:0.0f],
    [CIVector vectorWithX:0.20f Y:0.12f],
    [CIVector vectorWithX:0.50f Y:0.55f],
    [CIVector vectorWithX:0.85f Y:0.97f],
    [CIVector vectorWithX:1.0f Y:1.0f] ];
  NSArray<NSValue *> *bleAdjustments = @[
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(190.0f, 260.0f, 2.5f, 1.10f, 0.01f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(120.0f, 180.0f, -3.5f, 0.92f, -0.01f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(30.0f, 80.0f, 0.5f, 0.95f, -0.02f)]
  ];
  UIColor *bleAccent =
      [UIColor colorWithRed:0.32f green:0.62f blue:0.92f alpha:1.0f];
  UIColor *bleHalationTint =
      [UIColor colorWithRed:0.74f green:0.82f blue:1.0f alpha:1.0f];
  ARFilterDescriptor *leicaBLE = CMCreateLeicaColorFilter(
      @"leica_ble", @"LEICA BLE", bleAccent, bleCurve,
      [CIVector vectorWithX:0.96f Y:0.0f Z:0.02f W:0.0f],
      [CIVector vectorWithX:0.0f Y:1.02f Z:0.04f W:0.0f],
      [CIVector vectorWithX:0.02f Y:0.07f Z:1.08f W:0.0f],
      [CIVector vectorWithX:-0.015f Y:0.0f Z:0.02f W:0.0f], 0.36f,
      bleAdjustments, 33, 34.0f, 48.0f, 0.60f, 0.33f, 0.78f, 0.28f, 2.0f,
      YES, 0.78f, 0.12f, 18.0f, 0.22f, bleHalationTint, 0.52f, 0.98f,
      CGPointMake(0.5f, 0.48f), 0.90f);
  [filters addObject:leicaBLE];

  NSArray<CIVector *> *brsCurve = @[ [CIVector vectorWithX:0.0f Y:0.02f],
    [CIVector vectorWithX:0.18f Y:0.18f],
    [CIVector vectorWithX:0.52f Y:0.60f],
    [CIVector vectorWithX:0.82f Y:0.94f],
    [CIVector vectorWithX:1.0f Y:1.0f] ];
  NSArray<NSValue *> *brsAdjustments = @[
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(20.0f, 70.0f, 3.0f, 1.12f, 0.04f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(100.0f, 160.0f, -2.5f, 0.92f, -0.02f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(200.0f, 260.0f, -1.0f, 0.95f, -0.01f)]
  ];
  UIColor *brsAccent =
      [UIColor colorWithRed:0.84f green:0.58f blue:0.24f alpha:1.0f];
  UIColor *brsHalationTint =
      [UIColor colorWithRed:1.0f green:0.54f blue:0.30f alpha:1.0f];
  ARFilterDescriptor *leicaBRS = CMCreateLeicaColorFilter(
      @"leica_brs", @"LEICA BRS", brsAccent, brsCurve,
      [CIVector vectorWithX:1.12f Y:0.03f Z:0.0f W:0.0f],
      [CIVector vectorWithX:0.04f Y:0.98f Z:0.02f W:0.0f],
      [CIVector vectorWithX:0.0f Y:0.04f Z:0.90f W:0.0f],
      [CIVector vectorWithX:0.025f Y:0.005f Z:-0.02f W:0.0f], 0.38f,
      brsAdjustments, 33, 38.0f, 52.0f, 0.60f, 0.42f, 0.88f, 0.30f, 1.5f,
      NO, 0.70f, 0.10f, 18.0f, 0.32f, brsHalationTint, 0.50f, 0.86f,
      CGPointMake(0.5f, 0.50f), 0.94f);
  [filters addObject:leicaBRS];

  NSArray<CIVector *> *chrCurve = @[ [CIVector vectorWithX:0.0f Y:0.02f],
    [CIVector vectorWithX:0.22f Y:0.20f],
    [CIVector vectorWithX:0.48f Y:0.62f],
    [CIVector vectorWithX:0.78f Y:0.98f],
    [CIVector vectorWithX:1.0f Y:1.0f] ];
  NSArray<NSValue *> *chrAdjustments = @[
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(300.0f, 20.0f, 4.0f, 1.18f, 0.03f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(20.0f, 80.0f, 2.0f, 1.12f, 0.02f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(180.0f, 240.0f, -2.0f, 0.94f, -0.02f)]
  ];
  UIColor *chrAccent =
      [UIColor colorWithRed:0.90f green:0.20f blue:0.42f alpha:1.0f];
  UIColor *chrHalationTint =
      [UIColor colorWithRed:1.0f green:0.40f blue:0.50f alpha:1.0f];
  ARFilterDescriptor *leicaCHR = CMCreateLeicaColorFilter(
      @"leica_chr", @"LEICA CHR", chrAccent, chrCurve,
      [CIVector vectorWithX:1.08f Y:0.05f Z:0.0f W:0.0f],
      [CIVector vectorWithX:0.02f Y:1.03f Z:0.03f W:0.0f],
      [CIVector vectorWithX:0.01f Y:0.05f Z:1.04f W:0.0f],
      [CIVector vectorWithX:0.02f Y:0.0f Z:-0.01f W:0.0f], 0.42f,
      chrAdjustments, 33, 34.0f, 46.0f, 0.55f, 0.36f, 0.82f, 0.34f, 1.6f,
      NO, 0.72f, 0.14f, 16.0f, 0.26f, chrHalationTint, 0.48f, 0.90f,
      CGPointMake(0.5f, 0.50f), 0.96f);
  [filters addObject:leicaCHR];

  NSArray<CIVector *> *clsCurve = @[ [CIVector vectorWithX:0.0f Y:0.015f],
    [CIVector vectorWithX:0.20f Y:0.20f],
    [CIVector vectorWithX:0.50f Y:0.60f],
    [CIVector vectorWithX:0.80f Y:0.95f],
    [CIVector vectorWithX:1.0f Y:1.0f] ];
  NSArray<NSValue *> *clsAdjustments = @[
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(18.0f, 60.0f, 1.5f, 1.06f, 0.01f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(200.0f, 260.0f, -1.5f, 0.98f, -0.015f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(100.0f, 160.0f, -0.5f, 0.97f, 0.0f)]
  ];
  UIColor *clsAccent =
      [UIColor colorWithRed:0.78f green:0.28f blue:0.26f alpha:1.0f];
  UIColor *clsHalationTint =
      [UIColor colorWithRed:1.0f green:0.48f blue:0.36f alpha:1.0f];
  ARFilterDescriptor *leicaCLS = CMCreateLeicaColorFilter(
      @"leica_cls", @"LEICA CLS", clsAccent, clsCurve,
      [CIVector vectorWithX:1.04f Y:0.03f Z:0.0f W:0.0f],
      [CIVector vectorWithX:0.02f Y:0.99f Z:0.02f W:0.0f],
      [CIVector vectorWithX:0.0f Y:0.03f Z:0.95f W:0.0f],
      [CIVector vectorWithX:0.012f Y:0.0f Z:-0.012f W:0.0f], 0.34f,
      clsAdjustments, 33, 36.0f, 54.0f, 0.64f, 0.38f, 0.86f, 0.28f, 1.7f,
      NO, 0.74f, 0.11f, 14.0f, 0.22f, clsHalationTint, 0.52f, 0.90f,
      CGPointMake(0.5f, 0.50f), 0.90f);
  [filters addObject:leicaCLS];

  NSArray<CIVector *> *cntCurve = @[ [CIVector vectorWithX:0.0f Y:0.0f],
    [CIVector vectorWithX:0.16f Y:0.12f],
    [CIVector vectorWithX:0.48f Y:0.58f],
    [CIVector vectorWithX:0.82f Y:0.98f],
    [CIVector vectorWithX:1.0f Y:1.0f] ];
  NSArray<NSValue *> *cntAdjustments = @[
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(20.0f, 60.0f, 1.2f, 1.08f, -0.01f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(200.0f, 260.0f, -2.5f, 0.92f, -0.03f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(300.0f, 20.0f, 1.0f, 1.04f, 0.02f)]
  ];
  UIColor *cntAccent =
      [UIColor colorWithRed:0.86f green:0.22f blue:0.18f alpha:1.0f];
  UIColor *cntHalationTint =
      [UIColor colorWithRed:1.0f green:0.45f blue:0.32f alpha:1.0f];
  ARFilterDescriptor *leicaCNT = CMCreateLeicaColorFilter(
      @"leica_cnt", @"LEICA CNT", cntAccent, cntCurve,
      [CIVector vectorWithX:1.12f Y:0.04f Z:0.0f W:0.0f],
      [CIVector vectorWithX:0.02f Y:1.02f Z:0.02f W:0.0f],
      [CIVector vectorWithX:0.0f Y:0.05f Z:0.98f W:0.0f],
      [CIVector vectorWithX:0.015f Y:-0.005f Z:-0.02f W:0.0f], 0.48f,
      cntAdjustments, 33, 36.0f, 50.0f, 0.52f, 0.40f, 0.88f, 0.26f, 1.3f,
      NO, 0.68f, 0.10f, 18.0f, 0.30f, cntHalationTint, 0.60f, 0.84f,
      CGPointMake(0.5f, 0.48f), 0.98f);
  [filters addObject:leicaCNT];

  NSArray<CIVector *> *etnCurve = @[ [CIVector vectorWithX:0.0f Y:0.02f],
    [CIVector vectorWithX:0.22f Y:0.20f],
    [CIVector vectorWithX:0.52f Y:0.60f],
    [CIVector vectorWithX:0.82f Y:0.93f],
    [CIVector vectorWithX:1.0f Y:1.0f] ];
  NSArray<NSValue *> *etnAdjustments = @[
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(30.0f, 80.0f, 2.5f, 1.08f, 0.03f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(150.0f, 200.0f, -3.0f, 0.90f, -0.03f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(200.0f, 260.0f, -1.0f, 0.94f, -0.02f)]
  ];
  UIColor *etnAccent =
      [UIColor colorWithRed:0.74f green:0.50f blue:0.26f alpha:1.0f];
  UIColor *etnHalationTint =
      [UIColor colorWithRed:1.0f green:0.50f blue:0.34f alpha:1.0f];
  ARFilterDescriptor *leicaETN = CMCreateLeicaColorFilter(
      @"leica_etn", @"LEICA ETN", etnAccent, etnCurve,
      [CIVector vectorWithX:1.08f Y:0.04f Z:0.0f W:0.0f],
      [CIVector vectorWithX:0.03f Y:1.0f Z:0.02f W:0.0f],
      [CIVector vectorWithX:0.0f Y:0.04f Z:0.90f W:0.0f],
      [CIVector vectorWithX:0.02f Y:0.005f Z:-0.015f W:0.0f], 0.36f,
      etnAdjustments, 33, 40.0f, 58.0f, 0.66f, 0.37f, 0.84f, 0.30f, 1.9f,
      NO, 0.72f, 0.12f, 16.0f, 0.26f, etnHalationTint, 0.55f, 0.90f,
      CGPointMake(0.5f, 0.52f), 0.92f);
  [filters addObject:leicaETN];

  NSArray<CIVector *> *telCurve = @[ [CIVector vectorWithX:0.0f Y:0.01f],
    [CIVector vectorWithX:0.20f Y:0.18f],
    [CIVector vectorWithX:0.50f Y:0.58f],
    [CIVector vectorWithX:0.82f Y:0.96f],
    [CIVector vectorWithX:1.0f Y:1.0f] ];
  NSArray<NSValue *> *telAdjustments = @[
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(18.0f, 60.0f, 2.8f, 1.10f, 0.02f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(170.0f, 220.0f, -4.0f, 0.88f, -0.03f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(200.0f, 260.0f, -1.5f, 1.02f, 0.01f)]
  ];
  UIColor *telAccent =
      [UIColor colorWithRed:0.24f green:0.66f blue:0.68f alpha:1.0f];
  UIColor *telHalationTint =
      [UIColor colorWithRed:0.94f green:0.62f blue:0.42f alpha:1.0f];
  ARFilterDescriptor *leicaTEL = CMCreateLeicaColorFilter(
      @"leica_tel", @"LEICA TEL", telAccent, telCurve,
      [CIVector vectorWithX:1.05f Y:0.02f Z:0.0f W:0.0f],
      [CIVector vectorWithX:0.0f Y:1.02f Z:0.04f W:0.0f],
      [CIVector vectorWithX:0.02f Y:0.06f Z:1.05f W:0.0f],
      [CIVector vectorWithX:0.01f Y:0.005f Z:-0.01f W:0.0f], 0.40f,
      telAdjustments, 33, 35.0f, 50.0f, 0.58f, 0.34f, 0.80f, 0.30f, 1.7f,
      NO, 0.70f, 0.10f, 17.0f, 0.24f, telHalationTint, 0.50f, 0.88f,
      CGPointMake(0.5f, 0.50f), 0.94f);
  [filters addObject:leicaTEL];

  NSArray<CIVector *> *iaCurve = @[ [CIVector vectorWithX:0.0f Y:0.05f],
    [CIVector vectorWithX:0.22f Y:0.22f],
    [CIVector vectorWithX:0.50f Y:0.56f],
    [CIVector vectorWithX:0.78f Y:0.90f],
    [CIVector vectorWithX:1.0f Y:1.0f] ];
  NSArray<NSValue *> *iaAdjustments = @[
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(20.0f, 80.0f, 1.5f, 1.05f, 0.04f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(180.0f, 240.0f, -1.5f, 0.96f, -0.015f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(300.0f, 340.0f, 1.0f, 1.08f, 0.02f)]
  ];
  UIColor *iaAccent =
      [UIColor colorWithRed:0.68f green:0.44f blue:0.72f alpha:1.0f];
  UIColor *iaHalationTint =
      [UIColor colorWithRed:1.0f green:0.58f blue:0.50f alpha:1.0f];
  ARFilterDescriptor *leicaIA = CMCreateLeicaColorFilter(
      @"leica_ia", @"LEICA IA", iaAccent, iaCurve,
      [CIVector vectorWithX:1.00f Y:0.02f Z:0.0f W:0.0f],
      [CIVector vectorWithX:0.02f Y:1.0f Z:0.03f W:0.0f],
      [CIVector vectorWithX:0.02f Y:0.05f Z:0.98f W:0.0f],
      [CIVector vectorWithX:0.012f Y:0.01f Z:-0.008f W:0.0f], 0.25f,
      iaAdjustments, 33, 40.0f, 60.0f, 0.70f, 0.42f, 0.88f, 0.38f, 1.2f,
      NO, 0.76f, 0.14f, 15.0f, 0.18f, iaHalationTint, 0.40f, 1.00f,
      CGPointMake(0.5f, 0.50f), 0.88f);
  [filters addObject:leicaIA];

  NSArray<CIVector *> *bluCurve = @[ [CIVector vectorWithX:0.0f Y:0.02f],
    [CIVector vectorWithX:0.24f Y:0.22f],
    [CIVector vectorWithX:0.50f Y:0.58f],
    [CIVector vectorWithX:0.78f Y:0.96f],
    [CIVector vectorWithX:1.0f Y:1.0f] ];
  NSArray<NSValue *> *bluAdjustments = @[
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(190.0f, 260.0f, 3.0f, 1.12f, 0.02f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(120.0f, 180.0f, -2.5f, 0.94f, -0.015f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(20.0f, 60.0f, 0.5f, 0.96f, -0.01f)]
  ];
  UIColor *bluAccent =
      [UIColor colorWithRed:0.36f green:0.54f blue:0.92f alpha:1.0f];
  UIColor *bluHalationTint =
      [UIColor colorWithRed:0.72f green:0.82f blue:1.0f alpha:1.0f];
  ARFilterDescriptor *leicaBLU = CMCreateLeicaColorFilter(
      @"leica_blu", @"LEICA BLU", bluAccent, bluCurve,
      [CIVector vectorWithX:0.94f Y:0.0f Z:0.04f W:0.0f],
      [CIVector vectorWithX:0.0f Y:1.0f Z:0.05f W:0.0f],
      [CIVector vectorWithX:0.02f Y:0.08f Z:1.10f W:0.0f],
      [CIVector vectorWithX:-0.02f Y:0.0f Z:0.03f W:0.0f], 0.34f,
      bluAdjustments, 33, 32.0f, 44.0f, 0.55f, 0.30f, 0.76f, 0.26f, 2.2f,
      YES, 0.78f, 0.12f, 19.0f, 0.20f, bluHalationTint, 0.48f, 0.95f,
      CGPointMake(0.5f, 0.48f), 0.90f);
  [filters addObject:leicaBLU];

  NSArray<CIVector *> *selCurve = @[ [CIVector vectorWithX:0.0f Y:0.01f],
    [CIVector vectorWithX:0.22f Y:0.20f],
    [CIVector vectorWithX:0.52f Y:0.62f],
    [CIVector vectorWithX:0.82f Y:0.98f],
    [CIVector vectorWithX:1.0f Y:1.0f] ];
  NSArray<NSValue *> *selAdjustments = @[
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(280.0f, 340.0f, 3.5f, 1.14f, 0.02f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(30.0f, 70.0f, 1.2f, 1.05f, 0.02f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(160.0f, 200.0f, -2.5f, 0.92f, -0.02f)]
  ];
  UIColor *selAccent =
      [UIColor colorWithRed:0.86f green:0.28f blue:0.62f alpha:1.0f];
  UIColor *selHalationTint =
      [UIColor colorWithRed:1.0f green:0.46f blue:0.62f alpha:1.0f];
  ARFilterDescriptor *leicaSEL = CMCreateLeicaColorFilter(
      @"leica_sel", @"LEICA SEL", selAccent, selCurve,
      [CIVector vectorWithX:1.06f Y:0.04f Z:0.02f W:0.0f],
      [CIVector vectorWithX:0.02f Y:0.98f Z:0.03f W:0.0f],
      [CIVector vectorWithX:0.02f Y:0.06f Z:1.02f W:0.0f],
      [CIVector vectorWithX:0.015f Y:-0.002f Z:-0.008f W:0.0f], 0.36f,
      selAdjustments, 33, 38.0f, 52.0f, 0.60f, 0.37f, 0.80f, 0.30f, 1.6f,
      NO, 0.74f, 0.12f, 15.0f, 0.22f, selHalationTint, 0.50f, 0.92f,
      CGPointMake(0.5f, 0.52f), 0.90f);
  [filters addObject:leicaSEL];

  NSArray<CIVector *> *sepCurve = @[ [CIVector vectorWithX:0.0f Y:0.02f],
    [CIVector vectorWithX:0.20f Y:0.18f],
    [CIVector vectorWithX:0.50f Y:0.60f],
    [CIVector vectorWithX:0.82f Y:0.94f],
    [CIVector vectorWithX:1.0f Y:1.0f] ];
  NSArray<NSValue *> *sepAdjustments = @[
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(20.0f, 60.0f, 3.0f, 1.08f, 0.03f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(200.0f, 260.0f, -2.0f, 0.90f, -0.04f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(120.0f, 160.0f, -1.0f, 0.92f, -0.02f)]
  ];
  UIColor *sepAccent =
      [UIColor colorWithRed:0.72f green:0.44f blue:0.22f alpha:1.0f];
  UIColor *sepHalationTint =
      [UIColor colorWithRed:0.98f green:0.58f blue:0.36f alpha:1.0f];
  ARFilterDescriptor *leicaSEP = CMCreateLeicaColorFilter(
      @"leica_sep", @"LEICA SEP", sepAccent, sepCurve,
      [CIVector vectorWithX:1.05f Y:0.25f Z:0.10f W:0.0f],
      [CIVector vectorWithX:0.05f Y:0.82f Z:0.10f W:0.0f],
      [CIVector vectorWithX:0.02f Y:0.18f Z:0.60f W:0.0f],
      [CIVector vectorWithX:0.02f Y:0.01f Z:-0.02f W:0.0f], 0.32f,
      sepAdjustments, 33, 40.0f, 60.0f, 0.65f, 0.33f, 0.82f, 0.28f, 1.8f,
      NO, 0.72f, 0.12f, 17.0f, 0.26f, sepHalationTint, 0.56f, 0.88f,
      CGPointMake(0.5f, 0.50f), 0.92f);
  [filters addObject:leicaSEP];

  UIColor *gregAccent =
      [UIColor colorWithRed:0.82f green:0.58f blue:0.36f alpha:1.0f];
  NSArray<CIVector *> *gregCurve = @[ [CIVector vectorWithX:0.0f Y:0.04f],
    [CIVector vectorWithX:0.18f Y:0.20f],
    [CIVector vectorWithX:0.50f Y:0.58f],
    [CIVector vectorWithX:0.82f Y:0.92f],
    [CIVector vectorWithX:1.0f Y:1.0f] ];
  NSArray<NSValue *> *gregAdjustments = @[
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(18.0f, 60.0f, 3.5f, 1.10f, 0.04f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(110.0f, 160.0f, -1.5f, 0.94f, -0.01f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(200.0f, 260.0f, -1.0f, 0.96f, 0.0f)]
  ];
  UIColor *gregHalationTint =
      [UIColor colorWithRed:1.0f green:0.58f blue:0.40f alpha:1.0f];
  ARFilterDescriptor *gregWLM = CMCreateLeicaColorFilter(
      @"leica_greg_wlm", @"GREG WLM", gregAccent, gregCurve,
      [CIVector vectorWithX:1.10f Y:0.02f Z:0.0f W:0.0f],
      [CIVector vectorWithX:0.04f Y:0.98f Z:0.02f W:0.0f],
      [CIVector vectorWithX:0.0f Y:0.04f Z:0.92f W:0.0f],
      [CIVector vectorWithX:0.03f Y:0.015f Z:-0.02f W:0.0f], 0.28f,
      gregAdjustments, 33, 42.0f, 60.0f, 0.70f, 0.48f, 0.90f, 0.36f, 1.4f,
      NO, 0.68f, 0.10f, 18.0f, 0.30f, gregHalationTint, 0.52f, 0.90f,
      CGPointMake(0.5f, 0.50f), 0.90f);
  [filters addObject:gregWLM];

  UIColor *bwAccent = [UIColor colorWithWhite:0.82f alpha:1.0f];
  ARFilterDescriptor *leicaBWNAT = CMCreateLeicaBWFilter(
      @"leica_bw_nat", @"LEICA BW NAT", bwAccent, 0.30f, 0.82f, 0.38f, 1.8f,
      YES, NO, @[], 0.70f, 0.10f, 14.0f, 0.18f,
      [UIColor colorWithWhite:0.95f alpha:1.0f], 0.45f, 0.92f,
      CGPointMake(0.5f, 0.50f), 0.98f);
  [filters addObject:leicaBWNAT];

  NSArray<CIVector *> *bwHCCurve = @[ [CIVector vectorWithX:0.0f Y:0.0f],
    [CIVector vectorWithX:0.25f Y:0.18f],
    [CIVector vectorWithX:0.50f Y:0.60f],
    [CIVector vectorWithX:0.80f Y:0.96f],
    [CIVector vectorWithX:1.0f Y:1.0f] ];
  ARFilterDescriptor *leicaBWHC = CMCreateLeicaBWFilter(
      @"leica_bw_hc", @"LEICA BW HC", bwAccent, 0.36f, 0.88f, 0.32f, 1.5f,
      YES, YES, bwHCCurve, 0.68f, 0.08f, 16.0f, 0.24f,
      [UIColor colorWithWhite:0.9f alpha:1.0f], 0.58f, 0.88f,
      CGPointMake(0.5f, 0.48f), 0.95f);
  [filters addObject:leicaBWHC];

  return [filters copy];
}
@end
