import SwiftUI
import Combine

// MARK: - Premium Animation Components

/// Premium floating action button with ripple effects and haptic feedback
struct PremiumFloatingActionButton: View {
    let icon: String
    let action: () -> Void
    let color: Color
    let size: CGFloat
    
    @State private var isPressed = false
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0
    
    init(icon: String, color: Color = .blue, size: CGFloat = 56, action: @escaping () -> Void) {
        self.icon = icon
        self.action = action
        self.color = color
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Ripple effect
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: size, height: size)
                .scaleEffect(rippleScale)
                .opacity(rippleOpacity)
                .animation(.easeOut(duration: 0.6), value: rippleScale)
            
            // Main button
            Button(action: {
                HapticManager.shared.playImpactFeedback(.medium)
                performAction()
            }) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: size, height: size)
                        .shadow(color: color.opacity(0.3), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
                    
                    Image(systemName: icon)
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                isPressed = pressing
            }) {
                // Long press action
            }
        }
    }
    
    private func performAction() {
        // Trigger ripple animation
        withAnimation(.easeOut(duration: 0.6)) {
            rippleScale = 2.0
            rippleOpacity = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.5)) {
                rippleOpacity = 0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            rippleScale = 0
        }
        
        action()
    }
}

/// Premium card with glass morphism effect
struct PremiumCard<Content: View>: View {
    let content: Content
    let gradient: LinearGradient
    let cornerRadius: CGFloat
    let shadowColor: Color
    let glowIntensity: CGFloat
    
    @State private var isHovered = false
    
    init(
        gradient: LinearGradient = LinearGradient(
            colors: [Color.white.opacity(0.25), Color.white.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        cornerRadius: CGFloat = 20,
        shadowColor: Color = .black.opacity(0.1),
        glowIntensity: CGFloat = 0.5,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.gradient = gradient
        self.cornerRadius = cornerRadius
        self.shadowColor = shadowColor
        self.glowIntensity = glowIntensity
    }
    
    var body: some View {
        content
            .padding()
            .background(
                ZStack {
                    // Glass morphism background
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(gradient)
                        .background(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(.ultraThinMaterial)
                        )
                    
                    // Glow effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: shadowColor, radius: isHovered ? 20 : 10, x: 0, y: isHovered ? 10 : 5)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    HapticManager.shared.playSelectionFeedback()
                }
            }
    }
}

/// Premium progress indicator with particle effects
struct PremiumProgressIndicator: View {
    let progress: Double
    let color: Color
    let thickness: CGFloat
    let size: CGFloat
    
    @State private var animationAmount: CGFloat = 1
    @State private var particleOffset: CGFloat = 0
    
    init(progress: Double, color: Color = .blue, thickness: CGFloat = 8, size: CGFloat = 100) {
        self.progress = progress
        self.color = color
        self.thickness = thickness
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(color.opacity(0.2), lineWidth: thickness)
                .frame(width: size, height: size)
            
            // Progress circle with glow
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [color, color.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: thickness, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .shadow(color: color, radius: 4, x: 0, y: 0)
            
            // Animated particles
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: 4, height: 4)
                    .offset(x: cos(particleOffset + Double(index) * 0.4) * Double(size/2),
                            y: sin(particleOffset + Double(index) * 0.4) * Double(size/2))
                    .opacity(progress > 0.1 ? 0.8 : 0)
            }
            
            // Center text
            VStack {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: size * 0.2, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                particleOffset = 2 * .pi
            }
        }
    }
}

/// Premium toggle switch with smooth animations
struct PremiumToggle: View {
    @Binding var isOn: Bool
    let label: String
    let color: Color
    
    @State private var dragOffset: CGFloat = 0
    
    init(_ label: String, isOn: Binding<Bool>, color: Color = .blue) {
        self.label = label
        self._isOn = isOn
        self.color = color
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            ZStack {
                // Track
                RoundedRectangle(cornerRadius: 16)
                    .fill(isOn ? color : Color.gray.opacity(0.3))
                    .frame(width: 60, height: 32)
                    .animation(.spring(response: 0.3), value: isOn)
                
                // Thumb
                Circle()
                    .fill(.white)
                    .frame(width: 28, height: 28)
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                    .offset(x: isOn ? 14 : -14)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isOn)
            }
            .onTapGesture {
                HapticManager.shared.playImpactFeedback(.light)
                isOn.toggle()
            }
        }
        .padding(.horizontal)
    }
}

/// Premium slider with gradient track and haptic feedback
struct PremiumSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: String
    let color: Color
    let showValue: Bool
    
    @State private var isDragging = false
    
    init(
        _ label: String,
        value: Binding<Double>,
        in range: ClosedRange<Double> = 0...1,
        color: Color = .blue,
        showValue: Bool = true
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.color = color
        self.showValue = showValue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                if showValue {
                    Spacer()
                    Text(String(format: "%.1f", value))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    // Progress track with gradient
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.8), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.width, height: 8)
                    
                    // Thumb
                    Circle()
                        .fill(.white)
                        .frame(width: isDragging ? 24 : 20, height: isDragging ? 24 : 20)
                        .shadow(color: color.opacity(0.3), radius: isDragging ? 8 : 4, x: 0, y: 2)
                        .offset(x: CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.width - (isDragging ? 12 : 10))
                        .animation(.spring(response: 0.2), value: isDragging)
                }
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            if !isDragging {
                                isDragging = true
                                HapticManager.shared.playImpactFeedback(.light)
                            }
                            
                            let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * Double(gesture.location.x / geometry.size.width)
                            value = min(max(newValue, range.lowerBound), range.upperBound)
                        }
                        .onEnded { _ in
                            isDragging = false
                            HapticManager.shared.playImpactFeedback(.medium)
                        }
                )
            }
            .frame(height: 20)
        }
        .padding(.horizontal)
    }
}

