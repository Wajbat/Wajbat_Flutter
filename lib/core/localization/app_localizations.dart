import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  late Map<String, String> _localizedStrings;

  // Simple map for now, can be moved to JSON files later
  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_name': 'Wajbat',
      'login': 'Login',
      'email': 'Email',
      'password': 'Password',
      'forgot_password': 'Forgot Password?',
      'dont_have_account': 'Don\'t have an account?',
      'register': 'Register',
      'full_name': 'Full Name', 
      'phone_number': 'Phone Number',
      'role': 'I want to:',
      'donor': 'Donate Food',
      'recipient': 'Receive Food',
      'organization_name': 'Organization Name (Optional)',
      'recipient_type': 'Recipient Type',
      'individual': 'Individual',
      'charity': 'Charity',
      'food_allergies': 'Food Allergies',
      'add_allergy_hint': 'e.g., peanuts, dairy',
      'add_allergy_desc': 'Add or remove ingredients you\'re allergic to.',
      'my_allergies': 'My Allergies',
      'profile': 'Profile',
      'edit_profile': 'Edit Profile',
      'language': 'Language',
      'notifications': 'Notifications',
      'help_center': 'Help Center (Chatbot)',
      'privacy_policy': 'Privacy Policy',
      'terms_conditions': 'Terms & Conditions',
      'contact_support': 'Contact Support',
      'logout': 'Logout',
      'delete_account': 'Delete Account',
      'save_changes': 'Save Changes',
      'currently': 'Currently:',
      'switch_role': 'Switch Role',
      'total_donations': 'Total\nDonations',
      'active_posts': 'Active\nPosts',
      'impact_score': 'Impact\nScore',
      'home': 'Home',
      'chat': 'Chat',
      'requests': 'Requests',
      'create_post': 'Create Post',
      'item_name': 'Item Name',
      'quantity': 'Quantity',
      'description': 'Description',
      'pickup_time': 'Pickup Time',
      'expiration_date': 'Expiration Date',
      'location': 'Location',
      'submit': 'Submit',
      'cancel': 'Cancel',
      'warning': 'Warning',
      'allergy_warning': 'Allergy Warning',
      'contains_allergens': 'Contains: ',
      'request_this_food': 'Request This Food',
      'available': 'Available',
      'expired': 'Expired',
      // Added missing keys
      'welcome_back': 'Welcome Back',
      'create_account_title': 'Create Account',
      'browse': 'Browse',
      'my_posts': 'My Posts',
      'hello': 'Hello',
      'guest': 'Guest',
      'ready_to_make_difference': 'Ready to make a difference?',
      'find_food_near_you': 'Find food near you',
      'search_food': 'Search food...',
      'recent_posts': 'Recent Posts',
      'pending_requests': 'Pending Requests',
      'view_all': 'View All',
      'impact_points': 'Impact Points',
      'share_surplus_food': 'Share Surplus Food',
      'quickly_post_items': 'Quickly post items to help others.',
      'no_posts_yet': 'No posts yet',
      'start_sharing_surplus': 'Start sharing surplus food.',
      'no_pending_requests': 'No pending requests',
      'requests_appear_here': 'Requests will appear here.',
      'request_for': 'Request for',
      'status': 'Status: ',
      'donor_name': 'Donor Name',
      'expires': 'Expires: ',
      'exp': 'Exp: ',
      'filter_results': 'Filter Results',
      'distance_radius': 'Distance Radius',
      'sort_by': 'Sort By',
      'nearest': 'Nearest',
      'expiring_soon': 'Expiring Soon',
      'recently_added': 'Recently Added',
      'apply_filters': 'Apply Filters',
      'no_food_nearby': 'No food available nearby',
      'prepared_food': 'Prepared Food',
      'fruits_veggies': 'Fruits & Veggies',
      'bakery': 'Bakery',
      'groceries': 'Groceries',
      'other': 'Other',
      'all': 'All',
    },
    'ar': {
      'app_name': 'وجبات',
      'login': 'تسجيل الدخول',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'forgot_password': 'نسيت كلمة المرور؟',
      'dont_have_account': 'ليس لديك حساب؟',
      'register': 'تسجيل جديد',
      'full_name': 'الاسم الكامل',
      'phone_number': 'رقم الهاتف',
      'role': 'أريد أن:',
      'donor': 'أتبرع بالطعام',
      'recipient': 'أستقبل الطعام',
      'organization_name': 'اسم المنظمة (اختياري)',
      'recipient_type': 'نوع المستفيد',
      'individual': 'فرد',
      'charity': 'جمعية خيرية',
      'food_allergies': 'حساسية الطعام',
      'add_allergy_hint': 'مثال: فول سوداني، حليب',
      'add_allergy_desc': 'أضف أو أزل المكونات التي لديك حساسية منها.',
      'my_allergies': 'حساسيتي',
      'profile': 'الملف الشخصي',
      'edit_profile': 'تعديل الملف الشخصي',
      'language': 'اللغة',
      'notifications': 'الإشعارات',
      'help_center': 'مركز المساعدة',
      'privacy_policy': 'سياسة الخصوصية',
      'terms_conditions': 'الشروط والأحكام',
      'contact_support': 'تواصل مع الدعم',
      'logout': 'تسجيل الخروج',
      'delete_account': 'حذف الحساب',
      'save_changes': 'حفظ التغييرات',
      'currently': 'حالياً:',
      'switch_role': 'تغيير الدور',
      'total_donations': 'مجموع\nالتبرعات',
      'active_posts': 'الإعلانات\nالنشطة',
      'impact_score': 'نقاط\nالتأثير',
      'home': 'الرئيسية',
      'chat': 'المحادثات',
      'requests': 'الطلبات',
      'create_post': 'إضافة إعلان',
      'item_name': 'اسم العنصر',
      'quantity': 'الكمية',
      'description': 'الوصف',
      'pickup_time': 'وقت الاستلام',
      'expiration_date': 'تاريخ الانتهاء',
      'location': 'الموقع',
      'submit': 'إرسال',
      'cancel': 'إلغاء',
      'warning': 'تحذير',
      'allergy_warning': 'تحذير حساسية',
      'contains_allergens': 'يحتوي على: ',
      'request_this_food': 'طلب هذا الطعام',
      'available': 'متاح',
      'expired': 'منتهي',
      'select_language': 'اختر اللغة',
      // Added missing keys
      'welcome_back': 'مرحباً بعودتك',
      'create_account_title': 'إنشاء حساب',
      'browse': 'تصفح',
      'my_posts': 'إعلاناتي',
      'hello': 'مرحباً',
      'guest': 'ضيف',
      'ready_to_make_difference': 'مستعد لإحداث فرق؟',
      'find_food_near_you': 'ابحث عن طعام بالقرب منك',
      'search_food': 'ابحث عن طعام...',
      'recent_posts': 'أحدث الإعلانات',
      'pending_requests': 'الطلبات المعلقة',
      'view_all': 'عرض الكل',
      'impact_points': 'نقاط التأثير',
      'share_surplus_food': 'شارك الطعام الفائض',
      'quickly_post_items': 'اعرض العناصر بسرعة لمساعدة الآخرين.',
      'no_posts_yet': 'لا توجد إعلانات بعد',
      'start_sharing_surplus': 'ابدأ بمشاركة الطعام الفائض.',
      'no_pending_requests': 'لا توجد طلبات معلقة',
      'requests_appear_here': 'ستظهر الطلبات هنا.',
      'request_for': 'طلب لـ',
      'status': 'الحالة: ',
      'donor_name': 'اسم المتبرع',
      'expires': 'ينتهي: ',
      'exp': 'انتهاء: ',
      'filter_results': 'تصفية النتائج',
      'distance_radius': 'نطاق المسافة',
      'sort_by': 'ترتيب حسب',
      'nearest': 'الأقرب',
      'expiring_soon': 'ينتهي قريباً',
      'recently_added': 'أضيف مؤخراً',
      'apply_filters': 'تطبيق عوامل التصفية',
      'no_food_nearby': 'لا يوجد طعام متاح بالقرب منك',
      'prepared_food': 'طعام جاهز',
      'fruits_veggies': 'فواكه وخضروات',
      'bakery': 'مخبوزات',
      'groceries': 'بقالة',
      'other': 'أخرى',
      'all': 'الكل',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
