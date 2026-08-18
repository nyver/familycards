// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Семейный кошелёк карт';

  @override
  String get onboardingWelcomeTitle => 'Семейный кошелёк карт';

  @override
  String get onboardingServerAddressLabel => 'Адрес сервера';

  @override
  String get onboardingServerCheckButton => 'Продолжить';

  @override
  String get onboardingServerUnreachable =>
      'Не удалось подключиться к серверу. Проверьте адрес и соединение.';

  @override
  String get onboardingServerIncompatible =>
      'Похоже, это не сервер Family Card Wallet.';

  @override
  String get startCreateVault => 'Создать семейный сейф';

  @override
  String get startJoinByCode => 'Присоединиться по коду';

  @override
  String get startLogin => 'Войти';

  @override
  String get createVaultTitle => 'Создание семейного сейфа';

  @override
  String get loginLabel => 'Логин';

  @override
  String get displayNameLabel => 'Отображаемое имя';

  @override
  String get passwordLabel => 'Пароль';

  @override
  String get newPasswordLabel => 'Новый пароль';

  @override
  String passwordTooShort(int minLength) {
    return 'Не менее $minLength символов';
  }

  @override
  String passwordStrengthLabel(String strength) {
    return 'Надёжность пароля: $strength';
  }

  @override
  String get bootstrapTokenLabel => 'Bootstrap-токен';

  @override
  String get commonContinue => 'Продолжить';

  @override
  String get commonConfirm => 'Подтвердить';

  @override
  String get recoveryPhraseTitle => 'Фраза восстановления';

  @override
  String get recoveryPhraseWarning =>
      'Запишите эти 12 слов по порядку и сохраните в надёжном месте. Она будет показана только один раз — без неё при утере пароля доступ к сейфу будет потерян навсегда.';

  @override
  String get recoveryPhraseSavedButton => 'Я сохранил(а) её';

  @override
  String get recoveryPhraseConfirmTitle => 'Подтверждение фразы восстановления';

  @override
  String get recoveryPhraseConfirmInstructions =>
      'Введите запрошенные слова, чтобы подтвердить, что фраза сохранена правильно.';

  @override
  String recoveryPhraseWordAt(int position) {
    return 'Слово №$position';
  }

  @override
  String get recoveryPhraseConfirmMismatch =>
      'Не совпадает. Проверьте записанную фразу и попробуйте снова.';

  @override
  String get loginNoNetwork =>
      'Нет соединения. Проверьте сеть и попробуйте снова.';

  @override
  String get loginDeviceLimitReached =>
      'В этом семейном сейфе уже максимальное число устройств. Попросите другого участника отозвать старое устройство в настройках.';

  @override
  String get loginInvalidCredentials => 'Неверный логин или пароль.';

  @override
  String get loginForgotPassword => 'Забыли пароль?';

  @override
  String get inviteCodeLabel => 'Код приглашения';

  @override
  String get joinInviteExpired =>
      'Этот код приглашения истёк или уже использован. Попросите новый.';

  @override
  String get joinInvalidCode => 'Неверный код приглашения.';

  @override
  String get joinLoginTakenOrFull =>
      'Этот логин уже занят, либо семейный сейф заполнен.';

  @override
  String get recoverTitle => 'Восстановление доступа';

  @override
  String get recoveryPhraseInputLabel => 'Фраза восстановления (12 слов)';

  @override
  String get recoverInvalidPhrase =>
      'Эта фраза восстановления не подходит к данной учётной записи.';

  @override
  String get recoverSubmitButton => 'Восстановить доступ';

  @override
  String get changeServerTitle => 'Смена сервера';

  @override
  String get changeServerWarningTitle => 'Переключиться на другой сервер?';

  @override
  String get changeServerWarningBody =>
      'Это удалит все карты и данные учётной записи, хранящиеся на этом устройстве. Убедитесь, что они больше не нужны с этого сервера.';

  @override
  String get changeServerConfirmButton => 'Удалить и переключиться';

  @override
  String unlockGreeting(String name) {
    return 'С возвращением, $name';
  }

  @override
  String get unlockIncorrectPassword => 'Неверный пароль';

  @override
  String get unlockButton => 'Разблокировать';

  @override
  String get cardsListTitle => 'Мои карты';

  @override
  String get cardsListEmptyTitle => 'Пока нет карт';

  @override
  String get cardsListEmptySubtitle =>
      'Добавьте первую дисконтную карту, чтобы начать.';

  @override
  String get cardsListSearchHint => 'Поиск карт';

  @override
  String get cardsListFavoritesSection => 'Избранное';

  @override
  String get cardsListAddCard => 'Добавить карту';

  @override
  String get cardEditorTitleNew => 'Добавить карту';

  @override
  String get cardEditorTitleEdit => 'Изменить карту';

  @override
  String get storeNameLabel => 'Название магазина';

  @override
  String get cardNumberLabel => 'Номер карты';

  @override
  String get secondaryNumberLabel => 'Дополнительный номер (необязательно)';

  @override
  String get barcodeFormatLabel => 'Формат штрихкода';

  @override
  String get noteLabel => 'Заметка';

  @override
  String get colorLabel => 'Цвет';

  @override
  String get customFieldsSection => 'Пользовательские поля';

  @override
  String get addCustomField => 'Добавить поле';

  @override
  String get customFieldKeyLabel => 'Название поля';

  @override
  String get customFieldValueLabel => 'Значение';

  @override
  String get scanBarcodeButton => 'Сканировать';

  @override
  String get cardEditorValidationRequired =>
      'Название магазина и номер карты обязательны';

  @override
  String get discardChangesTitle => 'Отменить изменения?';

  @override
  String get discardChangesBody => 'Внесённые изменения будут потеряны.';

  @override
  String get discardChangesConfirm => 'Отменить';

  @override
  String get photoFrontLabel => 'Фото лицевой стороны';

  @override
  String get photoBackLabel => 'Фото оборотной стороны';

  @override
  String get photoAddButton => 'Добавить фото';

  @override
  String get photoRemoveButton => 'Удалить фото';

  @override
  String get photoSourceCamera => 'Камера';

  @override
  String get photoSourceGallery => 'Галерея';

  @override
  String get scannerTitle => 'Сканирование штрихкода';

  @override
  String get scannerPermissionDenied =>
      'Для сканирования штрихкодов нужен доступ к камере.';

  @override
  String get scannerOpenSettings => 'Повторить попытку';

  @override
  String get cardDetailCopyNumber => 'Скопировать номер';

  @override
  String get cardDetailNumberCopied => 'Номер скопирован';

  @override
  String get cardDetailDeleteConfirmTitle => 'Переместить в корзину?';

  @override
  String get cardDetailDeleteConfirmBody =>
      'Карту можно восстановить из корзины в течение 30 дней.';

  @override
  String get syncStatusIdle => 'Синхронизировано';

  @override
  String get syncStatusSyncing => 'Синхронизация…';

  @override
  String syncStatusPendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count несинхронизированных изменений',
      many: '$count несинхронизированных изменений',
      few: '$count несинхронизированных изменения',
      one: '1 несинхронизированное изменение',
    );
    return '$_temp0';
  }

  @override
  String get syncStatusError => 'Ошибка синхронизации, повтор позже';

  @override
  String syncConflictLostEdit(String cardName) {
    return 'Ваше изменение карты «$cardName» было перезаписано более новым изменением с другого устройства';
  }

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsMembersTile => 'Участники семьи';

  @override
  String get settingsSecurityTile => 'Безопасность';

  @override
  String get settingsTrashTile => 'Корзина';

  @override
  String get settingsExportTile => 'Экспорт данных';

  @override
  String get settingsImportTile => 'Импорт данных';

  @override
  String get settingsServerTile => 'Сервер';

  @override
  String get settingsLogoutTile => 'Выйти';

  @override
  String get membersTitle => 'Участники семьи';

  @override
  String get membersNoNetwork =>
      'Подключитесь к интернету, чтобы увидеть список участников.';

  @override
  String get membersRevokeButton => 'Отозвать доступ';

  @override
  String get membersRevokeConfirmTitle => 'Отозвать доступ?';

  @override
  String membersRevokeConfirmBody(String name) {
    return '$name потеряет доступ к семейному сейфу на всех своих устройствах.';
  }

  @override
  String get membersRevokedLabel => 'отозван';

  @override
  String membersDeviceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count устройства',
      many: '$count устройств',
      few: '$count устройства',
      one: '1 устройство',
      zero: 'Нет устройств',
    );
    return '$_temp0';
  }

  @override
  String get inviteTitle => 'Пригласить участника';

  @override
  String get inviteGenerateButton => 'Сгенерировать код приглашения';

  @override
  String inviteExpiresAt(String date) {
    return 'Истекает: $date';
  }

  @override
  String get inviteShareButton => 'Поделиться';

  @override
  String get inviteCancelButton => 'Отменить приглашение';

  @override
  String get inviteCancelConfirm => 'Этот код приглашения перестанет работать.';

  @override
  String get inviteCancelledMessage => 'Это приглашение отменено.';

  @override
  String get inviteLimitReached =>
      'Семейный сейф заполнен — удалите участника или дождитесь истечения ожидающего приглашения.';

  @override
  String get inviteScanQrButton => 'Сканировать QR-код';

  @override
  String get inviteScanQrTitle => 'Сканирование кода приглашения';

  @override
  String get securityBiometricTitle => 'Безопасность';

  @override
  String get securityBiometricToggle => 'Разблокировка биометрией';

  @override
  String get securityBiometricUnavailable =>
      'Биометрическая разблокировка недоступна на этом устройстве.';

  @override
  String get securityBiometricConfirmReason =>
      'Подтвердите, чтобы включить разблокировку биометрией';

  @override
  String get securityAutoLockNotice =>
      'Приложение всегда автоматически блокируется после 5 минут в фоне.';

  @override
  String get unlockBiometricButton => 'Разблокировать биометрией';

  @override
  String get trashTitle => 'Корзина';

  @override
  String get trashEmpty => 'Корзина пуста.';

  @override
  String get trashRestoreButton => 'Восстановить';

  @override
  String get trashDeleteForeverButton => 'Удалить навсегда';

  @override
  String get trashDeleteForeverConfirmTitle => 'Удалить навсегда?';

  @override
  String get trashDeleteForeverConfirmBody =>
      'Эту карту нельзя будет восстановить.';

  @override
  String trashDaysRemaining(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Осталось $days дня',
      many: 'Осталось $days дней',
      few: 'Осталось $days дня',
      one: 'Остался $days день',
      zero: 'Удалится сегодня',
    );
    return '$_temp0';
  }

  @override
  String get exportTitle => 'Экспорт данных';

  @override
  String get exportPasswordLabel => 'Пароль архива';

  @override
  String get exportPasswordConfirmLabel => 'Подтвердите пароль';

  @override
  String get exportWarning =>
      'Архив будет содержать номера всех карт в этом сейфе. Храните файл и пароль от него в надёжном месте.';

  @override
  String get exportButton => 'Экспортировать';

  @override
  String get exportPasswordMismatch => 'Пароли не совпадают';

  @override
  String get exportSuccessTitle => 'Экспорт завершён';

  @override
  String exportSuccessBody(String path) {
    return 'Сохранено в $path';
  }

  @override
  String get exportShareButton => 'Поделиться файлом';

  @override
  String get importTitle => 'Импорт данных';

  @override
  String get importPickPrompt =>
      'Выберите файл экспорта Family Card Wallet (.fcw) для импорта.';

  @override
  String get importPickButton => 'Выбрать файл';

  @override
  String get importPasswordLabel => 'Пароль архива';

  @override
  String get importDecryptButton => 'Продолжить';

  @override
  String get importPickAnotherButton => 'Выбрать другой файл';

  @override
  String get importWrongPassword => 'Неверный пароль для этого архива';

  @override
  String get importInvalidFile =>
      'Этот файл не является архивом экспорта Family Card Wallet';

  @override
  String importCardsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Найдено $count карты',
      many: 'Найдено $count карт',
      few: 'Найдено $count карты',
      one: 'Найдена 1 карта',
      zero: 'Карты не найдены',
    );
    return '$_temp0';
  }

  @override
  String get importIncludeDuplicatesToggle =>
      'Также импортировать карты, дублирующие существующие';

  @override
  String get importConfirmButton => 'Импортировать';

  @override
  String get importSuccessTitle => 'Импорт завершён';

  @override
  String importSuccessBody(int added, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'Добавлено $added карты',
      many: 'Добавлено $added карт',
      few: 'Добавлено $added карты',
      one: 'Добавлена 1 карта',
      zero: 'Карты не добавлены',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: 'пропущено $skipped дубликата',
      many: 'пропущено $skipped дубликатов',
      few: 'пропущено $skipped дубликата',
      one: 'пропущен 1 дубликат',
      zero: 'дубликатов не пропущено',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get serverSettingsTitle => 'Сервер';

  @override
  String get serverSettingsAddressLabel => 'Адрес сервера';

  @override
  String get serverSettingsReachable => 'Доступен';

  @override
  String get serverSettingsUnreachable => 'Недоступен';

  @override
  String get serverSettingsLastSync => 'Последняя успешная синхронизация';

  @override
  String get serverSettingsPendingCount => 'Несинхронизированные изменения';

  @override
  String get serverSettingsForceSyncButton => 'Синхронизировать сейчас';

  @override
  String get serverSettingsChangeAddressButton => 'Сменить сервер';

  @override
  String get logoutConfirmTitle => 'Выйти?';

  @override
  String logoutConfirmBodyUnsynced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count изменения ещё не отправлены',
      many: '$count изменений ещё не отправлены',
      few: '$count изменения ещё не отправлены',
      one: '1 изменение ещё не отправлено',
    );
    return '$_temp0 на сервер и будут потеряны.';
  }

  @override
  String get logoutConfirmBodyClean => 'Вы можете войти снова в любой момент.';
}
