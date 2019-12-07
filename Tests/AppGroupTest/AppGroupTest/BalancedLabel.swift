import UIKit

/// A label whose lines have similar width.
///
/// Compare BalancedLabel:
///
///     +----------------------------------------------------+
///     |       Ut enim ad minim veniam, quis nostrud        |
///     |       exercitation ullamco laboris nisi ut         |
///     |       aliquip ex ea commodo consequat.             |
///     +----------------------------------------------------+
///
/// ... with a regular UILabel:
///
///     +----------------------------------------------------+
///     | Ut enim ad minim veniam, quis nostrud exercitation |
///     | ullamco laboris nisi ut aliquip ex ea commodo      |
///     | consequat.                                         |
///     +----------------------------------------------------+
@IBDesignable
class BalancedLabel: UILabel {
    private var label: UILabel
    private var contentSizeCategoryDidChangeObserver: Any?
    private var contentHuggingConstraints: [NSLayoutConstraint] = [] {
        willSet { for constraint in contentHuggingConstraints { constraint.isActive = false } }
        didSet { for constraint in contentHuggingConstraints { constraint.isActive = true } }
    }
    private var alignmentConstraints: [NSLayoutConstraint] = [] {
        willSet { for constraint in alignmentConstraints { constraint.isActive = false } }
        didSet { for constraint in alignmentConstraints { constraint.isActive = true } }
    }
    
    override init(frame: CGRect) {
        label = UILabel(frame: .zero)
        super.init(frame: frame)
        numberOfLines = 0
        lineBreakMode = .byWordWrapping
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        label = UILabel(frame: .zero)
        super.init(coder: aDecoder)
        commonInit()
    }
    
    deinit {
        if let observer = contentSizeCategoryDidChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func commonInit() {
        label.text = super.text
        label.font = super.font
        label.textAlignment = super.textAlignment
        label.textColor = super.textColor
        label.numberOfLines = super.numberOfLines
        label.lineBreakMode = super.lineBreakMode
        label.isOpaque = false
        label.backgroundColor = .clear
        label.adjustsFontSizeToFitWidth = super.adjustsFontSizeToFitWidth
        label.adjustsFontForContentSizeCategory = super.adjustsFontForContentSizeCategory
        label.allowsDefaultTighteningForTruncation = super.allowsDefaultTighteningForTruncation
        label.minimumScaleFactor = super.minimumScaleFactor
        label.baselineAdjustment = super.baselineAdjustment
        super.text = nil
        
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.topAnchor.constraint(equalTo: topAnchor).isActive = true
        label.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        updateInnerConstraints()
    }
    
    // MARK: - Layout
    
    override func setContentCompressionResistancePriority(
        _ priority: UILayoutPriority,
        for axis: NSLayoutConstraint.Axis)
    {
        super.setContentCompressionResistancePriority(priority, for: axis)
        label.setContentCompressionResistancePriority(priority, for: axis)
    }
    
    override func setContentHuggingPriority(_ priority: UILayoutPriority, for axis: NSLayoutConstraint.Axis) {
        super.setContentHuggingPriority(priority, for: axis)
        switch axis {
        case .horizontal:
            for constraint in contentHuggingConstraints {
                constraint.priority = priority
            }
        case .vertical:
            label.setContentHuggingPriority(priority, for: axis)
        @unknown default:
            fatalError("Not implemented")
        }
    }
    
    override var intrinsicContentSize: CGSize {
        return label.intrinsicContentSize
    }
    
    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        label.invalidateIntrinsicContentSize()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let targetHeight = label.sizeThatFits(frame.size).height
        var minWidth = 0 as CGFloat
        var maxWidth = bounds.width
        
        while true {
            if maxWidth - minWidth <= 1 {
                let balancingWidth = ceil(maxWidth)
                
                // Update preferredMaxLayoutWidth and relayout, but avoid
                // infinite loops:
                if label.preferredMaxLayoutWidth < balancingWidth
                    || label.preferredMaxLayoutWidth > balancingWidth + 1
                {
                    label.preferredMaxLayoutWidth = balancingWidth
                    invalidateIntrinsicContentSize()
                    super.layoutSubviews()
                }
                
                return
            }
            let width = (minWidth + maxWidth) / 2
            let height = label.sizeThatFits(CGSize(width: width, height: 0)).height
            if height > targetHeight + 1 {   // + 1 : allow double imprecision
                minWidth = width
            } else {
                maxWidth = width
            }
        }
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        if let observer = contentSizeCategoryDidChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        if self.window != nil {
            contentSizeCategoryDidChangeObserver = NotificationCenter.default.addObserver(
                forName: UIContentSizeCategory.didChangeNotification,
                object: nil,
                queue: nil,
                using: { [unowned self] _ in
                    self.label.preferredMaxLayoutWidth = 0
                    self.invalidateIntrinsicContentSize()
            })
        }
    }
    
