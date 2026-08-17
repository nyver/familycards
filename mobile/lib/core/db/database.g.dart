// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CardsTable extends Cards with TableInfo<$CardsTable, Card> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeNameMeta = const VerificationMeta(
    'storeName',
  );
  @override
  late final GeneratedColumn<String> storeName = GeneratedColumn<String>(
    'store_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cardNumberMeta = const VerificationMeta(
    'cardNumber',
  );
  @override
  late final GeneratedColumn<String> cardNumber = GeneratedColumn<String>(
    'card_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _barcodeFormatMeta = const VerificationMeta(
    'barcodeFormat',
  );
  @override
  late final GeneratedColumn<String> barcodeFormat = GeneratedColumn<String>(
    'barcode_format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _secondaryNumberMeta = const VerificationMeta(
    'secondaryNumber',
  );
  @override
  late final GeneratedColumn<String> secondaryNumber = GeneratedColumn<String>(
    'secondary_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _logoAssetMeta = const VerificationMeta(
    'logoAsset',
  );
  @override
  late final GeneratedColumn<String> logoAsset = GeneratedColumn<String>(
    'logo_asset',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _frontBlobIdMeta = const VerificationMeta(
    'frontBlobId',
  );
  @override
  late final GeneratedColumn<String> frontBlobId = GeneratedColumn<String>(
    'front_blob_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backBlobIdMeta = const VerificationMeta(
    'backBlobId',
  );
  @override
  late final GeneratedColumn<String> backBlobId = GeneratedColumn<String>(
    'back_blob_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customFieldsMeta = const VerificationMeta(
    'customFields',
  );
  @override
  late final GeneratedColumn<String> customFields = GeneratedColumn<String>(
    'custom_fields',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _favoriteMeta = const VerificationMeta(
    'favorite',
  );
  @override
  late final GeneratedColumn<bool> favorite = GeneratedColumn<bool>(
    'favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseRevMeta = const VerificationMeta(
    'baseRev',
  );
  @override
  late final GeneratedColumn<int> baseRev = GeneratedColumn<int>(
    'base_rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    storeName,
    cardNumber,
    barcodeFormat,
    secondaryNumber,
    note,
    color,
    logoAsset,
    frontBlobId,
    backBlobId,
    customFields,
    favorite,
    sortOrder,
    createdAt,
    updatedAt,
    deleted,
    deletedAt,
    baseRev,
    dirty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<Card> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('store_name')) {
      context.handle(
        _storeNameMeta,
        storeName.isAcceptableOrUnknown(data['store_name']!, _storeNameMeta),
      );
    } else if (isInserting) {
      context.missing(_storeNameMeta);
    }
    if (data.containsKey('card_number')) {
      context.handle(
        _cardNumberMeta,
        cardNumber.isAcceptableOrUnknown(data['card_number']!, _cardNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_cardNumberMeta);
    }
    if (data.containsKey('barcode_format')) {
      context.handle(
        _barcodeFormatMeta,
        barcodeFormat.isAcceptableOrUnknown(
          data['barcode_format']!,
          _barcodeFormatMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_barcodeFormatMeta);
    }
    if (data.containsKey('secondary_number')) {
      context.handle(
        _secondaryNumberMeta,
        secondaryNumber.isAcceptableOrUnknown(
          data['secondary_number']!,
          _secondaryNumberMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('logo_asset')) {
      context.handle(
        _logoAssetMeta,
        logoAsset.isAcceptableOrUnknown(data['logo_asset']!, _logoAssetMeta),
      );
    }
    if (data.containsKey('front_blob_id')) {
      context.handle(
        _frontBlobIdMeta,
        frontBlobId.isAcceptableOrUnknown(
          data['front_blob_id']!,
          _frontBlobIdMeta,
        ),
      );
    }
    if (data.containsKey('back_blob_id')) {
      context.handle(
        _backBlobIdMeta,
        backBlobId.isAcceptableOrUnknown(
          data['back_blob_id']!,
          _backBlobIdMeta,
        ),
      );
    }
    if (data.containsKey('custom_fields')) {
      context.handle(
        _customFieldsMeta,
        customFields.isAcceptableOrUnknown(
          data['custom_fields']!,
          _customFieldsMeta,
        ),
      );
    }
    if (data.containsKey('favorite')) {
      context.handle(
        _favoriteMeta,
        favorite.isAcceptableOrUnknown(data['favorite']!, _favoriteMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('base_rev')) {
      context.handle(
        _baseRevMeta,
        baseRev.isAcceptableOrUnknown(data['base_rev']!, _baseRevMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Card map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Card(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      storeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_name'],
      )!,
      cardNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_number'],
      )!,
      barcodeFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode_format'],
      )!,
      secondaryNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secondary_number'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      logoAsset: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logo_asset'],
      ),
      frontBlobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}front_blob_id'],
      ),
      backBlobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}back_blob_id'],
      ),
      customFields: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_fields'],
      )!,
      favorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}favorite'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      baseRev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_rev'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
    );
  }

  @override
  $CardsTable createAlias(String alias) {
    return $CardsTable(attachedDatabase, alias);
  }
}

