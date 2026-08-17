// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Family Card Wallet';

  @override
  String get onboardingWelcomeTitle => 'Family Card Wallet';

  @override
  String get onboardingServerAddressLabel => 'Server address';

  @override
  String get onboardingServerCheckButton => 'Continue';

  @override
  String get onboardingServerUnreachable =>
      'Could not reach this server. Check the address and your connection.';

  @override
  String get onboardingServerIncompatible =>
      'This does not look like a Family Card Wallet server.';

  @override
  String get startCreateVault => 'Create a family vault';

  @override
  String get startJoinByCode => 'Join with an invite code';

  @override
  String get startLogin => 'Log in';

  @override
  String get createVaultTitle => 'Create your family vault';

  @override
  String get loginLabel => 'Login';

  @override
  String get displayNameLabel => 'Display name';

  @override
  String get passwordLabel => 'Password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String passwordTooShort(int minLength) {
    return 'At least $minLength characters';
  }

  @override
  String passwordStrengthLabel(String strength) {
    return 'Password strength: $strength';
  }

  @override
  String get bootstrapTokenLabel => 'Bootstrap token';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get recoveryPhraseTitle => 'Your recovery phrase';

  @override
  String get recoveryPhraseWarning =>
      'Write down these 12 words in order and keep them somewhere safe. This is the only time they will be shown - without them, losing your password means losing access to your vault forever.';

  @override
  String get recoveryPhraseSavedButton => 'I\'ve saved it';

  @override
  String get recoveryPhraseConfirmTitle => 'Confirm your recovery phrase';

  @override
  String get recoveryPhraseConfirmInstructions =>
      'Enter the requested words to confirm you saved the phrase correctly.';

  @override
  String recoveryPhraseWordAt(int position) {
    return 'Word #$position';
  }

  @override
  String get recoveryPhraseConfirmMismatch =>
      'That doesn\'t match. Check your written-down phrase and try again.';

  @override
  String get loginNoNetwork =>
      'No connection. Check your network and try again.';

  @override
  String get loginDeviceLimitReached =>
      'This family vault already has the maximum number of devices. Ask another member to remove an old device in Settings.';

  @override
  String get loginInvalidCredentials => 'Incorrect login or password.';

  @override
  String get loginForgotPassword => 'Forgot your password?';

  @override
  String get inviteCodeLabel => 'Invite code';

  @override
  String get joinInviteExpired =>
      'This invite code has expired or was already used. Ask for a new one.';

  @override
  String get joinInvalidCode => 'That invite code isn\'t valid.';

  @override
  String get joinLoginTakenOrFull =>
      'That login is already taken, or the family vault is full.';

  @override
  String get recoverTitle => 'Recover access';

  @override
  String get recoveryPhraseInputLabel => '12-word recovery phrase';

  @override
  String get recoverInvalidPhrase =>
      'That recovery phrase doesn\'t match this account.';

  @override
  String get recoverSubmitButton => 'Restore access';

  @override
  String get changeServerTitle => 'Change server';

  @override
  String get changeServerWarningTitle => 'Switch to a different server?';

  @override
  String get changeServerWarningBody =>
      'This will erase all cards and account data stored on this device. Make sure you don\'t need them from this server anymore.';

  @override
  String get changeServerConfirmButton => 'Erase and switch';

  @override
  String unlockGreeting(String name) {
    return 'Welcome back, $name';
  }

  @override
  String get unlockIncorrectPassword => 'Incorrect password';

  @override
  String get unlockButton => 'Unlock';

  @override
  String get cardsListTitle => 'My cards';

  @override
  String get cardsListEmptyTitle => 'No cards yet';

  @override
  String get cardsListEmptySubtitle =>
      'Add your first loyalty card to get started.';

  @override
  String get cardsListSearchHint => 'Search cards';

  @override
  String get cardsListFavoritesSection => 'Favorites';

  @override
  String get cardsListAddCard => 'Add card';

  @override
  String get cardEditorTitleNew => 'Add card';

  @override
  String get cardEditorTitleEdit => 'Edit card';

  @override
  String get storeNameLabel => 'Store name';

  @override
  String get cardNumberLabel => 'Card number';

  @override
  String get secondaryNumberLabel => 'Secondary number (optional)';

  @override
  String get barcodeFormatLabel => 'Barcode format';

  @override
  String get noteLabel => 'Note';

  @override
  String get colorLabel => 'Color';

  @override
  String get customFieldsSection => 'Custom fields';

  @override
  String get addCustomField => 'Add field';

  @override
  String get customFieldKeyLabel => 'Field name';

  @override
  String get customFieldValueLabel => 'Value';

  @override
  String get scanBarcodeButton => 'Scan';

  @override
  String get cardEditorValidationRequired =>
      'Store name and card number are required';

  @override
  String get discardChangesTitle => 'Discard changes?';

  @override
  String get discardChangesBody => 'Your edits will be lost.';

  @override
  String get discardChangesConfirm => 'Discard';

  @override
  String get photoFrontLabel => 'Front photo';

  @override
  String get photoBackLabel => 'Back photo';

  @override
  String get photoAddButton => 'Add photo';

  @override
  String get photoRemoveButton => 'Remove photo';

  @override
  String get photoSourceCamera => 'Camera';

  @override
  String get photoSourceGallery => 'Gallery';

  @override
  String get scannerTitle => 'Scan barcode';

  @override
  String get scannerPermissionDenied =>
      'Camera access is needed to scan barcodes.';

  @override
  String get scannerOpenSettings => 'Try again';

  @override
  String get cardDetailCopyNumber => 'Copy number';

  @override
  String get cardDetailNumberCopied => 'Number copied';

  @override
  String get cardDetailDeleteConfirmTitle => 'Move to trash?';

  @override
  String get cardDetailDeleteConfirmBody =>
      'You can restore this card from the trash within 30 days.';

  @override
  String get syncStatusIdle => 'Up to date';

  @override
  String get syncStatusSyncing => 'Syncing…';

  @override
  String syncStatusPendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes pending',
      one: '1 change pending',
    );
    return '$_temp0';
  }

  @override
  String get syncStatusError => 'Sync failed, will retry';

  @override
  String syncConflictLostEdit(String cardName) {
    return 'Your change to \"$cardName\" was overwritten by a newer edit from another device';
  }

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRetry => 'Retry';
}
