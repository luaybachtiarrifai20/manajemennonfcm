import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  static const String ENGLISH = 'en';
  static const String INDONESIAN = 'id';

  String _currentLanguage = INDONESIAN;

  String get currentLanguage => _currentLanguage;

  Future<void> setLanguage(String language) async {
    _currentLanguage = language;

    // Save to shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);

    notifyListeners(); // Notify all listeners about the change
  }

  // Load saved language
  Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString('language') ?? INDONESIAN;
    _currentLanguage = savedLanguage;
    notifyListeners();
  }

  String getTranslatedText(Map<String, String> translations) {
    return translations[_currentLanguage] ?? translations[INDONESIAN] ?? '';
  }
}

// Singleton instance
LanguageProvider languageProvider = LanguageProvider();

// Extension untuk memudahkan penggunaan
extension LocalizedString on Map<String, String> {
  String get tr {
    return languageProvider.getTranslatedText(this);
  }
}

class AppLocalizations {
  // Dashboard
  static Map<String, String> get appTitle => {
    'en': 'School Management',
    'id': 'Manajemen Sekolah',
  };

  // Tambahkan di class AppLocalizations

  // Class Management
  static Map<String, String> get editClass => {
    'en': 'Edit Class',
    'id': 'Edit Kelas',
  };

  static Map<String, String> get addClass => {
    'en': 'Add Class',
    'id': 'Tambah Kelas',
  };

  static Map<String, String> get className => {
    'en': 'Class Name',
    'id': 'Nama Kelas',
  };

  static Map<String, String> get classNameRequired => {
    'en': 'Class name is required',
    'id': 'Nama kelas harus diisi',
  };

  static Map<String, String> get gradeLevel => {
    'en': 'Grade Level',
    'id': 'Tingkat Kelas',
  };

  static Map<String, String> get retry => {
    'en': 'Retry',
    'id': 'Ulang',
  };

  static Map<String, String> get gradeLevelRequired => {
    'en': 'Grade level is required',
    'id': 'Tingkat kelas harus dipilih',
  };

  static Map<String, String> get selectGradeLevel => {
    'en': 'Select Grade Level',
    'id': 'Pilih Tingkat Kelas',
  };

  static Map<String, String> get homeroomTeacher => {
    'en': 'Homeroom Teacher',
    'id': 'Wali Kelas',
  };

  static Map<String, String> get noTeacher => {
    'en': 'No Teacher',
    'id': 'Tidak Ada Guru',
  };

  static Map<String, String> get update => {'en': 'Update', 'id': 'Perbarui'};

  static Map<String, String> get classDetails => {
    'en': 'Class Details',
    'id': 'Detail Kelas',
  };

  static Map<String, String> get numberOfStudents => {
    'en': 'Number of Students',
    'id': 'Jumlah Siswa',
  };

  static Map<String, String> get notAssigned => {
    'en': 'Not assigned',
    'id': 'Tidak ada',
  };

  static Map<String, String> get classesFound => {
    'en': 'classes found',
    'id': 'kelas ditemukan',
  };

  static Map<String, String> get noClasses => {
    'en': 'No classes',
    'id': 'Tidak ada kelas',
  };

  static Map<String, String> get tapToAddClass => {
    'en': 'Tap + to add a class',
    'id': 'Tap + untuk menambah kelas',
  };

  static Map<String, String> get searchClasses => {
    'en': 'Search classes...',
    'id': 'Cari kelas...',
  };

  static Map<String, String> get loadingClassData => {
    'en': 'Loading class data...',
    'id': 'Memuat data kelas...',
  };

  static Map<String, String> get classSuccessfullyUpdated => {
    'en': 'Class successfully updated',
    'id': 'Kelas berhasil diperbarui',
  };

  static Map<String, String> get classSuccessfullyAdded => {
    'en': 'Class successfully added',
    'id': 'Kelas berhasil ditambahkan',
  };

  static Map<String, String> get classSuccessfullyDeleted => {
    'en': 'Class successfully deleted',
    'id': 'Kelas berhasil dihapus',
  };

  static Map<String, String> get failedToSaveClass => {
    'en': 'Failed to save class',
    'id': 'Gagal menyimpan kelas',
  };

  static Map<String, String> get failedToDeleteClass => {
    'en': 'Failed to delete class',
    'id': 'Gagal menghapus kelas',
  };

  static Map<String, String> get areYouSureDeleteClass => {
    'en': 'Are you sure you want to delete this class?',
    'id': 'Apakah Anda yakin ingin menghapus kelas ini?',
  };

