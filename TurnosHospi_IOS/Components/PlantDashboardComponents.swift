//
//  PlantDashboardComponents.swift
//  TurnosHospi_IOS
//
//  Extracted components from PlantDashboardView for better maintainability
//

import SwiftUI

// MARK: - Dashboard Header

struct PlantDashboardHeaderView: View {
    let userName: String
    let userRole: String
    let unreadNotifications: Int
    let onMenuTap: () -> Void
    let onNotificationTap: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Menu Button
            Button(action: onMenuTap) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .padding(10)
                    .contentShape(Rectangle())
            }
            .zIndex(100)

            Spacer()

            // User Info
            VStack(alignment: .trailing) {
                Text("Mi Planta")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Text(userRole)
                    .font(.caption)
                    .foregroundColor(Color(red: 0.7, green: 0.5, blue: 1.0))
            }

            // Notification Bell
            NotificationBellButton(
                unreadCount: unreadNotifications,
                action: onNotificationTap
            )
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
        .padding(.top, 60)
        .background(Color.black.opacity(0.3))
    }
}

// MARK: - Notification Bell Button

struct NotificationBellButton: View {
    let unreadCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "bell.fill")
                            .foregroundColor(.white)
                    )

                if unreadCount > 0 {
                    BadgeView(count: unreadCount)
                        .offset(x: 6, y: -6)
                }
            }
        }
    }
}

// MARK: - Badge View

struct BadgeView: View {
    let count: Int
    var backgroundColor: Color = .red

    var displayText: String {
        count > 99 ? "99+" : "\(count)"
    }

    var body: some View {
        Text(displayText)
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(backgroundColor)
            .clipShape(Capsule())
    }
}

// MARK: - Floating Chat Button

struct FloatingChatButton: View {
    let unreadCount: Int
    let action: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()

                Button(action: action) {
                    ZStack(alignment: .topTrailing) {
                        Circle()
                            .fill(Color(red: 0.2, green: 0.4, blue: 1.0))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            )

                        if unreadCount > 0 {
                            BadgeView(count: unreadCount)
                                .offset(x: -6, y: -6)
                        }
                    }
                    .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 4)
                }
                .padding(.trailing, 25)
                .padding(.bottom, 30)
            }
        }
    }
}

// MARK: - Section Title View

struct DashboardSectionTitle: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
}

// MARK: - Menu Overlay

struct MenuOverlay: View {
    let isVisible: Bool
    let onTap: () -> Void

    var body: some View {
        if isVisible {
            Color.white.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture(perform: onTap)
        }
    }
}

// MARK: - Loading Placeholder

struct LoadingPlaceholderView: View {
    let message: String

    var body: some View {
        VStack {
            ProgressView(message)
                .tint(.white)
                .foregroundColor(.white)
        }
        .padding(.top, 60)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let iconName: String
    let title: String
    let message: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))

            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .padding(.top, 60)
    }
}

// MARK: - Card Container

struct DashboardCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - Staff Avatar

struct StaffAvatarView: View {
    let name: String
    let size: CGFloat

    var initial: String {
        String(name.prefix(1)).uppercased()
    }

    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.1))
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - Staff Row

struct StaffRowView: View {
    let name: String
    let role: String
    let avatarSize: CGFloat

    init(name: String, role: String, avatarSize: CGFloat = 35) {
        self.name = name
        self.role = role
        self.avatarSize = avatarSize
    }

    var body: some View {
        HStack(spacing: 15) {
            StaffAvatarView(name: name, size: avatarSize)

            VStack(alignment: .leading) {
                Text(name)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text(role)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - Shift Color Helper

struct ShiftColorHelper {
    static func color(for shiftName: String) -> Color {
        let name = shiftName.lowercased()

        if name.contains("mañana") || name.contains("dia") || name.contains("día") {
            return .yellow
        } else if name.contains("tarde") {
            return .orange
        } else if name.contains("noche") {
            return .blue
        } else {
            return .white
        }
    }
}

// MARK: - Status Message View

struct StatusMessageView: View {
    let message: String
    var isError: Bool {
        message.localizedCaseInsensitiveContains("error")
    }

    var body: some View {
        Text(message)
            .foregroundColor(isError ? .red : .green)
            .font(.footnote)
            .padding(.horizontal)
    }
}

// MARK: - Action Button

struct PrimaryActionButton: View {
    let title: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.black)
                }
                Text(isLoading ? "Guardando..." : title)
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .disabled(isLoading || isDisabled)
        .background(isLoading || isDisabled ? Color.gray : Color(red: 0.33, green: 0.8, blue: 0.95))
        .foregroundColor(.black)
        .cornerRadius(12)
    }
}

// MARK: - Danger Zone Card

struct DangerZoneCard: View {
    let title: String
    let description: String
    let buttonTitle: String
    let statusMessage: String?
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.red)

            Text(description)
                .foregroundColor(.white)
                .font(.subheadline)

            if let status = statusMessage {
                StatusMessageView(message: status)
            }

            Button(action: action) {
                Text(buttonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}
