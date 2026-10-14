// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get open => 'Apri';

  @override
  String get save => 'Salva';

  @override
  String get cancel => 'Annulla';

  @override
  String get replace => 'Sostituisci';

  @override
  String get ok => 'OK';

  @override
  String get delete => 'Elimina';

  @override
  String get openWith => 'Apri con';

  @override
  String get showInfo => 'Ottieni informazioni';

  @override
  String get rename => 'Rinomina';

  @override
  String get renameMany => 'Rinomina…';

  @override
  String get duplicate => 'Duplica';

  @override
  String get copy => 'Copia';

  @override
  String get tagsMenu => 'Tag…';

  @override
  String get moveToTrash => 'Sposta nel Cestino';

  @override
  String get restore => 'Ripristina';

  @override
  String newFolderWithSelection(int count) {
    return 'Nuova cartella con selezione ($count elementi)';
  }

  @override
  String defaultApp(String app) {
    return '$app (predefinita)';
  }

  @override
  String get otherApp => 'Altro…';

  @override
  String get newFolder => 'Nuova cartella';

  @override
  String pasteItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Incolla $count elementi',
      one: 'Incolla elemento',
      zero: 'Incolla elemento',
    );
    return '$_temp0';
  }

  @override
  String get view => 'Vista';

  @override
  String get viewIcons => 'Come icone';

  @override
  String get viewList => 'Come elenco';

  @override
  String get viewColumns => 'Come colonne';

  @override
  String get viewGallery => 'Come galleria';

  @override
  String get sortBy => 'Ordina per';

  @override
  String get sortName => 'Nome';

  @override
  String get sortKind => 'Tipo';

  @override
  String get sortModified => 'Data di modifica';

  @override
  String get sortSize => 'Dimensione';

  @override
  String get sortNone => 'Nessuno';

  @override
  String get snapToGrid => 'Allinea alla griglia';

  @override
  String get cleanUp => 'Allinea';

  @override
  String get cleanUpSelection => 'Allinea selezione';

  @override
  String get cleanUpBy => 'Disponi per';

  @override
  String get columnName => 'Nome';

  @override
  String get columnModified => 'Data di modifica';

  @override
  String get columnSize => 'Dimensioni';

  @override
  String get columnKind => 'Tipo';

  @override
  String get sidebarPinned => 'Preferiti';

  @override
  String get sidebarPlaces => 'Posizioni';

  @override
  String get sidebarTags => 'Tag';

  @override
  String get trash => 'Cestino';

  @override
  String get disk => 'Disco';

  @override
  String get tagRed => 'Rosso';

  @override
  String get tagOrange => 'Arancio';

  @override
  String get tagYellow => 'Giallo';

  @override
  String get tagGreen => 'Verde';

  @override
  String get tagBlue => 'Blu';

  @override
  String get tagPurple => 'Viola';

  @override
  String get tagGray => 'Grigio';

  @override
  String get tagError => 'Non si può assegnare l\'etichetta.';

  @override
  String get tagErrorDetail => 'Il disco non permette gli attributi estesi.';

  @override
  String get addTag => 'Aggiungi un tag…';

  @override
  String get paneEdit => 'Modifica';

  @override
  String get paneMore => 'Altro';

  @override
  String get sizeZero => 'Zero byte';

  @override
  String sizeBytes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count byte',
    );
    return '$_temp0';
  }

  @override
  String get decimalSeparator => ',';

  @override
  String get monthsShort => 'gen,feb,mar,apr,mag,giu,lug,ago,set,ott,nov,dic';

  @override
  String get monthsLong =>
      'gennaio,febbraio,marzo,aprile,maggio,giugno,luglio,agosto,settembre,ottobre,novembre,dicembre';

  @override
  String dateToday(String time) {
    return 'oggi, $time';
  }

  @override
  String dateYesterday(String time) {
    return 'ieri, $time';
  }

  @override
  String dateShort(String day, String month, String year, String time) {
    return '$day $month $year, $time';
  }

  @override
  String dateLong(String day, String month, String year, String time) {
    return '$day $month $year, $time';
  }

  @override
  String get kindLink => 'Collegamento';

  @override
  String get kindFolder => 'Cartella';

  @override
  String kindImage(String format) {
    return 'Immagine $format';
  }

  @override
  String kindAudio(String format) {
    return 'Audio $format';
  }

  @override
  String get kindVideo => 'Video';

  @override
  String get kindArchive => 'Archivio';

  @override
  String kindArchiveExt(String ext) {
    return 'Archivio $ext';
  }

  @override
  String get kindText => 'Testo';

  @override
  String get kindDocument => 'Documento';

  @override
  String get newFolderName => 'cartella senza nome';

  @override
  String copySuffix(String base) {
    return '$base copia';
  }

  @override
  String get errorGone => 'L\'elemento non esiste più.';

  @override
  String errorNameInvalid(String name) {
    return 'Il nome «$name» non può essere utilizzato. Scegli un altro nome.';
  }

  @override
  String errorNameSlash(String name) {
    return 'Il nome «$name» non può essere utilizzato. Prova a usare un nome senza la barra «/».';
  }

  @override
  String errorNameTaken(String name) {
    return 'Il nome «$name» è già stato assegnato. Scegline un altro.';
  }

  @override
  String errorUnknownOrigin(String name) {
    return 'Non si sa da dove viene «$name».';
  }

  @override
  String errorOriginTaken(String name) {
    return 'Nella cartella d\'origine c\'è già un elemento chiamato «$name».';
  }

  @override
  String get errorPermission => 'Non hai i permessi per questa operazione.';

  @override
  String get errorDiskFull => 'Il disco è pieno.';

  @override
  String get errorReadOnly => 'Il disco è di sola lettura.';

  @override
  String get errorFolderIntoItself =>
      'Non si può mettere una cartella dentro se stessa.';

  @override
  String errorAlreadyExists(String name) {
    return 'C\'è già un elemento chiamato «$name».';
  }

  @override
  String get opMove => 'Sposta';

  @override
  String undoAction(String action) {
    return 'Annulla $action';
  }

  @override
  String redoAction(String action) {
    return 'Ripeti $action';
  }

  @override
  String get opDuplicate => 'Duplicazione';

  @override
  String opDuplicateMany(int count) {
    return 'Duplicazione di $count elementi';
  }

  @override
  String get unknownCopy => 'Copia sconosciuta';

  @override
  String get copyCantRedo => 'La copia non si può ripetere.';

  @override
  String get cantRename => 'Non si può rinominare.';

  @override
  String cantRenameItem(String name) {
    return 'Non si può rinominare «$name».';
  }

  @override
  String get cantCreateFolder => 'Non si può creare la cartella.';

  @override
  String get cantDuplicate => 'Non si può duplicare.';

  @override
  String get cantTrash => 'Non si può spostare nel Cestino.';

  @override
  String get cantRestore => 'Non si può ripristinare.';

  @override
  String get cantDelete => 'Non si può eliminare.';

  @override
  String get cantUndo => 'Non si può annullare.';

  @override
  String get cantRedo => 'Non si può ripetere.';

  @override
  String get cantCopy => 'Non si può completare la copia.';

  @override
  String get cantMove => 'Non si può completare lo spostamento.';

  @override
  String cantOpenFolder(String error) {
    return 'Non si può aprire: $error';
  }

  @override
  String get cantOpenWindow => 'Non si può aprire una finestra nuova.';

  @override
  String get entryNotInstalled =>
      'La voce di Mustache non è installata (cargo xtask install-app).';

  @override
  String extensionRemove(String old) {
    return 'Vuoi togliere l\'estensione «$old»?';
  }

  @override
  String extensionChange(String newExt, String old) {
    return 'Vuoi usare l\'estensione «$newExt» invece di «$old»?';
  }

  @override
  String get extensionWarning =>
      'Cambiando l\'estensione il file potrebbe aprirsi con un\'altra app.';

  @override
  String keepExtension(String ext) {
    return 'Mantieni $ext';
  }

  @override
  String get removeExtension => 'Togli';

  @override
  String useExtension(String ext) {
    return 'Usa $ext';
  }

  @override
  String confirmDeleteOne(String name) {
    return 'Confermi di voler eliminare «$name»?';
  }

  @override
  String confirmDeleteMany(int count) {
    return 'Confermi di voler eliminare $count elementi?';
  }

  @override
  String get deleteWarningOne =>
      'Questo elemento verrà eliminato immediatamente. L\'operazione è irreversibile.';

  @override
  String get deleteWarningMany =>
      'Questi elementi verranno eliminati immediatamente. L\'operazione è irreversibile.';

  @override
  String appHasNoCommand(String app) {
    return 'La voce di «$app» non ha un comando.';
  }

  @override
  String appCantOpen(String app, String error) {
    return 'Non si può aprire «$app»: $error';
  }

  @override
  String replaceQuestion(String name) {
    return 'Vuoi sostituire «$name»?';
  }

  @override
  String get replaceDetail =>
      'Esiste già un elemento con questo nome in questa cartella.';

  @override
  String get saveAs => 'Salva con nome:';

  @override
  String get searchIn => 'Cerca in:';

  @override
  String get thisComputer => 'Questo computer';

  @override
  String searchTitle(String scope) {
    return 'Ricerca in «$scope»';
  }

  @override
  String quoted(String name) {
    return '«$name»';
  }

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi',
      one: '1 elemento',
    );
    return '$_temp0';
  }

  @override
  String selectedCount(int selected, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$selected di $count selezionati',
      one: '$selected di 1 selezionato',
    );
    return '$_temp0';
  }

  @override
  String available(String head, String free) {
    return '$head, $free disponibili';
  }

  @override
  String documentsSize(int count, String size) {
    return '$count documenti - $size';
  }

  @override
  String get information => 'Informazioni';

  @override
  String get created => 'Creato';

  @override
  String get modified => 'Modificato';

  @override
  String get size => 'Dimensioni';

  @override
  String get tags => 'Tag';

  @override
  String get infoGeneral => 'Generali';

  @override
  String get infoNameExtension => 'Nome ed estensione';

  @override
  String get infoComments => 'Commenti';

  @override
  String get infoPreview => 'Anteprima';

  @override
  String get infoPermissions => 'Condivisione e permessi';

  @override
  String get privilegeReadWrite => 'Lettura e scrittura';

  @override
  String get privilegeReadOnly => 'Sola lettura';

  @override
  String get privilegeWriteOnly => 'Sola scrittura';

  @override
  String get privilegeNone => 'Nessun accesso';

  @override
  String infoTitle(String name) {
    return 'Info su $name';
  }

  @override
  String modifiedOn(String date) {
    return 'Modificato: $date';
  }

  @override
  String get kind => 'Tipo';

  @override
  String sizeOnDisk(int bytes, String disk) {
    return '$bytes byte ($disk su disco)';
  }

  @override
  String get location => 'Situato in';

  @override
  String get app => 'App';

  @override
  String get none => 'Nessuna';

  @override
  String get groupFallback => 'gruppo';

  @override
  String get everyone => 'tutti';

  @override
  String ownerMe(String owner) {
    return '$owner (io)';
  }

  @override
  String positionOf(String name, int index, int count) {
    return '$name  ($index di $count)';
  }

  @override
  String openWithApp(String app) {
    return 'Apri con $app';
  }

  @override
  String lastModified(String date) {
    return 'Ultima modifica: $date';
  }

  @override
  String get copying => 'Copio';

  @override
  String get moving => 'Sposto';

  @override
  String transferLine(String verb, String name, String destination) {
    return '$verb «$name» in «$destination»';
  }

  @override
  String progressOf(String done, String total) {
    return '$done di $total';
  }

  @override
  String conflictCopy(String name) {
    return 'In questa posizione c\'è già un elemento chiamato «$name». Vuoi sostituirlo con quello che stai copiando?';
  }

  @override
  String conflictMove(String name) {
    return 'In questa posizione c\'è già un elemento chiamato «$name». Vuoi sostituirlo con quello che stai spostando?';
  }

  @override
  String get keepBoth => 'Mantieni entrambi';

  @override
  String get stop => 'Interrompi';
}