    private func updateInnerConstraints() {
        let huggingPriority = contentHuggingPriority(for: .horizontal)
        
        switch textAlignment {
        case .center:
            let leftContentHuggingConstraint = label.leftAnchor.constraint(equalTo: leftAnchor)
            leftContentHuggingConstraint.priority = huggingPriority
            let rightContentHuggingConstraint = label.rightAnchor.constraint(equalTo: rightAnchor)
            rightContentHuggingConstraint.priority = huggingPriority
            contentHuggingConstraints = [
                leftContentHuggingConstraint,
                rightContentHuggingConstraint,
            ]
            alignmentConstraints = [
                label.centerXAnchor.constraint(equalTo: centerXAnchor),
                label.leftAnchor.constraint(greaterThanOrEqualTo: leftAnchor),
                label.rightAnchor.constraint(lessThanOrEqualTo: rightAnchor)
            ]
        case .justified, .natural:
            let contentHuggingConstraint = label.trailingAnchor.constraint(equalTo: trailingAnchor)
            contentHuggingConstraint.priority = huggingPriority
            contentHuggingConstraints = [
                contentHuggingConstraint,
            ]
            alignmentConstraints = [
                label.leadingAnchor.constraint(equalTo: leadingAnchor),
                label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
            ]
        case .left:
            let contentHuggingConstraint = label.rightAnchor.constraint(equalTo: rightAnchor)
            contentHuggingConstraint.priority = huggingPriority
            contentHuggingConstraints = [
                contentHuggingConstraint,
            ]
            alignmentConstraints = [
                label.leftAnchor.constraint(equalTo: leftAnchor),
                label.rightAnchor.constraint(lessThanOrEqualTo: rightAnchor)
            ]
        case .right:
            let contentHuggingConstraint = label.leftAnchor.constraint(equalTo: leftAnchor)
            contentHuggingConstraint.priority = huggingPriority
            contentHuggingConstraints = [
                contentHuggingConstraint,
            ]
            alignmentConstraints = [
                label.leftAnchor.constraint(greaterThanOrEqualTo: leftAnchor),
                label.rightAnchor.constraint(equalTo: rightAnchor)
            ]
        @unknown default:
            fatalError("Not implemented")
        }
    }
    
    // MARK: - Delegated properties
    
    override var textColor: UIColor! {
        get { return label.textColor }
        set { label.textColor = newValue }
    }
    
    override var text: String? {
        get { return label.text }
        set {
            label.text = newValue
            label.preferredMaxLayoutWidth = 0
            invalidateIntrinsicContentSize()
        }
    }
    
    override var adjustsFontForContentSizeCategory: Bool {
        get { return label.adjustsFontForContentSizeCategory }
        set {
            label.adjustsFontForContentSizeCategory = newValue
            label.preferredMaxLayoutWidth = 0
            invalidateIntrinsicContentSize()
        }
    }
    
    override var attributedText: NSAttributedString? {
        get { return label.attributedText }
        set {
            label.attributedText = newValue
            label.preferredMaxLayoutWidth = 0
            invalidateIntrinsicContentSize()
        }
    }
    
    override var font: UIFont! {
        get { return label.font }
        set { label.font = newValue }
    }
    
    override var numberOfLines: Int {
        get { return label.numberOfLines }
        set { label.numberOfLines = newValue }
    }
    
    override var lineBreakMode: NSLineBreakMode {
        get { return label.lineBreakMode }
        set { label.lineBreakMode = newValue }
    }
    
    override var textAlignment: NSTextAlignment {
        get { return label.textAlignment }
        set {
            label.textAlignment = newValue
            updateInnerConstraints()
        }
    }
}
