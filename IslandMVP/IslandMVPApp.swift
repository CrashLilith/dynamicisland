import SwiftUI
import MediaPlayer
import UIKit

@main
struct IslandMVPApp: App {
    @StateObject private var music = MusicController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(music)
                .preferredColorScheme(.dark)
        }
    }
}

@MainActor
final class MusicController: ObservableObject {
    @Published var title = "Музыка не выбрана"
    @Published var artist = "Подключите системный плеер"
    @Published var artwork: UIImage?
    @Published var isPlaying = false
    @Published var accessGranted = false
    @Published var status = "Ожидает доступа к медиатеке"

    private let player = MPMusicPlayerController.systemMusicPlayer
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: player, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.refresh() } })
        observers.append(center.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: player, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.refresh() } })
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    func requestAccessAndRefresh() async {
        let current = MPMediaLibrary.authorizationStatus()
        let result: MPMediaLibraryAuthorizationStatus
        if current == .notDetermined {
            result = await withCheckedContinuation { continuation in
                MPMediaLibrary.requestAuthorization { continuation.resume(returning: $0) }
            }
        } else {
            result = current
        }
        accessGranted = result == .authorized
        guard accessGranted else {
            status = result == .denied || result == .restricted
                ? "Доступ запрещён в настройках iOS"
                : "Медиатека недоступна"
            title = "Нет доступа к музыке"
            artist = "Разрешите доступ в настройках"
            return
        }
        player.beginGeneratingPlaybackNotifications()
        refresh()
    }

    func refresh() {
        guard accessGranted else { return }
        isPlaying = player.playbackState == .playing
        if let item = player.nowPlayingItem {
            title = item.title ?? "Без названия"
            artist = item.artist ?? item.albumArtist ?? "Неизвестный исполнитель"
            artwork = item.artwork?.image(at: CGSize(width: 240, height: 240))
            status = isPlaying ? "Воспроизводится в Музыке" : "Пауза в Музыке"
        } else {
            title = "Нет текущего трека"
            artist = "Запустите музыку в приложении Музыка"
            artwork = nil
            status = "Системный плеер не сообщает трек"
        }
    }

    func togglePlayback() {
        guard accessGranted else { return }
        if player.playbackState == .playing { player.pause() } else { player.play() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.refresh() }
    }
}

struct ContentView: View {
    @EnvironmentObject private var music: MusicController
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("islandScale") private var islandScale = 1.0
    @AppStorage("islandTopInset") private var islandTopInset = 12.0
    @AppStorage("accentStyle") private var accentStyle = 0
    @State private var isExpanded = true
    @State private var isChargingDemo = false
    @State private var chargeProgress = 0.72
    @State private var showSettings = false

