//
//  AnimatableProperty.swift
//  Zeno
//
//  Created by James Taylor on 2016-02-26.
//  Copyright © 2016 James Taylor. All rights reserved.
//

import UIKit
import pop

// 💩
private typealias POPReadBlock = (AnyObject!, UnsafeMutablePointer<CGFloat>) -> ()
private typealias POPWriteBlock = (AnyObject!, UnsafePointer<CGFloat>) -> ()
private typealias POPInitializer = (POPMutableAnimatableProperty!) -> ()
private typealias POPCompletionBlock = (POPAnimation!, Bool) -> ()

/// An structure defining an animatable property of an object.
public struct AnimatableProperty<Object: NSObject> {
    
    // 🙌
    public typealias PropertyRead = (Object, inout CGFloat) -> ()
    public typealias PropertyWrite = (Object, CGFloat) -> ()
    
    // DEFINITELY SHOULD NOT BE USING UNOWNED HERE, ONLY USING BECAUSE THE WEAK
    // DECLARATION BELOW IS CRASHING IN XCODE 7.3 BETA 5. PLEASE TURN ME BACK TO WEAK.
    //
    // private(set) weak var object: Object? *Crashing in Xcode 7.3 Beta 5*
    //
    /// The object owner of the property.
    public unowned let object: Object
    
    /// The name associated with the property.
    public var name: String { return property.name }
    
    /// The threshold of the property.
    public var threshold: CGFloat { return property.threshold }
    
    // The backing POPAnimatableProperty object.
    private let property: POPAnimatableProperty
    
    // The next identifier to use when automatically generating a new key.
    private var nextKey: Int = 0
}

// + Equatable
extension AnimatableProperty: Equatable {}
public func == <Object where Object: Equatable> (lhs: AnimatableProperty<Object>, rhs: AnimatableProperty<Object>) -> Bool {
    return (lhs.object == rhs.object) && (lhs.name == rhs.name) && (lhs.threshold == rhs.threshold) && (lhs.property == rhs.property)
}

// + Initializers
public extension AnimatableProperty {
    
    /// Initialize a new instance of `AnimatableProperty` with
    /// the property's housing `object`, and appropriate `read`
    /// and `write` closures.
    init(object: Object, read: PropertyRead, write: PropertyWrite, name: String = "", threshold: CGFloat = 0.01) {
        
        self.object = object
        
        // Cast the PropertyRead block to a POPReadBlock
        let readBlock: POPReadBlock = { read($0 as! Object, &$1[0]) }
        
        // Cast the PropertyWrite block to a POPWriteBlock
        let writeBlock: POPWriteBlock = { write($0 as! Object, $1[0]) }
        
        // Build the backing POPAnimatableProperty
        property = POPAnimatableProperty.propertyWithName(name) {
            $0.readBlock = readBlock
            $0.writeBlock = writeBlock
            $0.threshold = threshold
        } as! POPAnimatableProperty
    }
}

// MARK: - Animations

public extension AnimatableProperty {
    
    /// Animates the receiver for `duration` to a final value following
    /// a timing function (default is `TimingFunction.Default`)
    mutating func animate(toValue toValue: CGFloat, duration: CFTimeInterval, timingFunction: TimingFunction = .Default, appliedBlock: (BasicAnimationState -> ())? = nil, completionBlock: (BasicAnimationState -> ())? = nil) {
        
        // guard let object = object else { return }
        
        let animation = POPBasicAnimation()
        animation.property = property
        animation.toValue = toValue
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(timingFunction)
        
        // Generate a new key
        let key = generateNewKey()
        
        // Capture state on completion
        animation.completionBlock = { (animation, completed) in
            completionBlock?(BasicAnimationState(animation: animation, key: key, completed: completed)!)
        }
        
        animation.animationDidApplyBlock = { animation in
            appliedBlock?(BasicAnimationState(animation: animation, key: key, completed: false)!)
        }
        
        object.pop_addAnimation(animation, forKey: key)
    }
    
    /// Animates the receiver to a final value based on a spring 
    /// and an initial velocity.
    mutating func animate(toValue toValue: CGFloat, initialVelocity: CGFloat = 0, springBounciness: CGFloat = 4, springSpeed: CGFloat = 12, appliedBlock: (SpringAnimationState -> ())? = nil, completionBlock: (SpringAnimationState -> ())? = nil) {
        
        // guard let object = object else { return }
        
        let animation = POPSpringAnimation()
        animation.property = property
        animation.toValue = toValue
        animation.velocity = initialVelocity
        animation.springBounciness = springBounciness
        animation.springSpeed = springSpeed
        
        // Generate a new key
        let key = generateNewKey()
        
        // Capture state on completion
        animation.completionBlock = { (animation, completed) in
            completionBlock?(SpringAnimationState(animation: animation, key: key, completed: completed)!)
        }
        
        animation.animationDidApplyBlock = { animation in
            appliedBlock?(SpringAnimationState(animation: animation, key: key, completed: false)!)
        }
        
        object.pop_addAnimation(animation, forKey: key)
    }
    
    /// Animates the receiver by giving it a initial velocity and
    /// letting it decay based on `damping`.
    mutating func animate(initialVelocity initialVelocity: CGFloat, damping: CGFloat = 0.998, appliedBlock: (DecayAnimationState -> ())? = nil, completionBlock: (DecayAnimationState -> ())? = nil) {
        
        // guard let object = object else { return }
        
        let animation = POPDecayAnimation()
        animation.property = property
        animation.velocity = initialVelocity
        animation.deceleration = damping
        
        // Generate a new key
        let key = generateNewKey()
        
        // Capture state on completion
        animation.completionBlock = { (animation, completed) in
            completionBlock?(DecayAnimationState(animation: animation, key: key, completed: completed)!)
        }
        
        animation.animationDidApplyBlock = { animation in
            appliedBlock?(DecayAnimationState(animation: animation, key: key, completed: false)!)
        }
        
        object.pop_addAnimation(animation, forKey: key)
    }
}

protocol POPAnimationCapturable {
    init(_ animation: POPAnimation, key: String, completed: Bool)
}

private extension AnimatableProperty {
    
    /// Return a new generated key for the property.
    ///
    /// - Important: NOT GREAT 😂
    mutating func generateNewKey() -> String {
        defer { nextKey += 1 }
        return name + "\(nextKey)"
    }
}