  // Filter Options
  static Map<String, String> get all => {'en': 'All', 'id': 'Semua'};

  static Map<String, String> get withHomeroomTeacher => {
    'en': 'With Homeroom Teacher',
    'id': 'Dengan Wali Kelas',
  };

  static Map<String, String> get withoutHomeroomTeacher => {
    'en': 'Without Homeroom Teacher',
    'id': 'Tanpa Wali Kelas',
  };

  static Map<String, String> get welcome => {
    'en': 'Welcome,',
    'id': 'Selamat datang,',
  };

  static Map<String, String> get activeAccount => {
    'en': 'Active account',
    'id': 'Akun aktif',
  };

  static Map<String, String> get searchHint => {
    'en': 'Search features, data, or menus...',
    'id': 'Cari fitur, data, atau menu...',
  };

  static Map<String, String> get logout => {'en': 'Logout', 'id': 'Keluar'};

  // Common
  static Map<String, String> get save => {'en': 'Save', 'id': 'Simpan'};

  static Map<String, String> get cancel => {'en': 'Cancel', 'id': 'Batal'};

  static Map<String, String> get edit => {'en': 'Edit', 'id': 'Edit'};

  static Map<String, String> get delete => {'en': 'Delete', 'id': 'Hapus'};

  static Map<String, String> get add => {'en': 'Add', 'id': 'Tambah'};

  static Map<String, String> get refresh => {
    'en': 'Refresh',
    'id': 'Muat Ulang',
  };

  static Map<String, String> get search => {'en': 'Search', 'id': 'Cari'};

  static Map<String, String> get loading => {
    'en': 'Loading...',
    'id': 'Memuat...',
  };

  static Map<String, String> get noData => {
    'en': 'No data',
    'id': 'Tidak ada data',
  };

  static Map<String, String> get noSearchResults => {
    'en': 'No search results found',
    'id': 'Tidak ditemukan hasil pencarian',
  };

  // Menu Items
  static Map<String, String> get manageStudents => {
    'en': 'Manage Students',
    'id': 'Kelola Siswa',
  };

  static Map<String, String> get manageTeachers => {
    'en': 'Manage Teachers',
    'id': 'Kelola Guru',
  };

  static Map<String, String> get manageClasses => {
    'en': 'Manage Classes',
    'id': 'Kelola Kelas',
  };

  static Map<String, String> get manageSubjects => {
    'en': 'Manage Subjects',
    'id': 'Kelola Mata Pelajaran',
  };

  static Map<String, String> get manageTeachingSchedule => {
    'en': 'Manage Schedule',
    'id': 'Kelola Jadwal',
  };

  static Map<String, String> get reports => {'en': 'Reports', 'id': 'Laporan'};

  static Map<String, String> get finance => {'en': 'Finance', 'id': 'Keuangan'};

  static Map<String, String> get announcements => {
    'en': 'Announcements',
    'id': 'Pengumuman',
  };

  static Map<String, String> get studentAttendance => {
    'en': 'Student Attendance',
    'id': 'Absensi Siswa',
  };

  static Map<String, String> get inputGrades => {
    'en': 'Input Grades',
    'id': 'Input Nilai',
  };

  static Map<String, String> get teachingSchedule => {
    'en': 'Teaching Schedule',
    'id': 'Jadwal Mengajar',
  };

  static Map<String, String> get classActivities => {
    'en': 'Class Activities',
    'id': 'Kegiatan Kelas',
  };

  static Map<String, String> get rppLearningMaterials => {
    'en': 'Learning Materials',
    'id': 'Materi Pembelajaran',
  };

  // TAMBAHKAN MENU RPP
  static Map<String, String> get myRpp => {
    'en': 'My Lesson Plans',
    'id': 'RPP Saya',
  };

  static Map<String, String> get manageRpp => {
    'en': 'Manage Lesson Plans',
    'id': 'Kelola RPP',
  };

  // Tambahkan di class AppLocalizations
  static Map<String, String> get tryAgain => {
    'en': 'Try Again',
    'id': 'Coba Lagi',
  };

  static Map<String, String> get close => {'en': 'Close', 'id': 'Tutup'};

  // Role Titles
  static Map<String, String> get adminRole => {'en': 'Admin', 'id': 'Admin'};

  static Map<String, String> get teacherRole => {'en': 'Teacher', 'id': 'Guru'};

  static Map<String, String> get staffRole => {'en': 'Staff', 'id': 'Staff'};

