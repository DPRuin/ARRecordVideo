//
//  DPlayer.swift
//  ARRecordVideo
//
//  Created by mac126 on 2018/4/19.
//  Copyright © 2018年 mac126. All rights reserved.
//

import UIKit
import AVFoundation

class DPlayer: UIView {

    open var videoUrl: URL! {
        didSet {
            removeAvPlayerNotificationObserver()
            nextPlayer()
        }
    }
    private var player: AVPlayer!
    
    init(frame: CGRect, withShowIn bgView: UIView, url: URL) {
        super.init(frame: frame)
        videoUrl = url
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        addAVPlayerNotificationObserver(playerItem: player.currentItem!)
        //创建播放器层
        let playerLayer = AVPlayerLayer(player: player)
        
        playerLayer.frame = bounds
        layer.addSublayer(playerLayer)

        bgView.addSubview(self)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        removeAvPlayerNotificationObserver()
        stopPlayer()
        player = nil
    }
    
    public func stopPlayer() {
        if player.rate == 1 {
            player.pause()
        }
    }
    
    private func removeAvPlayerNotificationObserver() {
        let playerItem = player.currentItem
        playerItem?.removeObserver(self, forKeyPath: "status")
        playerItem?.removeObserver(self, forKeyPath: "loadedTimeRanges")
        NotificationCenter.default.removeObserver(self)
    }
    
    private func addAVPlayerNotificationObserver(playerItem: AVPlayerItem) {
        // 监控状态属性
        playerItem.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context: nil)
        // 监控网络加载情况属性
        playerItem.addObserver(self, forKeyPath: "loadedTimeRanges", options: NSKeyValueObservingOptions.new, context: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.playbackFinished(notification:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        
    }
    
    private func nextPlayer() {
        player.seek(to: CMTime(seconds: 0, preferredTimescale: (player.currentItem?.duration.timescale)!))
        let avPlayerItem = AVPlayerItem(url: videoUrl)
        player.replaceCurrentItem(with: avPlayerItem)
        addAVPlayerNotificationObserver(playerItem: player.currentItem!)
        
        if player.rate == 0 {
            player.play()
        }
    }
    
    @objc func playbackFinished(notification: Notification) {
        player.seek(to: CMTime(value: 0, timescale: 1))
        player.play()
    }
    
    
}
