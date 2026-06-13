import SwiftUI

struct ContentView: View {
    @State private var showLogin = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color(red: 0.09, green: 0.11, blue: 0.18))

            Text("WKWebView POC")
                .font(.title2.weight(.semibold))

            Spacer()

            Button {
                showLogin = true
            } label: {
                Label("Login with Oloid", systemImage: "person.badge.key.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.09, green: 0.11, blue: 0.18))
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .fullScreenCover(isPresented: $showLogin) {
            LoginWebScreen()
        }
    }
}

/// Presents the Oloid login page in a `WKWebView`, with a dismiss button.
private struct LoginWebScreen: View {
    @Environment(\.dismiss) private var dismiss

    private let targetURL = URL(string: "https://guitarcenter.previewoloid.net/login")!

    @State private var isLoading = false
    @State private var pageTitle = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                WebView(
                    url: targetURL,
                    isLoading: $isLoading,
                    pageTitle: $pageTitle,
                    errorMessage: $errorMessage
                )
                .ignoresSafeArea(edges: .bottom)

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.4)
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }

                if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text("Failed to load")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding()
                }
            }
            .navigationTitle(pageTitle.isEmpty ? "Login" : pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
