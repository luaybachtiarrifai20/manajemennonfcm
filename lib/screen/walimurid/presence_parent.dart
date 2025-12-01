import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/models/siswa.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/api_student_services.dart';
import 'package:manajemensekolah/utils/date_utils.dart';

class PresenceParentPage extends StatefulWidget {
  final Map<String, dynamic> parent;
  final String siswaId; // ID siswa yang merupakan anak dari wali murid

  const PresenceParentPage({
    super.key,
    required this.parent,
    required this.siswaId,
  });

  @override
  PresenceParentPageState createState() => PresenceParentPageState();
}

class PresenceParentPageState extends State<PresenceParentPage> {
  List<dynamic> _absensiData = [];
  Siswa? _siswa;
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();
  final Map<String, int> _monthlySummary = {
    'hadir': 0,
    'terlambat': 0,
    'izin': 0,
    'sakit': 0,
    'alpha': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load data siswa
      final siswaData = await ApiStudentService.getStudent();
      final siswa = siswaData
          .map((s) => Siswa.fromJson(s))
          .firstWhere((s) => s.id == widget.siswaId);

      // Load data absensi
      final absensiData = await ApiService.getAbsensi(siswaId: widget.siswaId);

      // Find the most recent month with data
      DateTime? latestMonth;
      if (absensiData.isNotEmpty) {
        // Parse all dates and find the most recent one
        for (var absen in absensiData) {
          final absenDate = _parseLocalDate(absen['tanggal']);
          if (latestMonth == null || absenDate.isAfter(latestMonth)) {
            latestMonth = absenDate;
          }
        }

        // Set selected month to the month of the most recent attendance record
        if (latestMonth != null) {
          _selectedMonth = DateTime(latestMonth.year, latestMonth.month, 1);
          print(
            '🎯 Auto-selected month with latest data: ${_selectedMonth.month}/${_selectedMonth.year}',
          );
        }
      }

      setState(() {
        _siswa = siswa;
        _absensiData = absensiData;
        _calculateMonthlySummary();
        _isLoading = false;
      });

      print(
        'Loaded ${_absensiData.length} absensi records for student ${_siswa?.nama}',
      );
    } catch (e) {
      print('Error loading parent presence data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _calculateMonthlySummary() {
    // Reset summary
    _monthlySummary.updateAll((key, value) => 0);

    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    print('📅 Selected month: ${_selectedMonth.month}/${_selectedMonth.year}');
    print('📅 Month range: $monthStart to $monthEnd');
    print('📊 Total absensi records: ${_absensiData.length}');

    int matchCount = 0;
    for (var absen in _absensiData) {
      final absenDate = _parseLocalDate(absen['tanggal']);
      final matches =
          absenDate.isAfter(monthStart.subtract(const Duration(days: 1))) &&
          absenDate.isBefore(monthEnd.add(const Duration(days: 1)));

      print(
        '  📌 Record date: ${absen['tanggal']} -> parsed: $absenDate -> matches: $matches',
      );

      if (matches) {
        matchCount++;
        final status = absen['status'] ?? 'alpha';
        _monthlySummary[status] = (_monthlySummary[status] ?? 0) + 1;
      }
    }
    print('✅ Records matching current month: $matchCount');
    print('📈 Summary: $_monthlySummary');
  }

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialEntryMode: DatePickerEntryMode.calendar,
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = picked;
        _calculateMonthlySummary();
      });
    }
  }

  Widget _buildMonthlySummary() {
    final totalDays = _monthlySummary.values.reduce((a, b) => a + b);
    final presentaseKehadiran = totalDays > 0
        ? ((_monthlySummary['hadir']! + _monthlySummary['terlambat']!) /
                  totalDays *
                  100)
              .round()
        : 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header dengan bulan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rekap Bulanan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => _selectMonth(context),
                child: Text(
                  DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Persentase kehadiran
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '$presentaseKehadiran%',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tingkat Kehadiran',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Detail status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                'Hadir',
                _monthlySummary['hadir']!,
                Colors.green,
              ),
              _buildSummaryItem(
                'Terlambat',
                _monthlySummary['terlambat']!,
                Colors.orange,
              ),
              _buildSummaryItem('Izin', _monthlySummary['izin']!, Colors.blue),
              _buildSummaryItem(
                'Sakit',
                _monthlySummary['sakit']!,
                Colors.purple,
              ),
              _buildSummaryItem('Alpha', _monthlySummary['alpha']!, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAbsensiList() {
    final monthAbsensi = _absensiData.where((absen) {
      final absenDate = _parseLocalDate(absen['tanggal']);
      final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final monthEnd = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
      );
      return absenDate.isAfter(monthStart.subtract(const Duration(days: 1))) &&
          absenDate.isBefore(monthEnd.add(const Duration(days: 1)));
    }).toList()..sort((a, b) => b['tanggal'].compareTo(a['tanggal']));

    if (monthAbsensi.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Tidak ada data absensi',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Untuk bulan ${DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth)}',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: monthAbsensi.length,
      itemBuilder: (context, index) {
        final absen = monthAbsensi[index];
        return _buildAbsensiItem(absen);
      },
    );
  }

  Widget _buildAbsensiItem(Map<String, dynamic> absen) {
    final status = absen['status'] ?? 'alpha';
    final tanggal = _parseLocalDate(absen['tanggal']);
    final mataPelajaranNama = absen['mata_pelajaran_nama'] ?? 'Mata Pelajaran';
    final Color statusColor = _getStatusColor(status);
    final String statusText = _getStatusText(status);
    final String hari = DateFormat('EEEE', 'id_ID').format(tanggal);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Strip berwarna di pinggir kiri
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: _getPrimaryColor(),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                ),

                // Background pattern effect
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                // Status badge positioned
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Tanggal
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _getPrimaryColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('dd').format(tanggal),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _getPrimaryColor(),
                              ),
                            ),
                            Text(
                              DateFormat('MMM').format(tanggal),
                              style: TextStyle(
                                fontSize: 10,
                                color: _getPrimaryColor(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Detail absensi
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 80),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hari,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mataPelajaranNama,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat(
                                  'dd MMMM yyyy',
                                  'id_ID',
                                ).format(tanggal),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'izin':
        return Colors.blue;
      case 'sakit':
        return Colors.orange;
      case 'alpha':
        return Colors.red;
      case 'terlambat':
        return Colors.purple;
      default:
        return Colors.green;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'izin':
        return 'Izin';
      case 'sakit':
        return 'Sakit';
      case 'alpha':
        return 'Alpha';
      case 'terlambat':
        return 'Terlambat';
      default:
        return 'Hadir';
    }
  }

  // Helper function to parse date string as local date (not UTC)
  DateTime _parseLocalDate(String dateString) {
    // Gunakan AppDateUtils untuk parsing yang konsisten dan benar
    return AppDateUtils.parseApiDate(dateString) ?? DateTime.now();
  }

  Color _getPrimaryColor() {
    return Color(0xFF9333EA); // Warna purple untuk wali murid
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withOpacity(0.7)],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: _getCardGradient(),
        boxShadow: [
          BoxShadow(
            color: _getPrimaryColor().withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Absensi Anak',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      _siswa?.nama ?? 'Nama Siswa',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Memuat data absensi...'),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info siswa
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person,
                                color: Colors.blue[700],
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _siswa?.nama ?? 'Nama Siswa',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'NIS: ${_siswa?.nis ?? '-'}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    'Kelas: ${_siswa?.kelas ?? '-'}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Summary bulanan
                      _buildMonthlySummary(),

                      // Daftar absensi
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Riwayat Absensi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Expanded(child: _buildAbsensiList()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