  static Map<String, String> get parentRole => {
    'en': 'Parent',
    'id': 'Wali Murid',
  };

  // Login Screen
  static Map<String, String> get login => {'en': 'Login', 'id': 'Masuk'};

  static Map<String, String> get email => {'en': 'Email', 'id': 'Email'};

  static Map<String, String> get password => {
    'en': 'Password',
    'id': 'Kata Sandi',
  };

  static Map<String, String> get forgotPassword => {
    'en': 'Forgot Password?',
    'id': 'Lupa Kata Sandi?',
  };

  static Map<String, String> get loginSuccess => {
    'en': 'Login Successful',
    'id': 'Login Berhasil',
  };

  static Map<String, String> get loginError => {
    'en': 'Login Failed',
    'id': 'Login Gagal',
  };

  // Confirmation dialogs
  static Map<String, String> get confirmDelete => {
    'en': 'Confirm Delete',
    'id': 'Konfirmasi Hapus',
  };

  static Map<String, String> get areYouSure => {
    'en': 'Are you sure?',
    'id': 'Apakah Anda yakin?',
  };

  // Form fields
  static Map<String, String> get name => {'en': 'Name', 'id': 'Nama'};

  static Map<String, String> get class_ => {'en': 'Class', 'id': 'Kelas'};

  static Map<String, String> get subject => {
    'en': 'Subject',
    'id': 'Mata Pelajaran',
  };

  static Map<String, String> get teacher => {'en': 'Teacher', 'id': 'Guru'};

  static Map<String, String> get schedule => {'en': 'Schedule', 'id': 'Jadwal'};

  // Success messages
  static Map<String, String> get success => {'en': 'Success', 'id': 'Berhasil'};

  static Map<String, String> get error => {'en': 'Error', 'id': 'Error'};

  // Time related
  static Map<String, String> get startTime => {
    'en': 'Start Time',
    'id': 'Jam Mulai',
  };

  static Map<String, String> get endTime => {
    'en': 'End Time',
    'id': 'Jam Selesai',
  };

  static Map<String, String> get day => {'en': 'Day', 'id': 'Hari'};

  // ========== TAMBAHAN UNTUK FITUR RPP ==========

  // RPP Screen Titles
  static Map<String, String> get rpp => {
    'en': 'Lesson Plan',
    'id': 'Rencana Pelaksanaan Pembelajaran',
  };

  static Map<String, String> get rppList => {
    'en': 'Lesson Plan List',
    'id': 'Daftar RPP',
  };

  static Map<String, String> get createRpp => {
    'en': 'Create Lesson Plan',
    'id': 'Buat RPP',
  };

  static Map<String, String> get editRpp => {
    'en': 'Edit Lesson Plan',
    'id': 'Edit RPP',
  };

  // RPP Status
  static Map<String, String> get status => {'en': 'Status', 'id': 'Status'};

  static Map<String, String> get pending => {'en': 'Pending', 'id': 'Menunggu'};

  static Map<String, String> get approved => {
    'en': 'Approved',
    'id': 'Disetujui',
  };

  static Map<String, String> get rejected => {
    'en': 'Rejected',
    'id': 'Ditolak',
  };

  // RPP Form Fields
  static Map<String, String> get title => {'en': 'Title', 'id': 'Judul'};

  static Map<String, String> get semester => {
    'en': 'Semester',
    'id': 'Semester',
  };

  static Map<String, String> get academicYear => {
    'en': 'Academic Year',
    'id': 'Tahun Ajaran',
  };

  static Map<String, String> get coreCompetence => {
    'en': 'Core Competence',
    'id': 'Kompetensi Inti',
  };

  static Map<String, String> get basicCompetence => {
    'en': 'Basic Competence',
    'id': 'Kompetensi Dasar',
  };

  static Map<String, String> get indicators => {
    'en': 'Indicators',
    'id': 'Indikator',
  };

  static Map<String, String> get learningObjectives => {
    'en': 'Learning Objectives',
    'id': 'Tujuan Pembelajaran',
  };

  static Map<String, String> get learningMaterials => {
    'en': 'Learning Materials',
    'id': 'Materi Pembelajaran',
  };

  static Map<String, String> get learningMethods => {
    'en': 'Learning Methods',
    'id': 'Metode Pembelajaran',
  };

  static Map<String, String> get mediaTools => {
    'en': 'Media & Tools',
    'id': 'Media dan Alat',
  };

