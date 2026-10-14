import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('it'),
  ];

  /// Opens the chosen items (menu item, dialog button).
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// Save dialog button.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Cancels an alert or a dialog.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Replaces an existing item.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// Acknowledges an error.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Deletes items permanently.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Submenu and Info section listing apps that open a file.
  ///
  /// In en, this message translates to:
  /// **'Open With'**
  String get openWith;

  /// Opens the Info window of the items.
  ///
  /// In en, this message translates to:
  /// **'Show Info'**
  String get showInfo;

  /// Renames one item; also the name of the undoable operation.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// Renames several items (disabled).
  ///
  /// In en, this message translates to:
  /// **'Rename…'**
  String get renameMany;

  /// Makes copies next to the originals.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// Copies the items to the clipboard; also the name of the undoable copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// Opens the tag editor (disabled).
  ///
  /// In en, this message translates to:
  /// **'Tags…'**
  String get tagsMenu;

  /// Moves items to the Trash.
  ///
  /// In en, this message translates to:
  /// **'Move to Trash'**
  String get moveToTrash;

  /// Puts items in the Trash back where they were.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// Disabled item shown when several items are chosen.
  ///
  /// In en, this message translates to:
  /// **'New Folder from Selection ({count} items)'**
  String newFolderWithSelection(int count);

  /// The default app in the Open With submenu.
  ///
  /// In en, this message translates to:
  /// **'{app} (default)'**
  String defaultApp(String app);

  /// Chooses another app (disabled).
  ///
  /// In en, this message translates to:
  /// **'Other…'**
  String get otherApp;

  /// Creates a folder; also the name of the undoable operation.
  ///
  /// In en, this message translates to:
  /// **'New Folder'**
  String get newFolder;

  /// Pastes the copied items.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Paste Item} =1{Paste Item} other{Paste {count} Items}}'**
  String pasteItems(int count);

  /// Submenu that chooses the view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// Icon view.
  ///
  /// In en, this message translates to:
  /// **'Icons'**
  String get viewIcons;

  /// List view.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get viewList;

  /// Column view.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get viewColumns;

  /// Gallery view.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get viewGallery;

  /// Submenu that chooses the sort order.
  ///
  /// In en, this message translates to:
  /// **'Sort By'**
  String get sortBy;

  /// Sort by name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortName;

  /// Sort by type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get sortKind;

  /// Sort by modification date.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get sortModified;

  /// Sort by size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sortSize;

  /// Icon view sort order: no order, icons stay where the user puts them.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get sortNone;

  /// Icon view option: dropped icons land on the nearest free grid cell.
  ///
  /// In en, this message translates to:
  /// **'Snap to Grid'**
  String get snapToGrid;

  /// Icon view: moves icons that are off the grid to the nearest free cell.
  ///
  /// In en, this message translates to:
  /// **'Clean Up'**
  String get cleanUp;

  /// Icon view: like Clean Up, only for the selected icons.
  ///
  /// In en, this message translates to:
  /// **'Clean Up Selection'**
  String get cleanUpSelection;

  /// Icon view submenu: lays out all icons on the grid in an order, once.
  ///
  /// In en, this message translates to:
  /// **'Clean Up By'**
  String get cleanUpBy;

  /// List column header.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get columnName;

  /// List column header.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get columnModified;

  /// List column header.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get columnSize;

  /// List column header.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get columnKind;

  /// Sidebar section with the user folders.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get sidebarPinned;

  /// Sidebar section with home and Trash.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get sidebarPlaces;

  /// Sidebar section with the tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get sidebarTags;

  /// The Trash place.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get trash;

  /// Name of the root disk in the path bar.
  ///
  /// In en, this message translates to:
  /// **'Disk'**
  String get disk;

  /// Default tag name.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get tagRed;

  /// Default tag name.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get tagOrange;

  /// Default tag name.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get tagYellow;

  /// Default tag name.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get tagGreen;

  /// Default tag name.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get tagBlue;

  /// Default tag name.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get tagPurple;

  /// Default tag name.
  ///
  /// In en, this message translates to:
  /// **'Gray'**
  String get tagGray;

  /// Error title when writing a tag fails.
  ///
  /// In en, this message translates to:
  /// **'Can\'t assign the tag.'**
  String get tagError;

  /// Error detail when writing a tag fails.
  ///
  /// In en, this message translates to:
  /// **'The disk does not support extended attributes.'**
  String get tagErrorDetail;

  /// Placeholder of the tag field in the preview pane.
  ///
  /// In en, this message translates to:
  /// **'Add a tag…'**
  String get addTag;

  /// Preview pane action that opens the file with its app.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get paneEdit;

  /// Preview pane action that opens the item menu.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get paneMore;

  /// Size of an empty file.
  ///
  /// In en, this message translates to:
  /// **'Zero bytes'**
  String get sizeZero;

  /// Size below 1000 bytes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 byte} other{{count} bytes}}'**
  String sizeBytes(int count);

  /// Decimal separator in sizes.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get decimalSeparator;

  /// Comma-separated short month names.
  ///
  /// In en, this message translates to:
  /// **'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec'**
  String get monthsShort;

  /// Comma-separated month names.
  ///
  /// In en, this message translates to:
  /// **'January,February,March,April,May,June,July,August,September,October,November,December'**
  String get monthsLong;

  /// A date of today.
  ///
  /// In en, this message translates to:
  /// **'Today, {time}'**
  String dateToday(String time);

  /// A date of yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {time}'**
  String dateYesterday(String time);

  /// A date with the short month name.
  ///
  /// In en, this message translates to:
  /// **'{month} {day}, {year}, {time}'**
  String dateShort(String day, String month, String year, String time);

  /// A date with the full month name (Info window).
  ///
  /// In en, this message translates to:
  /// **'{month} {day}, {year}, {time}'**
  String dateLong(String day, String month, String year, String time);

  /// Type of a symbolic link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get kindLink;

  /// Type of a folder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get kindFolder;

  /// Type of an image.
  ///
  /// In en, this message translates to:
  /// **'{format} image'**
  String kindImage(String format);

  /// Type of an audio file.
  ///
  /// In en, this message translates to:
  /// **'{format} audio'**
  String kindAudio(String format);

  /// Type of a video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get kindVideo;

  /// Type of an archive without extension.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get kindArchive;

  /// Type of an archive.
  ///
  /// In en, this message translates to:
  /// **'{ext} archive'**
  String kindArchiveExt(String ext);

  /// Type of a text file.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get kindText;

  /// Type of any other file.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get kindDocument;

  /// Name of a new folder on disk.
  ///
  /// In en, this message translates to:
  /// **'new folder'**
  String get newFolderName;

  /// Name of a duplicate.
  ///
  /// In en, this message translates to:
  /// **'{base} copy'**
  String copySuffix(String base);

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'The item no longer exists.'**
  String get errorGone;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'The name “{name}” can\'t be used. Choose another name.'**
  String errorNameInvalid(String name);

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'The name “{name}” can\'t be used. Try a name without the slash “/”.'**
  String errorNameSlash(String name);

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'The name “{name}” is already taken. Choose another one.'**
  String errorNameTaken(String name);

  /// Error when restoring from the Trash.
  ///
  /// In en, this message translates to:
  /// **'It is not known where “{name}” came from.'**
  String errorUnknownOrigin(String name);

  /// Error when restoring from the Trash.
  ///
  /// In en, this message translates to:
  /// **'The original folder already has an item named “{name}”.'**
  String errorOriginTaken(String name);

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission for this operation.'**
  String get errorPermission;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'The disk is full.'**
  String get errorDiskFull;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'The disk is read-only.'**
  String get errorReadOnly;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'A folder can\'t be put inside itself.'**
  String get errorFolderIntoItself;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'There is already an item named “{name}”.'**
  String errorAlreadyExists(String name);

  /// Name of the undoable move.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get opMove;

  /// Edit menu item.
  ///
  /// In en, this message translates to:
  /// **'Undo {action}'**
  String undoAction(String action);

  /// Edit menu item.
  ///
  /// In en, this message translates to:
  /// **'Redo {action}'**
  String redoAction(String action);

  /// Name of the undoable duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get opDuplicate;

  /// Name of the undoable duplicate of several items.
  ///
  /// In en, this message translates to:
  /// **'Duplicate {count} items'**
  String opDuplicateMany(int count);

  /// Error when redoing a duplicate whose source is gone.
  ///
  /// In en, this message translates to:
  /// **'Unknown copy'**
  String get unknownCopy;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'The copy can\'t be redone.'**
  String get copyCantRedo;

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t rename.'**
  String get cantRename;

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t rename “{name}”.'**
  String cantRenameItem(String name);

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t create the folder.'**
  String get cantCreateFolder;

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t duplicate.'**
  String get cantDuplicate;

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t move to the Trash.'**
  String get cantTrash;

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t restore.'**
  String get cantRestore;

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t delete.'**
  String get cantDelete;

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t undo.'**
  String get cantUndo;

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t redo.'**
  String get cantRedo;

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t complete the copy.'**
  String get cantCopy;

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t complete the move.'**
  String get cantMove;

  /// Error shown in place of the list.
  ///
  /// In en, this message translates to:
  /// **'Can\'t open: {error}'**
  String cantOpenFolder(String error);

  /// Error title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t open a new window.'**
  String get cantOpenWindow;

  /// Error detail.
  ///
  /// In en, this message translates to:
  /// **'The Mustache desktop entry is not installed (cargo xtask install-app).'**
  String get entryNotInstalled;

  /// Title when a rename removes the extension.
  ///
  /// In en, this message translates to:
  /// **'Remove the extension “{old}”?'**
  String extensionRemove(String old);

  /// Title when a rename changes the extension.
  ///
  /// In en, this message translates to:
  /// **'Use the extension “{newExt}” instead of “{old}”?'**
  String extensionChange(String newExt, String old);

  /// Detail of the extension alert.
  ///
  /// In en, this message translates to:
  /// **'With another extension the file may open in a different app.'**
  String get extensionWarning;

  /// Keeps the old extension.
  ///
  /// In en, this message translates to:
  /// **'Keep {ext}'**
  String keepExtension(String ext);

  /// Removes the extension.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeExtension;

  /// Uses the new extension.
  ///
  /// In en, this message translates to:
  /// **'Use {ext}'**
  String useExtension(String ext);

  /// Title of the delete confirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}” permanently?'**
  String confirmDeleteOne(String name);

  /// Title of the delete confirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} items permanently?'**
  String confirmDeleteMany(int count);

  /// Detail of the delete confirmation.
  ///
  /// In en, this message translates to:
  /// **'This item will be deleted right away. This can\'t be undone.'**
  String get deleteWarningOne;

  /// Detail of the delete confirmation.
  ///
  /// In en, this message translates to:
  /// **'These items will be deleted right away. This can\'t be undone.'**
  String get deleteWarningMany;

  /// Error when launching an app.
  ///
  /// In en, this message translates to:
  /// **'The entry of “{app}” has no command.'**
  String appHasNoCommand(String app);

  /// Error when launching an app.
  ///
  /// In en, this message translates to:
  /// **'Can\'t open “{app}”: {error}'**
  String appCantOpen(String app, String error);

  /// Save dialog: an item with the name exists.
  ///
  /// In en, this message translates to:
  /// **'Replace “{name}”?'**
  String replaceQuestion(String name);

  /// Save dialog detail.
  ///
  /// In en, this message translates to:
  /// **'An item with this name already exists in this folder.'**
  String get replaceDetail;

  /// Label of the name field in the Save dialog.
  ///
  /// In en, this message translates to:
  /// **'Save as:'**
  String get saveAs;

  /// Search scope bar.
  ///
  /// In en, this message translates to:
  /// **'Search in:'**
  String get searchIn;

  /// Search scope: the whole computer.
  ///
  /// In en, this message translates to:
  /// **'This Computer'**
  String get thisComputer;

  /// Window title while searching.
  ///
  /// In en, this message translates to:
  /// **'Searching “{scope}”'**
  String searchTitle(String scope);

  /// A quoted name.
  ///
  /// In en, this message translates to:
  /// **'“{name}”'**
  String quoted(String name);

  /// Number of items.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemCount(int count);

  /// Selected items in the status bar.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{selected} of 1 selected} other{{selected} of {count} selected}}'**
  String selectedCount(int selected, int count);

  /// Status bar with the free space.
  ///
  /// In en, this message translates to:
  /// **'{head}, {free} available'**
  String available(String head, String free);

  /// Several items in the preview pane.
  ///
  /// In en, this message translates to:
  /// **'{count} documents - {size}'**
  String documentsSize(int count, String size);

  /// Preview pane section.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get information;

  /// Creation date label.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get created;

  /// Modification date label.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get modified;

  /// Size label.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// Tags label.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// Info section.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get infoGeneral;

  /// Info section.
  ///
  /// In en, this message translates to:
  /// **'Name and Extension'**
  String get infoNameExtension;

  /// Info section.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get infoComments;

  /// Info section.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get infoPreview;

  /// Info section.
  ///
  /// In en, this message translates to:
  /// **'Sharing and Permissions'**
  String get infoPermissions;

  /// Permission.
  ///
  /// In en, this message translates to:
  /// **'Read and write'**
  String get privilegeReadWrite;

  /// Permission.
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get privilegeReadOnly;

  /// Permission.
  ///
  /// In en, this message translates to:
  /// **'Write only'**
  String get privilegeWriteOnly;

  /// Permission.
  ///
  /// In en, this message translates to:
  /// **'No access'**
  String get privilegeNone;

  /// Title of the Info window.
  ///
  /// In en, this message translates to:
  /// **'{name} Info'**
  String infoTitle(String name);

  /// Info header.
  ///
  /// In en, this message translates to:
  /// **'Modified: {date}'**
  String modifiedOn(String date);

  /// Info row.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get kind;

  /// Info row.
  ///
  /// In en, this message translates to:
  /// **'{bytes} bytes ({disk} on disk)'**
  String sizeOnDisk(int bytes, String disk);

  /// Info row.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// Info Open With row.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get app;

  /// No app.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// Info permissions row when the group is unknown.
  ///
  /// In en, this message translates to:
  /// **'group'**
  String get groupFallback;

  /// Info permissions row for others.
  ///
  /// In en, this message translates to:
  /// **'everyone'**
  String get everyone;

  /// Owner row in Info.
  ///
  /// In en, this message translates to:
  /// **'{owner} (me)'**
  String ownerMe(String owner);

  /// Quick preview title with several items.
  ///
  /// In en, this message translates to:
  /// **'{name}  ({index} of {count})'**
  String positionOf(String name, int index, int count);

  /// Quick preview button.
  ///
  /// In en, this message translates to:
  /// **'Open with {app}'**
  String openWithApp(String app);

  /// Quick preview detail.
  ///
  /// In en, this message translates to:
  /// **'Last modified: {date}'**
  String lastModified(String date);

  /// Verb in the progress window.
  ///
  /// In en, this message translates to:
  /// **'Copying'**
  String get copying;

  /// Verb in the progress window.
  ///
  /// In en, this message translates to:
  /// **'Moving'**
  String get moving;

  /// Progress window line.
  ///
  /// In en, this message translates to:
  /// **'{verb} “{name}” to “{destination}”'**
  String transferLine(String verb, String name, String destination);

  /// Progress window bytes.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String progressOf(String done, String total);

  /// Conflict window.
  ///
  /// In en, this message translates to:
  /// **'An item named “{name}” already exists here. Replace it with the one you are copying?'**
  String conflictCopy(String name);

  /// Conflict window.
  ///
  /// In en, this message translates to:
  /// **'An item named “{name}” already exists here. Replace it with the one you are moving?'**
  String conflictMove(String name);

  /// Conflict choice.
  ///
  /// In en, this message translates to:
  /// **'Keep both'**
  String get keepBoth;

  /// Conflict choice.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// Folder context menu: opens Get Info on the Customize Folder section.
  ///
  /// In en, this message translates to:
  /// **'Customize Folder…'**
  String get customizeFolder;

  /// Info section of a folder: its colour and symbol.
  ///
  /// In en, this message translates to:
  /// **'Customize Folder'**
  String get infoCustomize;

  /// Customize Folder: the colour row.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get folderColor;

  /// Customize Folder: the symbol grid.
  ///
  /// In en, this message translates to:
  /// **'Symbol'**
  String get folderSymbol;

  /// Customize Folder: placeholder of the custom colour field.
  ///
  /// In en, this message translates to:
  /// **'Custom color, as #rrggbb'**
  String get folderCustomColor;

  /// Customize Folder: placeholder of the symbol search field.
  ///
  /// In en, this message translates to:
  /// **'Search symbols'**
  String get folderSymbolSearch;

  /// Customize Folder: the search found nothing, or the icons are not installed.
  ///
  /// In en, this message translates to:
  /// **'No symbols'**
  String get folderNoSymbols;

  /// Customize Folder: removes the custom colour and symbol.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get folderReset;

  /// Customize Folder: saving failed (no permission, read-only disk).
  ///
  /// In en, this message translates to:
  /// **'This folder can\'t be customized.'**
  String get folderStyleError;
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
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
