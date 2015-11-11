//
//  AVCompositionDebugView.swift
//  iOSAVCompositionDebugViewerSwift
//
//  Created by Justin Winter on 11/10/15.
//  Copyright © 2015 soundslides. All rights reserved.
//

import UIKit
import AVFoundation


extension String {
  func drawVeriticallyCenteredInRect(var rect: CGRect, withAttributes attributes: [String : AnyObject]?) {
    let size = self.sizeWithAttributes(attributes)
    rect.origin.y += (rect.size.height - size.height) / 2.0
    self.drawInRect(rect, withAttributes: attributes)
  }
}

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

class APLVideoCompositionStageInfo: NSObject {
  let timeRange: CMTimeRange = CMTimeRangeMake(kCMTimeZero, kCMTimeZero)
  let layerNames = [String]()
  let opacityRamps: [String : AnyObject]? = nil
}


class AVCompositionDebugView: UIView {

  // Constants
  let kLeftInsetToMatchTimeSlider: CGFloat = 50
  let kRightInsetToMatchTimeSlider:CGFloat = 60
  let kLeftMarginInset: CGFloat = 4
  let kBannerHeight: CGFloat = 20
  let kIdealRowHeight: CGFloat = 36
  let kGapAfterRows: CGFloat = 4
  
  
  var drawingLayer: CALayer = CALayer()
  
  var duration: CMTime = kCMTimeZero
  let compositionRectWidth: CGFloat = 0
  
  var compositionTracks = []
  var audioMixTracks = []
  var videoCompositionStages = []
  
  let scaledDurationToWidth = 0
  
  let player: AVPlayer? = nil
  
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
  
  func synchronizeToComposition(composition: AVComposition, videoComposition: AVVideoComposition, audioMix: AVAudioMix) {
    compositionTracks = []
    audioMixTracks = []
    videoCompositionStages = []
    
    duration = CMTimeMake(1, 1) // avoid division by zero later
    // composition
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
    
    // audioMix
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
    
    // videoComposition
    //...
    //..
    //. 
    
  }

}





























