import Foundation

/// Fossify Commons' Int color helpers (darkenColor / lightenColor / adjustAlpha / getContrastColor)
/// on ARGB values, with the same HSV <-> HSL lightness math.
extension UInt32 {
    /// darkenColor(factor): lowers the HSL lightness by factor %. White and black stay unchanged.
    public func darkened(by factor: Int = 8) -> UInt32 {
        shaded(by: -Float(factor) / 100)
    }

    /// lightenColor(factor): raises the HSL lightness by factor %. White and black stay unchanged.
    public func lightened(by factor: Int = 8) -> UInt32 {
        shaded(by: Float(factor) / 100)
    }

    /// adjustAlpha(factor): multiplies the alpha channel.
    public func alphaAdjusted(_ factor: Double) -> UInt32 {
        let alpha = UInt32(Swift.max(0, Swift.min(255, (Double((self >> 24) & 0xFF) * factor).rounded())))
        return alpha << 24 | (self & 0xFFFFFF)
    }

    /// getContrastColor() as ARGB: dark grey on light colors, white on dark ones.
    public var contrastARGB: UInt32 {
        func lin(_ c: UInt32) -> Double {
            let v = Double(c) / 255
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * lin((self >> 16) & 0xFF) + 0.7152 * lin((self >> 8) & 0xFF) + 0.0722 * lin(self & 0xFF)
        return luminance > 0.5 ? 0xFF333333 : 0xFFFFFFFF
    }

    private func shaded(by delta: Float) -> UInt32 {
        if self == 0xFFFFFFFF || self == 0xFF000000 { return self }
        let r = Float((self >> 16) & 0xFF) / 255, g = Float((self >> 8) & 0xFF) / 255, b = Float(self & 0xFF) / 255
        // Color.colorToHSV
        let mx = Swift.max(r, g, b), mn = Swift.min(r, g, b), d = mx - mn
        var h: Float = 0
        if d > 0 {
            if mx == r { h = (g - b) / d } else if mx == g { h = (b - r) / d + 2 } else { h = (r - g) / d + 4 }
            h *= 60
            if h < 0 { h += 360 }
        }
        let s: Float = mx == 0 ? 0 : d / mx
        let v = mx
        // hsv2hsl
        let l0 = (2 - s) * v
        var sl = s * v / (l0 < 1 ? l0 : 2 - l0)
        if sl > 1 || sl.isNaN { sl = sl.isNaN ? 0 : 1 }
        var l = l0 / 2 + delta
        if l < 0 { l = 0 }
        // hsl2hsv
        var sat = sl * (l < 0.5 ? l : 1 - l)
        let nv = l + sat
        sat = nv == 0 ? 0 : 2 * sat / (l + sat)
        // Color.HSVToColor
        let c = nv * sat, x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1)), m = nv - c
        let (r1, g1, b1): (Float, Float, Float)
        switch h {
        case ..<60: (r1, g1, b1) = (c, x, 0)
        case ..<120: (r1, g1, b1) = (x, c, 0)
        case ..<180: (r1, g1, b1) = (0, c, x)
        case ..<240: (r1, g1, b1) = (0, x, c)
        case ..<300: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }
        func ch(_ f: Float) -> UInt32 { UInt32(Swift.max(0, Swift.min(255, ((f + m) * 255).rounded()))) }
        return (self & 0xFF000000) | ch(r1) << 16 | ch(g1) << 8 | ch(b1)
    }
}
