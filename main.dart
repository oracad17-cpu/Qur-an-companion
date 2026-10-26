import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const QuranApp());

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Al-Qur’an Companion', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff08765b)), useMaterial3: true),
    home: const Reader(),
  );
}

class Reader extends StatefulWidget {
  const Reader({super.key});
  @override
  State<Reader> createState() => _ReaderState();
}

class _ReaderState extends State<Reader> {
  final player = AudioPlayer();
  final scroll = ScrollController();
  final List<GlobalKey> verseKeys = [];
  List<dynamic> surahs = [], arabic = [], translation = [], recited = [];
  List<Map<String, String>> translations = [], reciters = [];
  int surah = 1, active = -1, fontIndex = 0, repeat = 1;
  String translationId = 'en.sahih', reciterId = 'ar.alafasy', status = 'Loading…';
  bool playingSequence = false, showTranslation = true;
  final fonts = ['serif', 'sans-serif'];

  @override
  void initState() { super.initState(); initialize(); }
  @override
  void dispose() { playingSequence = false; player.dispose(); scroll.dispose(); super.dispose(); }
  Future<dynamic> api(String path) async {
    final response = await http.get(Uri.parse('https://api.alquran.cloud/v1/$path')).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw Exception('Network error ${response.statusCode}');
    final decoded = jsonDecode(response.body);
    if (decoded['code'] != 200) throw Exception('Content unavailable');
    return decoded['data'];
  }
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      surah = prefs.getInt('surah') ?? 1;
      final results = await Future.wait([api('surah'), api('edition/type/translation'), api('edition/type/versebyverse')]);
      surahs = results[0] as List<dynamic>;
      translations = (results[1] as List).where((e) => ['en', 'yo'].contains(e['language'])).map<Map<String,String>>((e) => {'id': '${e['identifier']}', 'name': '${e['englishName']} (${e['language']})'}).toList();
      // Audio editions are filtered by format; verse-by-verse audio must contain per-ayah URLs.
      reciters = (results[2] as List).where((e) => e['format'] == 'audio').map<Map<String,String>>((e) => {'id': '${e['identifier']}', 'name': '${e['englishName']}'}).toList();
      if (!reciters.any((e) => e['id'] == reciterId)) reciters.insert(0, {'id':'ar.alafasy', 'name':'Mishary Alafasy'});
      if (!translations.any((e) => e['id'] == translationId) && translations.isNotEmpty) translationId = translations.first['id']!;
      await loadSurah();
    } catch (e) { if (mounted) setState(() => status = 'Could not load catalogue. Check your connection and retry. $e'); }
  }
  Future<void> loadSurah() async {
    playingSequence = false; await player.stop();
    setState(() { status = 'Loading Surah $surah…'; active = -1; arabic = []; translation = []; recited = []; });
    try {
      final data = await Future.wait([api('surah/$surah/ar.alafasy'), api('surah/$surah/$translationId'), api('surah/$surah/$reciterId')]);
      if (!mounted) return;
      setState(() {
        arabic = data[0]['ayahs']; translation = data[1]['ayahs']; recited = data[2]['ayahs'];
        verseKeys.clear(); verseKeys.addAll(List.generate(arabic.length, (_) => GlobalKey()));
        status = '${data[0]['englishName']} • ${arabic.length} verses';
      });
      (await SharedPreferences.getInstance()).setInt('surah', surah);
    } catch (e) { if (mounted) setState(() => status = 'Unable to load this edition: $e'); }
  }
  Future<void> playFrom(int start) async {
    if (recited.isEmpty) return;
    playingSequence = false; await player.stop(); playingSequence = true;
    for (int i = start; i < recited.length && playingSequence && mounted; i++) {
      final url = recited[i]['audio']?.toString();
      if (url == null || url.isEmpty) { setState(() => status = 'This reciter has no per-verse audio for verse ${i+1}.'); break; }
      setState(() => active = i);
      final context = verseKeys[i].currentContext;
      if (context != null) Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 450), alignment: 0.18);
      try {
        for (int r = 0; r < repeat && playingSequence; r++) {
          await player.setUrl(url);
          if (!playingSequence) break;
          await player.play(); // Completes at end of the verse, not at a guessed timestamp.
        }
      } catch (e) { if (mounted) setState(() => status = 'Audio playback error: $e'); break; }
    }
    playingSequence = false;
    if (mounted) setState(() {});
  }
  Future<void> stop() async { playingSequence = false; await player.stop(); if (mounted) setState(() => active = -1); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Al-Qur’an Companion'), actions: [IconButton(onPressed: initialize, icon: const Icon(Icons.refresh), tooltip: 'Reload')]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DropdownButton<int>(isExpanded: true, value: surahs.isEmpty ? null : surah, hint: const Text('Choose Surah'), items: surahs.map((s) => DropdownMenuItem(value: s['number'] as int, child: Text('${s['number']}. ${s['englishName']} — ${s['name']}'))).toList(), onChanged: (v) { if(v != null) { surah = v; loadSurah(); } }),
        Text(status, style: Theme.of(context).textTheme.bodySmall),
        if (translations.isNotEmpty) DropdownButton<String>(isExpanded: true, value: translations.any((t) => t['id'] == translationId) ? translationId : null, items: translations.map((t) => DropdownMenuItem(value: t['id'], child: Text('Translation: ${t['name']}', overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) { if(v != null) { translationId = v; loadSurah(); } }),
        if (reciters.isNotEmpty) DropdownButton<String>(isExpanded: true, value: reciters.any((t) => t['id'] == reciterId) ? reciterId : null, items: reciters.map((t) => DropdownMenuItem(value: t['id'], child: Text('Reciter: ${t['name']}', overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) { if(v != null) { reciterId = v; loadSurah(); } }),
        Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          OutlinedButton.icon(onPressed: arabic.isEmpty ? null : () => playFrom(active < 0 ? 0 : active), icon: const Icon(Icons.play_arrow), label: const Text('Read & follow')),
          IconButton(onPressed: stop, icon: const Icon(Icons.stop), tooltip: 'Stop'),
          DropdownButton<int>(value: repeat, items: [1,2,3,5,10].map((n) => DropdownMenuItem(value:n, child: Text('Repeat ×$n'))).toList(), onChanged:(v) => setState(() => repeat = v ?? 1)),
          TextButton(onPressed: () => setState(() => fontIndex = (fontIndex+1)%fonts.length), child: const Text('Arabic font')),
          TextButton(onPressed: () => setState(() => showTranslation = !showTranslation), child: Text(showTranslation ? 'Hide meaning' : 'Show meaning')),
        ]),
      ])),
      Expanded(child: ListView.builder(controller: scroll, itemCount: arabic.length, itemBuilder: (context, i) => Card(
        key: verseKeys[i], margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        color: active == i ? const Color(0xffd2f4e6) : null,
        child: InkWell(onTap: () => playFrom(i), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${surah}:${i+1}   ${active == i ? '▶ Now reciting' : 'Tap to recite'}', style: const TextStyle(color: Color(0xff08765b))),
          const SizedBox(height: 14),
          Text('${arabic[i]['text']}', textDirection: TextDirection.rtl, textAlign: TextAlign.right, style: TextStyle(fontFamily: fonts[fontIndex], fontSize: 29, height: 2.0)),
          if (showTranslation && i < translation.length) ...[const Divider(), Text('${translation[i]['text']}', style: const TextStyle(fontSize: 16, height: 1.5))],
        ]))),
      ))),
    ]),
  );
}
