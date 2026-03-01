# Chetverka Android App (Flutter / Dart)

Android клиент полностью переписан на Dart (Flutter). Парсер `schools.by` реализован в приложении (без `/parse`), по логике iOS `SchoolsByWebClient`.

## Что внутри

- `lib/services/schools_by_web_client.dart`
  - direct login с CSRF и cookie;
  - получение `sessionid`/`pupilid`;
  - парсинг дневника по неделям `quarter/week`;
  - разбор кабинетов и вложений, включая раскрытие `LessonAttribute` ссылок.
- `lib/state/app_controller.dart` — авторизация, загрузка дневника, сохранение сессии.
- `lib/screens/` — вкладки: Главная, Дневник, Аналитика, Итоги, Профиль.
- `lib/theme/app_theme.dart` — бело-синяя тема.

## Запуск

1. Установи Flutter SDK: https://docs.flutter.dev/get-started/install
2. Из папки `Chetverka/android-app` выполни:

```bash
flutter pub get
flutter create .
flutter run
```

## Бэкенд

Для Android Flutter-клиента бэкенд `parse/login` не обязателен, так как парсинг выполняется на устройстве.

