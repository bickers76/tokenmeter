import SwiftUI

struct ActivationView: View {
    @ObservedObject var license: LicenseService
    @State private var key: String = ""
    @State private var isActivating = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Icon area
            VStack(spacing: 16) {
                // Eye icon placeholder
                Image(systemName: "eye.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                
                Text("TokenMeter")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("See what your AI costs. One glance.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 32)
            
            // License key input
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "key.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    TextField("Enter your license key", text: $key)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                }
                .padding(12)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                
                // Error message
                if let error = license.licenseError {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
                
                // Activate button
                Button(action: {
                    isActivating = true
                    Task {
                        _ = await license.activate(key: key)
                        isActivating = false
                    }
                }) {
                    HStack {
                        if isActivating {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        }
                        Text(isActivating ? "Verifying..." : "Activate")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(key.isEmpty ? Color.green.opacity(0.3) : Color.green)
                    .foregroundColor(key.isEmpty ? .secondary : .black)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(key.isEmpty || isActivating)
            }
            .frame(width: 280)
            
            Spacer()
            
            // Footer
            VStack(spacing: 8) {
                Divider()
                
                HStack {
                    Link("Buy license — $5", destination: URL(string: "https://waynebickerton.gumroad.com/l/tokenmeter")!)
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                    
                    Text("·")
                        .foregroundColor(.secondary.opacity(0.3))
                    
                    Link("Help", destination: URL(string: "https://github.com/bickers76/tokenmeter/issues")!)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 12)
            }
        }
        .padding(24)
        .frame(width: 360, height: 400)
        .background(Color(nsColor: NSColor(red: 0.07, green: 0.07, blue: 0.11, alpha: 1)))
        .preferredColorScheme(.dark)
    }
}