  static Map<String, String> get learningResources => {
    'en': 'Learning Resources',
    'id': 'Sumber Belajar',
  };

  static Map<String, String> get learningActivities => {
    'en': 'Learning Activities',
    'id': 'Kegiatan Pembelajaran',
  };

  static Map<String, String> get assessment => {
    'en': 'Assessment',
    'id': 'Penilaian',
  };

  static Map<String, String> get attachment => {
    'en': 'Attachment',
    'id': 'Lampiran',
  };

  // RPP Actions
  static Map<String, String> get createNewRpp => {
    'en': 'Create New Lesson Plan',
    'id': 'Buat RPP Baru',
  };

  static Map<String, String> get viewRpp => {
    'en': 'View Lesson Plan',
    'id': 'Lihat RPP',
  };

  static Map<String, String> get downloadRpp => {
    'en': 'Download Lesson Plan',
    'id': 'Unduh RPP',
  };

  static Map<String, String> get uploadFile => {
    'en': 'Upload File',
    'id': 'Unggah File',
  };

  static Map<String, String> get chooseFile => {
    'en': 'Choose File',
    'id': 'Pilih File',
  };

  static Map<String, String> get fileSelected => {
    'en': 'File Selected',
    'id': 'File Terpilih',
  };

  // RPP Messages
  static Map<String, String> get noRppAvailable => {
    'en': 'No lesson plans available',
    'id': 'Belum ada RPP',
  };

  static Map<String, String> get rppCreatedSuccess => {
    'en': 'Lesson plan created successfully',
    'id': 'RPP berhasil dibuat',
  };

  static Map<String, String> get rppUpdatedSuccess => {
    'en': 'Lesson plan updated successfully',
    'id': 'RPP berhasil diperbarui',
  };

  static Map<String, String> get rppDeletedSuccess => {
    'en': 'Lesson plan deleted successfully',
    'id': 'RPP berhasil dihapus',
  };

  static Map<String, String> get rppStatusUpdated => {
    'en': 'Lesson plan status updated',
    'id': 'Status RPP berhasil diupdate',
  };

  // File Upload
  static Map<String, String> get fileUploadSuccess => {
    'en': 'File uploaded successfully',
    'id': 'File berhasil diunggah',
  };

  static Map<String, String> get fileUploadError => {
    'en': 'File upload failed',
    'id': 'Gagal mengunggah file',
  };

  static Map<String, String> get invalidFileType => {
    'en': 'Invalid file type. Please upload Word or PDF files only.',
    'id': 'Tipe file tidak valid. Harap unggah file Word atau PDF saja.',
  };

  static Map<String, String> get fileTooLarge => {
    'en': 'File too large. Maximum size is 10MB.',
    'id': 'File terlalu besar. Ukuran maksimal 10MB.',
  };

  // Admin RPP Management
  static Map<String, String> get allRpp => {
    'en': 'All Lesson Plans',
    'id': 'Semua RPP',
  };

  static Map<String, String> get filterByStatus => {
    'en': 'Filter by Status',
    'id': 'Filter Berdasarkan Status',
  };

  static Map<String, String> get teacherName => {
    'en': 'Teacher Name',
    'id': 'Nama Guru',
  };

  static Map<String, String> get subjectName => {
    'en': 'Subject Name',
    'id': 'Nama Mata Pelajaran',
  };

  // static Map<String, String> get className => {
  //   'en': 'Class Name',
  //   'id': 'Nama Kelas',
  // };

  static Map<String, String> get creationDate => {
    'en': 'Creation Date',
    'id': 'Tanggal Dibuat',
  };

  static Map<String, String> get updateStatus => {
    'en': 'Update Status',
    'id': 'Update Status',
  };

  static Map<String, String> get adminNotes => {
    'en': 'Admin Notes',
    'id': 'Catatan Admin',
  };

  static Map<String, String> get notesOptional => {
    'en': 'Notes (Optional)',
    'id': 'Catatan (Opsional)',
  };

  static Map<String, String> get approveRpp => {
    'en': 'Approve Lesson Plan',
    'id': 'Setujui RPP',
  };

  static Map<String, String> get rejectRpp => {
    'en': 'Reject Lesson Plan',
    'id': 'Tolak RPP',
  };

  // RPP Details
  static Map<String, String> get rppDetails => {
    'en': 'Lesson Plan Details',
    'id': 'Detail RPP',
  };

  static Map<String, String> get basicInfo => {
    'en': 'Basic Information',
    'id': 'Informasi Dasar',
  };

