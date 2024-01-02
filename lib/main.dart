// ignore_for_file: use_build_context_synchronously
import 'package:ffmpeg_kit_flutter_audio/return_code.dart';
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:provider/provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:audiotags/audiotags.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart';

const platform = MethodChannel('media_scan_channel');
List<String> titles = <String>[
  'Home',
  'Recents',
  'About'
];
bool isDone = false;
bool isCorrect = false;
bool darkMode = true;
bool systemMode = true;

enum ColorLabel {
  dark('Dark', Colors.black),
  light('Light', Colors.white),
  system('System', Colors.grey);

  const ColorLabel(this.label, this.color);
  final String label;
  final Color color;
}

Future<File> writeTheme(String value) async {
  File file = File('data/flutter_assets/assets/theme');
  if (Platform.environment.containsKey('ANDROID_DATA')) {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String filePath = join(appDocDir.path, 'data/flutter_assets/assets/theme');
    file = File(filePath);
  }
  if (file.existsSync()) {
    debugPrint(value);
    return file.writeAsString(value);
  } else {
    await file.create(recursive: true);
    debugPrint(value);
    debugPrint("Created theme");
    return file.writeAsString(value);
  }
}

Future<String> readTheme() async {
  File file = File('data/flutter_assets/assets/theme');
  if (Platform.environment.containsKey('ANDROID_DATA')) {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String filePath = join(appDocDir.path, 'data/flutter_assets/assets/theme');
    file = File(filePath);
  }
  if (file.existsSync()) {
    return file.readAsString();
  } else {
    await file.create(recursive: true);
    debugPrint("Created theme");
    file.writeAsString('System');
    return file.readAsString();
  }
}

Future<void> setTheme(String value) async {
  switch (value) {
    case 'Light':
      darkMode = false;
      systemMode = false;
      break;
    case 'Dark':
      darkMode = true;
      systemMode = false;
      break;
    case 'System':
      systemMode = true;
      break;
  }
}

Future<void> executeFFmpeg(input, output) async {
  var result = await Process.run('data/flutter_assets/bin/ffmpeg.exe', ['-i', '$input', '-q:a', '0', '-map', 'a', '-c:a', 'libmp3lame', '$output']);
  if (result.exitCode == 0) {
    isDone = true;
  }
}

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  String savedTheme = await readTheme();
  await setTheme(savedTheme);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final _defaultLightColorScheme = ColorScheme.fromSwatch(primarySwatch: Colors.blue);

  static final _defaultDarkColorScheme = ColorScheme.fromSwatch(primarySwatch: Colors.blue, brightness: Brightness.dark);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: Builder(
          builder: (context) {
            return Consumer<MyAppState>(
              builder: (context, themeModel, _) {
                return DynamicColorBuilder(
                    builder: (lightColorScheme, darkColorScheme) {
                      return MaterialApp(
                        title: 'YT Downloader',
                        theme: ThemeData(
                          colorScheme: lightColorScheme ?? _defaultLightColorScheme,
                          useMaterial3: true,
                        ),
                        darkTheme: ThemeData(
                          colorScheme: darkColorScheme ?? _defaultDarkColorScheme,
                          useMaterial3: true,
                        ),
                        themeMode: systemMode ? ThemeMode.system : darkMode && !systemMode ? ThemeMode.dark : ThemeMode.light,
                        home: const SizedBox(
                            width: 400,
                            child: MyHomePage()
                        ),
                      );
                    }
                );
              }
            );
          }
      ),
    );
  }
}



class MyAppState extends ChangeNotifier {
  late FocusNode _focus = FocusNode();
  late TextEditingController _textController = TextEditingController();
  late TextEditingController _titleController = TextEditingController();
  late TextEditingController _authorController = TextEditingController();
  late TextEditingController _yearController = TextEditingController();
  late TextEditingController _albumController = TextEditingController();
  final TextEditingController colorController = TextEditingController();
  ColorLabel? selectedColor;
  bool isTextFieldFocused = false;
  var fileIndex = [];

  String selectedOption = readTheme().toString();

