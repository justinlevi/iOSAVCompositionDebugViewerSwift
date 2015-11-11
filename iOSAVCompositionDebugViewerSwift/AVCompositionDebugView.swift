//
//  AVCompositionDebugView.swift
//  iOSAVCompositionDebugViewerSwift
//
//  Created by Justin Winter on 11/10/15.
//  Copyright © 2015 soundslides. All rights reserved.
//

import UIKit
import AVFoundation
import CoreGraphics


// ============================================
// MARK: -  String Extension

extension String {
  func drawVeriticallyCenteredInRect(var rect: CGRect, withAttributes attributes: [String : AnyObject]?) {
    let size = self.sizeWithAttributes(attributes)
    rect.origin.y += (rect.size.height - size.height) / 2.0
    self.drawInRect(rect, withAttributes: attributes)
  }
}


// ============================================
// MARK: -  CLASS APLCompositionTrackSegmentInfo

class APLCompositionTrackSegmentInfo: NSObject {
  var timeRange: CMTimeRange = CMTimeRangeMake(kCMTimeZero, kCMTimeZero)
  var empty: Bool = false
  var mediaType: String = ""
  var localDescription: String = ""
  override var description: String {
    get { return localDescription }
    set { localDescription = newValue }
  }
}


// ============================================
// MARK: -  CLASS APLVideoCompositionStageInfo

class APLVideoCompositionStageInfo: NSObject {
  var timeRange: CMTimeRange = CMTimeRangeMake(kCMTimeZero, kCMTimeZero)
  var layerNames = [String]()
  var opacityRamps: [String : [CGPoint]]? = nil
}


// ============================================
// MARK: -  CLASS AVCompositionDebugView

class AVCompositionDebugView: UIView {

  
  // ============================================
  // MARK: -  Constants
  
  let kLeftInsetToMatchTimeSlider: CGFloat = 50.0
  let kRightInsetToMatchTimeSlider: CGFloat = 60.0
  let kLeftMarginInset: CGFloat = 4.0
  let kBannerHeight: CGFloat = 20.0
  let kIdealRowHeight: CGFloat = 36.0
  let kGapAfterRows: CGFloat = 4.0
  
  
  // ============================================
  // MARK: -  Properties
  
  var drawingLayer: CALayer = CALayer()
  
  var duration: CMTime = kCMTimeZero
  var compositionRectWidth: CGFloat = 0
  
  var compositionTracks = [[APLCompositionTrackSegmentInfo]]()
  var audioMixTracks = [[CGPoint]]()
  var videoCompositionStages = [APLVideoCompositionStageInfo]()
  
  var scaledDurationToWidth = 0.0
  
