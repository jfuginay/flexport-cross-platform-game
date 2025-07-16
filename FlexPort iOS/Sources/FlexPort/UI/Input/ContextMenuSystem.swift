import SwiftUI
import UIKit

/// Advanced context menu system with haptic feedback and animations
public struct ContextMenuSystem: View {
    @Binding var isShowing: Bool
    @Binding var location: CGPoint?
    let items: [ContextMenuItem]
    let onDismiss: () -> Void
    
    @State private var menuOpacity: Double = 0
    @State private var menuScale: CGFloat = 0.8
    @State private var itemsAppeared = false
    
    public var body: some View {
        if isShowing, let location = location {
            ZStack {
                // Backdrop to catch taps
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissMenu()
                    }
                
                // Context menu
                contextMenu
                    .position(adjustedPosition(for: location))
                    .opacity(menuOpacity)
                    .scaleEffect(menuScale)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: menuOpacity)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: menuScale)
            }
            .onAppear {
                showMenu()
            }
        }
    }
    
    private var contextMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with entity info
            if let firstItem = items.first, firstItem.entityInfo != nil {
                menuHeader(for: firstItem.entityInfo!)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                
                Divider()
                    .background(Color.white.opacity(0.2))
            }
            
            // Menu items
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if item.isSeparator {
                    menuSeparator()
                } else {
                    menuItem(item, index: index)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
        .frame(minWidth: 200, maxWidth: 280)
        .background(menuBackground)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func menuHeader(for info: EntityInfo) -> some View {
        HStack(spacing: 12) {
            // Entity icon
            ZStack {
                Circle()
                    .fill(info.color.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Image(systemName: info.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(info.color)
            }
            
            // Entity details
            VStack(alignment: .leading, spacing: 2) {
                Text(info.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if let subtitle = info.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status indicator
            if let status = info.status {
                statusIndicator(status)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func menuItem(_ item: ContextMenuItem, index: Int) -> some View {
        Button(action: {
            executeAction(item)
        }) {
            HStack(spacing: 12) {
                // Icon
                if let icon = item.icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(item.destructive ? .red : .blue)
                        .frame(width: 24)
                }
                
                // Title and subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline)
                        .foregroundColor(item.destructive ? .red : .primary)
                    
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Accessory
                if let accessory = item.accessory {
                    accessoryView(accessory)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, item.subtitle != nil ? 10 : 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(ContextMenuButtonStyle())
        .disabled(item.disabled)
        .opacity(item.disabled ? 0.5 : 1.0)
        .scaleEffect(itemsAppeared ? 1.0 : 0.8)
        .opacity(itemsAppeared ? 1.0 : 0.0)
        .animation(
            .spring(response: 0.3, dampingFraction: 0.8)
            .delay(Double(index) * 0.03),
            value: itemsAppeared
        )
    }
    
    private func menuSeparator() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(height: 1)
            .padding(.vertical, 4)
    }
    
    private func statusIndicator(_ status: EntityStatus) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
                .overlay(
                    Circle()
                        .fill(status.color)
                        .frame(width: 6, height: 6)
                        .scaleEffect(status.isActive ? 1.5 : 1.0)
                        .opacity(status.isActive ? 0.0 : 1.0)
                        .animation(
                            status.isActive ? .easeInOut(duration: 1.0).repeatForever() : .default,
                            value: status.isActive
                        )
                )
            
            if let text = status.text {
                Text(text)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func accessoryView(_ accessory: MenuAccessory) -> some View {
        Group {
            switch accessory {
            case .chevron:
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
            case .checkmark:
                Image(systemName: "checkmark")
                    .font(.caption)
                    .foregroundColor(.blue)
                
            case .badge(let count):
                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .cornerRadius(8)
                
            case .toggle(let isOn):
                Toggle("", isOn: .constant(isOn))
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .scaleEffect(0.8)
                    .disabled(true)
                
            case .custom(let view):
                view
            }
        }
    }
    
    private var menuBackground: some View {
        ZStack {
            // Base blur effect
            VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
            
            // Gradient overlay
            LinearGradient(
                colors: [
                    Color.white.opacity(0.05),
                    Color.white.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - Actions
    
    private func showMenu() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            menuOpacity = 1.0
            menuScale = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                itemsAppeared = true
            }
        }
        
        HapticManager.shared.playNotificationFeedback(.success)
    }
    
    private func dismissMenu() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
            menuOpacity = 0.0
            menuScale = 0.8
            itemsAppeared = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isShowing = false
            onDismiss()
        }
        
        HapticManager.shared.playSelectionFeedback()
    }
    
    private func executeAction(_ item: ContextMenuItem) {
        HapticManager.shared.playImpactFeedback(.light)
        
        // Animate selection
        withAnimation(.easeInOut(duration: 0.1)) {
            menuScale = 0.95
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            item.action()
            dismissMenu()
        }
    }
    
    // MARK: - Layout
    
    private func adjustedPosition(for location: CGPoint) -> CGPoint {
        let menuWidth: CGFloat = 280
        let estimatedHeight: CGFloat = CGFloat(items.count * 44 + 60)
        let screenBounds = UIScreen.main.bounds
        let padding: CGFloat = 20
        
        var adjustedX = location.x
        var adjustedY = location.y
        
        // Adjust X position
        if location.x + menuWidth / 2 > screenBounds.width - padding {
            adjustedX = screenBounds.width - menuWidth / 2 - padding
        } else if location.x - menuWidth / 2 < padding {
            adjustedX = menuWidth / 2 + padding
        }
        
        // Adjust Y position
        if location.y + estimatedHeight / 2 > screenBounds.height - padding {
            adjustedY = screenBounds.height - estimatedHeight / 2 - padding
        } else if location.y - estimatedHeight / 2 < padding {
            adjustedY = estimatedHeight / 2 + padding
        }
        
        return CGPoint(x: adjustedX, y: adjustedY)
    }
}

// MARK: - Supporting Types

public extension ContextMenuItem {
    var entityInfo: EntityInfo? { nil }
    var isSeparator: Bool { false }
    var subtitle: String? { nil }
    var destructive: Bool { false }
    var disabled: Bool { false }
    var accessory: MenuAccessory? { nil }
}

public struct EntityInfo {
    let name: String
    let subtitle: String?
    let icon: String
    let color: Color
    let status: EntityStatus?
    
    public init(
        name: String,
        subtitle: String? = nil,
        icon: String,
        color: Color,
        status: EntityStatus? = nil
    ) {
        self.name = name
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.status = status
    }
}

public struct EntityStatus {
    let color: Color
    let text: String?
    let isActive: Bool
    
    public init(color: Color, text: String? = nil, isActive: Bool = false) {
        self.color = color
        self.text = text
        self.isActive = isActive
    }
}

public enum MenuAccessory {
    case chevron
    case checkmark
    case badge(Int)
    case toggle(Bool)
    case custom(AnyView)
}

// MARK: - Button Style

struct ContextMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Rectangle()
                    .fill(configuration.isPressed ? Color.white.opacity(0.1) : Color.clear)
                    .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            )
    }
}

// MARK: - Visual Effect Blur

struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

// MARK: - Preset Context Menus

public extension ContextMenuSystem {
    static func portContextMenu(
        port: Port,
        onAction: @escaping (PortAction) -> Void
    ) -> [ContextMenuItem] {
        var items: [ContextMenuItem] = []
        
        // Port header info
        items.append(ContextMenuItem(
            title: port.name,
            icon: "building.2.fill",
            action: {}
        ))
        
        items.append(ContextMenuItem(
            title: "View Details",
            icon: "info.circle",
            action: { onAction(.viewDetails) }
        ))
        
        items.append(ContextMenuItem(
            title: "Create Trade Route",
            icon: "arrow.triangle.swap",
            action: { onAction(.createRoute) }
        ))
        
        items.append(ContextMenuItem(
            title: "Market Prices",
            icon: "chart.line.uptrend.xyaxis",
            action: { onAction(.viewMarket) }
        ))
        
        items.append(ContextMenuItem(
            title: "Send Fleet",
            icon: "ferry.fill",
            action: { onAction(.sendFleet) }
        ))
        
        return items
    }
    
    static func shipContextMenu(
        ship: Ship,
        onAction: @escaping (ShipAction) -> Void
    ) -> [ContextMenuItem] {
        var items: [ContextMenuItem] = []
        
        items.append(ContextMenuItem(
            title: ship.name,
            icon: "ferry",
            action: {}
        ))
        
        items.append(ContextMenuItem(
            title: "Ship Details",
            icon: "info.circle",
            action: { onAction(.viewDetails) }
        ))
        
        items.append(ContextMenuItem(
            title: "Follow",
            icon: "location.viewfinder",
            action: { onAction(.follow) }
        ))
        
        items.append(ContextMenuItem(
            title: "Assign Route",
            icon: "map",
            action: { onAction(.assignRoute) }
        ))
        
        items.append(ContextMenuItem(
            title: "Repair",
            icon: "wrench.and.screwdriver",
            action: { onAction(.repair) }
        ))
        
        items.append(ContextMenuItem(
            title: "Sell Ship",
            icon: "dollarsign.circle",
            action: { onAction(.sell) }
        ))
        
        return items
    }
}

public enum PortAction {
    case viewDetails
    case createRoute
    case viewMarket
    case sendFleet
}

public enum ShipAction {
    case viewDetails
    case follow
    case assignRoute
    case repair
    case sell
}