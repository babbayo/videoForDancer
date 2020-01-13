//
//  ABVideoHelper.swift
//  selfband
//
//  Created by Oscar J. Irun on 27/11/16.
//  Copyright © 2016 appsboulevard. All rights reserved.
//

import UIKit
import AVFoundation

class ABVideoHelper: NSObject {

    static func thumbnailFromVideo(asset: AVURLAsset, time: CMTime) -> UIImage{
        let imgGenerator = AVAssetImageGenerator(asset: asset)
        imgGenerator.appliesPreferredTrackTransform = true
        do{
            let cgImage = try imgGenerator.copyCGImage(at: time, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)
            return uiImage
        }catch{
            
        }
        return UIImage()
    }
    
    static func videoDuration(asset: AVURLAsset) -> Float64{
        return CMTimeGetSeconds(asset.duration)
    }
    
}
