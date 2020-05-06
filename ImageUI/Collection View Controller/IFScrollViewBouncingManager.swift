//
//  IFScrollViewBouncingManager.swift
//  ImageUI
//
//  Created by Alberto Saltarelli on 28/04/2020.
//

import Foundation
import Photos

extension UIScrollView {
    enum BouncingDirection {
        case top
        case left
        case bottom
        case right
    }
}

protocol IFScrollViewBouncingDelegate: class {
    func scrollView(_ scrollView: UIScrollView, didBeginBouncing direction: UIScrollView.BouncingDirection)
    func scrollView(_ scrollView: UIScrollView, didReverseBouncing direction: UIScrollView.BouncingDirection)
}

extension IFScrollViewBouncingDelegate {
    func scrollView(_ scrollView: UIScrollView, didBeginBouncing direction: UIScrollView.BouncingDirection) { }
    func scrollView(_ scrollView: UIScrollView, didReverseBouncing direction: UIScrollView.BouncingDirection) { }
}

class IFScrollViewBouncingManager {
    weak var delegate: IFScrollViewBouncingDelegate?
    
    private var observations: Set<Observation> = []
    
    func startObserving(scrollView: UIScrollView, bouncingDirections: [UIScrollView.BouncingDirection]) {
        let token = scrollView.observe(\.contentOffset, options: [.old, .new]) { [weak self] scrollView, change in
            guard let oldValue = change.oldValue else { return }
            self?.handleContentOffset(in: scrollView, previousValue: oldValue)
        }

        let observation = Observation(scrollView: scrollView, token: token, directions: bouncingDirections)
        observations.insert(observation)
    }
    
    func stopObserving(scrollView: UIScrollView) {
        guard let observation = observation(of: scrollView) else { return }
        observations.remove(observation)
    }
    
    func stopObservingAllScrollViews() {
        observations = []
    }
    
    func bouncingDirections(of scrollView: UIScrollView) -> [UIScrollView.BouncingDirection] {
        guard let observation = observation(of: scrollView) else { return [] }
        var directions: [UIScrollView.BouncingDirection] = []
        if observation.isHorizontalBouncing {
            directions.append(scrollView.contentOffset.x < -scrollView.contentInset.left.rounded(.up) ? .left : .right)
        }
        if observation.isVerticalBouncing {
            directions.append(scrollView.contentOffset.y < -scrollView.contentInset.top.rounded(.up) ? .top : .bottom)
        }
        return directions
    }
    
    private func handleContentOffset(in scrollView: UIScrollView, previousValue: CGPoint) {
        guard let observation = observation(of: scrollView) else { return }
        guard scrollView.isDecelerating else {
            observation.stopBouncing()
            return
        }
        
        handleHorizontalContentOffsetIfNeeded(in: scrollView, previousOffset: previousValue.x)
        handleVerticalContentOffsetIfNeeded(in: scrollView, previousOffset: previousValue.y)
    }
    
    private func handleHorizontalContentOffsetIfNeeded(in scrollView: UIScrollView, previousOffset: CGFloat) {
        guard let observation = observation(of: scrollView) else { return }
                
        let minimumContentOffsetX = -scrollView.contentInset.left.rounded(.up)
        let maximumContentOffsetX: CGFloat
        if scrollView.contentSize.width <= scrollView.frame.width {
            maximumContentOffsetX = minimumContentOffsetX
        } else {
            maximumContentOffsetX = (scrollView.contentSize.width - scrollView.frame.width + scrollView.contentInset.right).rounded(.down)
        }
        
        let isMinimumBouncing = scrollView.contentOffset.x < minimumContentOffsetX && observation.directions.contains(.left)
        let isMaximumBouncing = scrollView.contentOffset.x > maximumContentOffsetX && observation.directions.contains(.right)
        guard isMinimumBouncing || isMaximumBouncing else { return }
        
        if !observation.isHorizontalBouncing {
            observation.isHorizontalBouncing = true
            delegate?.scrollView(scrollView, didBeginBouncing: isMinimumBouncing ? .left : .right)
        } else if !observation.isHorizontalReverseBouncing {
            let isMinimumBouncingReverted = isMinimumBouncing && scrollView.contentOffset.x > previousOffset
            let isMaximumBouncingReverted = isMaximumBouncing && scrollView.contentOffset.x < previousOffset
            if isMinimumBouncingReverted || isMaximumBouncingReverted {
                observation.isHorizontalReverseBouncing = true
                delegate?.scrollView(scrollView, didReverseBouncing: isMinimumBouncingReverted ? .left : .right)
            }
        }
    }
    
    private func handleVerticalContentOffsetIfNeeded(in scrollView: UIScrollView, previousOffset: CGFloat) {
        guard
            let observation = observation(of: scrollView),
            observation.directions.contains(where: { $0 == .top || $0 == .bottom }) else { return }
        
        let minimumContentOffsetY = -scrollView.contentInset.top.rounded(.up)
        let maximumContentOffsetY: CGFloat
        if scrollView.contentSize.height <= scrollView.frame.height {
            maximumContentOffsetY = minimumContentOffsetY
        } else {
            maximumContentOffsetY = (scrollView.contentSize.height - scrollView.frame.height + scrollView.contentInset.bottom).rounded(.down)
        }
        
        let isMinimumBouncing = scrollView.contentOffset.y < minimumContentOffsetY && observation.directions.contains(.top)
        let isMaximumBouncing = scrollView.contentOffset.y > maximumContentOffsetY && observation.directions.contains(.bottom)
        guard isMinimumBouncing || isMaximumBouncing else { return }
        
        if !observation.isVerticalBouncing {
            observation.isVerticalBouncing = true
            delegate?.scrollView(scrollView, didBeginBouncing: isMinimumBouncing ? .left : .right)
        } else if !observation.isVerticalReverseBouncing {
            let isMinimumBouncingReverted = isMinimumBouncing && scrollView.contentOffset.x > previousOffset
            let isMaximumBouncingReverted = isMaximumBouncing && scrollView.contentOffset.x < previousOffset
            if isMinimumBouncingReverted || isMaximumBouncingReverted {
                observation.isVerticalReverseBouncing = true
                delegate?.scrollView(scrollView, didReverseBouncing: isMinimumBouncingReverted ? .left : .right)
            }
        }
    }
    
    private func observation(of scrollView: UIScrollView) -> Observation? {
        let observation = Observation(scrollView: scrollView)
        return observations.firstIndex(of: observation).map { observations[$0] }
    }
}

extension IFScrollViewBouncingManager {
    private class Observation: Hashable {
        let scrollView: UIScrollView
        let token: NSKeyValueObservation?
        let directions: [UIScrollView.BouncingDirection]
        var isHorizontalBouncing = false
        var isVerticalBouncing = false
        var isHorizontalReverseBouncing = false
        var isVerticalReverseBouncing = false
        
        init(scrollView: UIScrollView, token: NSKeyValueObservation? = nil, directions: [UIScrollView.BouncingDirection] = []) {
            self.scrollView = scrollView
            self.token = token
            self.directions = directions
        }
        
        static func == (lhs: Observation, rhs: Observation) -> Bool {
            lhs.scrollView == rhs.scrollView
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(scrollView)
        }
        
        func stopBouncing() {
            isHorizontalBouncing = false
            isVerticalBouncing = false
            isHorizontalReverseBouncing = false
            isVerticalReverseBouncing = false
        }
    }
}