    private var accent: Color {
        [Color(red: 0.48, green: 0.92, blue: 0.72), .cyan, .orange, .purple][accentStyle % 4]
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.09, green: 0.12, blue: 0.15), .black, .black],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                header
                    .padding(.top, 8)
                island
                    .padding(.top, islandTopInset)
                    .padding(.horizontal, 25)
                Spacer(minLength: 28)
                nowPlayingCard
                demoCard
                footer
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 18)
        }
        .task { await music.requestAccessAndRefresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { music.refresh() }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(scale: $islandScale, topInset: $islandTopInset,
                         accentStyle: $accentStyle)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("ISLAND").font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(2.2).foregroundStyle(accent)
                Text("Музыка под рукой").font(.system(size: 26, weight: .bold, design: .rounded))
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white).frame(width: 46, height: 46)
                    .background(.white.opacity(0.08), in: Circle())
            }
            .accessibilityLabel("Настройки")
        }
        .foregroundStyle(.white)
    }

    private var island: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Capsule().fill(.black).frame(width: 78, height: 25)
                    .overlay(alignment: .trailing) {
                        Circle().fill(Color(red: 0.05, green: 0.08, blue: 0.1))
                            .frame(width: 8, height: 8).padding(.trailing, 15)
                    }
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    ForEach(0..<4) { index in
                        Capsule().fill(isChargingDemo ? accent : (music.isPlaying ? accent : .white.opacity(0.45)))
                            .frame(width: 3, height: music.isPlaying && !isChargingDemo
                                   ? CGFloat([9, 16, 12, 19][index]) : 7)
                            .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.08), value: music.isPlaying)
                    }
                }
                .frame(width: 31, height: 25)
            }
            if isExpanded {
                Divider().overlay(.white.opacity(0.08)).padding(.horizontal, 17).padding(.top, 13)
                if isChargingDemo {
                    chargingContent.padding(.horizontal, 17).padding(.vertical, 14)
                } else {
                    musicContent.padding(.horizontal, 15).padding(.vertical, 13)
                }
            }
        }
        .padding(.horizontal, 17).padding(.top, 13).padding(.bottom, isExpanded ? 3 : 13)
        .frame(maxWidth: 400)
        .background(.black, in: RoundedRectangle(cornerRadius: isExpanded ? 32 : 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: isExpanded ? 32 : 30, style: .continuous)
            .stroke(.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
        .scaleEffect(islandScale)
        .contentShape(RoundedRectangle(cornerRadius: 32))
        .onTapGesture {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { isExpanded.toggle() }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: isExpanded)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: isChargingDemo)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Демонстрационная панель Island внутри приложения")
    }

    private var musicContent: some View {
        HStack(spacing: 12) {
            artworkView(size: 43)
            VStack(alignment: .leading, spacing: 3) {
                Text(music.title).font(.system(size: 14, weight: .semibold))
                    .lineLimit(1).foregroundStyle(.white)
                Text(music.artist).font(.system(size: 12)).lineLimit(1).foregroundStyle(.white.opacity(0.58))
            }
            Spacer(minLength: 4)
            Button { music.togglePlayback() } label: {
                Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(.black)
                    .frame(width: 34, height: 34).background(accent, in: Circle())
            }
            .disabled(!music.accessGranted).opacity(music.accessGranted ? 1 : 0.55)
            .accessibilityLabel(music.isPlaying ? "Пауза" : "Воспроизвести")
        }
    }

    private var chargingContent: some View {
        HStack(spacing: 11) {
            Image(systemName: "bolt.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(accent)
                .frame(width: 40, height: 40).background(accent.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Зарядка · демо").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(chargeProgress * 100))%").font(.system(size: 13, weight: .bold)).foregroundStyle(accent)
                }
                ProgressView(value: chargeProgress).tint(accent)
            }
        }
    }

    private var nowPlayingCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Label("СИСТЕМНАЯ МУЗЫКА", systemImage: "waveform")
                    .font(.system(size: 10, weight: .bold)).tracking(1.3).foregroundStyle(accent)
                Spacer()
                Circle().fill(music.accessGranted ? accent : .orange).frame(width: 6, height: 6)
                Text(music.accessGranted ? music.status : "Нужно разрешение")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.55))
            }
            HStack(spacing: 14) {
                artworkView(size: 64)
                VStack(alignment: .leading, spacing: 5) {
                    Text(music.title).font(.system(size: 17, weight: .bold)).lineLimit(1)
                    Text(music.artist).font(.system(size: 13)).lineLimit(1).foregroundStyle(.white.opacity(0.58))
                }
                Spacer(minLength: 0)
                Button { music.togglePlayback() } label: {
                    Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(.black)
                        .frame(width: 44, height: 44).background(accent, in: Circle())
                }
                .disabled(!music.accessGranted).opacity(music.accessGranted ? 1 : 0.5)
            }
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text("Показываются данные, доступные системному плееру Apple Music.")
            }
            .font(.system(size: 10)).foregroundStyle(.white.opacity(0.42))
        }
        .padding(16)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 23).stroke(.white.opacity(0.07), lineWidth: 1))
        .padding(.bottom, 12)
    }

    private var demoCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("ДЕМО-РЕЖИМЫ").font(.system(size: 10, weight: .bold)).tracking(1.4)
                    .foregroundStyle(.white.opacity(0.42))
                Spacer()
                Text("Не системный оверлей").font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
            Button {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    isChargingDemo.toggle()
                    isExpanded = true
                }
                if isChargingDemo { animateCharge() }
            } label: {
                HStack(spacing: 13) {
                    Image(systemName: isChargingDemo ? "music.note" : "bolt.fill")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(accent)
                        .frame(width: 42, height: 42).background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isChargingDemo ? "Вернуться к музыке" : "Показать зарядку")
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        Text(isChargingDemo ? "Демонстрацию можно отключить здесь" : "Отдельная анимация, без чтения батареи")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.48))
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(12)
                .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(15)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.bottom, 12)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "iphone.gen3").foregroundStyle(accent)
            Text("Панель видна только внутри этого приложения")
        }
        .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.4))
        .frame(maxWidth: .infinity).padding(.top, 2)
    }

    @ViewBuilder private func artworkView(size: CGFloat) -> some View {
        if let artwork = music.artwork {
            Image(uiImage: artwork).resizable().scaledToFill()
                .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.24))
        } else {
            RoundedRectangle(cornerRadius: size * 0.24)
                .fill(LinearGradient(colors: [accent.opacity(0.45), .white.opacity(0.08)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
                .overlay(Image(systemName: "music.note").font(.system(size: size * 0.34, weight: .medium)).foregroundStyle(.white.opacity(0.8)))
        }
    }

    private func animateCharge() {
        chargeProgress = 0.18
        withAnimation(.easeInOut(duration: 2.4)) { chargeProgress = 0.86 }
    }
}

struct SettingsView: View {
    @Binding var scale: Double
    @Binding var topInset: Double
    @Binding var accentStyle: Int
    @Environment(\.dismiss) private var dismiss
    private let colors: [(String, Color)] = [
        ("Мята", Color(red: 0.48, green: 0.92, blue: 0.72)),
        ("Циан", .cyan), ("Янтарь", .orange), ("Лаванда", .purple)
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Размер панели") {
                    LabeledContent("Масштаб", value: "\(Int(scale * 100))%")
                    Slider(value: $scale, in: 0.85...1.12, step: 0.01)
                        .tint(colors[accentStyle % colors.count].1)
                }
                Section("Расположение") {
                    LabeledContent("Отступ сверху", value: "\(Int(topInset)) pt")
                    Slider(value: $topInset, in: 0...40, step: 1)
                        .tint(colors[accentStyle % colors.count].1)
                }
                Section("Акцент") {
                    ForEach(colors.indices, id: \.self) { index in
                        Button { accentStyle = index } label: {
                            HStack {
                                Circle().fill(colors[index].1).frame(width: 13, height: 13)
                                Text(colors[index].0).foregroundStyle(.primary)
                                Spacer()
                                if accentStyle == index { Image(systemName: "checkmark").foregroundStyle(colors[index].1) }
                            }
                        }
                    }
                }
                Section {
                    Text("Настройки меняют только визуальную панель в приложении. iOS не разрешает обычным приложениям рисовать поверх других приложений.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Готово") { dismiss() }
            } }
        }
        .preferredColorScheme(.dark)
    }
}

