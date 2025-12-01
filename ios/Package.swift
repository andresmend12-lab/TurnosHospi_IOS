// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TurnoshospiIOS",
    defaultLocalization: "es",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .iOSApplication(
            name: "Turnoshospi",
            targets: ["TurnoshospiIOS"],
            bundleIdentifier: "com.example.turnoshospi",
            teamIdentifier: "ABCDEFG123",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .asset("AppIcon"),
            accentColor: .presetColor(.blue),
            launchScreen: .storyboard("LaunchScreen"),
            supportedDeviceFamilies: [.phone, .pad],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeLeft,
                .landscapeRight
            ],
            capabilities: [
                .pushNotifications(purposeString: "Recibir avisos de turnos y chat"),
                .localNotifications()
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "TurnoshospiIOS",
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        )
    ]
)
