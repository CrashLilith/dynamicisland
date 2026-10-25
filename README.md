# Island MVP

SwiftUI-прототип визуальной Dynamic Island для iPhone 12 Pro Max. Он рисуется только внутри собственного окна приложения: обычные iOS-приложения не могут закрепить произвольную панель поверх чужих приложений или системного интерфейса.

## Что уже есть

- Чёрная pill-панель с анимацией раскрытия и сворачивания.
- Обложка, трек и исполнитель через `MPMusicPlayerController.systemMusicPlayer`, если системный Music сообщает эти сведения и пользователь разрешил доступ к медиатеке.
- Кнопка воспроизведения/паузы системного Music.
- Отдельный демонстрационный экран зарядки (не читает состояние батареи).
- Настройка масштаба, верхнего отступа и акцентного цвета.

`MPNowPlayingInfoCenter` предназначен для публикации метаданных собственного аудиоплеера приложения, а не для чтения текущего трека произвольного стороннего приложения. Поэтому MVP запрашивает медиатеку и наблюдает за `MPMusicPlayerController.systemMusicPlayer`. Доступность названия, исполнителя и обложки зависит от источника музыки и разрешений; например, документация отмечает, что сведения о треке могут быть недоступны при Home Sharing.

## Совместимость

Проект использует SwiftUI и MediaPlayer API, доступные задолго до iOS 27. Deployment target — iOS 17.0; SDK выбирается установленным Xcode. Для сборки с SDK iOS 27 потребуется версия Xcode, в которой Apple поставляет iOS 27 SDK. Сам SDK iOS 27 в текущей среде не установлен, и сборка здесь не проверялась.

ActivityKit и Live Activities — отдельный системный путь, а не способ создать произвольный оверлей. Live Activity может отображаться в системных поверхностях, включая экран блокировки; Dynamic Island на iPhone доступен только на моделях с поддержкой Dynamic Island. iPhone 12 Pro Max не имеет физического Dynamic Island, поэтому ActivityKit не создаст на нём такой вырез. ActivityKit не включён в первый MVP.

## Сборка и установка на iPhone

1. Откройте `IslandMVP.xcodeproj` на Mac в Xcode с iOS 27 SDK (либо выберите установленный SDK и совместимую версию Xcode).
2. Подключите iPhone 12 Pro Max кабелем, разблокируйте его и подтвердите доверие компьютеру. В Xcode выберите телефон как Run Destination.
3. В Signing & Capabilities выберите свою Team. Для установки на личное устройство достаточно личной Apple Account в Xcode; для распространения другим пользователям потребуется подходящий профиль подписи.
4. Нажмите Run. При первом запуске разрешите доступ к медиатеке. Запустите трек в приложении Музыка и вернитесь в Island MVP.
5. Если iPhone попросит доверить профиль разработчика, подтвердите это в Settings → General → VPN & Device Management.

Если проект открывается в GitHub Codespaces или на Windows, iOS-приложение там не соберётся: для Xcode и установки на iPhone нужен Mac.

## Ссылки Apple

- [MPMusicPlayerController.systemMusicPlayer](https://developer.apple.com/documentation/mediaplayer/mpmusicplayercontroller/systemmusicplayer)
- [MPMusicPlayerController.nowPlayingItem](https://developer.apple.com/documentation/mediaplayer/mpmusicplayercontroller/nowplayingitem)
- [Media Player privacy and authorization](https://developer.apple.com/documentation/mediaplayer)
- [ActivityKit Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)

