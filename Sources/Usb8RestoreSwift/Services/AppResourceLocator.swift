import Foundation

enum AppResourceLocator {
    static func toolURL(named name: String) -> URL? {
        fileURL(name: name, extension: nil, subdirectories: toolSubdirectories)
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    static func requiredToolURL(named name: String) throws -> URL {
        guard let url = toolURL(named: name) else {
            throw RestoreError.missingTool(name)
        }
        return url
    }

    static var toolDirectories: [String] {
        directoryURLs(subdirectories: toolSubdirectories)
            .map(\.path)
    }

    static func pythonToolEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        if let pythonURL = resourceURL(name: "usb", extension: nil, subdirectories: ["Tools/python", "Resources/Tools/python"])?.deletingLastPathComponent() {
            let existing = environment["PYTHONPATH"].flatMap { $0.isEmpty ? nil : $0 }
            environment["PYTHONPATH"] = [pythonURL.path, existing].compactMap { $0 }.joined(separator: ":")
        }
        return environment
    }

    private static var toolSubdirectories: [String] {
        #if arch(x86_64)
        return ["Tools/x86_64", "Resources/Tools/x86_64", "Tools", "Resources/Tools"]
        #else
        return ["Tools", "Resources/Tools"]
        #endif
    }

    static func resourceURL(name: String, extension fileExtension: String?, subdirectories: [String]) -> URL? {
        fileURL(name: name, extension: fileExtension, subdirectories: subdirectories)
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static func fileURL(name: String, extension fileExtension: String?, subdirectories: [String]) -> [URL] {
        var urls: [URL] = []

        for bundle in bundles {
            for subdirectory in subdirectories {
                if let url = bundle.url(forResource: name, withExtension: fileExtension, subdirectory: subdirectory) {
                    urls.append(url)
                }
            }

            for directory in directoryURLs(bundle: bundle, subdirectories: subdirectories) {
                let filename = fileExtension.map { "\(name).\($0)" } ?? name
                urls.append(directory.appendingPathComponent(filename))
            }
        }

        for subdirectory in subdirectories {
            let filename = fileExtension.map { "\(name).\($0)" } ?? name
            urls.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Sources/Usb8RestoreSwift/Resources")
                .appendingPathComponent(subdirectory)
                .appendingPathComponent(filename))
        }

        return unique(urls)
    }

    private static func directoryURLs(subdirectories: [String]) -> [URL] {
        unique(bundles.flatMap { directoryURLs(bundle: $0, subdirectories: subdirectories) } + subdirectories.map {
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Sources/Usb8RestoreSwift/Resources")
                .appendingPathComponent($0)
        })
    }

    private static func directoryURLs(bundle: Bundle, subdirectories: [String]) -> [URL] {
        var urls: [URL] = []

        for subdirectory in subdirectories {
            if let resourceURL = bundle.resourceURL {
                urls.append(resourceURL.appendingPathComponent(subdirectory))
            }
            urls.append(bundle.bundleURL.appendingPathComponent("Contents/Resources").appendingPathComponent(subdirectory))
        }

        return urls
    }

    private static var bundles: [Bundle] {
        uniqueBundles([Bundle.usb8Resources, .main])
    }

    private static func unique(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    private static func uniqueBundles(_ bundles: [Bundle]) -> [Bundle] {
        var seen = Set<String>()
        return bundles.filter { seen.insert($0.bundleURL.standardizedFileURL.path).inserted }
    }
}
