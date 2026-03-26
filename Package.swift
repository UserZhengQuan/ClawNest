// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ClawNest",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClawNest", targets: ["ClawNest"])
    ],
    targets: [
        .executableTarget(
            name: "ClawNest",
            path: "Sources/ClawNest",
            exclude: [
                "Models/AppLanguage.swift",
                "Models/AppModels.swift",
                "Services/ConfigurationStore.swift",
                "Services/GatewaySupervisor.swift",
                "Services/HealthProbeInterpreter.swift",
                "Services/OpenClawInstallProgress.swift",
                "Services/LogInspector.swift",
                "Services/OpenClawInstaller.swift",
                "ViewModels/AppModel.swift",
                "ViewModels/AppModel+Installer.swift",
                "Views/DashboardWebView.swift",
                "Views/Installer",
                "Views/MainWindowBehaviorView.swift",
                "Views/MenuBarContentView.swift",
                "Views/Workspace",
                "Views/WorkspaceLayout.swift"
            ],
            sources: [
                "ClawNestApp.swift",
                "Models/OpenClawStatusModels.swift",
                "Services/CommandRunner.swift",
                "Services/OpenClawStatusService.swift",
                "ViewModels/StatusPanelViewModel.swift",
                "Views/ContentView.swift"
            ]
        ),
        .testTarget(
            name: "ClawNestTests",
            dependencies: ["ClawNest"],
            path: "Tests/ClawNestTests",
            exclude: [
                "HealthProbeInterpreterTests.swift",
                "LanguagePreferenceStoreTests.swift",
                "OpenClawInstallerTests.swift",
                "RuntimeActionResolverTests.swift",
                "RuntimeSafetyTests.swift"
            ],
            sources: [
                "OpenClawStatusServiceTests.swift"
            ]
        )
    ],
    swiftLanguageModes: [
        .v6
    ]
)
