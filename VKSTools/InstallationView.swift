import SwiftUI

struct InstallationView: View {
    @EnvironmentObject private var installationState: InstallationState
    @State private var timer: Timer?
    @State private var progressTimer: Timer?
    @State private var elapsedTime: TimeInterval = 0
    @State private var isInstallationCompleted = false
    @State private var devtronInstaller: DevtronInstaller?
    @State private var progressDirection: Bool = true // true为增加，false为减少
    
    private let installationTimeout: TimeInterval = 420 // 7分钟超时
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 标题和说明 - 固定在顶部
            VStack(alignment: .leading, spacing: 8) {
                Text(installationState.installDevtron ? "正在安装Devtron" : "正在配置环境")
                    .font(.system(size: 20, weight: .medium))
                
                Text("请稍候，安装过程正在进行中")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            // 进度部分 - 固定在顶部不随滚动
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("安装进度")
                        .font(.system(size: 13, weight: .medium))
                    
                    Spacer()
                    
                    Text("已运行: \(formatTime(elapsedTime))")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                ProgressBar(progress: installationState.installationProgress)
                    .frame(height: 5)
                
                HStack {
                    if !isInstallationCompleted {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 12))
                    }
                    
                    Text(isInstallationCompleted ? "安装完成" : "正在安装...")
                        .font(.system(size: 12))
                        .foregroundColor(isInstallationCompleted ? .green : .primary)
                }
            }
            .padding(.bottom, 8)
            
            // 安装日志标题 - 固定在滚动视图上方
            HStack {
                Text("安装日志")
                    .font(.system(size: 13, weight: .medium))
                
                Spacer()
                
                Button(action: {
                    copyLogsToClipboard()
                }) {
                    Text("复制")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // 只有日志内容可滚动
            ScrollView {
                Text(installationState.logs)
                    .font(.system(size: 10, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(6)
            }
            .frame(height: 160) // 减小日志窗口高度
            
            Spacer()
            
            // 导航按钮 - 固定在底部
            HStack {
                // 左侧区域 - 取消按钮
                if !isInstallationCompleted {
                    Button(action: {
                        cancelInstallation()
                    }) {
                        Text("取消")
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text("安装过程中请勿关闭应用")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.leading, 10)
                }
                
                Spacer()
                
                // 右侧下一步按钮（完成时显示）
                if isInstallationCompleted {
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
                }
            }
            .frame(height: 36)
        }
        .padding(30)
        .onAppear {
            startInstallation()
            startTimer()
            startProgressAnimation()
        }
        .onDisappear {
            stopTimer()
            stopProgressAnimation()
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.elapsedTime += 1
            
            // 检查是否超时
            if self.elapsedTime >= installationTimeout && !isInstallationCompleted {
                self.handleTimeout()
                self.stopTimer()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func startProgressAnimation() {
        // 创建进度条动画计时器
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            // 如果安装已完成，停止动画
            if isInstallationCompleted {
                stopProgressAnimation()
                return
            }
            
            // 进度条来回移动效果
            let currentProgress = installationState.installationProgress
            
            if progressDirection {
                // 向前移动进度
                let newProgress = min(currentProgress + 0.003, 0.95)
                installationState.installationProgress = newProgress
                
                // 到达上限时改变方向
                if newProgress >= 0.95 {
                    progressDirection = false
                }
            } else {
                // 向后移动进度
                let newProgress = max(currentProgress - 0.003, 0.1)
                installationState.installationProgress = newProgress
                
                // 到达下限时改变方向
                if newProgress <= 0.1 {
                    progressDirection = true
                }
            }
        }
        
        // 确保计时器不被立即释放
        RunLoop.main.add(progressTimer!, forMode: .common)
    }
    
    private func stopProgressAnimation() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func startInstallation() {
        // 重置状态
        installationState.installationProgress = 0.1
        installationState.appendLog("开始安装程序...")
        
        // 创建DevtronInstaller实例
        devtronInstaller = DevtronInstaller(
            kubeconfigPath: installationState.kubeconfigPath,
            progressCallback: { progress in
                DispatchQueue.main.async {
                    // 实际安装有明确进度时停止动画并使用实际进度
                    if progress > 0 {
                        self.stopProgressAnimation()
                        self.installationState.installationProgress = progress
                    }
                }
            },
            logCallback: { message in
                self.installationState.appendLog(message)
            },
            completionCallback: { success, errorMessage in
                DispatchQueue.main.async {
                    if success {
                        // 这部分代码缺失 - 添加成功处理
                        self.installationState.appendLog("安装完成，状态: 成功")
                        self.completeInstallation()
                    } else {
                        if let errorMessage = errorMessage, errorMessage.starts(with: "NO_ALERT:") {
                            // 不显示弹框，直接返回上一步
                            self.installationState.appendLog("安装已取消: 集群中已存在Devtron")
                            self.goBackToPreviousStep()
                        } else {
                            // 正常的错误处理
                            self.handleFailure(reason: errorMessage ?? "未知错误")
                        }
                    }
                }
            }
        )
        
        // 如果不安装Devtron，只配置环境
        if !installationState.installDevtron {
            installationState.appendLog("仅配置环境，不安装Devtron")
            
            // 只设置环境而不安装Devtron
            if let installer = devtronInstaller, installer.setupEnvironment() {
                installationState.appendLog("环境配置成功")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.completeInstallation()
                }
            } else {
                let errorMsg = "环境配置失败：无法设置Kubernetes环境。请检查kubeconfig文件权限和有效性，以及kubectl和helm工具是否正常安装。"
                installationState.appendLog("配置失败详情: \(errorMsg)")
                self.handleFailure(reason: errorMsg)
            }
            return
        }
        
        // 执行Devtron安装
        installationState.appendLog("开始安装Devtron...")
        devtronInstaller?.installDevtron()
    }
    
    // 处理安装失败
    private func handleFailure(reason: String) {
        // 记录详细失败原因
        self.installationState.appendLog("=== 安装失败 ===")
        self.installationState.appendLog("失败原因: \(reason)")
        
        // 在弹窗中显示更突出的错误信息，确保完整展示错误详情
        let errorPrefix = "安装失败"
        
        // 特殊处理kubeconfig相关的错误
        let kubeConfigErrorMsgPrefix = "环境配置失败"
        var displayError: String
        
        if reason.contains(kubeConfigErrorMsgPrefix) {
            // 针对kubeconfig错误提供更多具体建议
            displayError = reason + "\n\n可能的原因：\n" +
                         "1. 选择的kubeconfig文件权限不足\n" +
                         "2. kubeconfig文件内容格式不正确\n" +
                         "3. 应用程序无法写入配置目录\n" +
                         "4. kubectl或helm工具无法正确配置\n\n" +
                         "建议：\n" +
                         "- 检查kubeconfig文件格式和权限\n" +
                         "- 尝试手动测试kubeconfig文件（kubectl --kubeconfig=YOUR_FILE get nodes）"
        }
        // 如果错误已经很详细，则直接显示，否则添加前缀
        else if reason.contains("：") || reason.contains(":") || reason.contains(errorPrefix) {
            displayError = reason
        } else {
            displayError = "\(errorPrefix): \(reason)"
        }
        
        // 确保错误信息足够详细
        if displayError.count < 20 && !installationState.logs.isEmpty {
            // 如果错误信息过短，尝试从日志中提取更多信息
            let logLines = installationState.logs.split(separator: "\n")
            let errorLines = logLines.filter { $0.contains("错误") || $0.contains("失败") || $0.contains("!!") }
            
            if !errorLines.isEmpty {
                let additionalInfo = errorLines.suffix(3).joined(separator: "\n")
                self.installationState.showError("\(displayError)\n\n详细信息:\n\(additionalInfo)")
            } else {
                self.installationState.showError(displayError)
            }
        } else {
            self.installationState.showError(displayError)
        }
        
        // 停止所有计时器和动画
        self.stopProgressAnimation()
        self.stopTimer()
        
        // 等待2秒后返回上一步，让用户有足够时间看到错误提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.goBackToPreviousStep()
        }
    }
    
    // 新增: 处理超时
    private func handleTimeout() {
        // 标记安装不完整
        installationState.installationComplete = false
        
        // 记录超时信息
        installationState.appendLog("=== 安装超时 ===")
        installationState.appendLog("安装已运行\(formatTime(elapsedTime))，已超过预定时间")
        installationState.appendLog("自动返回安装选择页面")
        
        // 停止所有计时器和动画
        self.stopProgressAnimation()
        self.stopTimer()
        
        // 取消安装
        devtronInstaller?.cancelInstallation()
        
        // 短暂延迟后返回安装选择页面
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.goBackToPreviousStep()
        }
    }
    
    private func completeInstallation() {
        // 最终进度设为100%
        installationState.installationProgress = 1.0
        isInstallationCompleted = true
        
        // 自动进入下一步，不需要用户点击
        installationState.appendLog("安装完成，正在自动跳转到下一步...")
        
        // 短暂等待后自动进入下一步
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // 如果不安装Devtron，直接跳到完成页面，跳过等待服务启动页面
            if !self.installationState.installDevtron {
                self.installationState.appendLog("跳过等待服务启动页面，直接进入完成页面")
                self.installationState.currentStep = .completion
                
                // 记录安装时间
                if let startTime = self.installationState.installationStartTime {
                    self.installationState.installationTime = Date().timeIntervalSince(startTime)
                    self.installationState.appendLog("总安装时间: \(self.installationState.formatTime(self.installationState.installationTime))")
                }
                self.installationState.isInstalling = false
            } else {
                // 否则正常进入下一步（等待服务启动页面）
                self.installationState.moveToNextStep()
            }
        }
    }
    
    private func goBackToPreviousStep() {
        // 返回到上一步 (Devtron选择界面)
        installationState.appendLog("返回到安装选择界面")
        
        // 直接强制更新状态，确保返回上一步
        self.installationState.currentStep = .devtronChoice
        
        // 防止状态更新不及时，多次调用确保返回
        DispatchQueue.main.async {
            self.installationState.currentStep = .devtronChoice
        }
    }
    
    private func cancelInstallation() {
        // 取消安装
        installationState.appendLog("用户取消了安装")
        devtronInstaller?.cancelInstallation()
        
        // 停止所有计时器
        stopTimer()
        stopProgressAnimation()
        
        // 返回到上一步
        goBackToPreviousStep()
    }
    
    private func copyLogsToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(installationState.logs, forType: .string)
        
        // 显示复制成功通知
        installationState.appendLog("安装日志已复制到剪贴板")
    }
}
