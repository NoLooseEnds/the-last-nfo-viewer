import Cocoa

class ThemeAwareScrollView: NSScrollView {
    var onAppearanceChanged: (() -> Void)?
    
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChanged?()
    }
}