  let player: AVPlayer? = nil
  
  
  // ============================================
  // MARK: -  Initializers
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setup()
  }
  
  func setup(){
    drawingLayer = self.layer
  }
  
  
  // ============================================
  // MARK: -  Value Harvesting
  
  func synchronizeToComposition(composition: AVComposition?, videoComposition: AVVideoComposition?, audioMix: AVAudioMix?) {
    compositionTracks = []
    audioMixTracks = []
    videoCompositionStages = []
    
    duration = CMTimeMake(1, 1) // avoid division by zero later
    // composition
    if let composition = composition {
      var tracks = [[APLCompositionTrackSegmentInfo]]()
      for t in composition.tracks {
        var segments = [APLCompositionTrackSegmentInfo]()
        for s in t.segments {
          let segment = APLCompositionTrackSegmentInfo()
          segment.timeRange = s.empty ? s.timeMapping.target : s.timeMapping.source // only used for duration : assumes non-scaled edit
          segment.empty = s.empty
          segment.mediaType = t.mediaType
          
          if !segment.empty {
            var description = String(format: "%1.1f - %1.1f: \"%@\" ", CMTimeGetSeconds(segment.timeRange.start), CMTimeGetSeconds(CMTimeRangeGetEnd(segment.timeRange)), (s.sourceURL?.lastPathComponent)!)
            switch segment.mediaType {
              case AVMediaTypeVideo: description += "(v)"
              case AVMediaTypeAudio: description += "(a)"
              default: description += segment.mediaType
            }
            segment.description = description
          }
          segments.append(segment)
        }
        
        tracks.append(segments)
      }
    
      compositionTracks = tracks
      duration = CMTimeMaximum(duration, composition.duration)
    }
    
    // audioMix
    if let audioMix = audioMix {
      var mixTracks = [[CGPoint]]()
      for input in audioMix.inputParameters {
        var ramp = [CGPoint]()
        var startTime = kCMTimeZero
        var startVolume: Float = 1
        var endVolume: Float = 1
        var timeRange: CMTimeRange = (CMTimeRangeMake(kCMTimeZero, kCMTimeZero))
        while input.getVolumeRampForTime(startTime, startVolume: &startVolume , endVolume: &endVolume , timeRange: &timeRange){
          if startTime == kCMTimeZero && timeRange.start > kCMTimeZero {
            ramp.append(CGPointMake(0, 1.0))
            ramp.append(CGPointMake(CGFloat(CMTimeGetSeconds(timeRange.start)), 1.0))
          }
          ramp.append(CGPointMake(CGFloat(CMTimeGetSeconds(timeRange.start)), CGFloat(startVolume)))
          ramp.append(CGPointMake(CGFloat(CMTimeGetSeconds(CMTimeRangeGetEnd(timeRange))), CGFloat(endVolume)))
          startTime = CMTimeRangeGetEnd(timeRange)
        }
        if startTime < duration {
          ramp.append(CGPointMake(CGFloat(CMTimeGetSeconds(duration)), CGFloat(endVolume)))
        }
        mixTracks.append(ramp)
      }
      
      audioMixTracks = mixTracks
    }
    
    // videoComposition
    if let videoComposition = videoComposition{
      var stages = [APLVideoCompositionStageInfo]()
      for instruction in videoComposition.instructions {
        let stage = APLVideoCompositionStageInfo()
        stage.timeRange = instruction.timeRange
        var rampsDictionary = [String : [CGPoint]]()
        
        if let instruction = instruction as? AVVideoCompositionInstruction {
          var layerNames = [String]()
          for layerInstruction in instruction.layerInstructions {
            var ramp = [CGPoint]()
            var startTime = kCMTimeZero
            var startOpacity: Float = 1.0, endOpacity: Float = 1.0
            var timeRange = CMTimeRangeMake(kCMTimeZero, kCMTimeZero)
            while layerInstruction.getOpacityRampForTime(startTime, startOpacity: &startOpacity , endOpacity: &endOpacity, timeRange: &timeRange){
              if startTime == kCMTimeZero && timeRange.start > kCMTimeZero {
                ramp.append(CGPointMake(CGFloat(CMTimeGetSeconds(timeRange.start)), CGFloat(startOpacity)))
              }
              ramp.append(CGPointMake(CGFloat(CMTimeGetSeconds(CMTimeRangeGetEnd(timeRange))), CGFloat(endOpacity)))
              startTime = CMTimeRangeGetEnd(timeRange)
            }
            
            let name = "\(layerInstruction.trackID)"
            layerNames.append(name)
            rampsDictionary[name] = ramp
          }
          
          if layerNames.count > 1 {
            stage.opacityRamps = rampsDictionary
          }
          
          stage.layerNames = layerNames
          stages.append(stage)
        }
      }
      videoCompositionStages = stages
    }
    
    drawingLayer.setNeedsDisplay()
  }
  
  
  // ============================================
  // MARK: -  View Drawing
  
  override func willMoveToSuperview(newSuperview: UIView?) {
    drawingLayer.frame = self.bounds
    drawingLayer.delegate = self
    drawingLayer.setNeedsDisplay()
  }
  
  // TODO: Is this right??? There is no viewWillDisappear method on a UIView Subclass
  func viewWillDisappear(animated: Bool){
    drawingLayer.delegate = nil
  }

  override func drawRect(rect: CGRect) {
    let context = UIGraphicsGetCurrentContext()
    
    let rect = CGRectInset(rect, kLeftMarginInset, 4.0)
    
    let style = NSMutableParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
    style.alignment = NSTextAlignment.Center

    let textAttributes = [
      NSForegroundColorAttributeName: UIColor.whiteColor(),
      NSParagraphStyleAttributeName: style
    ]
    let numBanners = compositionTracks.count + audioMixTracks.count + videoCompositionStages.count
    
    //FIXME: This doesn't make sense in the original
    let numRows = compositionTracks.count + audioMixTracks.count //+ videoCompositionStages
    //int numRows = (int)[compositionTracks count] + (int)[audioMixTracks count] + (videoCompositionStages != nil)
    
    let totalBannerHeight = CGFloat(numBanners) * (kBannerHeight + kGapAfterRows)
    var rowHeight = kIdealRowHeight
    if numRows > 0 {
      let maxRowHeight = (rect.size.height - totalBannerHeight) / CGFloat(numRows)
      rowHeight = min(rowHeight, maxRowHeight)
    }
    
    var runningTop = rect.origin.y
    var bannerRect = rect
    bannerRect.size.height = kBannerHeight
    bannerRect.origin.y = runningTop
    
    var rowRect = rect
    rowRect.size.height = rowHeight
    
    rowRect.origin.x += kLeftInsetToMatchTimeSlider
    rowRect.size.width -= (kLeftInsetToMatchTimeSlider + kRightInsetToMatchTimeSlider)
    compositionRectWidth = rowRect.size.width
    
    scaledDurationToWidth = Double(compositionRectWidth) / CMTimeGetSeconds(duration)
    
    if (compositionTracks.count > 0) {
      bannerRect.origin.y = runningTop
      CGContextSetRGBFillColor(context, 0.00, 0.00, 0.00, 1.00) // black
      
      NSString(format: "AVComposition").drawInRect(bannerRect, withAttributes: [NSForegroundColorAttributeName : UIColor.whiteColor()])
      
      runningTop += bannerRect.size.height
      
      for track in compositionTracks {
        rowRect.origin.y = runningTop
        var segmentRect = rowRect
        for segment in track {
          segmentRect.size.width = CGFloat(CMTimeGetSeconds(segment.timeRange.duration) * scaledDurationToWidth)
          
          if segment.empty {
            CGContextSetRGBFillColor(context, 0.00, 0.00, 0.00, 1.00) // white
            
            "Empty".drawVeriticallyCenteredInRect(segmentRect, withAttributes: textAttributes)
          }
          else {
            if segment.mediaType == AVMediaTypeVideo {
              CGContextSetRGBFillColor(context, 0.00, 0.36, 0.36, 1.00) // blue-green
              CGContextSetRGBStrokeColor(context, 0.00, 0.50, 0.50, 1.00) // brigher blue-green
            }
            else {
              CGContextSetRGBFillColor(context, 0.00, 0.24, 0.36, 1.00) // bluer-green
              CGContextSetRGBStrokeColor(context, 0.00, 0.33, 0.60, 1.00) // brigher bluer-green
            }
            CGContextSetLineWidth(context, 2.0)
            CGContextAddRect(context, CGRectInset(segmentRect, 3.0, 3.0))
            CGContextDrawPath(context, CGPathDrawingMode.FillStroke)
            
            CGContextSetRGBFillColor(context, 0.00, 0.00, 0.00, 1.00) // white
            
            let description: String = segment.description
            description.drawVeriticallyCenteredInRect(segmentRect, withAttributes: textAttributes)
          }
          
          segmentRect.origin.x += segmentRect.size.width
        }
        
        runningTop += rowRect.size.height
      }
      runningTop += kGapAfterRows
    }
    
    if videoCompositionStages.count > 0 {
      bannerRect.origin.y = runningTop
      CGContextSetRGBFillColor(context, 0.00, 0.00, 0.00, 1.00) // white
      NSString(format: "AVVideoComposition").drawInRect(bannerRect, withAttributes: [NSForegroundColorAttributeName : UIColor.whiteColor()])
      runningTop += bannerRect.size.height
      
      rowRect.origin.y = runningTop
      var stageRect = rowRect
      for stage in videoCompositionStages {
        stageRect.size.width = CGFloat(CMTimeGetSeconds(stage.timeRange.duration) * scaledDurationToWidth)
        
        let layerCount = stage.layerNames.count
        var layerRect = stageRect
        if layerCount > 0 {
          layerRect.size.height /= CGFloat(layerCount)
        }
        
        for layerName in stage.layerNames {
          if (Int(layerName)! % 2 == 1) {
            CGContextSetRGBFillColor(context, 0.55, 0.02, 0.02, 1.00) // darker red
            CGContextSetRGBStrokeColor(context, 0.87, 0.10, 0.10, 1.00) // brighter red
          }
          else {
            CGContextSetRGBFillColor(context, 0.00, 0.40, 0.76, 1.00) // darker blue
            CGContextSetRGBStrokeColor(context, 0.00, 0.67, 1.00, 1.00) // brighter blue
          }
          CGContextSetLineWidth(context, 2.0)
          CGContextAddRect(context, CGRectInset(layerRect, 3.0, 1.0))
          CGContextDrawPath(context, CGPathDrawingMode.FillStroke)
          
          // (if there are two layers, the first should ideally have a gradient fill.)
          
          CGContextSetRGBFillColor(context, 0.00, 0.00, 0.00, 1.00) // white
          layerName.drawVeriticallyCenteredInRect(layerRect, withAttributes: textAttributes)
          
          // Draw the opacity ramps for each layer as per the layerInstructions
          if let rampArray = stage.opacityRamps?[layerName] {
            
            if rampArray.count > 0 {
              var rampRect = layerRect
              rampRect.size.width = CGFloat(CMTimeGetSeconds(duration) * scaledDurationToWidth)
              rampRect = CGRectInset(rampRect, 3.0, 3.0)
              
              CGContextBeginPath(context)
              CGContextSetRGBStrokeColor(context, 0.95, 0.68, 0.09, 1.00) // yellow
              CGContextSetLineWidth(context, 2.0)
              var firstPoint = true
              
              for pointValue in rampArray {
                let timeVolumePoint = pointValue
                var pointInRow = CGPoint()
                
                pointInRow.x = CGFloat(horizontalPositionForTime(CMTimeMakeWithSeconds(Double(timeVolumePoint.x), 1)) - 3.0)
                pointInRow.y = rampRect.origin.y + ( 0.9 - 0.8 * timeVolumePoint.y ) * rampRect.size.height
                
                pointInRow.x = max(pointInRow.x, CGRectGetMinX(rampRect))
                pointInRow.x = min(pointInRow.x, CGRectGetMaxX(rampRect))
                
                if firstPoint {
                  CGContextMoveToPoint(context, pointInRow.x, pointInRow.y)
                  firstPoint = false
                }
                else {
                  CGContextAddLineToPoint(context, pointInRow.x, pointInRow.y)
                }
              }
              CGContextStrokePath(context)
            }
            
          }
          
          layerRect.origin.y += layerRect.size.height
        }
        
        stageRect.origin.x += stageRect.size.width
      }
      
      runningTop += rowRect.size.height
      runningTop += kGapAfterRows
    }
    
    if audioMixTracks.count > 0 {
      bannerRect.origin.y = runningTop
      CGContextSetRGBFillColor(context, 0.00, 0.00, 0.00, 1.00) // white
      NSString(format: "AVAudioMix").drawInRect(bannerRect, withAttributes: [NSForegroundColorAttributeName : UIColor.whiteColor()])
      
      runningTop += bannerRect.size.height
      
      for mixTrack in audioMixTracks {
        rowRect.origin.y = runningTop
        
        var rampRect = rowRect
        rampRect.size.width = CGFloat(CMTimeGetSeconds(duration) * scaledDurationToWidth)
        rampRect = CGRectInset(rampRect, 3.0, 3.0)
        
        CGContextSetRGBFillColor(context, 0.55, 0.02, 0.02, 1.00) // darker red
        CGContextSetRGBStrokeColor(context, 0.87, 0.10, 0.10, 1.00) // brighter red
        CGContextSetLineWidth(context, 2.0)
        CGContextAddRect(context, rampRect)
        CGContextDrawPath(context, CGPathDrawingMode.FillStroke)
        
        CGContextBeginPath(context)
        CGContextSetRGBStrokeColor(context, 0.95, 0.68, 0.09, 1.00) // yellow
        CGContextSetLineWidth(context, 3.0)
        var firstPoint = false
        for pointValue in mixTrack {
          let timeVolumePoint = pointValue
          var pointInRow = CGPoint()
          
          pointInRow.x = rampRect.origin.x + timeVolumePoint.x * CGFloat(scaledDurationToWidth)
          pointInRow.y = rampRect.origin.y + ( 0.9 - 0.8 * timeVolumePoint.y ) * rampRect.size.height
          
          pointInRow.x = max(pointInRow.x, CGRectGetMinX(rampRect))
          pointInRow.x = min(pointInRow.x, CGRectGetMaxX(rampRect))
          
          if firstPoint {
            CGContextMoveToPoint(context, pointInRow.x, pointInRow.y)
            firstPoint = false
          }
          else {
            CGContextAddLineToPoint(context, pointInRow.x, pointInRow.y)
          }
        }
        CGContextStrokePath(context)
        
        runningTop += rowRect.size.height
      }
      runningTop += kGapAfterRows
    }
    
    if compositionTracks.count > 0 {
      self.layer.sublayers = nil
      let visibleRect = self.layer.bounds
      var currentTimeRect = visibleRect
      
      // The red band of the timeMaker will be 8 pixels wide
      currentTimeRect.origin.x = 0
      currentTimeRect.size.width = 8
      
      let timeMarkerRedBandLayer = CAShapeLayer()
      timeMarkerRedBandLayer.frame = currentTimeRect
      timeMarkerRedBandLayer.position = CGPointMake(rowRect.origin.x, self.bounds.size.height / 2)
      let linePath = CGPathCreateWithRect(currentTimeRect, nil)
      timeMarkerRedBandLayer.fillColor = UIColor(red: 1.0, green: 0, blue: 0, alpha: 0.5).CGColor
      timeMarkerRedBandLayer.path = linePath
      
      currentTimeRect.origin.x = 0
      currentTimeRect.size.width = 1
      
      // Position the white line layer of the timeMarker at the center of the red band layer
      let timeMarkerWhiteLineLayer = CAShapeLayer()
      timeMarkerWhiteLineLayer.frame = currentTimeRect
      timeMarkerWhiteLineLayer.position = CGPointMake(4, self.bounds.size.height / 2)
      let whiteLinePath = CGPathCreateWithRect(currentTimeRect, nil)
      timeMarkerWhiteLineLayer.fillColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0).CGColor
      timeMarkerWhiteLineLayer.path = whiteLinePath
      
      // Add the white line layer to red band layer, by doing so we can only animate the red band layer which in turn animates its sublayers
      timeMarkerRedBandLayer.addSublayer(timeMarkerWhiteLineLayer)
      
      // This scrubbing animation controls the x position of the timeMarker
      // On the left side it is bound to where the first segment rectangle of the composition starts
      // On the right side it is bound to where the last segment rectangle of the composition ends
      // Playback at rate 1.0 would take the timeMarker "duration" time to reach from one end to the other, that is marked as the duration of the animation
      let scrubbingAnimation = CABasicAnimation(keyPath: "position.x")
      scrubbingAnimation.fromValue = horizontalPositionForTime(kCMTimeZero)
      scrubbingAnimation.toValue = horizontalPositionForTime(duration)
      scrubbingAnimation.removedOnCompletion = false
      scrubbingAnimation.beginTime = AVCoreAnimationBeginTimeAtZero
      scrubbingAnimation.duration = CMTimeGetSeconds(duration)
      scrubbingAnimation.fillMode = kCAFillModeBoth
      timeMarkerRedBandLayer.addAnimation(scrubbingAnimation, forKey: nil)
      
      // We add the red band layer along with the scrubbing animation to a AVSynchronizedLayer to have precise timing information
      if let currentItem = self.player?.currentItem {
        var syncLayer = AVSynchronizedLayer(playerItem: currentItem)
        syncLayer.addSublayer(timeMarkerRedBandLayer)
        
        self.layer.addSublayer(syncLayer)
      }
    }
  }
  
  
  func horizontalPositionForTime(time: CMTime) -> Double {
    let seconds = CMTIME_IS_NUMERIC(time) && time > kCMTimeZero ? CMTimeGetSeconds(time) :  0.0
    return seconds * scaledDurationToWidth + Double(kLeftInsetToMatchTimeSlider + kLeftMarginInset)
  }
}
