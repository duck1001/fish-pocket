import Foundation

/// 插件被启用到互相打架时（`tool-executor-ptc` / `pwsh-sandbox` 抢同一个 executor），
/// 引擎每次启动都失败、App 卡在「引擎还没起来」，而这时插件管理页也进不去。
/// 启动前看一眼前一次的日志：命中这两条错误就把 `cordis.patch.yml` 停用（留备份），
/// 让引擎回到默认插件集。用户可以在「设置 → 高级 → 配置文件」里再改回来。
enum ProfileRepair {
    static var patch: URL {
        EnginePaths.dshHome.appendingPathComponent("profiles/web/cordis.patch.yml")
    }

    static func repairIfBricked() {
        let log = EnginePaths.real(EnginePaths.shared + "/engine.log")
        guard let text = try? String(contentsOf: log, encoding: .utf8) else { return }
        let tail = String(text.suffix(8000))
        let bricked = tail.contains("Only one tool executor may be registered")
            || tail.contains("service \"shell\" has been registered")
        guard bricked, FileManager.default.fileExists(atPath: patch.path) else { return }
        let backup = patch.deletingLastPathComponent().appendingPathComponent("cordis.patch.yml.broken")
        try? FileManager.default.removeItem(at: backup)
        guard (try? FileManager.default.moveItem(at: patch, to: backup)) != nil else { return }
        RunLog.note("启动修复：cordis.patch.yml 已停用，备份为 cordis.patch.yml.broken")
    }
}
