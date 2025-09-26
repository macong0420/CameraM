//
//  ARFilterFactory.m
//  CameraM
//
//  Created by Generated on 2025/9/26.
//

#import "ARFilterFactory.h"
#import "ARClassicBWOperation.h"
#import "ARCoolToneOperation.h"
#import "ARFilterDescriptor.h"
#import "ARFilterPipeline.h"
#import "ARWarmToneOperation.h"
#import "CMFilmLookOperations.h"
#import <UIKit/UIKit.h>

@implementation ARFilterFactory

+ (NSArray<ARFilterDescriptor *> *)defaultFilters {
  // 1) 原片
  ARFilterPipeline *none = [[ARFilterPipeline alloc] initWithOperations:@[]];
  ARFilterDescriptor *d0 = [ARFilterDescriptor descriptorWithId:@"none"
                                                           name:@"原片"
                                                       pipeline:none];

  // 2) 经典黑白
  ARFilterPipeline *bw = [[ARFilterPipeline alloc]
      initWithOperations:@[ [ARClassicBWOperation new] ]];
  ARFilterDescriptor *d1 = [ARFilterDescriptor descriptorWithId:@"classic_bw"
                                                           name:@"经典黑白"
                                                       pipeline:bw];

  // 3) 暖色调
  ARFilterPipeline *warm = [[ARFilterPipeline alloc]
      initWithOperations:@[ [ARWarmToneOperation new] ]];
  ARFilterDescriptor *d2 = [ARFilterDescriptor descriptorWithId:@"warm_tone"
                                                           name:@"暖色调"
                                                       pipeline:warm];

  // 4) 冷色调
  ARFilterPipeline *cool = [[ARFilterPipeline alloc]
      initWithOperations:@[ [ARCoolToneOperation new] ]];
  ARFilterDescriptor *d3 = [ARFilterDescriptor descriptorWithId:@"cool_tone"
                                                           name:@"冷色调"
                                                       pipeline:cool];

  // 5) 徕卡经典
  NSArray<CIVector *> *leicaCurve = @[ [CIVector vectorWithX:0.0f Y:0.02f],
    [CIVector vectorWithX:0.25f Y:0.22f],
    [CIVector vectorWithX:0.5f Y:0.56f],
    [CIVector vectorWithX:0.75f Y:0.88f],
    [CIVector vectorWithX:1.0f Y:1.0f] ];
  CMFilmColorMatrixOperation *leicaColor =
      [[CMFilmColorMatrixOperation alloc]
          initWithRedVector:[CIVector vectorWithX:1.08f Y:0.03f Z:0.0f W:0.0f]
                   greenVector:[CIVector vectorWithX:0.02f Y:0.98f Z:0.01f W:0.0f]
                    blueVector:[CIVector vectorWithX:0.0f Y:0.03f Z:0.94f W:0.0f]
                    biasVector:[CIVector vectorWithX:0.015f Y:0.0f Z:-0.01f W:0.0f]
               toneCurvePoints:leicaCurve
                 microContrast:0.35f];
  NSArray<NSValue *> *leicaAdjustments = @[ 
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(8.0f, 60.0f, 2.5f, 1.08f, 0.04f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(150.0f, 220.0f, -3.5f, 0.95f, -0.01f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(280.0f, 340.0f, -5.0f, 0.90f, -0.02f)]
  ];
  CMFilmHSLRemapOperation *leicaHSL =
      [[CMFilmHSLRemapOperation alloc] initWithAdjustments:leicaAdjustments
                                             cubeDimension:33
                                             skinHueCenter:38.0f
                                              skinHueWidth:55.0f
                                        skinPreserveFactor:0.65f];
  CMFilmGrainOperation *leicaGrain = [[CMFilmGrainOperation alloc]
      initWithIntensity:0.45f
             shadowWeight:0.9f
          highlightWeight:0.3f
                grainScale:1.6f
                monochrome:NO];
  CMFilmHalationOperation *leicaHalation = [[CMFilmHalationOperation alloc]
      initWithThreshold:0.72f
                 softness:0.12f
                   radius:16.0f
                intensity:0.35f
                tintColor:[UIColor colorWithRed:1.0f green:0.48f blue:0.38f alpha:1.0f]];
  CMFilmVignetteOperation *leicaVignette = [[CMFilmVignetteOperation alloc]
      initWithIntensity:0.8f
                   radius:0.85f
                   center:CGPointMake(0.5f, 0.52f)];
  ARFilterPipeline *leicaPipeline = [[ARFilterPipeline alloc]
      initWithOperations:@[ leicaColor, leicaHSL, leicaGrain, leicaHalation, leicaVignette ]];
  UIColor *leicaAccent = [UIColor colorWithRed:0.8f green:0.13f blue:0.13f alpha:1.0f];
  ARFilterDescriptor *leica = [ARFilterDescriptor descriptorWithId:@"leica_classic"
                                                             name:@"徕卡经典"
                                                         pipeline:leicaPipeline
                                                       accentColor:leicaAccent];
  leica.intensity = 0.9f;

  // 6) 蔡司蓝调
  NSArray<CIVector *> *zeissCurve = @[ [CIVector vectorWithX:0.0f Y:0.0f],
    [CIVector vectorWithX:0.2f Y:0.12f],
    [CIVector vectorWithX:0.5f Y:0.55f],
    [CIVector vectorWithX:0.8f Y:0.92f],
    [CIVector vectorWithX:1.0f Y:1.0f] ];
  CMFilmColorMatrixOperation *zeissColor =
      [[CMFilmColorMatrixOperation alloc]
          initWithRedVector:[CIVector vectorWithX:0.97f Y:0.02f Z:0.01f W:0.0f]
                   greenVector:[CIVector vectorWithX:0.01f Y:1.0f Z:0.02f W:0.0f]
                    blueVector:[CIVector vectorWithX:0.02f Y:0.05f Z:1.06f W:0.0f]
                    biasVector:[CIVector vectorWithX:-0.01f Y:0.0f Z:0.015f W:0.0f]
               toneCurvePoints:zeissCurve
                 microContrast:0.42f];
  NSArray<NSValue *> *zeissAdjustments = @[ 
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(200.0f, 260.0f, -2.5f, 1.12f, -0.02f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(40.0f, 90.0f, -1.0f, 0.92f, 0.03f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(320.0f, 20.0f, 1.5f, 0.90f, 0.01f)]
  ];
  CMFilmHSLRemapOperation *zeissHSL =
      [[CMFilmHSLRemapOperation alloc] initWithAdjustments:zeissAdjustments
                                             cubeDimension:33
                                             skinHueCenter:36.0f
                                              skinHueWidth:50.0f
                                        skinPreserveFactor:0.6f];
  CMFilmGrainOperation *zeissGrain = [[CMFilmGrainOperation alloc]
      initWithIntensity:0.3f
             shadowWeight:0.7f
          highlightWeight:0.2f
                grainScale:2.4f
                monochrome:YES];
  CMFilmHalationOperation *zeissHalation = [[CMFilmHalationOperation alloc]
      initWithThreshold:0.82f
                 softness:0.08f
                   radius:12.0f
                intensity:0.25f
                tintColor:[UIColor colorWithRed:0.6f green:0.74f blue:1.0f alpha:1.0f]];
  CMFilmVignetteOperation *zeissVignette = [[CMFilmVignetteOperation alloc]
      initWithIntensity:0.55f
                   radius:1.05f
                   center:CGPointMake(0.5f, 0.5f)];
  ARFilterPipeline *zeissPipeline = [[ARFilterPipeline alloc]
      initWithOperations:@[ zeissColor, zeissHSL, zeissGrain, zeissHalation, zeissVignette ]];
  UIColor *zeissAccent = [UIColor colorWithRed:0.15f green:0.45f blue:0.85f alpha:1.0f];
  ARFilterDescriptor *zeiss = [ARFilterDescriptor descriptorWithId:@"zeiss_blue"
                                                              name:@"蔡司蓝调"
                                                          pipeline:zeissPipeline
                                                        accentColor:zeissAccent];
  zeiss.intensity = 0.85f;

  // 7) 富士胶片
  NSArray<CIVector *> *fujiCurve = @[ [CIVector vectorWithX:0.0f Y:0.02f],
    [CIVector vectorWithX:0.18f Y:0.16f],
    [CIVector vectorWithX:0.5f Y:0.58f],
    [CIVector vectorWithX:0.82f Y:0.94f],
    [CIVector vectorWithX:1.0f Y:1.0f] ];
  CMFilmColorMatrixOperation *fujiColor =
      [[CMFilmColorMatrixOperation alloc]
          initWithRedVector:[CIVector vectorWithX:1.02f Y:0.03f Z:0.0f W:0.0f]
                   greenVector:[CIVector vectorWithX:0.02f Y:1.0f Z:0.05f W:0.0f]
                    blueVector:[CIVector vectorWithX:0.0f Y:0.05f Z:0.98f W:0.0f]
                    biasVector:[CIVector vectorWithX:0.008f Y:0.005f Z:-0.006f W:0.0f]
               toneCurvePoints:fujiCurve
                 microContrast:0.28f];
  NSArray<NSValue *> *fujiAdjustments = @[ 
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(80.0f, 160.0f, -4.0f, 1.18f, 0.03f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(0.0f, 40.0f, 1.5f, 1.05f, 0.02f)],
    [NSValue valueWithCMHSLAdjustment:CMHSLAdjustmentMake(200.0f, 260.0f, -6.0f, 0.90f, -0.02f)]
  ];
  CMFilmHSLRemapOperation *fujiHSL =
      [[CMFilmHSLRemapOperation alloc] initWithAdjustments:fujiAdjustments
                                             cubeDimension:33
                                             skinHueCenter:42.0f
                                              skinHueWidth:58.0f
                                        skinPreserveFactor:0.68f];
  CMFilmGrainOperation *fujiGrain = [[CMFilmGrainOperation alloc]
      initWithIntensity:0.52f
             shadowWeight:0.85f
          highlightWeight:0.45f
                grainScale:1.4f
                monochrome:NO];
  CMFilmHalationOperation *fujiHalation = [[CMFilmHalationOperation alloc]
      initWithThreshold:0.70f
                 softness:0.12f
                   radius:14.0f
                intensity:0.30f
                tintColor:[UIColor colorWithRed:1.0f green:0.62f blue:0.35f alpha:1.0f]];
  CMFilmVignetteOperation *fujiVignette = [[CMFilmVignetteOperation alloc]
      initWithIntensity:0.65f
                   radius:0.92f
                   center:CGPointMake(0.5f, 0.5f)];
  ARFilterPipeline *fujiPipeline = [[ARFilterPipeline alloc]
      initWithOperations:@[ fujiColor, fujiHSL, fujiGrain, fujiHalation, fujiVignette ]];
  UIColor *fujiAccent = [UIColor colorWithRed:0.12f green:0.58f blue:0.38f alpha:1.0f];
  ARFilterDescriptor *fuji = [ARFilterDescriptor descriptorWithId:@"fujifilm_chrome"
                                                            name:@"富士胶片"
                                                        pipeline:fujiPipeline
                                                      accentColor:fujiAccent];
  fuji.intensity = 0.88f;

  return @[ d0, d1, d2, d3, leica, zeiss, fuji ];
}

@end