// MARK: - Premium Data Visualization Components

/// Premium chart with smooth animations
struct PremiumLineChart: View {
    let data: [Double]
    let color: Color
    let showGrid: Bool
    let animated: Bool
    
    @State private var animationProgress: CGFloat = 0
    
    init(data: [Double], color: Color = .blue, showGrid: Bool = true, animated: Bool = true) {
        self.data = data
        self.color = color
        self.showGrid = showGrid
        self.animated = animated
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid lines
                if showGrid {
                    gridLines(in: geometry)
                }
                
                // Chart line
                chartPath(in: geometry)
                    .trim(from: 0, to: animated ? animationProgress : 1)
                    .stroke(
                        LinearGradient(
                            colors: [color.opacity(0.8), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                
                // Area fill
                areaPath(in: geometry)
                    .trim(from: 0, to: animated ? animationProgress : 1)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Data points
                dataPoints(in: geometry)
            }
        }
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 1.5)) {
                    animationProgress = 1
                }
            }
        }
    }
    
    private func gridLines(in geometry: GeometryProxy) -> some View {
        ZStack {
            // Horizontal lines
            ForEach(0..<5) { index in
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1)
                    .offset(y: CGFloat(index) * geometry.size.height / 4 - geometry.size.height / 2)
            }
            
            // Vertical lines
            ForEach(0..<5) { index in
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1)
                    .offset(x: CGFloat(index) * geometry.size.width / 4 - geometry.size.width / 2)
            }
        }
    }
    
    private func chartPath(in geometry: GeometryProxy) -> Path {
        guard data.count > 1 else { return Path() }
        
        let maxValue = data.max() ?? 1
        let minValue = data.min() ?? 0
        let range = maxValue - minValue
        
        var path = Path()
        
        for (index, value) in data.enumerated() {
            let x = CGFloat(index) / CGFloat(data.count - 1) * geometry.size.width
            let y = geometry.size.height - CGFloat((value - minValue) / range) * geometry.size.height
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        return path
    }
    
    private func areaPath(in geometry: GeometryProxy) -> Path {
        guard data.count > 1 else { return Path() }
        
        let maxValue = data.max() ?? 1
        let minValue = data.min() ?? 0
        let range = maxValue - minValue
        
        var path = Path()
        
        // Start from bottom left
        path.move(to: CGPoint(x: 0, y: geometry.size.height))
        
        // Draw to first data point
        let firstY = geometry.size.height - CGFloat((data[0] - minValue) / range) * geometry.size.height
        path.addLine(to: CGPoint(x: 0, y: firstY))
        
        // Draw through all data points
        for (index, value) in data.enumerated() {
            let x = CGFloat(index) / CGFloat(data.count - 1) * geometry.size.width
            let y = geometry.size.height - CGFloat((value - minValue) / range) * geometry.size.height
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // Close the path
        path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
        path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
        
        return path
    }
    
    private func dataPoints(in geometry: GeometryProxy) -> some View {
        guard data.count > 1 else { return AnyView(EmptyView()) }
        
        let maxValue = data.max() ?? 1
        let minValue = data.min() ?? 0
        let range = maxValue - minValue
        
        return AnyView(
            ZStack {
                ForEach(data.indices, id: \.self) { index in
                    let x = CGFloat(index) / CGFloat(data.count - 1) * geometry.size.width
                    let y = geometry.size.height - CGFloat((data[index] - minValue) / range) * geometry.size.height
                    
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                        .shadow(color: color.opacity(0.3), radius: 2, x: 0, y: 1)
                        .position(x: x, y: y)
                        .opacity(animated ? animationProgress : 1)
                        .scaleEffect(animated ? animationProgress : 1)
                }
            }
        )
    }
}

// MARK: - Matrix Math Extensions

extension simd_float4x4 {
    init(rotationX angle: Float) {
        let c = cos(angle)
        let s = sin(angle)
        self.init(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, c, s, 0),
            SIMD4<Float>(0, -s, c, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
    
    init(rotationY angle: Float) {
        let c = cos(angle)
        let s = sin(angle)
        self.init(
            SIMD4<Float>(c, 0, -s, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(s, 0, c, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
    
    init(rotationZ angle: Float) {
        let c = cos(angle)
        let s = sin(angle)
        self.init(
            SIMD4<Float>(c, s, 0, 0),
            SIMD4<Float>(-s, c, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
}

// Matrix helper functions
func matrix4x4_rotation(radians: Float, axis: SIMD3<Float>) -> simd_float4x4 {
    let unitAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
    
    return simd_float4x4(
        SIMD4<Float>(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
        SIMD4<Float>(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
        SIMD4<Float>(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
        SIMD4<Float>(                  0,                   0,                   0, 1)
    )
}

func matrix_look_at(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
    let z = normalize(eye - center)
    let x = normalize(cross(up, z))
    let y = cross(z, x)
    
    return simd_float4x4(
        SIMD4<Float>(x.x, y.x, z.x, 0),
        SIMD4<Float>(x.y, y.y, z.y, 0),
        SIMD4<Float>(x.z, y.z, z.z, 0),
        SIMD4<Float>(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)
    )
}

func matrix_perspective_right_hand(fovyRadians: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> simd_float4x4 {
    let ys = 1 / tanf(fovyRadians * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    
    return simd_float4x4(
        SIMD4<Float>(xs, 0, 0, 0),
        SIMD4<Float>(0, ys, 0, 0),
        SIMD4<Float>(0, 0, zs, -1),
        SIMD4<Float>(0, 0, zs * nearZ, 0)
    )
}

// ShipType extension
extension ShipType: CaseIterable {
    static var allCases: [ShipType] = [.container, .bulk, .tanker, .general]
}