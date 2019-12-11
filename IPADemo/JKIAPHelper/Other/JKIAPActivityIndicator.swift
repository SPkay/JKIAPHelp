//
//  JKIAPActivityIndicator.swift
//  JKIAPHelper
//
//  Created by Kane on 2019/8/7.
//  Copyright © 2019 kane. All rights reserved.
//

import Foundation



struct JKIAPActivityIndicator {
    
    let actIndicatorView :UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .whiteLarge)
       
        view.color = .black
       
        return view
    }()
    let activitybackView : UIVisualEffectView = {
        let blur = UIBlurEffect(style: .light)
        let  visualEffectView = UIVisualEffectView(effect: blur)
        visualEffectView.alpha = 1;
        visualEffectView.layer.cornerRadius = 5;
        return visualEffectView
    }()
    let backView : UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
  
        
    init() {
        
        actIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        backView.translatesAutoresizingMaskIntoConstraints = false
        activitybackView.translatesAutoresizingMaskIntoConstraints = false
        backView.addSubview(activitybackView)
        activitybackView.addSubview(actIndicatorView)
       layoutViews()
    }
        /**
         * 活动指示器弹出框开始
         */
    
    func start() {
        DispatchQueue.main.async {
            if self.actIndicatorView.isAnimating{
                self.stop()
            }
            self.backView.alpha = 0
            self.actIndicatorView.startAnimating()
            self.backView.layoutIfNeeded()
            UIView.animate(withDuration: 0.5, animations: {
                self.backView.alpha = 1
            })
        }
    }
    
    
    /**
     * 活动指示器弹出框结束
     */
    func stop() {
        UIView.animate(withDuration: 0.5, animations: {
            self.backView.alpha = 0
        }) { (_) in
            self.backView.removeFromSuperview()
            self.actIndicatorView.stopAnimating()
        }
            
    }

  private  func layoutViews() {
        let keyWindow = UIApplication.shared.keyWindow
        keyWindow?.addSubview(backView)
        let constrant11 = NSLayoutConstraint(item: backView, attribute: .top, relatedBy: .equal, toItem: keyWindow, attribute: .top, multiplier: 1.0, constant: 0)
        let constrant12 = NSLayoutConstraint(item: backView, attribute: .left, relatedBy: .equal, toItem: keyWindow, attribute: .left, multiplier: 1.0, constant: 0)
        let constrant13 = NSLayoutConstraint(item: backView, attribute: .right, relatedBy: .equal, toItem: keyWindow, attribute: .right, multiplier: 1.0, constant: 0)
        let constrant14 = NSLayoutConstraint(item: backView, attribute: .bottom, relatedBy: .equal, toItem: keyWindow, attribute: .bottom, multiplier: 1.0, constant: 0)
        keyWindow?.addConstraints([constrant11, constrant12, constrant13, constrant14])
        
        
        
        let constrant21 = NSLayoutConstraint(item: activitybackView, attribute: .centerX, relatedBy: .equal, toItem: backView, attribute: .centerX, multiplier: 1.0, constant: 0)
        
        let constrant22 = NSLayoutConstraint(item: activitybackView, attribute: .centerY, relatedBy: .equal, toItem: backView, attribute: .centerY, multiplier: 1.0, constant: 0)
        
        let constrant23 = NSLayoutConstraint(item: activitybackView, attribute: .height, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 95)
        
        let constrant24 = NSLayoutConstraint(item: activitybackView, attribute: .width, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 130)
        backView.addConstraints([constrant21, constrant22, constrant23, constrant24])

let constrant41 = NSLayoutConstraint(item: actIndicatorView, attribute: .centerX, relatedBy: .equal, toItem: activitybackView, attribute: .centerX, multiplier: 1.0, constant: 0)

let constrant42 = NSLayoutConstraint(item: actIndicatorView, attribute: .centerY, relatedBy: .equal, toItem: activitybackView, attribute: .centerY, multiplier: 1.0, constant: -10)

activitybackView.addConstraints([constrant41, constrant42])

    

    }
    
   

}