  themeSelector(context) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Change app theme'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Column(
                  children: [
                    RadioListTile(
                      title: const Text('Light Mode'),
                      value: 'Light',
                      groupValue: selectedOption,
                      onChanged: (value) {
                          selectedOption = value.toString();
                          writeTheme(selectedOption);
                          setTheme(selectedOption);
                          notifyListeners();
                      },
                    ),
                    RadioListTile(
                      title: const Text('Dark Mode'),
                      value: 'Dark',
                      groupValue: selectedOption,
                      onChanged: (value) {
                        selectedOption = value.toString();
                        writeTheme(selectedOption);
                        setTheme(selectedOption);
                        notifyListeners();
                      },
                    ),
                    RadioListTile(
                      title: const Text('System Default'),
                      value: 'System',
                      groupValue: selectedOption,
                      onChanged: (value) {
                        selectedOption = value.toString();
                        writeTheme(selectedOption);
                        setTheme(selectedOption);
                        notifyListeners();
                      },
                    ),
                  ]
                )
              )
            )
          );
        }
    );
  }

  MyAppState() {
    _focus = FocusNode();
    _textController = TextEditingController();
    _titleController = TextEditingController();
    _albumController = TextEditingController();
    _yearController = TextEditingController();
    _authorController = TextEditingController();


    // Add a listener to the FocusNode
    _focus.addListener(_onFocusChange);
  }

  Future<Tag?> _displayTextInputDialog(BuildContext context, title, author, album, year, thumbnailData) async {
    _titleController.text = title;
    _authorController.text = author;
    _albumController.text = album;
    _yearController.text = year.toString();

    img.Image thumbnailImage = img.decodeImage(thumbnailData) ?? img.Image(1, 1);
    thumbnailImage = img.copyResizeCropSquare(thumbnailImage, 300);

    Map<String, Object> result = await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Edit metadata'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: "Title"),
                    ),
                    TextField(
                      controller: _authorController,
                      decoration: const InputDecoration(labelText: "Artist"),
                    ),
                    TextField(
                      controller: _albumController,
                      decoration: const InputDecoration(labelText: "Album"),
                    ),
                    TextField(
                      controller: _yearController,
                      decoration: const InputDecoration(labelText: "Year"),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text('Album Cover'),
                            ),
                            Image.memory(
                              Picture(
                                bytes: Uint8List.fromList(img.encodeJpg(thumbnailImage)),
                                mimeType: MimeType.jpeg,
                                pictureType: PictureType.other
                              ).bytes,
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
                            )
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              ElevatedButton(
                child: const Text('OK'),
                onPressed: () {
                  isCorrect = true;
                  String title = _titleController.text;
                  String artist = _authorController.text;
                  String album = _albumController.text;
                  int year = int.parse(_yearController.text);
                  Navigator.pop(context, {
                    'title': title,
                    'artist': artist,
                    'album': album,
                    'year': year,
                  });
                },
              ),
            ],
          );
        });

    var titleFinalObject = result['title'] ?? '';
    var artistFinalObject = result['artist'] ?? '';
    var albumFinalObject = result['album'] ?? '';
    var yearFinalObject = result['year'] ?? '0';

    String artistFinal = artistFinalObject.toString();
    String albumFinal = albumFinalObject.toString();
    String yearFinalString = yearFinalObject.toString();
    int yearFinal = int.parse(yearFinalString);
    String titleFinal = titleFinalObject.toString();

    return Tag(
      title: titleFinal,
      trackArtist: artistFinal,
      album: albumFinal,
      albumArtist: artistFinal,
      genre: "",
      year: yearFinal,
      pictures: [
        Picture(
          bytes: Uint8List.fromList(img.encodeJpg(thumbnailImage)),
          mimeType: MimeType.jpeg,
          pictureType: PictureType.other,
        ),
      ],
    );
  }

  void _onFocusChange() {
    // This method will be called whenever the focus state changes
    if (_focus.hasFocus) {
      isTextFieldFocused = true;
      _textController.text = '';
    } else {
      isTextFieldFocused = false;
      // Do something when the text field loses focus
    }
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
    _focus.dispose();
    _textController.dispose();
    _titleController.dispose();
    _albumController.dispose();
    _yearController.dispose();
    _authorController.dispose();
  }

  String getURL() {
    var currentLink = _textController.text;
    return currentLink;
  }

  String progressText = '';
  var recentsListTitle = [];
  var recentsListArtist = [];
  var recentsListYear = [];
  var recentsListCover = [];

  void download(String url, BuildContext context) async {
    bool replacement = false;
    progressText = '';
    notifyListeners();
    try {
      progressText = 'Downloading';
      notifyListeners();
      var ytExplode = YoutubeExplode();
      progressText = 'Downloading.';
      notifyListeners();
      var video = await ytExplode.videos.get(url);
      progressText = 'Downloading..';
      notifyListeners();

      var manifest = await ytExplode.videos.streamsClient.getManifest(video.id);
      var audio = manifest.audioOnly.withHighestBitrate();
      var audioFile = ytExplode.videos.streamsClient.get(audio);
      progressText = 'Downloading...';
      notifyListeners();
      var title = video.title
          .replaceAll(r'\', '')
          .replaceAll('/', '')
          .replaceAll('*', '')
          .replaceAll('?', '')
          .replaceAll('"', '')
          .replaceAll('<', '')
          .replaceAll('>', '')
          .replaceAll('|', '');
      var titleMeta = video.title;
      var author = video.author;
      var uploadYear = int.parse(video.uploadDate!.year.toString());
      var pic = video.thumbnails.standardResUrl;
      var response = await http.get(Uri.parse(pic));
      Uint8List thumbnailData = Uint8List.fromList(response.bodyBytes);

      if (Platform.environment['OS'] == 'Windows_NT') {
        final appDocDir = await getApplicationDocumentsDirectory();
        try {
          var defaultMusicDir = Directory('${Platform.environment['HOME']!}\\Music');
          final savePathTemp = '$defaultMusicDir\\$title.temp.mp3';
          final savePath = '$defaultMusicDir\\$title.mp3';
          var file = File(savePathTemp);
          var fileStream = file.openWrite();
          await audioFile.pipe(fileStream);
          var fileExisting = File(savePath);
          if (fileIndex.contains(savePath) && fileIndex.length > 1) {
            fileIndex.removeLast();
            notifyListeners();
          } else {
            fileIndex.add(savePath);
            notifyListeners();
          }
          if (await fileExisting.exists()) {
            await fileExisting.delete();
            progressText = ' Existing file found in:\n $savePath\n Replacing...';
            notifyListeners();
            replacement = true;
          }
          Tag? tag = await _displayTextInputDialog(context, titleMeta, author, "", uploadYear, thumbnailData);
          await executeFFmpeg(savePathTemp, savePath);
          if (isDone == true && isCorrect == true) {
            if (tag != null) {
              AudioTags.write(savePath, tag);
              if (replacement == false || recentsListTitle.isEmpty) {
                recentsListTitle.add(tag.title);
                recentsListArtist.add(tag.trackArtist);
                recentsListYear.add(tag.year);
                recentsListCover.add(thumbnailData);
                notifyListeners();
              } else {
                int indexToReplace = fileIndex.indexOf(savePath);
                recentsListTitle[indexToReplace] = tag.title;
                recentsListArtist[indexToReplace] = tag.trackArtist;
                recentsListYear[indexToReplace] = tag.year;
                recentsListCover[indexToReplace] = thumbnailData;
                replacement = false;
                notifyListeners();
              }
            }
            progressText = ' Done! File saved to:\n $savePath';
            notifyListeners();
            isDone = false;
            await file.delete();
          }
        } catch (e) {
          var musicDir = await Directory('${appDocDir.path}\\Music').exists();
          if (musicDir == false) {
            var newDirectory = Directory('${appDocDir.path}\\Music');
            await newDirectory.create(recursive: true);
            final savePathTemp = '${appDocDir.path}\\Music\\$title.temp.mp3';
            final savePath = '${appDocDir.path}\\Music\\$title.mp3';
            var file = File(savePathTemp);
            var fileStream = file.openWrite();
            await audioFile.pipe(fileStream);
            var fileExisting = File(savePath);
            if (fileIndex.contains(savePath) && fileIndex.length > 1) {
              fileIndex.removeLast();
              notifyListeners();
            } else {
              fileIndex.add(savePath);
              notifyListeners();
            }
            if (await fileExisting.exists()) {
              await fileExisting.delete();
              progressText = ' Existing file found in:\n $savePath\n Replacing...';
              notifyListeners();
              replacement = true;
            }
            Tag? tag = await _displayTextInputDialog(context, titleMeta, author, "", uploadYear, thumbnailData);
            await executeFFmpeg(savePathTemp, savePath);
            if (isDone == true && isCorrect == true) {
              if (tag != null) {
                AudioTags.write(savePath, tag);
                if (replacement == false || recentsListTitle.isEmpty) {
                  recentsListTitle.add(tag.title);
                  recentsListArtist.add(tag.trackArtist);
                  recentsListYear.add(tag.year);
                  recentsListCover.add(thumbnailData);
                  notifyListeners();
                } else {
                  int indexToReplace = fileIndex.indexOf(savePath);
                  recentsListTitle[indexToReplace] = tag.title;
                  recentsListArtist[indexToReplace] = tag.trackArtist;
                  recentsListYear[indexToReplace] = tag.year;
                  recentsListCover[indexToReplace] = thumbnailData;
                  replacement = false;
                  notifyListeners();
                }
              }
              progressText = ' Done! File saved to:\n $savePath';
              notifyListeners();
              isDone = false;
              await file.delete();
            }
          } else {
            final savePathTemp = '${appDocDir.path}\\Music\\$title.temp.mp3';
            final savePath = '${appDocDir.path}\\Music\\$title.mp3';
            var file = File(savePathTemp);
            var fileStream = file.openWrite();
            await audioFile.pipe(fileStream);
            var fileExisting = File(savePath);
            if (fileIndex.contains(savePath) && fileIndex.length > 1) {
              fileIndex.removeLast();
              notifyListeners();
            } else {
              fileIndex.add(savePath);
              notifyListeners();
            }
            if (await fileExisting.exists()) {
              await fileExisting.delete();
              progressText = ' Existing file found in:\n $savePath\n Replacing...';
              notifyListeners();
              replacement = true;
            }
            Tag? tag = await _displayTextInputDialog(context, titleMeta, author, "", uploadYear, thumbnailData);
            await executeFFmpeg(savePathTemp, savePath);
            if (isDone == true && isCorrect == true) {
              if (tag != null) {
                AudioTags.write(savePath, tag);
                if (replacement == false || recentsListTitle.isEmpty) {
                  recentsListTitle.add(tag.title);
                  recentsListArtist.add(tag.trackArtist);
                  recentsListYear.add(tag.year);
                  recentsListCover.add(thumbnailData);
                  notifyListeners();
                } else {
                  int indexToReplace = fileIndex.indexOf(savePath);
                  recentsListTitle[indexToReplace] = tag.title;
                  recentsListArtist[indexToReplace] = tag.trackArtist;
                  recentsListYear[indexToReplace] = tag.year;
                  recentsListCover[indexToReplace] = thumbnailData;
                  replacement = false;
                  notifyListeners();
                }
              }
              progressText = ' Done! File saved to:\n $savePath';
              notifyListeners();
              isDone = false;
              await file.delete();
            }
          }
        }
      } else if (Platform.environment.containsKey('ANDROID_DATA')) {
        var status = await Permission.audio.status;
        if (status.isGranted == false) {
          await Permission.audio.request();
        }
        var musicDir = await Directory('storage/emulated/0/Music').exists();
        if (musicDir == false) {
          var newDirectory = Directory('storage/emulated/0/Music');
          await newDirectory.create(recursive: true);
          final savePathTemp = 'storage/emulated/0/Music/$title.temp.mp3';
          final savePath = 'storage/emulated/0/Music/$title.mp3';
          var file = File(savePathTemp);
          var fileStream = file.openWrite();
          await audioFile.pipe(fileStream);
          var fileExisting = File(savePath);
          if (fileIndex.contains(savePath) && fileIndex.length > 1) {
            fileIndex.removeLast();
            notifyListeners();
          } else {
            fileIndex.add(savePath);
            notifyListeners();
          }
          if (await fileExisting.exists()) {
            await fileExisting.delete();
            progressText = ' Existing file found in:\n /Music/$title.mp3\n Replacing...';
            notifyListeners();
            replacement = true;
          }
          FFmpegKit.execute('-i "$savePathTemp" -q:a 0 -map a -c:a libmp3lame "$savePath"').then((session) async {
            final returnCode = await session.getReturnCode();
            Tag? tag = await _displayTextInputDialog(context, titleMeta, author, "", uploadYear, thumbnailData);
            if (ReturnCode.isSuccess(returnCode) && isCorrect == true) {
              if (tag != null) {
                AudioTags.write(savePath, tag);
                if (replacement == false || recentsListTitle.isEmpty) {
                  recentsListTitle.add(tag.title);
                  recentsListArtist.add(tag.trackArtist);
                  recentsListYear.add(tag.year);
                  recentsListCover.add(thumbnailData);
                  notifyListeners();
                } else {
                  int indexToReplace = fileIndex.indexOf(savePath);
                  recentsListTitle[indexToReplace] = tag.title;
                  recentsListArtist[indexToReplace] = tag.trackArtist;
                  recentsListYear[indexToReplace] = tag.year;
                  recentsListCover[indexToReplace] = thumbnailData;
                  replacement = false;
                  notifyListeners();
                }
              }
              progressText = ' Done! File saved to:\n /Music/$title.mp3';
              notifyListeners();
              FFmpegKit.cancel();
              MediaScanner.loadMedia(path: savePath);
              await file.delete();
            } else {
              progressText = ' Something went wrong with ffmpeg!';
              notifyListeners();
              FFmpegKit.cancel();
              await file.delete();
            }
          });
        } else {
          final savePathTemp = 'storage/emulated/0/Music/$title.temp.mp3';
          final savePath = 'storage/emulated/0/Music/$title.mp3';
          var file = File(savePathTemp);
          var fileStream = file.openWrite();
          await audioFile.pipe(fileStream);
          var fileExisting = File(savePath);
          if (fileIndex.contains(savePath) && fileIndex.isNotEmpty) {
            fileIndex.add(savePath);
            fileIndex.removeLast();
            debugPrint(fileIndex[0]);
            notifyListeners();
          } else {
            fileIndex.add(savePath);
            notifyListeners();
          }
          if (await fileExisting.exists()) {
            await fileExisting.delete();
            progressText = ' Existing file found in:\n /Music/$title.mp3\n Replacing...';
            notifyListeners();
            replacement = true;
          }
          FFmpegKit.execute('-i "$savePathTemp" -q:a 0 -map a -c:a libmp3lame "$savePath"').then((session) async {
            final returnCode = await session.getReturnCode();
            Tag? tag = await _displayTextInputDialog(context, titleMeta, author, "", uploadYear, thumbnailData);
            if (ReturnCode.isSuccess(returnCode) && isCorrect == true) {
              if (tag != null) {
                AudioTags.write(savePath, tag);
                if (replacement == false || recentsListTitle.isEmpty) {
                  recentsListTitle.add(tag.title);
                  recentsListArtist.add(tag.trackArtist);
                  recentsListYear.add(tag.year);
                  recentsListCover.add(thumbnailData);
                  notifyListeners();
                } else {
                  int indexToReplace = fileIndex.indexOf(savePath);
                  recentsListTitle[indexToReplace] = tag.title;
                  recentsListArtist[indexToReplace] = tag.trackArtist;
                  recentsListYear[indexToReplace] = tag.year;
                  recentsListCover[indexToReplace] = thumbnailData;
                  replacement = false;
                  notifyListeners();
                }
              }
              progressText = ' Done! File saved to:\n /Music/$title.mp3';
              notifyListeners();
              FFmpegKit.cancel();
              MediaScanner.loadMedia(path: savePath);
              await file.delete();
            } else {
              progressText = ' Something went wrong with ffmpeg!';
              notifyListeners();
              FFmpegKit.cancel();
              await file.delete();
            }
          });
        }
      }
      ytExplode.close();
    } catch (e)  {
      progressText = ' Something went wrong.\n Please, check the url.';
      notifyListeners();
    }
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  static final GlobalKey<_MyHomePageState> homePageKey = GlobalKey<_MyHomePageState>();

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  var selectedIndex = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_tabController.index != 0) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    return WillPopScope(
      onWillPop: () async {
        FocusManager.instance.primaryFocus?.unfocus();
        return true;
      },
      child: DefaultTabController(
        initialIndex: 0,
        length: 3,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            title: const Text("YT Downloader"),
            centerTitle: true,
            notificationPredicate: (ScrollNotification notification) {
              return notification.depth == 1;
              },
            scrolledUnderElevation: 4.0,
            shadowColor: Theme.of(context).shadowColor,
            bottom: TabBar(
              controller: _tabController,
              tabs: <Widget>[
                Tab(
                  icon: const Icon(Icons.home),
                  text: titles[0],
                ),
                Tab(
                  icon: const Icon(Icons.history),
                  text: titles[1],
                ),
                Tab(
                  icon: const Icon(Icons.info_outline_rounded),
                  text: titles[2],
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
              children: <Widget>[
                HomePage(textController: appState._textController, focusNode: appState._focus, key: MyHomePage.homePageKey,),
                const RecentsPage(),
                const AboutPage()
              ]
          ),
        ),
      ),
    );
  }
  bool get wantKeepAlive => true;
}


