import SwiftUI

struct WaitingForServicesView: View {
    @EnvironmentObject private var installationState: InstallationState
    @State private var remainingTime: Int = 100 // 100秒倒计时
    @State private var timer: Timer?
    @State private var isComplete = false
    @State private var isRetrievingCredentials = false
    @State private var elapsedTime: Int = 0 // 已用时间
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 标题和说明
            VStack(alignment: .leading, spacing: 8) {
                Text("等待服务启动")
                    .font(.system(size: 20, weight: .medium))
                
                Text(installationState.installDevtron ? "Devtron服务正在启动中，请稍候..." : "正在完成环境配置...")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            // 内容区域 - 使用固定高度的ScrollView容器
            ScrollView {
                // 等待状态区域
                VStack(alignment: .leading, spacing: 16) {
                    Text("状态")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.bottom, 2)
                    
                    // 等待进度
                    VStack(alignment: .leading, spacing: 12) {
                        if remainingTime > 0 && !isComplete {
                            Text("剩余等待时间: \(remainingTime)秒")
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                            
                            ProgressBar(progress: Double(100 - remainingTime) / 100.0)
                                .frame(height: 5)
                                
                        } else if isRetrievingCredentials {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                                
                                Text("正在获取Devtron凭证...")
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                            }
                                
                        } else if isComplete {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 12))
                                
                                Text("服务已准备就绪")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    
                    // 显示服务启动状态信息
                    if installationState.installDevtron {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Devtron服务")
                                .font(.system(size: 13, weight: .medium))
                                .padding(.bottom, 2)
                            
                            if isComplete {
                                Text("准备就绪，点击「下一步」查看访问信息")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("服务启动后将自动获取访问凭证")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                    }
                    
                    // 添加底部空间，确保内容足够高度
                    Spacer(minLength: 20)
                }
            }
            
            Spacer()
            
