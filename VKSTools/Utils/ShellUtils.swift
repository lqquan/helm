import Foundation

class ShellUtils {
    static func runCommand(_ command: String) -> (output: String, error: String, exitCode: Int32) {
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""
            
            return (output, error, task.terminationStatus)
        } catch {
            return ("", "Failed to execute command: \(error.localizedDescription)", 1)
        }
    }
    
    static func runCommandAsync(_ command: String, completion: @escaping (String, String, Int32) -> Void) {
        DispatchQueue.global().async {
            let result = runCommand(command)
            completion(result.output, result.error, result.exitCode)
        }
    }
    
    static func runCommandAsyncWithEnv(_ command: String, environment: [String: String], completion: @escaping (String, String, Int32) -> Void) {
        DispatchQueue.global().async {
            let task = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            task.arguments = ["-c", command]
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            
            // 设置环境变量
            var env = ProcessInfo.processInfo.environment
            for (key, value) in environment {
                env[key] = value
            }
            task.environment = env
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""
                
                completion(output, error, task.terminationStatus)
            } catch {
                completion("", "Failed to execute command: \(error.localizedDescription)", 1)
            }
        }
    }
    
    static func copyFile(from sourcePath: String, to destinationPath: String) -> Bool {
        let fileManager = FileManager.default
        
        do {
            // 检查源文件是否存在
            if !fileManager.fileExists(atPath: sourcePath) {
                print("源文件不存在: \(sourcePath)")
                return false
            }
            
            // 检查目标路径的父目录是否存在，如果不存在则创建
            let destinationDir = (destinationPath as NSString).deletingLastPathComponent
            if !fileManager.fileExists(atPath: destinationDir) {
                try fileManager.createDirectory(atPath: destinationDir, withIntermediateDirectories: true)
                print("已创建目标目录: \(destinationDir)")
            }
            
            // 如果目标文件已存在，先创建备份
            if fileManager.fileExists(atPath: destinationPath) {
                let backupPath = "\(destinationPath).backup.\(Int(Date().timeIntervalSince1970))"
                try fileManager.copyItem(atPath: destinationPath, toPath: backupPath)
                print("已备份原文件: \(backupPath)")
            }
            
            // 复制文件
            try fileManager.copyItem(atPath: sourcePath, toPath: destinationPath)
            
            // 确保文件权限正确
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destinationPath)
            
            print("文件复制成功: \(sourcePath) -> \(destinationPath)")
            return true
        } catch {
            print("复制文件失败: \(error.localizedDescription)")
            print("源路径: \(sourcePath)")
            print("目标路径: \(destinationPath)")
            
            // 尝试使用shell命令复制
            let result = runCommand("cp \"\(sourcePath)\" \"\(destinationPath)\" && chmod 600 \"\(destinationPath)\"")
            if result.exitCode == 0 {
                print("使用shell命令复制文件成功")
                return true
            } else {
                print("shell复制也失败: \(result.error)")
                return false
            }
        }
    }
    
    static func writeToFile(content: String, path: String) -> Bool {
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("写入文件失败: \(error.localizedDescription)")
            return false
        }
    }
    
    static func requestSudo(forCommand command: String) -> Bool {
        // 首先尝试不使用管理员权限执行命令
        let normalResult = runCommand(command)
        if normalResult.exitCode == 0 {
            print("命令执行成功，无需管理员权限")
            return true
        }
        
        // 只有在普通权限失败时才尝试管理员权限
        print("普通权限执行失败，尝试使用管理员权限")
        
        // 不使用AppleScript，而是使用更可靠的方法 - 运行包装脚本
        let tempScriptPath = NSTemporaryDirectory() + "sudo_script_\(UUID().uuidString).sh"
        
        // 创建临时脚本
        do {
            let scriptContent = """
            #!/bin/bash
            # 临时脚本用于以管理员权限执行命令
            \(command)
            """
            try scriptContent.write(toFile: tempScriptPath, atomically: true, encoding: .utf8)
            
            // 使脚本可执行
            _ = runCommand("chmod +x \"\(tempScriptPath)\"")
            
            // 使用osascript执行
            let osascriptCmd = "osascript -e 'do shell script \"\(tempScriptPath)\" with administrator privileges'"
            let sudoResult = runCommand(osascriptCmd)
            
            // 无论结果如何，清理临时脚本
            _ = runCommand("rm -f \"\(tempScriptPath)\"")
            
            if sudoResult.exitCode == 0 {
                print("管理员权限命令执行成功")
                return true
            } else {
                print("管理员权限命令失败: \(sudoResult.error)")
                return false
            }
        } catch {
            print("创建临时脚本失败: \(error.localizedDescription)")
            return false
        }
    }
    
    static func setEnvironmentVariable(name: String, value: String) -> Bool {
        // 仅为当前进程设置环境变量，不修改.zshrc文件
        // 这样可以避免权限问题，但环境变量只在当前运行的应用进程中有效
        setenv(name, value, 1)
        
        // 验证环境变量是否设置成功
        if let envValue = ProcessInfo.processInfo.environment[name], envValue == value {
            print("成功设置环境变量 \(name)=\(value) (仅当前进程)")
            return true
        } else {
            print("设置环境变量失败: \(name)=\(value)")
            
            // 尝试通过Shell检查环境变量
            let checkResult = runCommand("echo $\(name)")
            if checkResult.output.trimmingCharacters(in: .whitespacesAndNewlines) == value {
                print("通过Shell验证环境变量已设置")
                return true
            }
            
            return false
        }
    }
    
    static func decodeBase64(_ encodedString: String) -> String? {
        if let data = Data(base64Encoded: encodedString) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    static func runCommandWithEnv(_ command: String, environment: [String: String]) -> (output: String, error: String, exitCode: Int32) {
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        
        // 设置环境变量
        var env = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            env[key] = value
        }
        task.environment = env
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""
            
            return (output, error, task.terminationStatus)
        } catch {
            return ("", "Failed to execute command: \(error.localizedDescription)", 1)
        }
    }
}
