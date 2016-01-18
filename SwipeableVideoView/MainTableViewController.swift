//
//  MainTableViewController.swift
//  SwipeableVideoView
//
//  Created by KittenYang on 15/11/25.
//  Copyright © 2015年 KittenYang. All rights reserved.
//

import UIKit
import MediaPlayer

class MainTableViewController: UITableViewController {
    
    var player : MPMoviePlayerController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    private func playerVideo() {
        
        let indicatorView = UIActivityIndicatorView(activityIndicatorStyle: .White)
        player = MPMoviePlayerController()
        player?.view.frame = CGRect(x: 0, y: 64, width: UIScreen.mainScreen().bounds.width, height: 200)
        player?.controlStyle = .Default
        player?.shouldAutoplay = true
        player?.repeatMode = .None
        player?.scalingMode = .AspectFit
        if let keywindow = UIApplication.sharedApplication().keyWindow, let player = player {
            keywindow.addSubview(player.view)
            indicatorView.center = CGPoint(x: player.view.bounds.width/2, y: player.view.bounds.height/2)
            indicatorView.bounds = CGRect(x: 0, y: 0, width: 30, height: 30)
            player.view.addSubview(indicatorView)
            indicatorView.startAnimating()
        }
        
        HCYoutubeParser.h264videosWithYoutubeURL(NSURL(string: "https://www.youtube.com/watch?v=Z56jc_pVVvk")) { [weak self] (qualities, error) -> Void in
            
            if error == nil && qualities != nil{
                var urlString = ""
                if qualities["small"] == nil && qualities["live"] == nil {
                    let _ = UIAlertView(title: "Error", message: "Couldn't find youtube video", delegate: nil, cancelButtonTitle: "Close", otherButtonTitles: "", "").show()
                    return
                } else {
                    if qualities["small"] != nil {
                        urlString = qualities["small"] as! String
                    } else if qualities["live"] != nil{
                        urlString = qualities["live"] as! String
                    }
                }
                
                if urlString != "" {
                    if let strongSelf = self {
                        strongSelf.player?.contentURL = NSURL(string: urlString)
                        strongSelf.player?.prepareToPlay()
                        indicatorView.stopAnimating()
                        indicatorView.removeFromSuperview()
                    }
                }
            } else {
                if let error = error{
                    let _ = UIAlertView(title: "Error", message: error.localizedDescription, delegate: nil, cancelButtonTitle: "Dismiss", otherButtonTitles: "", "").show()
                }
            }
        }
    }
    
}

// MARK: - Table view data source & delegate

extension MainTableViewController {
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 20
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("demoCell", forIndexPath: indexPath)
        
        cell.textLabel?.text = "No.\(indexPath.row+1)"
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        playerVideo()
    }

}
