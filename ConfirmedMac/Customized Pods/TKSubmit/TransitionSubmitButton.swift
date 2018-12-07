import Foundation

@IBDesignable
class TKTransitionSubmitButton : TunnelsButton, CAAnimationDelegate {
    
    
    lazy var spinnerAnimation : CABasicAnimation! = {
        let rotate = CABasicAnimation(keyPath: "transform.rotation.z")
        rotate.fromValue = 0
        rotate.toValue = Double.pi * 2
        rotate.duration = 0.3
        rotate.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        
        rotate.repeatCount = HUGE
        rotate.fillMode = kCAFillModeForwards
        rotate.isRemovedOnCompletion = false
        
        return rotate
    }()
    
    @IBInspectable open var spinnerColor: NSColor = NSColor.white {
        didSet {
        }
    }
    
    open var didEndFinishAnimation : (()->())? = nil

    let springGoEase = CAMediaTimingFunction(controlPoints: 0.45, -0.36, 0.44, 0.92)
    let shrinkCurve = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
    let expandCurve = CAMediaTimingFunction(controlPoints: 0.95, 0.02, 1, 0.05)
    let shrinkDuration: CFTimeInterval  = 0.1
    
    var mp : MaterialProgress?
    
    @IBInspectable open var normalCornerRadius:CGFloat = 0.0 {
        didSet {
            self.layer?.cornerRadius = normalCornerRadius
        }
    }

    var cachedTitle: String?
    var cachedCornerRadius: CGFloat = 0.0

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    public required init!(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        self.setup()
    }

    func setup() {
        //self.layer?.masksToBounds = true
        let width = self.frame.size.height //* 0.7
        let xPos = self.frame.size.width / 2.0 + width / 4.0
        let yPos = self.frame.size.height / 2.0 + width / 4.0
        cachedCornerRadius = 5.0
        
        mp = MaterialProgress.init(frame: CGRect.init(x: xPos, y: yPos, width: width, height: width), ratio: 0.5)
        
        mp?.progressLayer.strokeColor = spinnerColor.cgColor
        mp?.progressLayer.anchorPoint = CGPoint.init(x: 0.5, y: 0.5)
        mp?.progressLayer.strokeEnd = 0.5
        //mp.progressLayer.bounds = self.bounds
        
    }

    open func startLoadingAnimation() {
        self.cachedTitle = self.title
        self.title = ""
        self.mp?.progressLayer.isHidden = true
        
        self.layer?.masksToBounds = true
        self.layer?.cornerRadius = self.frame.size.width
        self.layer?.addSublayer((mp?.progressLayer)!)
        
        mp?.progressLayer.add(spinnerAnimation, forKey: spinnerAnimation.keyPath)
      
        self.cornerRadius = self.frame.size.height / 2.0
        
            self.shrink()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.mp?.progressLayer.isHidden = false
        }
        
    }

    open func startFinishAnimation(_ delay: TimeInterval,_ animation: CAMediaTimingFunction, completion:(()->())?) {
        Timer.schedule(delay: delay) { timer in
            self.didEndFinishAnimation = completion
            self.expand(animation)
        }
    }

    open func animate(_ duration: TimeInterval,_ animation: CAMediaTimingFunction, completion:(()->())?) {
        startLoadingAnimation()
        startFinishAnimation(duration, animation, completion: completion)
    }

    open func setOriginalState() {
        self.returnToOriginalState()
    }
    
    public func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        let a = anim as! CABasicAnimation
        if a.keyPath == "transform.scale" {
            didEndFinishAnimation?()
            Timer.schedule(delay: 1) { timer in
                self.returnToOriginalState()
            }
        }
    }
    
    open func returnToOriginalState() {
        
        self.layer?.removeAllAnimations()
        mp?.progressLayer.isHidden = true
        mp?.progressLayer.removeAllAnimations()
        self.title = cachedTitle!
        self.layer?.cornerRadius = cachedCornerRadius
        self.cornerRadius = cachedCornerRadius
    }
    
    func shrink() {
        var shrinkAnim = CABasicAnimation(keyPath: "bounds.size.width")
        shrinkAnim.fromValue = frame.width
        shrinkAnim.toValue = frame.height
        shrinkAnim.duration = shrinkDuration
        shrinkAnim.timingFunction = shrinkCurve
        shrinkAnim.fillMode = kCAFillModeForwards
        shrinkAnim.isRemovedOnCompletion = false
        
        var shrinkAnimPosition = CABasicAnimation(keyPath: "position.x")
        shrinkAnimPosition.fromValue = 0
        shrinkAnimPosition.toValue = self.frame.width / 2.0 + self.frame.height / 3.0
        shrinkAnimPosition.duration = shrinkDuration * 0.9
        shrinkAnimPosition.timingFunction = shrinkCurve
        shrinkAnimPosition.fillMode = kCAFillModeForwards
        shrinkAnimPosition.isRemovedOnCompletion = false
        layer?.add(shrinkAnim, forKey: shrinkAnim.keyPath)
        layer?.add(shrinkAnimPosition, forKey: shrinkAnimPosition.keyPath)
        
    }
    
    func expand(_ animation: CAMediaTimingFunction) {
        let expandAnim = CABasicAnimation(keyPath: "transform.scale")
        expandAnim.fromValue = 1.0
        expandAnim.toValue = 26.0
        expandAnim.timingFunction = animation
        expandAnim.duration = 0.3
        expandAnim.delegate = self
        expandAnim.fillMode = kCAFillModeForwards
        expandAnim.isRemovedOnCompletion = false
        layer?.add(expandAnim, forKey: expandAnim.keyPath)
    }
    
}
