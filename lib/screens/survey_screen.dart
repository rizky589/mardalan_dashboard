import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/survey_provider.dart';
import '../services/location_service.dart';

const _orange = Color(0xFFFF9800);
const _darkOrange = Color(0xFFEF7D00);
const _brown = Color(0xFF795548);
const _cream = Color(0xFFFFF7ED);
const _ink = Color(0xFF2D2F35);

class SurveyScreen extends StatefulWidget {
  @override
  _SurveyScreenState createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  String _view = 'home';
  String _selectedSurvey = 'Sensus Ekonomi 2026 UB';
  final List<String> _history = [];
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    LocationService.instance.initialize();
    _ticker = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        title: Text(_title,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        leading: _view == 'home'
            ? Icon(Icons.home)
            : IconButton(icon: Icon(Icons.arrow_back), onPressed: _goBack),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              auth.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(auth)),
    );
  }

  String get _title {
    if (_view == 'home') return 'mardalan';
    if (_view == 'submenu') return _selectedSurvey;
    if (_view == 'history') return 'History Tracking';
    return 'Live Tracking';
  }

  Widget _buildBody(AuthProvider auth) {
    if (_view == 'submenu') return _buildSubMenu();
    if (_view == 'live') return _buildLiveTracking();
    if (_view == 'history') return _buildHistoryTracking();
    return _buildHome(auth);
  }

  void _goBack() {
    setState(() {
      if (_view == 'live' || _view == 'history') {
        _view = 'submenu';
      } else {
        _view = 'home';
      }
    });
  }

  Widget _buildHome(AuthProvider auth) {
    final surveys = ['Sensus Ekonomi 2026 UB', 'Sensus Ekonomi 2026 UMKM'];
    return SingleChildScrollView(
      padding: EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_orange, _darkOrange]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: _orange.withOpacity(.25),
                    blurRadius: 18,
                    offset: Offset(0, 8))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Halo, ${auth.currentUser?['name'] ?? 'Petugas'}',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Login sebagai ${auth.currentUser?['role'] ?? 'PCL'}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(.86),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 12),
                Icon(Icons.navigation, color: Colors.white, size: 34),
                SizedBox(height: 12),
                Text('Welcome to MARDALAN',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
                SizedBox(height: 5),
                Text('',
                    style: TextStyle(
                        color: Colors.white.withOpacity(.9), height: 1.4)),
              ],
            ),
          ),
          SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                  child: Text('Daftar Survei',
                      style:
                          TextStyle(fontWeight: FontWeight.w900, color: _ink))),
              TextButton.icon(
                onPressed: () => setState(() {}),
                icon: Icon(Icons.refresh, size: 16),
                label: Text('Refresh'),
                style: TextButton.styleFrom(foregroundColor: _orange),
              ),
            ],
          ),
          ...surveys.map((survey) => _surveyCard(survey)),
        ],
      ),
    );
  }

  Widget _surveyCard(String survey) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: _brown,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() {
            _selectedSurvey = survey;
            _view = 'submenu';
          }),
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.14),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.map_outlined, color: Colors.white),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(survey,
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900)),
                      SizedBox(height: 3),
                      Text('Tap to open tracking menu',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubMenu() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Sub Menu Survei'),
          SizedBox(height: 10),
          Text(
              'Setelah memilih survei, petugas diarahkan ke halaman sub menu survei dengan sub menu:',
              style: TextStyle(color: Colors.grey[700], height: 1.45)),
          SizedBox(height: 22),
          _submenuCard(
            icon: Icons.my_location,
            title: 'Live Tracking',
            subtitle: 'Pilih Live Tracking untuk memulai tracking.',
            onTap: () => setState(() => _view = 'live'),
          ),
          _submenuCard(
            icon: Icons.history,
            title: 'History Tracking',
            subtitle: 'Untuk melihat history tracking yang telah dilakukan.',
            onTap: () => setState(() => _view = 'history'),
          ),
        ],
      ),
    );
  }

  Widget _submenuCard(
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return Container(
      margin: EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(15),
            child: Row(
              children: [
                CircleAvatar(
                    backgroundColor: _cream, child: Icon(icon, color: _orange)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontWeight: FontWeight.w900, color: _ink)),
                      SizedBox(height: 4),
                      Text(subtitle,
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12.5)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[500]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveTracking() {
    return Consumer2<AuthProvider, SurveyProvider>(
      builder: (context, auth, survey, _) {
        final isPml = (auth.currentUser?['role'] ?? 'PCL') == 'PML';
        return SingleChildScrollView(
          padding: EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Live Tracking'),
              SizedBox(height: 16),
              Container(
                height: 330,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(.08),
                          blurRadius: 18,
                          offset: Offset(0, 8)),
                    ]),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(children: [
                      Positioned.fill(
                          child: CustomPaint(
                              painter: _MapPreviewPainter(
                                  active: survey.isSurveyActive))),
                      Positioned(
                          left: 12,
                          top: 12,
                          child: _mapTool(
                              Icons.my_location,
                              'Current Location',
                              () => _message(
                                  'Mengarahkan ke posisi saat ini.', _orange))),
                      Positioned(
                          right: 12,
                          top: 72,
                          child: _mapTool(
                              Icons.zoom_out_map,
                              'Zoom To Selected Polygon',
                              () => _message(
                                  'Mengarahkan peta ke polygon wilayah tugas.',
                                  _orange))),
                      Positioned(
                          right: 12,
                          top: 132,
                          child: _mapTool(
                              Icons.near_me,
                              'Near Me',
                              () => _message(
                                  'Menampilkan prelist SBR di sekitar lokasi saat ini.',
                                  _orange))),
                      if (isPml)
                        Positioned(
                            right: 12,
                            top: 192,
                            child: _mapTool(
                                Icons.person_pin_circle,
                                'Posisi PCL',
                                () => _message(
                                    'Menampilkan posisi terakhir PCL.',
                                    _orange))),
                      if (isPml)
                        Positioned(
                            left: 12,
                            top: 72,
                            child: _mapTool(Icons.route, 'Track Lokasi Petugas',
                                () => setState(() => _view = 'history'))),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 16,
                        child: ElevatedButton(
                          onPressed: survey.isLoading
                              ? null
                              : () => survey.isSurveyActive
                                  ? _stopTracking(survey)
                                  : _startTracking(survey, auth),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: survey.isSurveyActive
                                ? Colors.red[700]
                                : _brown,
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 46),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                              survey.isSurveyActive
                                  ? 'Stop Tracking'
                                  : 'Start Tracking',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ])),
              ),
              SizedBox(height: 22),
              _featureList(isPml),
              SizedBox(height: 18),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                        text: '',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    TextSpan(
                      text: '',
                    ),
                  ],
                ),
                style: TextStyle(fontSize: 15, height: 1.45, color: _ink),
              ),
              SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                        text: '',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    TextSpan(text: ''),
                  ],
                ),
                style: TextStyle(fontSize: 15, height: 1.45, color: _ink),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mapTool(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: _orange, size: 21),
          ),
        ),
      ),
    );
  }

  Widget _featureList(bool isPml) {
    final features = [
      ['01', 'Current Location', 'Untuk mengarahkan ke posisi saat ini'],
      [
        '02',
        'Zoom To Selected Polygon',
        'Untuk mengarahkan ke polygon sesuai wilayah tugas'
      ],
      ['03', 'Near Me', 'Menampilkan prelist SBR di sekitar lokasi saat ini'],
      if (isPml)
        ['04', 'Lihat Posisi Terakhir PCL', 'Menampilkan posisi terakhir PCL'],
      if (isPml)
        ['05', 'Track Lokasi Petugas', 'Menampilkan history terakhir PCL'],
    ];
    return Column(
        children: features
            .map((item) => _featureItem(item[0], item[1], item[2]))
            .toList());
  }

  Widget _featureItem(String number, String title, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
              radius: 17,
              backgroundColor: _orange,
              child: Text(number,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900))),
          SizedBox(width: 11),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      color: title.contains('Zoom')
                          ? Colors.green
                          : title.contains('Lihat') || title.contains('Track')
                              ? Colors.blue
                              : _ink,
                      fontWeight: FontWeight.w900)),
              Text(text,
                  style: TextStyle(
                      color: Colors.grey[700], fontSize: 12.5, height: 1.35)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTracking() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('History Tracking'),
          SizedBox(height: 16),
          Container(
            height: 230,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                    painter:
                        _MapPreviewPainter(active: true, historyMode: true),
                    child: Container())),
          ),
          SizedBox(height: 18),
          _historyAction(
              '01',
              'Filter History Tracking by date',
              'Menampilkan History Tracking sesuai tanggal yang dipilih',
              Icons.calendar_month,
              () =>
                  _message('Filter tanggal history tracking aktif.', _orange)),
          _historyAction(
              '02',
              'Synchronization Status',
              'Status sinkronisasi ke server',
              Icons.cloud_done_outlined,
              () => _message(
                  'Status sinkronisasi: data lokal akan dikirim saat online.',
                  Colors.green)),
          _historyAction(
              '03',
              'Delete Data From Local',
              'Menghapus history dari penyimpanan lokal',
              Icons.delete_outline,
              () => setState(() {
                    _history.clear();
                    _message('History lokal dihapus.', Colors.red);
                  })),
          SizedBox(height: 16),
          ...(_history.isEmpty
                  ? ['Belum ada history tracking lokal.']
                  : _history)
              .map((item) => _historyTile(item)),
        ],
      ),
    );
  }

  Widget _historyAction(String number, String title, String text, IconData icon,
      VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                    backgroundColor: _orange,
                    child: Text(number,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12))),
                SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Icon(icon, color: _orange, size: 18),
                        SizedBox(width: 6),
                        Expanded(
                            child: Text(title,
                                style: TextStyle(
                                    fontWeight: FontWeight.w900, color: _ink)))
                      ]),
                      SizedBox(height: 3),
                      Text(text,
                          style: TextStyle(
                              color: Colors.grey[700], fontSize: 12.5)),
                    ])),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _historyTile(String item) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(13),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(Icons.location_on, color: _orange),
        SizedBox(width: 10),
        Expanded(child: Text(item, style: TextStyle(color: _ink))),
      ]),
    );
  }

  Widget _sectionTitle(String text) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(text,
          style: TextStyle(
              color: _ink,
              fontSize: 25,
              height: 1.05,
              fontWeight: FontWeight.w900)),
      SizedBox(height: 11),
      Container(width: 44, height: 3, color: _orange),
    ]);
  }

  Future<void> _startTracking(SurveyProvider survey, AuthProvider auth) async {
    final ok = await survey.startSurvey(
        auth.currentUser?['id'] ?? 'petugas', _selectedSurvey);
    if (ok) {
      setState(() => _history.insert(0,
          '${DateFormat('HH:mm:ss').format(DateTime.now())} - Start Tracking $_selectedSurvey'));
      _message(
          'Tracking dimulai. Background process dan sinkronisasi otomatis aktif.',
          Colors.green);
    } else {
      _message(survey.error ?? 'Gagal memulai tracking', Colors.red);
    }
  }

  Future<void> _stopTracking(SurveyProvider survey) async {
    final ok = await survey.endSurvey();
    if (ok) {
      setState(() => _history.insert(0,
          '${DateFormat('HH:mm:ss').format(DateTime.now())} - Stop Tracking $_selectedSurvey'));
      _message('Tracking selesai.', _orange);
    } else {
      _message(survey.error ?? 'Gagal menghentikan tracking', Colors.red);
    }
  }

  void _message(String text, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }
}