class HomePage extends StatelessWidget {
  const HomePage({Key? key, required this.textController, required this.focusNode}) : super(key: key);

  final TextEditingController textController;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    IconData icon;
    icon = Icons.download;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.25,
            width: 400,
            child: Align(
              alignment: Alignment.center,
              child:
                Text(
                  appState.progressText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: TextField(
              controller: textController,
              decoration:  const InputDecoration(
                labelText: 'Enter a valid YouTube video url',
                border: OutlineInputBorder(),
              ),
              focusNode: focusNode,
              autofocus: true,
            ),
          ),
          ElevatedButton.icon(
            style: ButtonStyle(
              minimumSize: MaterialStateProperty.all(const Size(100, 50)),
            ),
            onPressed: () {
              String currentLink = appState.getURL();
              appState.download(currentLink, context);
            },
            icon: Icon(icon),
            label: const Text('Download'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: Text(
              '', // Your dynamic text content here
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }
}

class RecentsPage extends StatelessWidget {
  const RecentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<MyAppState>(
        builder: (context, appState, _) {
          var title = appState.recentsListTitle;
          var artist = appState.recentsListArtist;
          var cover = appState.recentsListCover;
          var year = appState.recentsListYear;
          var fileIndex = appState.fileIndex;
          return fileIndex.isEmpty
           ? ListView.builder(
            itemCount: 1,
            itemBuilder: (BuildContext context, int index) {
              return const ListTile(
                title: Text('There are no recents yet! Download something, so it shows up here!'),
              );
            },
          )
          : ListView.builder(
            itemCount: fileIndex.length,
            itemBuilder: (BuildContext context, int index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.5),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        // Image
                        SizedBox(
                          width: 100, // Adjust the width as needed
                          height: 100, // Adjust the height as needed
                          child: Image.memory(
                            cover[index],
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12), // Add some spacing between image and text
                        // Text information
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Title: ${title[index]}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Artist(s): ${artist[index]}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Year: ${year[index].toString()}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    return ListView(
      shrinkWrap: true,
        children: <Widget>[
          Card(
            color: Theme.of(context).colorScheme.background.withAlpha(0),
            elevation: 0,
            child:
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ListTile(
                  title: Text('Settings',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 14
                    ),
                  ),
                  subtitle: const Text('Select theme',
                    style: TextStyle(
                      fontSize: 18
                    ),
                  ),
                  onTap: () {
                    appState.themeSelector(context);
                  },
                ),
              ),
          ),
          Card(
            color: Theme.of(context).colorScheme.background.withAlpha(0),
            elevation: 0,
            child:
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ListTile(
                  title: Text('About\n',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 14
                    ),
                  ),
                  subtitle: const Text('YouTube Downloader\nMade by Bartosz "BarteQ" Chmiel',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
          ),
              Center(
                  child: Card(child: Image.asset('assets/logo.png', width: 200, height: 200,))
              ),
            ],
    );
  }
}
