//
//  AVCompositionDebugView.swift
//  iOSAVCompositionDebugViewerSwift
//
//  Created by Justin Winter on 11/10/15.
//  Copyright © 2015 soundslides. All rights reserved.
//

import UIKit
import AVFoundation

class AVCompositionDebugView: UIView {

  let drawingLayer: CALayer = CALayer()
  let duration: CMTime = kCMTimeZero
  let compositionRectWidth: CGFloat = 0
  
  var compositionTracks = []
  var audioMixTracks = []
  var videoCompositionStages = []
  
  let scaledDurationToWidth = 0
  
  let player: AVPlayer? = nil
  
  func synchronizeToComposition(composition: AVComposition, videoComposition: AVVideoComposition, audioMix: AVAudioMix) {}

}
