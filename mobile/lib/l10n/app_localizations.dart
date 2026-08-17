import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// The application name, shown as the app title and on the home screen.
  ///
  /// In en, this message translates to:
  /// **'Family Card Wallet'**
  String get appTitle;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Family Card Wallet'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingServerAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get onboardingServerAddressLabel;

  /// No description provided for @onboardingServerCheckButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingServerCheckButton;

  /// No description provided for @onboardingServerUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach this server. Check the address and your connection.'**
  String get onboardingServerUnreachable;

  /// No description provided for @onboardingServerIncompatible.
  ///
  /// In en, this message translates to:
  /// **'This does not look like a Family Card Wallet server.'**
  String get onboardingServerIncompatible;

  /// No description provided for @startCreateVault.
  ///
  /// In en, this message translates to:
  /// **'Create a family vault'**
  String get startCreateVault;

  /// No description provided for @startJoinByCode.
  ///
  /// In en, this message translates to:
  /// **'Join with an invite code'**
  String get startJoinByCode;

  /// No description provided for @startLogin.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get startLogin;

  /// No description provided for @createVaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your family vault'**
  String get createVaultTitle;

  /// No description provided for @loginLabel.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginLabel;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayNameLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least {minLength} characters'**
  String passwordTooShort(int minLength);

  /// No description provided for @passwordStrengthLabel.
  ///
  /// In en, this message translates to:
  /// **'Password strength: {strength}'**
  String passwordStrengthLabel(String strength);

  /// No description provided for @bootstrapTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Bootstrap token'**
  String get bootstrapTokenLabel;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @recoveryPhraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Your recovery phrase'**
  String get recoveryPhraseTitle;

  /// No description provided for @recoveryPhraseWarning.
  ///
  /// In en, this message translates to:
  /// **'Write down these 12 words in order and keep them somewhere safe. This is the only time they will be shown - without them, losing your password means losing access to your vault forever.'**
  String get recoveryPhraseWarning;

  /// No description provided for @recoveryPhraseSavedButton.
  ///
  /// In en, this message translates to:
  /// **'I\'ve saved it'**
  String get recoveryPhraseSavedButton;

  /// No description provided for @recoveryPhraseConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your recovery phrase'**
  String get recoveryPhraseConfirmTitle;

  /// No description provided for @recoveryPhraseConfirmInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter the requested words to confirm you saved the phrase correctly.'**
  String get recoveryPhraseConfirmInstructions;

  /// No description provided for @recoveryPhraseWordAt.
  ///
  /// In en, this message translates to:
  /// **'Word #{position}'**
  String recoveryPhraseWordAt(int position);

  /// No description provided for @recoveryPhraseConfirmMismatch.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t match. Check your written-down phrase and try again.'**
  String get recoveryPhraseConfirmMismatch;

  /// No description provided for @loginNoNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your network and try again.'**
  String get loginNoNetwork;

  /// No description provided for @loginDeviceLimitReached.
  ///
  /// In en, this message translates to:
  /// **'This family vault already has the maximum number of devices. Ask another member to remove an old device in Settings.'**
  String get loginDeviceLimitReached;

  /// No description provided for @loginInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect login or password.'**
  String get loginInvalidCredentials;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get loginForgotPassword;

  /// No description provided for @inviteCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteCodeLabel;

  /// No description provided for @joinInviteExpired.
  ///
  /// In en, this message translates to:
  /// **'This invite code has expired or was already used. Ask for a new one.'**
  String get joinInviteExpired;

  /// No description provided for @joinInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'That invite code isn\'t valid.'**
  String get joinInvalidCode;

  /// No description provided for @joinLoginTakenOrFull.
  ///
  /// In en, this message translates to:
  /// **'That login is already taken, or the family vault is full.'**
  String get joinLoginTakenOrFull;

  /// No description provided for @recoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Recover access'**
  String get recoverTitle;

  /// No description provided for @recoveryPhraseInputLabel.
  ///
  /// In en, this message translates to:
  /// **'12-word recovery phrase'**
  String get recoveryPhraseInputLabel;

  /// No description provided for @recoverInvalidPhrase.
  ///
  /// In en, this message translates to:
  /// **'That recovery phrase doesn\'t match this account.'**
  String get recoverInvalidPhrase;

  /// No description provided for @recoverSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Restore access'**
  String get recoverSubmitButton;

  /// No description provided for @changeServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Change server'**
  String get changeServerTitle;

  /// No description provided for @changeServerWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to a different server?'**
  String get changeServerWarningTitle;

  /// No description provided for @changeServerWarningBody.
  ///
  /// In en, this message translates to:
  /// **'This will erase all cards and account data stored on this device. Make sure you don\'t need them from this server anymore.'**
  String get changeServerWarningBody;

  /// No description provided for @changeServerConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Erase and switch'**
  String get changeServerConfirmButton;

  /// No description provided for @unlockGreeting.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}'**
  String unlockGreeting(String name);

  /// No description provided for @unlockIncorrectPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password'**
  String get unlockIncorrectPassword;

  /// No description provided for @unlockButton.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlockButton;

  /// No description provided for @cardsListTitle.
  ///
  /// In en, this message translates to:
  /// **'My cards'**
  String get cardsListTitle;

  /// No description provided for @cardsListEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No cards yet'**
  String get cardsListEmptyTitle;

  /// No description provided for @cardsListEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first loyalty card to get started.'**
  String get cardsListEmptySubtitle;

  /// No description provided for @cardsListSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search cards'**
  String get cardsListSearchHint;

  /// No description provided for @cardsListFavoritesSection.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get cardsListFavoritesSection;

  /// No description provided for @cardsListAddCard.
  ///
  /// In en, this message translates to:
  /// **'Add card'**
  String get cardsListAddCard;

  /// No description provided for @cardEditorTitleNew.
  ///
  /// In en, this message translates to:
  /// **'Add card'**
  String get cardEditorTitleNew;

  /// No description provided for @cardEditorTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit card'**
  String get cardEditorTitleEdit;

  /// No description provided for @storeNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Store name'**
  String get storeNameLabel;

  /// No description provided for @cardNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Card number'**
  String get cardNumberLabel;

  /// No description provided for @secondaryNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Secondary number (optional)'**
  String get secondaryNumberLabel;

  /// No description provided for @barcodeFormatLabel.
  ///
  /// In en, this message translates to:
  /// **'Barcode format'**
  String get barcodeFormatLabel;

  /// No description provided for @noteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get noteLabel;

  /// No description provided for @colorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get colorLabel;

  /// No description provided for @customFieldsSection.
  ///
  /// In en, this message translates to:
  /// **'Custom fields'**
  String get customFieldsSection;

  /// No description provided for @addCustomField.
  ///
  /// In en, this message translates to:
  /// **'Add field'**
  String get addCustomField;

  /// No description provided for @customFieldKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Field name'**
  String get customFieldKeyLabel;

  /// No description provided for @customFieldValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get customFieldValueLabel;

  /// No description provided for @scanBarcodeButton.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scanBarcodeButton;

  /// No description provided for @cardEditorValidationRequired.
  ///
  /// In en, this message translates to:
  /// **'Store name and card number are required'**
  String get cardEditorValidationRequired;

  /// No description provided for @discardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChangesTitle;

  /// No description provided for @discardChangesBody.
  ///
  /// In en, this message translates to:
  /// **'Your edits will be lost.'**
  String get discardChangesBody;

  /// No description provided for @discardChangesConfirm.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardChangesConfirm;

  /// No description provided for @photoFrontLabel.
  ///
  /// In en, this message translates to:
  /// **'Front photo'**
  String get photoFrontLabel;

  /// No description provided for @photoBackLabel.
  ///
  /// In en, this message translates to:
  /// **'Back photo'**
  String get photoBackLabel;

  /// No description provided for @photoAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get photoAddButton;

  /// No description provided for @photoRemoveButton.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get photoRemoveButton;

  /// No description provided for @photoSourceCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get photoSourceCamera;

  /// No description provided for @photoSourceGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get photoSourceGallery;

  /// No description provided for @scannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get scannerTitle;

  /// No description provided for @scannerPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera access is needed to scan barcodes.'**
  String get scannerPermissionDenied;

  /// No description provided for @scannerOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get scannerOpenSettings;

  /// No description provided for @cardDetailCopyNumber.
  ///
  /// In en, this message translates to:
  /// **'Copy number'**
  String get cardDetailCopyNumber;

  /// No description provided for @cardDetailNumberCopied.
  ///
  /// In en, this message translates to:
  /// **'Number copied'**
  String get cardDetailNumberCopied;

  /// No description provided for @cardDetailDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to trash?'**
  String get cardDetailDeleteConfirmTitle;

  /// No description provided for @cardDetailDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You can restore this card from the trash within 30 days.'**
  String get cardDetailDeleteConfirmBody;

  /// No description provided for @syncStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get syncStatusIdle;

  /// No description provided for @syncStatusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncStatusSyncing;

  /// No description provided for @syncStatusPendingChanges.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 change pending} other {{count} changes pending}}'**
  String syncStatusPendingChanges(int count);

  /// No description provided for @syncStatusError.
  ///
  /// In en, this message translates to:
  /// **'Sync failed, will retry'**
  String get syncStatusError;

  /// No description provided for @syncConflictLostEdit.
  ///
  /// In en, this message translates to:
  /// **'Your change to \"{cardName}\" was overwritten by a newer edit from another device'**
  String syncConflictLostEdit(String cardName);

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsMembersTile.
  ///
  /// In en, this message translates to:
  /// **'Family members'**
  String get settingsMembersTile;

  /// No description provided for @settingsSecurityTile.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurityTile;

  /// No description provided for @settingsTrashTile.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get settingsTrashTile;

  /// No description provided for @settingsExportTile.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get settingsExportTile;

  /// No description provided for @settingsServerTile.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get settingsServerTile;

  /// No description provided for @settingsLogoutTile.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogoutTile;

  /// No description provided for @membersTitle.
  ///
  /// In en, this message translates to:
  /// **'Family members'**
  String get membersTitle;

  /// No description provided for @membersNoNetwork.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet to see the member list.'**
  String get membersNoNetwork;

  /// No description provided for @membersRevokeButton.
  ///
  /// In en, this message translates to:
  /// **'Revoke access'**
  String get membersRevokeButton;

  /// No description provided for @membersRevokeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke access?'**
  String get membersRevokeConfirmTitle;

  /// No description provided for @membersRevokeConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will lose access to the family vault on all of their devices.'**
  String membersRevokeConfirmBody(String name);

  /// No description provided for @membersRevokedLabel.
  ///
  /// In en, this message translates to:
  /// **'revoked'**
  String get membersRevokedLabel;

  /// No description provided for @membersDeviceCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {No devices} one {1 device} other {{count} devices}}'**
  String membersDeviceCount(int count);

  /// No description provided for @inviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite a member'**
  String get inviteTitle;

  /// No description provided for @inviteGenerateButton.
  ///
  /// In en, this message translates to:
  /// **'Generate invite code'**
  String get inviteGenerateButton;

  /// No description provided for @inviteExpiresAt.
  ///
  /// In en, this message translates to:
  /// **'Expires: {date}'**
  String inviteExpiresAt(String date);

  /// No description provided for @inviteShareButton.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get inviteShareButton;

  /// No description provided for @inviteCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel invite'**
  String get inviteCancelButton;

  /// No description provided for @inviteCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'This invite code will no longer work.'**
  String get inviteCancelConfirm;

  /// No description provided for @inviteCancelledMessage.
  ///
  /// In en, this message translates to:
  /// **'This invite has been cancelled.'**
  String get inviteCancelledMessage;

  /// No description provided for @inviteLimitReached.
  ///
  /// In en, this message translates to:
  /// **'The family vault is full - remove a member or wait for a pending invite to expire.'**
  String get inviteLimitReached;

  /// No description provided for @securityBiometricTitle.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securityBiometricTitle;

  /// No description provided for @securityBiometricToggle.
  ///
  /// In en, this message translates to:
  /// **'Unlock with biometrics'**
  String get securityBiometricToggle;

  /// No description provided for @securityBiometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock is not available on this device.'**
  String get securityBiometricUnavailable;

  /// No description provided for @securityBiometricConfirmReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm to enable biometric unlock'**
  String get securityBiometricConfirmReason;

  /// No description provided for @securityAutoLockNotice.
  ///
  /// In en, this message translates to:
  /// **'The app always locks itself automatically after 5 minutes in the background.'**
  String get securityAutoLockNotice;

  /// No description provided for @unlockBiometricButton.
  ///
  /// In en, this message translates to:
  /// **'Unlock with biometrics'**
  String get unlockBiometricButton;

  /// No description provided for @trashTitle.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get trashTitle;

  /// No description provided for @trashEmpty.
  ///
  /// In en, this message translates to:
  /// **'Trash is empty.'**
  String get trashEmpty;

  /// No description provided for @trashRestoreButton.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get trashRestoreButton;

  /// No description provided for @trashDeleteForeverButton.
  ///
  /// In en, this message translates to:
  /// **'Delete forever'**
  String get trashDeleteForeverButton;

  /// No description provided for @trashDeleteForeverConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete forever?'**
  String get trashDeleteForeverConfirmTitle;

  /// No description provided for @trashDeleteForeverConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This card cannot be recovered after this.'**
  String get trashDeleteForeverConfirmBody;

  /// No description provided for @trashDaysRemaining.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0 {Removed today} one {1 day left} other {{days} days left}}'**
  String trashDaysRemaining(int days);

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get exportTitle;

  /// No description provided for @exportPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Archive password'**
  String get exportPasswordLabel;

  /// No description provided for @exportPasswordConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get exportPasswordConfirmLabel;

  /// No description provided for @exportWarning.
  ///
  /// In en, this message translates to:
  /// **'The archive will contain every card number in this vault. Keep the file and its password safe.'**
  String get exportWarning;

  /// No description provided for @exportButton.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportButton;

  /// No description provided for @exportPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get exportPasswordMismatch;

  /// No description provided for @exportSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Export complete'**
  String get exportSuccessTitle;

  /// No description provided for @exportSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String exportSuccessBody(String path);

  /// No description provided for @exportShareButton.
  ///
  /// In en, this message translates to:
  /// **'Share file'**
  String get exportShareButton;

  /// No description provided for @serverSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverSettingsTitle;

  /// No description provided for @serverSettingsAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverSettingsAddressLabel;

  /// No description provided for @serverSettingsReachable.
  ///
  /// In en, this message translates to:
  /// **'Reachable'**
  String get serverSettingsReachable;

  /// No description provided for @serverSettingsUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Unreachable'**
  String get serverSettingsUnreachable;

  /// No description provided for @serverSettingsLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last successful sync'**
  String get serverSettingsLastSync;

  /// No description provided for @serverSettingsPendingCount.
  ///
  /// In en, this message translates to:
  /// **'Unsynced changes'**
  String get serverSettingsPendingCount;

  /// No description provided for @serverSettingsForceSyncButton.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get serverSettingsForceSyncButton;

  /// No description provided for @serverSettingsChangeAddressButton.
  ///
  /// In en, this message translates to:
  /// **'Change server'**
  String get serverSettingsChangeAddressButton;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmBodyUnsynced.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 change has} other {{count} changes have}} not been sent to the server yet and will be lost.'**
  String logoutConfirmBodyUnsynced(int count);

  /// No description provided for @logoutConfirmBodyClean.
  ///
  /// In en, this message translates to:
  /// **'You can log back in at any time.'**
  String get logoutConfirmBodyClean;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