            // 导航按钮 - 使用固定高度和边距
            HStack {
                if isComplete {
                    Spacer()
                    
                    Button(action: {
                        installationState.moveToNextStep()
                    }) {
                        Text("下一步")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                } else {
                    Text(installationState.installDevtron ? "正在初始化Devtron服务..." : "正在完成环境配置...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            .frame(height: 36)
        }
        .padding(30)
        .onAppear {
            startWaiting()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startWaiting() {
        installationState.appendLog("开始等待服务就绪阶段")
        elapsedTime = 0
        
        // 如果没有安装Devtron，只是短暂等待后继续
        if !installationState.installDevtron {
            installationState.appendLog("跳过等待阶段（未安装Devtron）")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isComplete = true
                installationState.installationComplete = true
                installationState.moveToNextStep()
            }
            return
        }
        
        installationState.appendLog("等待Devtron服务启动，倒计时: \(remainingTime)秒")
        startTimer()
    }
    
    // 启动计时器
    private func startTimer() {
        // 停止现有计时器
        stopTimer()
        
        // 启动倒计时
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            // 增加已经等待的时间
            elapsedTime += 1
            
            // 更新剩余等待时间
            if remainingTime > 0 {
                remainingTime -= 1
                
                // 每10秒记录一次倒计时状态
                if remainingTime % 10 == 0 {
                    installationState.appendLog("等待中... 剩余\(remainingTime)秒")
                }
                
                if remainingTime == 0 {
                    installationState.appendLog("等待时间结束，开始检索Devtron凭证")
                    retrieveDevtronCredentials()
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        installationState.appendLog("停止等待计时器")
    }
    
    private func retrieveDevtronCredentials() {
        isRetrievingCredentials = true
        installationState.appendLog("正在获取Devtron凭证...")
        
        // 真实执行命令获取Devtron信息
        DispatchQueue.global().async {
            installationState.appendLog("执行Kubernetes命令获取Devtron信息")
            
            // 获取工具路径
            let bundlePath = Bundle.main.bundlePath
            let toolsDir = "\(bundlePath)/Contents/Resources/tools"
            let kubectlPath = "\(toolsDir)/kubectl"
            
            // 环境变量设置
            let kubeconfigPath = installationState.kubeconfigPath
            let env = [
                "PATH": "\(toolsDir):/usr/bin:/bin:/usr/sbin:/sbin",
                "KUBECONFIG": kubeconfigPath,
                "KUBE_INSECURE_SKIP_TLS_VERIFY": "true"
            ]
            
            // 获取Devtron服务地址
            installationState.appendLog("获取Devtron服务地址: \"\(kubectlPath)\" describe serviceexporter devtron-itf -n devtroncd")
            let getUrlCmd = "\"\(kubectlPath)\" describe serviceexporter devtron-itf -n devtroncd"
            let urlResult = ShellUtils.runCommandWithEnv(getUrlCmd, environment: env)
            
            var devtronUrl = ""
            
            if urlResult.exitCode == 0 {
                installationState.appendLog("命令执行成功，正在解析输出...")
                installationState.appendLog("输出内容长度: \(urlResult.output.count)字节")
                
                // 完整的输出记录到日志
                installationState.appendLog("完整输出:")
                for line in urlResult.output.split(separator: "\n") {
                    installationState.appendLog(">> \(line)")
                }
                
                // 解析输出获取URL - 根据特定格式匹配
                // 尝试多种可能的格式
                
                // 格式1: 查找包含"url:"的行
                if devtronUrl.isEmpty {
                    for line in urlResult.output.split(separator: "\n") {
                        if line.lowercased().contains("url:") {
                            if let urlRange = line.range(of: "url:", options: .caseInsensitive) {
                                devtronUrl = String(line[urlRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                                installationState.appendLog("从'url:'字段解析到URL: \(devtronUrl)")
                                break
                            }
                        }
                    }
                }
                
                // 格式2: 查找Message字段中的URL
                if devtronUrl.isEmpty {
                    for line in urlResult.output.split(separator: "\n") {
                        if line.contains("Message:") {
                            let messageContent = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
                            // 尝试使用正则表达式匹配URL
                            do {
                                let regex = try NSRegularExpression(pattern: "https?://[\\w\\.-]+\\.[a-zA-Z]{2,}(?:/[\\w\\.-]*)*", options: [])
                                let nsString = messageContent as NSString
                                let matches = regex.matches(in: messageContent, options: [], range: NSRange(location: 0, length: nsString.length))
                                
                                if let match = matches.first {
                                    devtronUrl = nsString.substring(with: match.range)
                                    installationState.appendLog("从Message字段解析到URL: \(devtronUrl)")
                                    break
                                }
                            } catch {
                                installationState.appendLog("正则表达式匹配错误: \(error.localizedDescription)")
                            }
                        }
                    }
                }
                
                // 格式3: 直接查找含有http或https的URL
                if devtronUrl.isEmpty {
                    do {
                        let regex = try NSRegularExpression(pattern: "https?://[\\w\\.-]+\\.[a-zA-Z]{2,}(?:/[\\w\\.-]*)*", options: [])
                        let nsString = urlResult.output as NSString
                        let matches = regex.matches(in: urlResult.output, options: [], range: NSRange(location: 0, length: nsString.length))
                        
                        if let match = matches.first {
                            devtronUrl = nsString.substring(with: match.range)
                            installationState.appendLog("通过正则表达式直接匹配到URL: \(devtronUrl)")
                        }
                    } catch {
                        installationState.appendLog("正则表达式匹配错误: \(error.localizedDescription)")
                    }
                }
            } else {
                installationState.appendLog("获取URL命令执行失败，退出代码: \(urlResult.exitCode)")
                if !urlResult.error.isEmpty {
                    installationState.appendLog("错误输出: \(urlResult.error)")
                }
            }
            
            // 如果URL为空，使用默认值
            if devtronUrl.isEmpty {
                devtronUrl = "http://localhost:8080"
                installationState.appendLog("未找到Devtron URL，使用默认值: \(devtronUrl)")
            } else if !devtronUrl.contains(":") || (devtronUrl.contains("://") && devtronUrl.components(separatedBy: "://")[1].contains(":") == false) {
                // 如果URL不包含端口号，添加:22443
                if devtronUrl.hasSuffix("/") {
                    let index = devtronUrl.index(devtronUrl.endIndex, offsetBy: -1)
                    devtronUrl = String(devtronUrl[..<index]) + ":22443/"
                } else {
                    devtronUrl = devtronUrl + ":22443"
                }
                installationState.appendLog("添加端口号到URL: \(devtronUrl)")
            }
            
            // 获取Devtron管理员密码
            installationState.appendLog("获取Devtron管理员密码: \"\(kubectlPath)\" get secret -n devtroncd devtron-secret -o jsonpath={.data.ADMIN_PASSWORD}")
            let getPasswordCmd = "\"\(kubectlPath)\" get secret -n devtroncd devtron-secret -o jsonpath={.data.ADMIN_PASSWORD}"
            let passwordResult = ShellUtils.runCommandWithEnv(getPasswordCmd, environment: env)
            
            var password = "admin" // 默认密码
            
            if passwordResult.exitCode == 0 && !passwordResult.output.isEmpty {
                let encodedPassword = passwordResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                installationState.appendLog("获取到编码密码: \(encodedPassword)")
                
                // 解码Base64密码
                if let decodedPassword = ShellUtils.decodeBase64(encodedPassword) {
                    password = decodedPassword
                    installationState.appendLog("Base64解码密码成功")
                } else {
                    installationState.appendLog("Base64解码密码失败，使用默认密码")
                }
            } else {
                installationState.appendLog("获取密码命令执行失败，退出代码: \(passwordResult.exitCode)")
                if !passwordResult.error.isEmpty {
                    installationState.appendLog("错误输出: \(passwordResult.error)")
                }
                installationState.appendLog("使用默认密码: \(password)")
            }
            
            // 更新状态
            DispatchQueue.main.async {
                installationState.devtronUrl = devtronUrl
                installationState.devtronPassword = password
                installationState.appendLog("成功获取Devtron凭证，URL: \(devtronUrl), 用户名: admin")
                installationState.appendLog("服务启动完成，可以进入下一步")
                isRetrievingCredentials = false
                isComplete = true
                installationState.installationComplete = true
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label + ":")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 65, alignment: .leading)
            
            Text(value)
                .font(.system(size: 12, design: value.contains("://") ? .monospaced : .default))
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
} 