  static Map<String, String> get learningComponents => {
    'en': 'Learning Components',
    'id': 'Komponen Pembelajaran',
  };

  static Map<String, String> get assessmentMethods => {
    'en': 'Assessment Methods',
    'id': 'Metode Penilaian',
  };

  // Empty States
  static Map<String, String> get noRppCreated => {
    'en': 'No lesson plans created yet',
    'id': 'Belum ada RPP yang dibuat',
  };

  static Map<String, String> get clickPlusToCreate => {
    'en': 'Press the + button to create a lesson plan',
    'id': 'Tekan tombol + untuk membuat RPP',
  };

  static Map<String, String> get viewAndManageRpp => {
    'en': 'View and manage your lesson plans',
    'id': 'Lihat dan kelola RPP Anda',
  };

  static Map<String, String> get noRppForFilter => {
    'en': 'No lesson plans found for the selected filter',
    'id': 'Tidak ada RPP untuk filter yang dipilih',
  };

  // Validation Messages
  static Map<String, String> get titleRequired => {
    'en': 'Title is required',
    'id': 'Judul harus diisi',
  };

  static Map<String, String> get subjectRequired => {
    'en': 'Subject is required',
    'id': 'Mata pelajaran harus dipilih',
  };

  static Map<String, String> get semesterRequired => {
    'en': 'Semester is required',
    'id': 'Semester harus dipilih',
  };

  static Map<String, String> get academicYearRequired => {
    'en': 'Academic year is required',
    'id': 'Tahun ajaran harus diisi',
  };

  // File Types
  static Map<String, String> get wordDocument => {
    'en': 'Word Document',
    'id': 'Dokumen Word',
  };

  static Map<String, String> get pdfDocument => {
    'en': 'PDF Document',
    'id': 'Dokumen PDF',
  };

  static Map<String, String> get supportedFormats => {
    'en': 'Supported formats: .doc, .docx, .pdf',
    'id': 'Format yang didukung: .doc, .docx, .pdf',
  };

  static Map<String, String> get selectAndOrganizeMaterials => {
    'en': 'Select and organize your teaching materials',
    'id': 'Pilih dan kelola materi pembelajaran Anda',
  };
}

// Extension untuk memudahkan penggunaan terjemahan
extension AppLocalizationsExtension on AppLocalizations {
  // Class Management
  static String get editClass => AppLocalizations.editClass.tr;
  static String get addClass => AppLocalizations.addClass.tr;
  static String get className => AppLocalizations.className.tr;
  static String get classNameRequired => AppLocalizations.classNameRequired.tr;
  static String get gradeLevel => AppLocalizations.gradeLevel.tr;
  static String get gradeLevelRequired =>
      AppLocalizations.gradeLevelRequired.tr;
  static String get selectGradeLevel => AppLocalizations.selectGradeLevel.tr;
  static String get homeroomTeacher => AppLocalizations.homeroomTeacher.tr;
  static String get noTeacher => AppLocalizations.noTeacher.tr;
  static String get update => AppLocalizations.update.tr;
  static String get classDetails => AppLocalizations.classDetails.tr;
  static String get numberOfStudents => AppLocalizations.numberOfStudents.tr;
  static String get notAssigned => AppLocalizations.notAssigned.tr;
  static String get classesFound => AppLocalizations.classesFound.tr;
  static String get noClasses => AppLocalizations.noClasses.tr;
  static String get tapToAddClass => AppLocalizations.tapToAddClass.tr;
  static String get searchClasses => AppLocalizations.searchClasses.tr;
  static String get loadingClassData => AppLocalizations.loadingClassData.tr;
  static String get classSuccessfullyUpdated =>
      AppLocalizations.classSuccessfullyUpdated.tr;
  static String get classSuccessfullyAdded =>
      AppLocalizations.classSuccessfullyAdded.tr;
  static String get classSuccessfullyDeleted =>
      AppLocalizations.classSuccessfullyDeleted.tr;
  static String get failedToSaveClass => AppLocalizations.failedToSaveClass.tr;
  static String get failedToDeleteClass =>
      AppLocalizations.failedToDeleteClass.tr;
  static String get areYouSureDeleteClass =>
      AppLocalizations.areYouSureDeleteClass.tr;
  static String get all => AppLocalizations.all.tr;
  static String get withHomeroomTeacher =>
      AppLocalizations.withHomeroomTeacher.tr;
  static String get withoutHomeroomTeacher =>
      AppLocalizations.withoutHomeroomTeacher.tr;
}
