import SwiftUI

// 共享的进度条组件
struct ProgressBar: View {
    var progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景条
                Rectangle()
                    .foregroundColor(Color.gray.opacity(0.2))
                    .cornerRadius(3)
                
                // 进度条
                Rectangle()
                    .foregroundColor(Color.blue)
                    .frame(width: geometry.size.width * CGFloat(min(max(progress, 0.02), 1.0)))
                    .cornerRadius(3)
            }
        }
    }
}

// 添加共享的标题样式
struct TitleText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .medium))
    }
}

// 添加共享的副标题样式
struct SubtitleText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
    }
}

// 添加共享的段落标题样式
struct SectionTitle: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .padding(.bottom, 2)
    }
} 
