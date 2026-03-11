import Foundation

#if DEBUG
public let IS_PREVIEW: Bool =
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
#else
public let IS_PREVIEW: Bool = false
#endif