class _MapPreviewPainter extends CustomPainter {
  final bool active;
  final bool historyMode;

  _MapPreviewPainter({required this.active, this.historyMode = false});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Color(0xFFEFE7DA);
    canvas.drawRect(Offset.zero & size, bg);

    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final roadLine = Paint()
      ..color = Color(0xFFD0C6B8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final orange = Paint()
      ..color = _orange
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * .12, size.height * .85)
      ..cubicTo(size.width * .25, size.height * .55, size.width * .48,
          size.height * .62, size.width * .55, size.height * .35)
      ..cubicTo(size.width * .65, size.height * .02, size.width * .82,
          size.height * .2, size.width * .9, size.height * .08);
    canvas.drawPath(path, road);
    canvas.drawPath(path, roadLine);
    if (active) canvas.drawPath(path, orange);

    final rnd = Random(7);
    final dotPaint = Paint()..color = _brown.withOpacity(.72);
    final activeDot = Paint()..color = _orange;
    for (int i = 0; i < 42; i++) {
      final point =
          Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      canvas.drawCircle(point, 4, dotPaint);
      canvas.drawCircle(
          point, 2.2, Paint()..color = Colors.white.withOpacity(.75));
    }

    final marker = Offset(
        size.width * .55, historyMode ? size.height * .38 : size.height * .48);
    canvas.drawCircle(marker, 13, Paint()..color = Colors.white);
    canvas.drawCircle(marker, 9, activeDot);
    canvas.drawCircle(marker, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _MapPreviewPainter oldDelegate) {
    return oldDelegate.active != active ||
        oldDelegate.historyMode != historyMode;
  }
}
