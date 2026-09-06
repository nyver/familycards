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
  String get certificateFingerprintLabel =>
      'Certificate fingerprint (optional)';

  @override
  String get certificateFingerprintHelper =>
      'Paste the SHA-256 fingerprint from the server\'s startup log to verify it before connecting.';

  @override
  String get certificateFingerprintInvalid =>
      'Enter a valid 32-byte SHA-256 fingerprint (64 hex characters, with or without separators).';

  @override
  String get certificateMismatchMessage =>
      'The server\'s certificate does not match this fingerprint.';

  @override
  String get certificateConfirmTitle => 'Verify the server\'s certificate';

  @override
  String get certificateConfirmBody =>
      'This certificate is not automatically trusted by your device. Compare the fingerprint below with the one printed in the server\'s startup log before continuing - there is no way to skip this check.';

  @override
  String get certificateConfirmButton => 'It matches, pin it';

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
  String get cardEditorLogoPreviewLabel => 'Logo preview';

  @override
  String get cardEditorRemoveLogoButton => 'Remove logo';

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

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsMembersTile => 'Family members';

  @override
  String get settingsSecurityTile => 'Security';

  @override
  String get settingsTrashTile => 'Trash';

  @override
  String get settingsExportTile => 'Export data';

  @override
  String get settingsImportTile => 'Import data';

  @override
  String get settingsServerTile => 'Server';

  @override
  String get settingsLogoutTile => 'Log out';

  @override
  String get membersTitle => 'Family members';

  @override
  String get membersNoNetwork =>
      'Connect to the internet to see the member list.';

  @override
  String get membersRevokeButton => 'Revoke access';

  @override
  String get membersRevokeConfirmTitle => 'Revoke access?';

  @override
  String membersRevokeConfirmBody(String name) {
    return '$name will lose access to the family vault on all of their devices.';
  }

  @override
  String get membersRevokedLabel => 'revoked';

  @override
  String membersDeviceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices',
      one: '1 device',
      zero: 'No devices',
    );
    return '$_temp0';
  }

  @override
  String get inviteTitle => 'Invite a member';

  @override
  String get inviteGenerateButton => 'Generate invite code';

  @override
  String inviteExpiresAt(String date) {
    return 'Expires: $date';
  }

  @override
  String get inviteShareButton => 'Share';

  @override
  String get inviteCancelButton => 'Cancel invite';

  @override
  String get inviteCancelConfirm => 'This invite code will no longer work.';

  @override
  String get inviteCancelledMessage => 'This invite has been cancelled.';

  @override
  String get inviteLimitReached =>
      'The family vault is full - remove a member or wait for a pending invite to expire.';

  @override
  String get inviteScanQrButton => 'Scan QR code';

  @override
  String get inviteScanQrTitle => 'Scan invite code';

  @override
  String get securityBiometricTitle => 'Security';

  @override
  String get securityBiometricToggle => 'Unlock with biometrics';

  @override
  String get securityBiometricUnavailable =>
      'Biometric unlock is not available on this device.';

  @override
  String get securityBiometricConfirmReason =>
      'Confirm to enable biometric unlock';

  @override
  String get securityAutoLockNotice =>
      'The app always locks itself automatically after 5 minutes in the background.';

  @override
  String get unlockBiometricButton => 'Unlock with biometrics';

  @override
  String get trashTitle => 'Trash';

  @override
  String get trashEmpty => 'Trash is empty.';

  @override
  String get trashRestoreButton => 'Restore';

  @override
  String get trashDeleteForeverButton => 'Delete forever';

  @override
  String get trashDeleteForeverConfirmTitle => 'Delete forever?';

  @override
  String get trashDeleteForeverConfirmBody =>
      'This card cannot be recovered after this.';

  @override
  String trashDaysRemaining(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
      zero: 'Removed today',
    );
    return '$_temp0';
  }

  @override
  String get exportTitle => 'Export data';

  @override
  String get exportPasswordLabel => 'Archive password';

  @override
  String get exportPasswordConfirmLabel => 'Confirm password';

  @override
  String get exportWarning =>
      'The archive will contain every card number in this vault. Keep the file and its password safe.';

  @override
  String get exportButton => 'Export';

  @override
  String get exportPasswordMismatch => 'Passwords don\'t match';

  @override
  String get exportSuccessTitle => 'Export complete';

  @override
  String exportSuccessBody(String path) {
    return 'Saved to $path';
  }

  @override
  String get exportShareButton => 'Share file';

  @override
  String get importTitle => 'Import data';

  @override
  String get importPickPrompt =>
      'Choose a Family Card Wallet export file (.fcw) to import.';

  @override
  String get importPickButton => 'Choose file';

  @override
  String get importPasswordLabel => 'Archive password';

  @override
  String get importDecryptButton => 'Continue';

  @override
  String get importPickAnotherButton => 'Choose a different file';

  @override
  String get importWrongPassword => 'Wrong password for this archive';

  @override
  String get importInvalidFile =>
      'This file isn\'t a Family Card Wallet export';

  @override
  String importCardsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards found',
      one: '1 card found',
      zero: 'No cards found',
    );
    return '$_temp0';
  }

  @override
  String get importIncludeDuplicatesToggle =>
      'Also import cards that duplicate existing ones';

  @override
  String get importConfirmButton => 'Import';

  @override
  String get importSuccessTitle => 'Import complete';

  @override
  String importSuccessBody(int added, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added cards added',
      one: '1 card added',
      zero: 'No cards added',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: '$skipped duplicates skipped',
      one: '1 duplicate skipped',
      zero: 'no duplicates skipped',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get serverSettingsTitle => 'Server';

  @override
  String get serverSettingsAddressLabel => 'Server address';

  @override
  String get serverSettingsReachable => 'Reachable';

  @override
  String get serverSettingsUnreachable => 'Unreachable';

  @override
  String get serverSettingsLastSync => 'Last successful sync';

  @override
  String get serverSettingsPendingCount => 'Unsynced changes';

  @override
  String get serverSettingsForceSyncButton => 'Sync now';

  @override
  String get serverSettingsChangeAddressButton => 'Change server';

  @override
  String get serverSettingsCertificateTitle => 'Certificate pin';

  @override
  String get serverSettingsCertificateNotPinned =>
      'Not pinned - using system certificate authorities';

  @override
  String get serverSettingsCertificatePinButton => 'Pin certificate';

  @override
  String get serverSettingsCertificateReplaceButton => 'Replace';

  @override
  String get serverSettingsCertificateRemoveButton => 'Remove';

  @override
  String get serverSettingsCertificateMismatchNotice =>
      'Sync is failing because the server\'s certificate no longer matches the pinned fingerprint. Replace or remove the pin to continue.';

  @override
  String get serverSettingsCertificateAcmeWarningTitle =>
      'This certificate is publicly trusted';

  @override
  String get serverSettingsCertificateAcmeWarningBody =>
      'This certificate also validates through your system\'s certificate authorities, which usually means it renews automatically. Renewal changes the fingerprint, and this pin will need to be updated when that happens.';

  @override
  String get serverSettingsCertificateRemoveConfirmTitle =>
      'Remove the certificate pin?';

  @override
  String get serverSettingsCertificateRemoveConfirmBody =>
      'The app will go back to verifying this server\'s certificate through your system\'s certificate authorities.';

  @override
  String get logoutConfirmTitle => 'Log out?';

  @override
  String logoutConfirmBodyUnsynced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes have',
      one: '1 change has',
    );
    return '$_temp0 not been sent to the server yet and will be lost.';
  }

  @override
  String get logoutConfirmBodyClean => 'You can log back in at any time.';
}
