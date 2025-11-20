// admin_class_activity.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/error_screen.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/services/api_class_activity_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/services/excel_class_activity_service.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/date_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

class AdminClassActivityScreen extends StatefulWidget {
  const AdminClassActivityScreen({super.key});

  @override
  AdminClassActivityScreenState createState() =>
      AdminClassActivityScreenState();
}

class AdminClassActivityScreenState extends State<AdminClassActivityScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _teacherList = [];
  List<dynamic> _classList = []; // Add class list
  List<dynamic> _subjectList = []; // Add subject list
  List<dynamic> _schedule = []; // store schedule for filtering subjects/classes
  List<dynamic> _activityList = [];

  bool _isLoading = true;
  String? _selectedTeacherId;
  String? _selectedTeacherName;
  String? _selectedClassId; // Add selected class ID
  String? _selectedClassName; // Add selected class name
  String? _selectedSubjectId; // selected subject id
  String? _selectedSubjectName; // selected subject name
  bool _showTeacherList = true;
  bool _showSubjectList = false; // Show subject list flag
  bool _showClassList = false; // Add show class list flag
  String? _errorMessage;

  // Search
  final TextEditingController _searchController = TextEditingController();

  // Animations
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // (removed unused day color map - other screens contain day color helpers)

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _loadTeachers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final apiTeacherService = ApiTeacherService();
      final teachers = await apiTeacherService.getTeacher();

      setState(() {
        _teacherList = teachers;
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      _showErrorSnackBar('Failed to load teacher data: $e');
    }
  }

  // Method untuk export data
  Future<void> exportActivities() async {
    if (_activityList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak ada data kegiatan untuk diexport'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ExcelClassActivityService.exportClassActivitiesToExcel(
        activities: _activityList,
        context: context,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error exporting activities: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _onTeacherSelected(String teacherId, String teacherName) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _selectedTeacherId = teacherId;
        _selectedTeacherName = teacherName;
        _showTeacherList = false;
        _showSubjectList = true; // Show subject list first
        _showClassList = false;
      });

      // Fetch schedule for the teacher using getJadwalForForm
      final schedule = await ApiClassActivityService.getJadwalForForm(
        guruId: teacherId,
        tahunAjaran:
            '2024/2025', // You might want to make this dynamic or fetch current academic year
      );

      // store schedule for later subject->class filtering
      _schedule = schedule;

      // Extract unique subjects from schedule (robust against different API shapes)
      final uniqueSubjects = <String, Map<String, dynamic>>{};
      for (var item in schedule) {
        if (item == null || item is! Map) continue;
        final Map<String, dynamic> map = Map<String, dynamic>.from(item);

        // Try several possible locations for subject id/name
        String subjectId = '';
        String subjectName = '';

        subjectId =
            (map['mata_pelajaran_id'] ??
                    map['mata_pelajaran']?['id'] ??
                    map['mata_pelajaran']?['mata_pelajaran_id'])
                ?.toString() ??
            '';
        subjectName =
            (map['mata_pelajaran_nama'] ??
                    map['mata_pelajaran']?['nama'] ??
                    map['mata_pelajaran']?['mata_pelajaran_nama'])
                ?.toString() ??
            '';

        if (subjectId.isEmpty && subjectName.isNotEmpty) {
          // fallback: use name as id (not ideal but prevents omission)
          subjectId = subjectName;
        }

        if (subjectId.isEmpty) continue;

        if (!uniqueSubjects.containsKey(subjectId)) {
          uniqueSubjects[subjectId] = {'id': subjectId, 'nama': subjectName};
        }
      }

      // If schedule didn't contain subjects, fallback to teacher subjects endpoint
      if (uniqueSubjects.isEmpty) {
        try {
          final apiTeacher = ApiTeacherService();
          final subjectsFromApi = await apiTeacher.getSubjectByTeacher(
            teacherId,
          );
          for (var s in subjectsFromApi) {
            if (s == null || s is! Map) continue;
            final sid =
                (s['id'] ??
                        s['mata_pelajaran_id'] ??
                        s['mata_pelajaran']?['id'])
                    ?.toString() ??
                '';
            final sname =
                (s['nama'] ??
                        s['nama_mata_pelajaran'] ??
                        s['mata_pelajaran']?['nama'])
                    ?.toString() ??
                '';
            if (sid.isEmpty && sname.isEmpty) continue;
            final key = sid.isNotEmpty ? sid : sname;
            if (!uniqueSubjects.containsKey(key)) {
              uniqueSubjects[key] = {
                'id': sid.isNotEmpty ? sid : key,
                'nama': sname.isNotEmpty ? sname : key,
              };
            }
          }
        } catch (e) {
          // ignore fallback errors, will show empty state below
          if (kDebugMode) print('Fallback getSubjectByTeacher error: $e');
        }
      }

      setState(() {
        _subjectList = uniqueSubjects.values.toList();
        _classList = [];
        _activityList = [];
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      _showErrorSnackBar('Failed to load subject data: $e');
    }
  }

  Future<void> _onClassSelected(String classId, String className) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _selectedClassId = classId;
        _selectedClassName = className;
        _showClassList = false;
        // _showActivityList is implied when both _showTeacherList and _showClassList are false
      });

      final activities = await ApiClassActivityService.getClassActivityPaginated(
        guruId: _selectedTeacherId,
        kelasId: classId,
        mataPelajaranId: _selectedSubjectId,
        limit:
            100, // Fetch more items since we are not implementing full pagination UI yet
      );

      final List<dynamic> activityList = activities['data'] ?? [];

      setState(() {
        _activityList = activityList;
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      _showErrorSnackBar('Failed to load activity data: $e');
    }
  }

  Future<void> _onSubjectSelected(String subjectId, String subjectName) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _selectedSubjectId = subjectId;
        _selectedSubjectName = subjectName;
        _showSubjectList = false;
        _showClassList = true;
      });

      // Filter schedule for the selected subject and extract unique classes
      final uniqueClasses = <String, Map<String, dynamic>>{};
      for (var item in _schedule) {
        if (item == null || item is! Map) continue;
        final Map<String, dynamic> map = Map<String, dynamic>.from(item);

        // extract subject id/name from possible shapes
        final sid =
            (map['mata_pelajaran_id'] ??
                    map['mata_pelajaran']?['id'] ??
                    map['mata_pelajaran']?['mata_pelajaran_id'])
                ?.toString() ??
            '';
        final sname =
            (map['mata_pelajaran_nama'] ??
                    map['mata_pelajaran']?['nama'] ??
                    map['mata_pelajaran']?['mata_pelajaran_nama'])
                ?.toString() ??
            '';

        // normalize for comparison
        final normSelectedId = subjectId.toString().toLowerCase();
        final normSelectedName = subjectName.toString().toLowerCase();
        final normSid = sid.toLowerCase();
        final normSname = sname.toLowerCase();

        if (sid.isEmpty && sname.isEmpty) continue;

        // match by id or by name (case-insensitive)
        final matchesSubject =
            (normSid.isNotEmpty &&
                (normSid == normSelectedId || normSid == normSelectedName)) ||
            (normSname.isNotEmpty &&
                (normSname == normSelectedName || normSname == normSelectedId));
        if (!matchesSubject) continue;

        final cid = (map['kelas_id'] ?? map['kelas']?['id'])?.toString() ?? '';
        final cname =
            (map['kelas_nama'] ?? map['kelas']?['nama'])?.toString() ?? '';
        if (cid.isEmpty && cname.isEmpty) continue;
        final key = cid.isNotEmpty ? cid : cname;
        if (!uniqueClasses.containsKey(key)) {
          uniqueClasses[key] = {
            'id': cid.isNotEmpty ? cid : key,
            'nama': cname.isNotEmpty ? cname : key,
          };
        }
      }

      // Fallback: if schedule doesn't include classes, derive classes from activities filtered by guru+subject
      if (uniqueClasses.isEmpty) {
        try {
          // First try to fetch kelas options from backend filter-options which
          // now supports filtering by guru_id and mata_pelajaran_id. This is
          // more reliable than searching activity titles when subject ids are
          // not stable strings.
          final filterRes = await ApiClassActivityService.getKegiatanFilterOptions(
            guruId: _selectedTeacherId,
            mataPelajaranId: (subjectId != null && subjectId.isNotEmpty) ? subjectId : null,
          );

          if (filterRes['success'] == true) {
            final data = filterRes['data'] ?? {};
            final kelasOptions = (data['kelas_options'] as List<dynamic>?) ?? [];
            for (var c in kelasOptions) {
              if (c == null || c is! Map) continue;
              final cid = (c['id'] ?? c['kelas_id'])?.toString() ?? '';
              final cname = (c['label'] ?? c['nama'])?.toString() ?? '';
              if (cid.isEmpty && cname.isEmpty) continue;
              final key = cid.isNotEmpty ? cid : cname;
              if (!uniqueClasses.containsKey(key)) {
                uniqueClasses[key] = {'id': cid.isNotEmpty ? cid : key, 'nama': cname.isNotEmpty ? cname : key};
              }
            }
          }

          // If still empty, fall back to scanning activities as before
          if (uniqueClasses.isEmpty) {
            final activitiesRes = await ApiClassActivityService.getClassActivityPaginated(
              guruId: _selectedTeacherId,
              mataPelajaranId: (subjectId.isNotEmpty && subjectId != subjectName) ? subjectId : null,
              search: (subjectId.isNotEmpty && subjectId == subjectName) ? subjectName : null,
              limit: 200,
            );

            final List<dynamic> acts = activitiesRes['data'] ?? [];
            for (var a in acts) {
              if (a == null || a is! Map) continue;
              final Map<String, dynamic> am = Map<String, dynamic>.from(a);

              final cid = (am['kelas_id'] ?? am['kelas']?['id'])?.toString() ?? '';
              final cname = (am['kelas_nama'] ?? am['kelas']?['nama'])?.toString() ?? '';
              if (cid.isEmpty && cname.isEmpty) continue;
              final key = cid.isNotEmpty ? cid : cname;
              if (!uniqueClasses.containsKey(key)) {
                uniqueClasses[key] = {'id': cid.isNotEmpty ? cid : key, 'nama': cname.isNotEmpty ? cname : key};
              }
            }
          }
        } catch (e) {
          if (kDebugMode)
            print('Fallback derive classes from activities error: $e');
        }
      }

      setState(() {
        _classList = uniqueClasses.values.toList();
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      _showErrorSnackBar('Failed to load class data: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _backToTeacherList() {
    setState(() {
      _showTeacherList = true;
      _showSubjectList = false;
      _showClassList = false;
      _selectedTeacherId = null;
      _selectedTeacherName = null;
      _selectedClassId = null;
      _selectedClassName = null;
      _selectedSubjectId = null;
      _selectedSubjectName = null;
      _searchController.clear();
    });
    _animationController.forward();
  }

  void _backToClassList() {
    setState(() {
      _showTeacherList = false;
      _showSubjectList = true;
      _showClassList = false;
      _selectedClassId = null;
      _selectedClassName = null;
      _searchController.clear();
    });
    _animationController.forward();
  }

  void _backToClassFromActivities() {
    setState(() {
      _showTeacherList = false;
      _showSubjectList = false;
      _showClassList = true;
      _selectedClassId = null;
      _selectedClassName = null;
      _searchController.clear();
    });
    _animationController.forward();
  }

  List<dynamic> _getFilteredTeachers() {
    final searchTerm = _searchController.text.toLowerCase();
    return _teacherList.where((teacher) {
      final teacherName = teacher['nama']?.toString().toLowerCase() ?? '';
      final teacherEmail = teacher['email']?.toString().toLowerCase() ?? '';
      final teacherSubject =
          teacher['mata_pelajaran_nama']?.toString().toLowerCase() ?? '';

      return searchTerm.isEmpty ||
          teacherName.contains(searchTerm) ||
          teacherEmail.contains(searchTerm) ||
          teacherSubject.contains(searchTerm);
    }).toList();
  }

  List<dynamic> _getFilteredClasses() {
    final searchTerm = _searchController.text.toLowerCase();
    return _classList.where((cls) {
      final className = cls['nama']?.toString().toLowerCase() ?? '';
      return searchTerm.isEmpty || className.contains(searchTerm);
    }).toList();
  }

  List<dynamic> _getFilteredSubjects() {
    final searchTerm = _searchController.text.toLowerCase();
    return _subjectList.where((subj) {
      final name = subj['nama']?.toString().toLowerCase() ?? '';
      return searchTerm.isEmpty || name.contains(searchTerm);
    }).toList();
  }

  List<dynamic> _getFilteredActivities() {
    final searchTerm = _searchController.text.toLowerCase();
    return _activityList.where((activity) {
      final title = activity['judul']?.toString().toLowerCase() ?? '';
      final subject =
          activity['mata_pelajaran_nama']?.toString().toLowerCase() ?? '';
      final className = activity['kelas_nama']?.toString().toLowerCase() ?? '';
      final description = activity['deskripsi']?.toString().toLowerCase() ?? '';

      return searchTerm.isEmpty ||
          title.contains(searchTerm) ||
          subject.contains(searchTerm) ||
          className.contains(searchTerm) ||
          description.contains(searchTerm);
    }).toList();
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher, int index) {
    final teacherName = teacher['nama']?.toString() ?? 'Nama tidak tersedia';
    final teacherEmail = teacher['email']?.toString() ?? '';

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delay = index * 0.1;
        final animation = CurvedAnimation(
          parent: _animationController,
          curve: Interval(delay, 1.0, curve: Curves.easeOut),
        );

        return FadeTransition(
          opacity: animation,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _onTeacherSelected(teacher['id'].toString(), teacherName),
        child: Container(
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            top: index == 0 ? 0 : 6,
            bottom: 6,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () =>
                  _onTeacherSelected(teacher['id'].toString(), teacherName),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 5,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Strip biru di pinggir kiri
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 6,
                        decoration: BoxDecoration(
                          color: _getPrimaryColor(),
                          borderRadius: BorderRadius.only(
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

                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header dengan nama dan email
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      teacherName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      teacherEmail,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getPrimaryColor().withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _getPrimaryColor().withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  'Guru',
                                  style: TextStyle(
                                    color: _getPrimaryColor(),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 12),

                          // Action button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _buildActionButton(
                                icon: Icons.visibility,
                                label: 'Lihat Kegiatan',
                                color: _getPrimaryColor(),
                                backgroundColor: Colors.white,
                                borderColor: _getPrimaryColor(),
                                onPressed: () => _onTeacherSelected(
                                  teacher['id'].toString(),
                                  teacherName,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> cls, int index) {
    final className = cls['nama']?.toString() ?? 'Nama Kelas';

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delay = index * 0.1;
        final animation = CurvedAnimation(
          parent: _animationController,
          curve: Interval(delay, 1.0, curve: Curves.easeOut),
        );

        return FadeTransition(
          opacity: animation,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _onClassSelected(cls['id'].toString(), className),
        child: Container(
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            top: index == 0 ? 0 : 6,
            bottom: 6,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _onClassSelected(cls['id'].toString(), className),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 5,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getPrimaryColor().withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.class_,
                              color: _getPrimaryColor(),
                            ),
                          ),
                          SizedBox(width: 16),
                          Text(
                            className,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subj, int index) {
    final subjectName = subj['nama']?.toString() ?? 'Mata Pelajaran';

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delay = index * 0.1;
        final animation = CurvedAnimation(
          parent: _animationController,
          curve: Interval(delay, 1.0, curve: Curves.easeOut),
        );

        return FadeTransition(
          opacity: animation,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _onSubjectSelected(subj['id'].toString(), subjectName),
        child: Container(
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            top: index == 0 ? 0 : 6,
            bottom: 6,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () =>
                  _onSubjectSelected(subj['id'].toString(), subjectName),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 5,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getPrimaryColor().withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.menu_book,
                              color: _getPrimaryColor(),
                            ),
                          ),
                          SizedBox(width: 16),
                          Text(
                            subjectName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity, int index) {
    final isAssignment = activity['jenis'] == 'tugas';
    final isSpecificTarget = activity['target'] == 'khusus';

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delay = index * 0.1;
        final animation = CurvedAnimation(
          parent: _animationController,
          curve: Interval(delay, 1.0, curve: Curves.easeOut),
        );

        return FadeTransition(
          opacity: animation,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          top: index == 0 ? 0 : 6,
          bottom: 6,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showActivityDetail(activity),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 5,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Strip biru di pinggir kiri
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 6,
                      decoration: BoxDecoration(
                        color: _getPrimaryColor(),
                        borderRadius: BorderRadius.only(
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

                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header dengan judul dan jenis
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activity['judul'] ?? 'Judul Kegiatan',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    '${activity['mata_pelajaran_nama']} • ${activity['kelas_nama']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getPrimaryColor().withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _getPrimaryColor().withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                isAssignment ? 'TUGAS' : 'MATERI',
                                style: TextStyle(
                                  color: _getPrimaryColor(),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 12),

                        // Informasi tanggal dan hari
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _getPrimaryColor().withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.calendar_today,
                                color: _getPrimaryColor(),
                                size: 16,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tanggal',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  Text(
                                    '${activity['hari']} • ${_formatDate(activity['tanggal'])}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Informasi guru
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _getPrimaryColor().withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.person,
                                color: _getPrimaryColor(),
                                size: 16,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Guru Pengajar',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  Text(
                                    activity['guru_nama'] ?? 'Tidak Diketahui',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Informasi deskripsi
                        if (activity['deskripsi'] != null &&
                            activity['deskripsi'].isNotEmpty) ...[
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: _getPrimaryColor().withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.description,
                                  color: _getPrimaryColor(),
                                  size: 16,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Deskripsi',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 1),
                                    Text(
                                      activity['deskripsi'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],

                        SizedBox(height: 12),

                        // Status dan action buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isSpecificTarget
                                    ? Colors.purple.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSpecificTarget
                                      ? Colors.purple
                                      : Colors.green,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSpecificTarget
                                        ? Icons.person
                                        : Icons.group,
                                    size: 12,
                                    color: isSpecificTarget
                                        ? Colors.purple
                                        : Colors.green,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    isSpecificTarget
                                        ? 'Khusus Siswa'
                                        : 'Semua Siswa',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isSpecificTarget
                                          ? Colors.purple
                                          : Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildActionButton(
                              icon: Icons.visibility,
                              label: 'Detail',
                              color: _getPrimaryColor(),
                              backgroundColor: Colors.white,
                              borderColor: _getPrimaryColor(),
                              onPressed: () => _showActivityDetail(activity),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    Color? backgroundColor,
    Color? borderColor,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor ?? Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActivityDetail(Map<String, dynamic> activity) {
    final languageProvider = context.read<LanguageProvider>();
    final isAssignment = activity['jenis'] == 'tugas';
    final isSpecificTarget = activity['target'] == 'khusus';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header dengan gradient
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: _getCardGradient(),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isAssignment ? Icons.assignment : Icons.menu_book,
                        size: 30,
                        color: _getPrimaryColor(),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      activity['judul'] ?? 'Judul Kegiatan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${activity['mata_pelajaran_nama']} • ${activity['kelas_nama']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailItem(
                      icon: Icons.person,
                      label: 'Guru Pengajar',
                      value: activity['guru_nama'] ?? 'Tidak Diketahui',
                    ),
                    _buildDetailItem(
                      icon: Icons.calendar_today,
                      label: 'Hari',
                      value: activity['hari'] ?? '-',
                    ),
                    _buildDetailItem(
                      icon: Icons.date_range,
                      label: 'Tanggal',
                      value: _formatDate(activity['tanggal']),
                    ),
                    if (isAssignment)
                      _buildDetailItem(
                        icon: Icons.access_time,
                        label: 'Batas Waktu',
                        value: _formatDate(activity['batas_waktu']),
                      ),
                    _buildDetailItem(
                      icon: Icons.category,
                      label: 'Jenis Kegiatan',
                      value: isAssignment ? 'Tugas' : 'Materi',
                    ),
                    _buildDetailItem(
                      icon: Icons.group,
                      label: 'Target Siswa',
                      value: isSpecificTarget ? 'Khusus Siswa' : 'Semua Siswa',
                    ),

                    if (activity['deskripsi'] != null &&
                        activity['deskripsi'].isNotEmpty) ...[
                      SizedBox(height: 16),
                      Text(
                        'Deskripsi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          activity['deskripsi'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],

                    if (activity['judul_bab'] != null ||
                        activity['judul_sub_bab'] != null) ...[
                      SizedBox(height: 16),
                      Text(
                        'Informasi Bab',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 8),
                      if (activity['judul_bab'] != null)
                        _buildDetailItem(
                          icon: Icons.menu_book,
                          label: 'Bab',
                          value: activity['judul_bab']!,
                        ),
                      if (activity['judul_sub_bab'] != null)
                        _buildDetailItem(
                          icon: Icons.bookmark,
                          label: 'Sub Bab',
                          value: activity['judul_sub_bab']!,
                        ),
                    ],

                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Close',
                                'id': 'Tutup',
                              }),
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _getPrimaryColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: _getPrimaryColor()),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor().withOpacity(0.7)],
    );
  }

  String _formatDate(String? date) {
    if (date == null) return '-';
    return AppDateUtils.formatDateString(date, format: 'dd/MM/yyyy');
  }

  Widget _buildTeacherList() {
    final filteredTeachers = _getFilteredTeachers();
    if (filteredTeachers.isEmpty) {
      return EmptyState(
        title: 'Tidak ada guru',
        subtitle: 'Coba sesuaikan pencarian Anda',
        icon: Icons.person_off,
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(top: 8),
      itemCount: filteredTeachers.length,
      itemBuilder: (context, index) {
        return _buildTeacherCard(filteredTeachers[index], index);
      },
    );
  }

  Widget _buildSubjectList() {
    final filteredSubjects = _getFilteredSubjects();
    if (filteredSubjects.isEmpty) {
      return EmptyState(
        title: 'Tidak ada mata pelajaran',
        subtitle: 'Guru ini belum memiliki mata pelajaran',
        icon: Icons.menu_book,
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(top: 8),
      itemCount: filteredSubjects.length,
      itemBuilder: (context, index) {
        return _buildSubjectCard(filteredSubjects[index], index);
      },
    );
  }

  Widget _buildClassList() {
    final filteredClasses = _getFilteredClasses();
    if (filteredClasses.isEmpty) {
      return EmptyState(
        title: 'Tidak ada kelas',
        subtitle: 'Guru ini belum memiliki jadwal kelas',
        icon: Icons.class_outlined,
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(top: 8),
      itemCount: filteredClasses.length,
      itemBuilder: (context, index) {
        return _buildClassCard(filteredClasses[index], index);
      },
    );
  }

  Widget _buildActivityList() {
    final filteredActivities = _getFilteredActivities();
    if (filteredActivities.isEmpty) {
      return EmptyState(
        title: 'Tidak ada kegiatan',
        subtitle: 'Belum ada kegiatan untuk kelas ini',
        icon: Icons.event_busy,
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(top: 8),
      itemCount: filteredActivities.length,
      itemBuilder: (context, index) {
        return _buildActivityCard(filteredActivities[index], index);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        if (_isLoading) {
          return LoadingScreen(
            message: _showTeacherList
                ? languageProvider.getTranslatedText({
                    'en': 'Loading teacher data...',
                    'id': 'Memuat data guru...',
                  })
                : _showClassList
                ? languageProvider.getTranslatedText({
                    'en': 'Loading class data...',
                    'id': 'Memuat data kelas...',
                  })
                : languageProvider.getTranslatedText({
                    'en': 'Loading activities...',
                    'id': 'Memuat kegiatan...',
                  }),
          );
        }

        if (_errorMessage != null) {
          return ErrorScreen(
            errorMessage: _errorMessage!,
            onRetry: _showTeacherList
                ? _loadTeachers
                : _showSubjectList
                ? () {
                    if (_selectedTeacherId != null) {
                      _onTeacherSelected(
                        _selectedTeacherId!,
                        _selectedTeacherName!,
                      );
                    }
                  }
                : _showClassList
                ? () {
                    if (_selectedTeacherId != null &&
                        _selectedSubjectId != null) {
                      // re-open subject (reload classes)
                      _onSubjectSelected(
                        _selectedSubjectId!,
                        _selectedSubjectName!,
                      );
                    }
                  }
                : () {
                    if (_selectedClassId != null) {
                      _onClassSelected(_selectedClassId!, _selectedClassName!);
                    }
                  },
          );
        }

        return Scaffold(
          backgroundColor: Color(0xFFF8F9FA),
          body: Column(
            children: [
              // Header
              Container(
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
                        if (!_showTeacherList)
                          GestureDetector(
                            onTap: _showSubjectList
                                ? _backToTeacherList
                                : _showClassList
                                ? _backToClassList
                                : _backToClassFromActivities,
                            child: Container(
                              margin: EdgeInsets.only(right: 12),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _showTeacherList
                                    ? languageProvider.getTranslatedText({
                                        'en': 'Class Activities',
                                        'id': 'Kegiatan Kelas',
                                      })
                                    : _showSubjectList
                                    ? 'Mata Pelajaran - $_selectedTeacherName'
                                    : _showClassList
                                    ? 'Kelas - $_selectedSubjectName'
                                    : 'Kegiatan - $_selectedClassName',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              // Home button - always visible, returns to app root/home
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).popUntil((route) => route.isFirst);
                                },
                                child: Container(
                                  margin: EdgeInsets.only(left: 12),
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.home,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                _showTeacherList
                                    ? languageProvider.getTranslatedText({
                                        'en': 'Select a teacher',
                                        'id': 'Pilih guru',
                                      })
                                    : _showSubjectList
                                    ? languageProvider.getTranslatedText({
                                        'en': 'Select a subject',
                                        'id': 'Pilih mata pelajaran',
                                      })
                                    : _showClassList
                                    ? languageProvider.getTranslatedText({
                                        'en': 'Select a class',
                                        'id': 'Pilih kelas',
                                      })
                                    : languageProvider.getTranslatedText({
                                        'en': 'View activities',
                                        'id': 'Lihat kegiatan',
                                      }),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() {}),
                        style: TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: _showTeacherList
                              ? 'Cari guru...'
                              : _showSubjectList
                              ? 'Cari mata pelajaran...'
                              : _showClassList
                              ? 'Cari kelas...'
                              : 'Cari kegiatan...',
                          hintStyle: TextStyle(color: Colors.grey),
                          prefixIcon: Icon(Icons.search, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: _showTeacherList
                    ? _buildTeacherList()
                    : _showSubjectList
                    ? _buildSubjectList()
                    : _showClassList
                    ? _buildClassList()
                    : _buildActivityList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