class Card extends DataClass implements Insertable<Card> {
  final String id;
  final String storeName;
  final String cardNumber;
  final String barcodeFormat;
  final String? secondaryNumber;
  final String note;
  final int color;
  final String? logoAsset;
  final String? frontBlobId;
  final String? backBlobId;
  final String customFields;
  final bool favorite;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
  final bool deleted;
  final int? deletedAt;
  final int baseRev;
  final bool dirty;
  const Card({
    required this.id,
    required this.storeName,
    required this.cardNumber,
    required this.barcodeFormat,
    this.secondaryNumber,
    required this.note,
    required this.color,
    this.logoAsset,
    this.frontBlobId,
    this.backBlobId,
    required this.customFields,
    required this.favorite,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
    this.deletedAt,
    required this.baseRev,
    required this.dirty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['store_name'] = Variable<String>(storeName);
    map['card_number'] = Variable<String>(cardNumber);
    map['barcode_format'] = Variable<String>(barcodeFormat);
    if (!nullToAbsent || secondaryNumber != null) {
      map['secondary_number'] = Variable<String>(secondaryNumber);
    }
    map['note'] = Variable<String>(note);
    map['color'] = Variable<int>(color);
    if (!nullToAbsent || logoAsset != null) {
      map['logo_asset'] = Variable<String>(logoAsset);
    }
    if (!nullToAbsent || frontBlobId != null) {
      map['front_blob_id'] = Variable<String>(frontBlobId);
    }
    if (!nullToAbsent || backBlobId != null) {
      map['back_blob_id'] = Variable<String>(backBlobId);
    }
    map['custom_fields'] = Variable<String>(customFields);
    map['favorite'] = Variable<bool>(favorite);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['base_rev'] = Variable<int>(baseRev);
    map['dirty'] = Variable<bool>(dirty);
    return map;
  }

  CardsCompanion toCompanion(bool nullToAbsent) {
    return CardsCompanion(
      id: Value(id),
      storeName: Value(storeName),
      cardNumber: Value(cardNumber),
      barcodeFormat: Value(barcodeFormat),
      secondaryNumber: secondaryNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(secondaryNumber),
      note: Value(note),
      color: Value(color),
      logoAsset: logoAsset == null && nullToAbsent
          ? const Value.absent()
          : Value(logoAsset),
      frontBlobId: frontBlobId == null && nullToAbsent
          ? const Value.absent()
          : Value(frontBlobId),
      backBlobId: backBlobId == null && nullToAbsent
          ? const Value.absent()
          : Value(backBlobId),
      customFields: Value(customFields),
      favorite: Value(favorite),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      baseRev: Value(baseRev),
      dirty: Value(dirty),
    );
  }

  factory Card.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Card(
      id: serializer.fromJson<String>(json['id']),
      storeName: serializer.fromJson<String>(json['storeName']),
      cardNumber: serializer.fromJson<String>(json['cardNumber']),
      barcodeFormat: serializer.fromJson<String>(json['barcodeFormat']),
      secondaryNumber: serializer.fromJson<String?>(json['secondaryNumber']),
      note: serializer.fromJson<String>(json['note']),
      color: serializer.fromJson<int>(json['color']),
      logoAsset: serializer.fromJson<String?>(json['logoAsset']),
      frontBlobId: serializer.fromJson<String?>(json['frontBlobId']),
      backBlobId: serializer.fromJson<String?>(json['backBlobId']),
      customFields: serializer.fromJson<String>(json['customFields']),
      favorite: serializer.fromJson<bool>(json['favorite']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      baseRev: serializer.fromJson<int>(json['baseRev']),
      dirty: serializer.fromJson<bool>(json['dirty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'storeName': serializer.toJson<String>(storeName),
      'cardNumber': serializer.toJson<String>(cardNumber),
      'barcodeFormat': serializer.toJson<String>(barcodeFormat),
      'secondaryNumber': serializer.toJson<String?>(secondaryNumber),
      'note': serializer.toJson<String>(note),
      'color': serializer.toJson<int>(color),
      'logoAsset': serializer.toJson<String?>(logoAsset),
      'frontBlobId': serializer.toJson<String?>(frontBlobId),
      'backBlobId': serializer.toJson<String?>(backBlobId),
      'customFields': serializer.toJson<String>(customFields),
      'favorite': serializer.toJson<bool>(favorite),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'baseRev': serializer.toJson<int>(baseRev),
      'dirty': serializer.toJson<bool>(dirty),
    };
  }

  Card copyWith({
    String? id,
    String? storeName,
    String? cardNumber,
    String? barcodeFormat,
    Value<String?> secondaryNumber = const Value.absent(),
    String? note,
    int? color,
    Value<String?> logoAsset = const Value.absent(),
    Value<String?> frontBlobId = const Value.absent(),
    Value<String?> backBlobId = const Value.absent(),
    String? customFields,
    bool? favorite,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
    bool? deleted,
    Value<int?> deletedAt = const Value.absent(),
    int? baseRev,
    bool? dirty,
  }) => Card(
    id: id ?? this.id,
    storeName: storeName ?? this.storeName,
    cardNumber: cardNumber ?? this.cardNumber,
    barcodeFormat: barcodeFormat ?? this.barcodeFormat,
    secondaryNumber: secondaryNumber.present
        ? secondaryNumber.value
        : this.secondaryNumber,
    note: note ?? this.note,
    color: color ?? this.color,
    logoAsset: logoAsset.present ? logoAsset.value : this.logoAsset,
    frontBlobId: frontBlobId.present ? frontBlobId.value : this.frontBlobId,
    backBlobId: backBlobId.present ? backBlobId.value : this.backBlobId,
    customFields: customFields ?? this.customFields,
    favorite: favorite ?? this.favorite,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    baseRev: baseRev ?? this.baseRev,
    dirty: dirty ?? this.dirty,
  );
  Card copyWithCompanion(CardsCompanion data) {
    return Card(
      id: data.id.present ? data.id.value : this.id,
      storeName: data.storeName.present ? data.storeName.value : this.storeName,
      cardNumber: data.cardNumber.present
          ? data.cardNumber.value
          : this.cardNumber,
      barcodeFormat: data.barcodeFormat.present
          ? data.barcodeFormat.value
          : this.barcodeFormat,
      secondaryNumber: data.secondaryNumber.present
          ? data.secondaryNumber.value
          : this.secondaryNumber,
      note: data.note.present ? data.note.value : this.note,
      color: data.color.present ? data.color.value : this.color,
      logoAsset: data.logoAsset.present ? data.logoAsset.value : this.logoAsset,
      frontBlobId: data.frontBlobId.present
          ? data.frontBlobId.value
          : this.frontBlobId,
      backBlobId: data.backBlobId.present
          ? data.backBlobId.value
          : this.backBlobId,
      customFields: data.customFields.present
          ? data.customFields.value
          : this.customFields,
      favorite: data.favorite.present ? data.favorite.value : this.favorite,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      baseRev: data.baseRev.present ? data.baseRev.value : this.baseRev,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Card(')
          ..write('id: $id, ')
          ..write('storeName: $storeName, ')
          ..write('cardNumber: $cardNumber, ')
          ..write('barcodeFormat: $barcodeFormat, ')
          ..write('secondaryNumber: $secondaryNumber, ')
          ..write('note: $note, ')
          ..write('color: $color, ')
          ..write('logoAsset: $logoAsset, ')
          ..write('frontBlobId: $frontBlobId, ')
          ..write('backBlobId: $backBlobId, ')
          ..write('customFields: $customFields, ')
          ..write('favorite: $favorite, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('baseRev: $baseRev, ')
          ..write('dirty: $dirty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    storeName,
    cardNumber,
    barcodeFormat,
    secondaryNumber,
    note,
    color,
    logoAsset,
    frontBlobId,
    backBlobId,
    customFields,
    favorite,
    sortOrder,
    createdAt,
    updatedAt,
    deleted,
    deletedAt,
    baseRev,
    dirty,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Card &&
          other.id == this.id &&
          other.storeName == this.storeName &&
          other.cardNumber == this.cardNumber &&
          other.barcodeFormat == this.barcodeFormat &&
          other.secondaryNumber == this.secondaryNumber &&
          other.note == this.note &&
          other.color == this.color &&
          other.logoAsset == this.logoAsset &&
          other.frontBlobId == this.frontBlobId &&
          other.backBlobId == this.backBlobId &&
          other.customFields == this.customFields &&
          other.favorite == this.favorite &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.deletedAt == this.deletedAt &&
          other.baseRev == this.baseRev &&
          other.dirty == this.dirty);
}

class CardsCompanion extends UpdateCompanion<Card> {
  final Value<String> id;
  final Value<String> storeName;
  final Value<String> cardNumber;
  final Value<String> barcodeFormat;
  final Value<String?> secondaryNumber;
  final Value<String> note;
  final Value<int> color;
  final Value<String?> logoAsset;
  final Value<String?> frontBlobId;
  final Value<String?> backBlobId;
  final Value<String> customFields;
  final Value<bool> favorite;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<bool> deleted;
  final Value<int?> deletedAt;
  final Value<int> baseRev;
  final Value<bool> dirty;
  final Value<int> rowid;
  const CardsCompanion({
    this.id = const Value.absent(),
    this.storeName = const Value.absent(),
    this.cardNumber = const Value.absent(),
    this.barcodeFormat = const Value.absent(),
    this.secondaryNumber = const Value.absent(),
    this.note = const Value.absent(),
    this.color = const Value.absent(),
    this.logoAsset = const Value.absent(),
    this.frontBlobId = const Value.absent(),
    this.backBlobId = const Value.absent(),
    this.customFields = const Value.absent(),
    this.favorite = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.baseRev = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardsCompanion.insert({
    required String id,
    required String storeName,
    required String cardNumber,
    required String barcodeFormat,
    this.secondaryNumber = const Value.absent(),
    this.note = const Value.absent(),
    required int color,
    this.logoAsset = const Value.absent(),
    this.frontBlobId = const Value.absent(),
    this.backBlobId = const Value.absent(),
    this.customFields = const Value.absent(),
    this.favorite = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.baseRev = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       storeName = Value(storeName),
       cardNumber = Value(cardNumber),
       barcodeFormat = Value(barcodeFormat),
       color = Value(color),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Card> custom({
    Expression<String>? id,
    Expression<String>? storeName,
    Expression<String>? cardNumber,
    Expression<String>? barcodeFormat,
    Expression<String>? secondaryNumber,
    Expression<String>? note,
    Expression<int>? color,
    Expression<String>? logoAsset,
    Expression<String>? frontBlobId,
    Expression<String>? backBlobId,
    Expression<String>? customFields,
    Expression<bool>? favorite,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<int>? deletedAt,
    Expression<int>? baseRev,
    Expression<bool>? dirty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storeName != null) 'store_name': storeName,
      if (cardNumber != null) 'card_number': cardNumber,
      if (barcodeFormat != null) 'barcode_format': barcodeFormat,
      if (secondaryNumber != null) 'secondary_number': secondaryNumber,
      if (note != null) 'note': note,
      if (color != null) 'color': color,
      if (logoAsset != null) 'logo_asset': logoAsset,
      if (frontBlobId != null) 'front_blob_id': frontBlobId,
      if (backBlobId != null) 'back_blob_id': backBlobId,
      if (customFields != null) 'custom_fields': customFields,
      if (favorite != null) 'favorite': favorite,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (baseRev != null) 'base_rev': baseRev,
      if (dirty != null) 'dirty': dirty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardsCompanion copyWith({
    Value<String>? id,
    Value<String>? storeName,
    Value<String>? cardNumber,
    Value<String>? barcodeFormat,
    Value<String?>? secondaryNumber,
    Value<String>? note,
    Value<int>? color,
    Value<String?>? logoAsset,
    Value<String?>? frontBlobId,
    Value<String?>? backBlobId,
    Value<String>? customFields,
    Value<bool>? favorite,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<bool>? deleted,
    Value<int?>? deletedAt,
    Value<int>? baseRev,
    Value<bool>? dirty,
    Value<int>? rowid,
  }) {
    return CardsCompanion(
      id: id ?? this.id,
      storeName: storeName ?? this.storeName,
      cardNumber: cardNumber ?? this.cardNumber,
      barcodeFormat: barcodeFormat ?? this.barcodeFormat,
      secondaryNumber: secondaryNumber ?? this.secondaryNumber,
      note: note ?? this.note,
      color: color ?? this.color,
      logoAsset: logoAsset ?? this.logoAsset,
      frontBlobId: frontBlobId ?? this.frontBlobId,
      backBlobId: backBlobId ?? this.backBlobId,
      customFields: customFields ?? this.customFields,
      favorite: favorite ?? this.favorite,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
      baseRev: baseRev ?? this.baseRev,
      dirty: dirty ?? this.dirty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (storeName.present) {
      map['store_name'] = Variable<String>(storeName.value);
    }
    if (cardNumber.present) {
      map['card_number'] = Variable<String>(cardNumber.value);
    }
    if (barcodeFormat.present) {
      map['barcode_format'] = Variable<String>(barcodeFormat.value);
    }
    if (secondaryNumber.present) {
      map['secondary_number'] = Variable<String>(secondaryNumber.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (logoAsset.present) {
      map['logo_asset'] = Variable<String>(logoAsset.value);
    }
    if (frontBlobId.present) {
      map['front_blob_id'] = Variable<String>(frontBlobId.value);
    }
    if (backBlobId.present) {
      map['back_blob_id'] = Variable<String>(backBlobId.value);
    }
    if (customFields.present) {
      map['custom_fields'] = Variable<String>(customFields.value);
    }
    if (favorite.present) {
      map['favorite'] = Variable<bool>(favorite.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (baseRev.present) {
      map['base_rev'] = Variable<int>(baseRev.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardsCompanion(')
          ..write('id: $id, ')
          ..write('storeName: $storeName, ')
          ..write('cardNumber: $cardNumber, ')
          ..write('barcodeFormat: $barcodeFormat, ')
          ..write('secondaryNumber: $secondaryNumber, ')
          ..write('note: $note, ')
          ..write('color: $color, ')
          ..write('logoAsset: $logoAsset, ')
          ..write('frontBlobId: $frontBlobId, ')
          ..write('backBlobId: $backBlobId, ')
          ..write('customFields: $customFields, ')
          ..write('favorite: $favorite, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('baseRev: $baseRev, ')
          ..write('dirty: $dirty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lastServerRevMeta = const VerificationMeta(
    'lastServerRev',
  );
  @override
  late final GeneratedColumn<int> lastServerRev = GeneratedColumn<int>(
    'last_server_rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta(
    'lastSyncAt',
  );
  @override
  late final GeneratedColumn<int> lastSyncAt = GeneratedColumn<int>(
    'last_sync_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, lastServerRev, lastSyncAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('last_server_rev')) {
      context.handle(
        _lastServerRevMeta,
        lastServerRev.isAcceptableOrUnknown(
          data['last_server_rev']!,
          _lastServerRevMeta,
        ),
      );
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
        _lastSyncAtMeta,
        lastSyncAt.isAcceptableOrUnknown(
          data['last_sync_at']!,
          _lastSyncAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lastServerRev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_server_rev'],
      )!,
      lastSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_sync_at'],
      )!,
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateData extends DataClass implements Insertable<SyncStateData> {
  final int id;
  final int lastServerRev;
  final int lastSyncAt;
  const SyncStateData({
    required this.id,
    required this.lastServerRev,
    required this.lastSyncAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['last_server_rev'] = Variable<int>(lastServerRev);
    map['last_sync_at'] = Variable<int>(lastSyncAt);
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      id: Value(id),
      lastServerRev: Value(lastServerRev),
      lastSyncAt: Value(lastSyncAt),
    );
  }

  factory SyncStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateData(
      id: serializer.fromJson<int>(json['id']),
      lastServerRev: serializer.fromJson<int>(json['lastServerRev']),
      lastSyncAt: serializer.fromJson<int>(json['lastSyncAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lastServerRev': serializer.toJson<int>(lastServerRev),
      'lastSyncAt': serializer.toJson<int>(lastSyncAt),
    };
  }

  SyncStateData copyWith({int? id, int? lastServerRev, int? lastSyncAt}) =>
      SyncStateData(
        id: id ?? this.id,
        lastServerRev: lastServerRev ?? this.lastServerRev,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      );
  SyncStateData copyWithCompanion(SyncStateCompanion data) {
    return SyncStateData(
      id: data.id.present ? data.id.value : this.id,
      lastServerRev: data.lastServerRev.present
          ? data.lastServerRev.value
          : this.lastServerRev,
      lastSyncAt: data.lastSyncAt.present
          ? data.lastSyncAt.value
          : this.lastSyncAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateData(')
          ..write('id: $id, ')
          ..write('lastServerRev: $lastServerRev, ')
          ..write('lastSyncAt: $lastSyncAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, lastServerRev, lastSyncAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateData &&
          other.id == this.id &&
          other.lastServerRev == this.lastServerRev &&
          other.lastSyncAt == this.lastSyncAt);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateData> {
  final Value<int> id;
  final Value<int> lastServerRev;
  final Value<int> lastSyncAt;
  const SyncStateCompanion({
    this.id = const Value.absent(),
    this.lastServerRev = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
  });
  SyncStateCompanion.insert({
    this.id = const Value.absent(),
    this.lastServerRev = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
  });
  static Insertable<SyncStateData> custom({
    Expression<int>? id,
    Expression<int>? lastServerRev,
    Expression<int>? lastSyncAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lastServerRev != null) 'last_server_rev': lastServerRev,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
    });
  }

  SyncStateCompanion copyWith({
    Value<int>? id,
    Value<int>? lastServerRev,
    Value<int>? lastSyncAt,
  }) {
    return SyncStateCompanion(
      id: id ?? this.id,
      lastServerRev: lastServerRev ?? this.lastServerRev,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lastServerRev.present) {
      map['last_server_rev'] = Variable<int>(lastServerRev.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<int>(lastSyncAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('id: $id, ')
          ..write('lastServerRev: $lastServerRev, ')
          ..write('lastSyncAt: $lastSyncAt')
          ..write(')'))
        .toString();
  }
}

class $LocalBlobsTable extends LocalBlobs
    with TableInfo<$LocalBlobsTable, LocalBlob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalBlobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _blobIdMeta = const VerificationMeta('blobId');
  @override
  late final GeneratedColumn<String> blobId = GeneratedColumn<String>(
    'blob_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uploadedMeta = const VerificationMeta(
    'uploaded',
  );
  @override
  late final GeneratedColumn<bool> uploaded = GeneratedColumn<bool>(
    'uploaded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("uploaded" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    blobId,
    path,
    size,
    uploaded,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_blobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalBlob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('blob_id')) {
      context.handle(
        _blobIdMeta,
        blobId.isAcceptableOrUnknown(data['blob_id']!, _blobIdMeta),
      );
    } else if (isInserting) {
      context.missing(_blobIdMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('uploaded')) {
      context.handle(
        _uploadedMeta,
        uploaded.isAcceptableOrUnknown(data['uploaded']!, _uploadedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {blobId};
  @override
  LocalBlob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalBlob(
      blobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blob_id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      uploaded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}uploaded'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalBlobsTable createAlias(String alias) {
    return $LocalBlobsTable(attachedDatabase, alias);
  }
}

class LocalBlob extends DataClass implements Insertable<LocalBlob> {
  final String blobId;
  final String path;
  final int size;
  final bool uploaded;
  final int createdAt;
  const LocalBlob({
    required this.blobId,
    required this.path,
    required this.size,
    required this.uploaded,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['blob_id'] = Variable<String>(blobId);
    map['path'] = Variable<String>(path);
    map['size'] = Variable<int>(size);
    map['uploaded'] = Variable<bool>(uploaded);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  LocalBlobsCompanion toCompanion(bool nullToAbsent) {
    return LocalBlobsCompanion(
      blobId: Value(blobId),
      path: Value(path),
      size: Value(size),
      uploaded: Value(uploaded),
      createdAt: Value(createdAt),
    );
  }

  factory LocalBlob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalBlob(
      blobId: serializer.fromJson<String>(json['blobId']),
      path: serializer.fromJson<String>(json['path']),
      size: serializer.fromJson<int>(json['size']),
      uploaded: serializer.fromJson<bool>(json['uploaded']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'blobId': serializer.toJson<String>(blobId),
      'path': serializer.toJson<String>(path),
      'size': serializer.toJson<int>(size),
      'uploaded': serializer.toJson<bool>(uploaded),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  LocalBlob copyWith({
    String? blobId,
    String? path,
    int? size,
    bool? uploaded,
    int? createdAt,
  }) => LocalBlob(
    blobId: blobId ?? this.blobId,
    path: path ?? this.path,
    size: size ?? this.size,
    uploaded: uploaded ?? this.uploaded,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalBlob copyWithCompanion(LocalBlobsCompanion data) {
    return LocalBlob(
      blobId: data.blobId.present ? data.blobId.value : this.blobId,
      path: data.path.present ? data.path.value : this.path,
      size: data.size.present ? data.size.value : this.size,
      uploaded: data.uploaded.present ? data.uploaded.value : this.uploaded,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalBlob(')
          ..write('blobId: $blobId, ')
          ..write('path: $path, ')
          ..write('size: $size, ')
          ..write('uploaded: $uploaded, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(blobId, path, size, uploaded, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalBlob &&
          other.blobId == this.blobId &&
          other.path == this.path &&
          other.size == this.size &&
          other.uploaded == this.uploaded &&
          other.createdAt == this.createdAt);
}

class LocalBlobsCompanion extends UpdateCompanion<LocalBlob> {
  final Value<String> blobId;
  final Value<String> path;
  final Value<int> size;
  final Value<bool> uploaded;
  final Value<int> createdAt;
  final Value<int> rowid;
  const LocalBlobsCompanion({
    this.blobId = const Value.absent(),
    this.path = const Value.absent(),
    this.size = const Value.absent(),
    this.uploaded = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalBlobsCompanion.insert({
    required String blobId,
    required String path,
    required int size,
    this.uploaded = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : blobId = Value(blobId),
       path = Value(path),
       size = Value(size),
       createdAt = Value(createdAt);
  static Insertable<LocalBlob> custom({
    Expression<String>? blobId,
    Expression<String>? path,
    Expression<int>? size,
    Expression<bool>? uploaded,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (blobId != null) 'blob_id': blobId,
      if (path != null) 'path': path,
      if (size != null) 'size': size,
      if (uploaded != null) 'uploaded': uploaded,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalBlobsCompanion copyWith({
    Value<String>? blobId,
    Value<String>? path,
    Value<int>? size,
    Value<bool>? uploaded,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalBlobsCompanion(
      blobId: blobId ?? this.blobId,
      path: path ?? this.path,
      size: size ?? this.size,
      uploaded: uploaded ?? this.uploaded,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (blobId.present) {
      map['blob_id'] = Variable<String>(blobId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (uploaded.present) {
      map['uploaded'] = Variable<bool>(uploaded.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalBlobsCompanion(')
          ..write('blobId: $blobId, ')
          ..write('path: $path, ')
          ..write('size: $size, ')
          ..write('uploaded: $uploaded, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CardsTable cards = $CardsTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final $LocalBlobsTable localBlobs = $LocalBlobsTable(this);
  late final CardsDao cardsDao = CardsDao(this as AppDatabase);
  late final SyncStateDao syncStateDao = SyncStateDao(this as AppDatabase);
  late final LocalBlobsDao localBlobsDao = LocalBlobsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cards,
    syncState,
    localBlobs,
  ];
}

typedef $$CardsTableCreateCompanionBuilder = CardsCompanion Function({
  required String id,
  required String storeName,
  required String cardNumber,
  required String barcodeFormat,
  Value<String?> secondaryNumber,
  Value<String> note,
  required int color,
  Value<String?> logoAsset,
  Value<String?> frontBlobId,
  Value<String?> backBlobId,
  Value<String> customFields,
  Value<bool> favorite,
  Value<int> sortOrder,
  required int createdAt,
  required int updatedAt,
  Value<bool> deleted,
  Value<int?> deletedAt,
  Value<int> baseRev,
  Value<bool> dirty,
  Value<int> rowid,
});
typedef $$CardsTableUpdateCompanionBuilder = CardsCompanion Function({
  Value<String> id,
  Value<String> storeName,
  Value<String> cardNumber,
  Value<String> barcodeFormat,
  Value<String?> secondaryNumber,
  Value<String> note,
  Value<int> color,
  Value<String?> logoAsset,
  Value<String?> frontBlobId,
  Value<String?> backBlobId,
  Value<String> customFields,
  Value<bool> favorite,
  Value<int> sortOrder,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<bool> deleted,
  Value<int?> deletedAt,
  Value<int> baseRev,
  Value<bool> dirty,
  Value<int> rowid,
});

class $$CardsTableFilterComposer extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storeName => $composableBuilder(
    column: $table.storeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardNumber => $composableBuilder(
    column: $table.cardNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcodeFormat => $composableBuilder(
    column: $table.barcodeFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secondaryNumber => $composableBuilder(
    column: $table.secondaryNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logoAsset => $composableBuilder(
    column: $table.logoAsset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frontBlobId => $composableBuilder(
    column: $table.frontBlobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backBlobId => $composableBuilder(
    column: $table.backBlobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customFields => $composableBuilder(
    column: $table.customFields,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseRev => $composableBuilder(
    column: $table.baseRev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CardsTableOrderingComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storeName => $composableBuilder(
    column: $table.storeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardNumber => $composableBuilder(
    column: $table.cardNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcodeFormat => $composableBuilder(
    column: $table.barcodeFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secondaryNumber => $composableBuilder(
    column: $table.secondaryNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logoAsset => $composableBuilder(
    column: $table.logoAsset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frontBlobId => $composableBuilder(
    column: $table.frontBlobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backBlobId => $composableBuilder(
    column: $table.backBlobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customFields => $composableBuilder(
    column: $table.customFields,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseRev => $composableBuilder(
    column: $table.baseRev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get storeName =>
      $composableBuilder(column: $table.storeName, builder: (column) => column);

  GeneratedColumn<String> get cardNumber => $composableBuilder(
    column: $table.cardNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get barcodeFormat => $composableBuilder(
    column: $table.barcodeFormat,
    builder: (column) => column,
  );

  GeneratedColumn<String> get secondaryNumber => $composableBuilder(
    column: $table.secondaryNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get logoAsset =>
      $composableBuilder(column: $table.logoAsset, builder: (column) => column);

  GeneratedColumn<String> get frontBlobId => $composableBuilder(
    column: $table.frontBlobId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get backBlobId => $composableBuilder(
    column: $table.backBlobId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customFields => $composableBuilder(
    column: $table.customFields,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get favorite =>
      $composableBuilder(column: $table.favorite, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get baseRev =>
      $composableBuilder(column: $table.baseRev, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);
}

class $$CardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardsTable,
          Card,
          $$CardsTableFilterComposer,
          $$CardsTableOrderingComposer,
          $$CardsTableAnnotationComposer,
          $$CardsTableCreateCompanionBuilder,
          $$CardsTableUpdateCompanionBuilder,
          (Card, BaseReferences<_$AppDatabase, $CardsTable, Card>),
          Card,
          PrefetchHooks Function()
        > {
  $$CardsTableTableManager(_$AppDatabase db, $CardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> storeName = const Value.absent(),
                Value<String> cardNumber = const Value.absent(),
                Value<String> barcodeFormat = const Value.absent(),
                Value<String?> secondaryNumber = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<String?> logoAsset = const Value.absent(),
                Value<String?> frontBlobId = const Value.absent(),
                Value<String?> backBlobId = const Value.absent(),
                Value<String> customFields = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> baseRev = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion(
                id: id,
                storeName: storeName,
                cardNumber: cardNumber,
                barcodeFormat: barcodeFormat,
                secondaryNumber: secondaryNumber,
                note: note,
                color: color,
                logoAsset: logoAsset,
                frontBlobId: frontBlobId,
                backBlobId: backBlobId,
                customFields: customFields,
                favorite: favorite,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deleted: deleted,
                deletedAt: deletedAt,
                baseRev: baseRev,
                dirty: dirty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String storeName,
                required String cardNumber,
                required String barcodeFormat,
                Value<String?> secondaryNumber = const Value.absent(),
                Value<String> note = const Value.absent(),
                required int color,
                Value<String?> logoAsset = const Value.absent(),
                Value<String?> frontBlobId = const Value.absent(),
                Value<String?> backBlobId = const Value.absent(),
                Value<String> customFields = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> baseRev = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion.insert(
                id: id,
                storeName: storeName,
                cardNumber: cardNumber,
                barcodeFormat: barcodeFormat,
                secondaryNumber: secondaryNumber,
                note: note,
                color: color,
                logoAsset: logoAsset,
                frontBlobId: frontBlobId,
                backBlobId: backBlobId,
                customFields: customFields,
                favorite: favorite,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deleted: deleted,
                deletedAt: deletedAt,
                baseRev: baseRev,
                dirty: dirty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardsTable,
      Card,
      $$CardsTableFilterComposer,
      $$CardsTableOrderingComposer,
      $$CardsTableAnnotationComposer,
      $$CardsTableCreateCompanionBuilder,
      $$CardsTableUpdateCompanionBuilder,
      (Card, BaseReferences<_$AppDatabase, $CardsTable, Card>),
      Card,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder = SyncStateCompanion Function({
  Value<int> id,
  Value<int> lastServerRev,
  Value<int> lastSyncAt,
});
typedef $$SyncStateTableUpdateCompanionBuilder = SyncStateCompanion Function({
  Value<int> id,
  Value<int> lastServerRev,
  Value<int> lastSyncAt,
});

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastServerRev => $composableBuilder(
    column: $table.lastServerRev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastServerRev => $composableBuilder(
    column: $table.lastServerRev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lastServerRev => $composableBuilder(
    column: $table.lastServerRev,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => column,
  );
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTable,
          SyncStateData,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateData,
            BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
          ),
          SyncStateData,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> lastServerRev = const Value.absent(),
                Value<int> lastSyncAt = const Value.absent(),
              }) => SyncStateCompanion(
                id: id,
                lastServerRev: lastServerRev,
                lastSyncAt: lastSyncAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> lastServerRev = const Value.absent(),
                Value<int> lastSyncAt = const Value.absent(),
              }) => SyncStateCompanion.insert(
                id: id,
                lastServerRev: lastServerRev,
                lastSyncAt: lastSyncAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTable,
      SyncStateData,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateData,
        BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
      ),
      SyncStateData,
      PrefetchHooks Function()
    >;
typedef $$LocalBlobsTableCreateCompanionBuilder = LocalBlobsCompanion Function({
  required String blobId,
  required String path,
  required int size,
  Value<bool> uploaded,
  required int createdAt,
  Value<int> rowid,
});
typedef $$LocalBlobsTableUpdateCompanionBuilder = LocalBlobsCompanion Function({
  Value<String> blobId,
  Value<String> path,
  Value<int> size,
  Value<bool> uploaded,
  Value<int> createdAt,
  Value<int> rowid,
});

class $$LocalBlobsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalBlobsTable> {
  $$LocalBlobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get uploaded => $composableBuilder(
    column: $table.uploaded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalBlobsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalBlobsTable> {
  $$LocalBlobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get uploaded => $composableBuilder(
    column: $table.uploaded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalBlobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalBlobsTable> {
  $$LocalBlobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get blobId =>
      $composableBuilder(column: $table.blobId, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<bool> get uploaded =>
      $composableBuilder(column: $table.uploaded, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalBlobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalBlobsTable,
          LocalBlob,
          $$LocalBlobsTableFilterComposer,
          $$LocalBlobsTableOrderingComposer,
          $$LocalBlobsTableAnnotationComposer,
          $$LocalBlobsTableCreateCompanionBuilder,
          $$LocalBlobsTableUpdateCompanionBuilder,
          (
            LocalBlob,
            BaseReferences<_$AppDatabase, $LocalBlobsTable, LocalBlob>,
          ),
          LocalBlob,
          PrefetchHooks Function()
        > {
  $$LocalBlobsTableTableManager(_$AppDatabase db, $LocalBlobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalBlobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalBlobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalBlobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> blobId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<bool> uploaded = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalBlobsCompanion(
                blobId: blobId,
                path: path,
                size: size,
                uploaded: uploaded,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String blobId,
                required String path,
                required int size,
                Value<bool> uploaded = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalBlobsCompanion.insert(
                blobId: blobId,
                path: path,
                size: size,
                uploaded: uploaded,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalBlobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalBlobsTable,
      LocalBlob,
      $$LocalBlobsTableFilterComposer,
      $$LocalBlobsTableOrderingComposer,
      $$LocalBlobsTableAnnotationComposer,
      $$LocalBlobsTableCreateCompanionBuilder,
      $$LocalBlobsTableUpdateCompanionBuilder,
      (LocalBlob, BaseReferences<_$AppDatabase, $LocalBlobsTable, LocalBlob>),
      LocalBlob,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CardsTableTableManager get cards =>
      $$CardsTableTableManager(_db, _db.cards);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  $$LocalBlobsTableTableManager get localBlobs =>
      $$LocalBlobsTableTableManager(_db, _db.localBlobs);
}
