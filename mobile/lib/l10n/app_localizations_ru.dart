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
}
