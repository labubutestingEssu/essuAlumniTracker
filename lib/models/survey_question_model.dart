import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/batch_year_utils.dart';

enum QuestionType {
  textInput,
  textArea,
  multipleChoice,
  rating,
  checkboxList,
  dropdown,
  dateInput,
  numberInput,
  switchToggle,
  section, // For section headers
}

class SurveyQuestionModel {
  final String id;
  final String title;
  final String? description;
  final QuestionType type;
  final bool isRequired;
  final int order;
  final String? sectionId; // Section identifier (e.g., 'section_personal', 'section_education')
  final String setId; // Question set identifier (e.g., 'set_1', 'set_2')
  final Map<String, dynamic> configuration; // Flexible configuration for different question types
  final List<String> options; // For single/multiple choice, dropdown, checkboxes
  final Map<String, String> validation; // Validation rules
  final Map<String, dynamic> conditionalLogic; // Conditional logic for showing/hiding questions
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  SurveyQuestionModel({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    required this.isRequired,
    required this.order,
    this.sectionId,
    this.setId = 'set_1', // Default to set_1 for backward compatibility
    required this.configuration,
    required this.options,
    required this.validation,
    this.conditionalLogic = const {},
    required this.createdAt,
    this.updatedAt,
    required this.isActive,
  });

  // Create from Firestore document
  factory SurveyQuestionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return SurveyQuestionModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'],
      type: QuestionType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => QuestionType.textInput,
      ),
      isRequired: data['isRequired'] ?? false,
      order: data['order'] ?? 0,
      sectionId: data['sectionId'],
      setId: data['setId'] ?? 'set_1', // Default to set_1 for backward compatibility
      configuration: Map<String, dynamic>.from(data['configuration'] ?? {}),
      options: List<String>.from(data['options'] ?? []),
      validation: Map<String, String>.from(data['validation'] ?? {}),
      conditionalLogic: Map<String, dynamic>.from(data['conditionalLogic'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      isActive: data['isActive'] ?? true,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'type': type.toString(),
      'isRequired': isRequired,
      'order': order,
      'sectionId': sectionId,
      'setId': setId,
      'configuration': configuration,
      'options': options,
      'validation': validation,
      'conditionalLogic': conditionalLogic,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isActive': isActive,
    };
  }

  // Create a copy with updated values
  SurveyQuestionModel copyWith({
    String? id,
    String? title,
    String? description,
    QuestionType? type,
    bool? isRequired,
    int? order,
    String? sectionId,
    String? setId,
    Map<String, dynamic>? configuration,
    List<String>? options,
    Map<String, String>? validation,
    Map<String, dynamic>? conditionalLogic,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return SurveyQuestionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      isRequired: isRequired ?? this.isRequired,
      order: order ?? this.order,
      sectionId: sectionId ?? this.sectionId,
      setId: setId ?? this.setId,
      configuration: configuration ?? this.configuration,
      options: options ?? this.options,
      validation: validation ?? this.validation,
      conditionalLogic: conditionalLogic ?? this.conditionalLogic,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  // Helper method to get section ID based on question ID for existing questions
  String getSectionIdFromQuestionId() {
    if (id.startsWith('section_')) return id;
    if (id == 'consent') return 'section_privacy';
    if (['last_name', 'first_name', 'middle_name', 'present_address', 'permanent_address', 
         'sex', 'date_of_birth', 'religion', 'civil_status', 'email_address', 'mobile_number'].contains(id)) {
      return 'section_personal';
    }
    if (['year_graduated', 'essu_campus', 'college_degree'].contains(id)) {
      return 'section_education';
    }
    if (['currently_employed', 'organization_name', 'organization_address', 'organization_type',
         'employment_status', 'employment_type', 'job_position', 'monthly_income',
         'job_related_to_degree', 'first_job_after_college'].contains(id)) {
      return 'section_employment';
    }
    if (['nature_of_employment', 'self_employment_years', 'self_employment_income'].contains(id)) {
      return 'section_self_employment';
    }
    return sectionId ?? '';
  }

  // Helper method to check if question should be shown based on conditional logic
  bool shouldShow(Map<String, dynamic> responses) {
    // Since we're now handling section-level visibility in the UI,
    // individual questions always show (unless they have other conditional logic)
    return true;
  }

  // Helper method to get default configuration for question types
  static Map<String, dynamic> getDefaultConfiguration(QuestionType type) {
    switch (type) {
      case QuestionType.textInput:
        return {
          'maxLength': 255,
          'placeholder': '',
        };
      case QuestionType.textArea:
        return {
          'maxLength': 1000,
          'minLines': 3,
          'maxLines': 5,
          'placeholder': '',
        };
      case QuestionType.rating:
        return {
          'minValue': 1,
          'maxValue': 5,
          'step': 1,
          'labels': ['Poor', 'Fair', 'Good', 'Very Good', 'Excellent'],
        };
      case QuestionType.numberInput:
        return {
          'minValue': 0,
          'maxValue': 999999,
          'allowDecimals': false,
        };
      case QuestionType.section:
        return {
          'showDivider': true,
          'backgroundColor': '',
        };
      default:
        return {};
    }
  }

  // Helper method to create predefined questions from the initial survey
  static List<SurveyQuestionModel> createInitialQuestions() {
    return [
      // Data Privacy Section
      SurveyQuestionModel(
        id: 'section_privacy',
        title: 'PURPOSE & DATA PRIVACY ACT',
        description: 'PURPOSE:\nThe Eastern Samar State University System Alumni Tracer Survey collects feedback from alumni to assess the program\'s effectiveness in preparing graduates for their careers and post-graduation life. The survey aims to gather baseline data on ESSU graduates, helping the university identify areas for program improvement. By understanding alumni experiences and outcomes, the university strives to enhance its programs, better serve current and future students, and ensure graduates are well-equipped for success and informed decision-making about their future.\n\nDATA PRIVACY ACT\nIn compliance with RA 10173 or the Data Protection Act of 2012 (DPA of 2012) and its Implementing Rules and Regulations, we are detailing the processing of the data you will provide.\n\nStorage, Retention, Disposal:\nCollected personal data will be securely stored, using physical security for paper files and technical security for digital files. ESSU will retain both paper and digital files only as long as necessary. Once personal data is no longer needed, ESSU will take reasonable steps to securely dispose of the information, preventing further editing, processing, and unauthorized disclosure.',
        type: QuestionType.section,
        isRequired: false,
        order: 1,
        sectionId: 'section_privacy',
        configuration: {'showDivider': true},
        options: [],
        validation: {},
        createdAt: DateTime.now(),
        isActive: true,
      ),
      
      SurveyQuestionModel(
        id: 'consent',
        title: 'Do you want to continue with the survey?',
        description: 'In compliance with RA 10173 or the Data Protection Act of 2012 (DPA of 2012), we are detailing the processing of the data you will provide.',
        type: QuestionType.multipleChoice,
        isRequired: true,
        order: 2,
        sectionId: 'section_privacy',
        configuration: {},
        options: ['Yes', 'No'],
        validation: {},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      // Personal Information Section
      SurveyQuestionModel(
        id: 'section_personal',
        title: 'PERSONAL INFORMATION',
        description: 'Kindly complete this questionnaire accurately. Your responses will be used solely for research purposes.',
        type: QuestionType.section,
        isRequired: false,
        order: 3,
        sectionId: 'section_personal',
        configuration: {'showDivider': true},
        options: [],
        validation: {},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'last_name',
        title: 'LAST NAME',
        type: QuestionType.textInput,
        isRequired: true,
        order: 4,
        sectionId: 'section_personal',
        configuration: {'maxLength': 100},
        options: [],
        validation: {'required': 'Last name is required'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'first_name',
        title: 'FIRST NAME',
        type: QuestionType.textInput,
        isRequired: true,
        order: 5,
        sectionId: 'section_personal',
        configuration: {'maxLength': 100},
        options: [],
        validation: {'required': 'First name is required'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'middle_name',
        title: 'MIDDLE NAME',
        type: QuestionType.textInput,
        isRequired: false,
        order: 6,
        sectionId: 'section_personal',
        configuration: {'maxLength': 100},
        options: [],
        validation: {},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'present_address',
        title: 'PRESENT ADDRESS',
        type: QuestionType.textArea,
        isRequired: true,
        order: 7,
        sectionId: 'section_personal',
        configuration: {'maxLength': 200, 'minLines': 2},
        options: [],
        validation: {'required': 'Present address is required'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'permanent_address',
        title: 'PERMANENT ADDRESS',
        type: QuestionType.textArea,
        isRequired: true,
        order: 8,
        sectionId: 'section_personal',
        configuration: {'maxLength': 200, 'minLines': 2},
        options: [],
        validation: {'required': 'Permanent address is required'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'sex',
        title: 'SEX',
        type: QuestionType.multipleChoice,
        isRequired: true,
        order: 9,
        sectionId: 'section_personal',
        configuration: {},
        options: ['Male', 'Female'],
        validation: {'required': 'Sex is required'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'date_of_birth',
        title: 'DATE OF BIRTH',
        type: QuestionType.dateInput,
        isRequired: false,
        order: 10,
        sectionId: 'section_personal',
        configuration: {},
        options: [],
        validation: {},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'religion',
        title: 'RELIGION',
        type: QuestionType.multipleChoice,
        isRequired: true,
        order: 11,
        sectionId: 'section_personal',
        configuration: {},
        options: [
          'Roman Catholic',
          'Christian',
          'Protestant',
          'Muslim',
          'Iglesia ni Cristo',
          'The Church of Jesus Christ of Latter day Saints',
          'Other'
        ],
        validation: {'required': 'Religion is required'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'civil_status',
        title: 'CIVIL STATUS',
        type: QuestionType.multipleChoice,
        isRequired: true,
        order: 12,
        sectionId: 'section_personal',
        configuration: {},
        options: ['Single', 'Married', 'Separated', 'Widowed'],
        validation: {'required': 'Civil status is required'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'email_address',
        title: 'EMAIL ADDRESS',
        type: QuestionType.textInput,
        isRequired: false,
        order: 13,
        sectionId: 'section_personal',
        configuration: {'maxLength': 100},
        options: [],
        validation: {'email': 'Please enter a valid email address'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'mobile_number',
        title: 'MOBILE NUMBER',
        type: QuestionType.textInput,
        isRequired: true,
        order: 14,
        sectionId: 'section_personal',
        configuration: {'maxLength': 20},
        options: [],
        validation: {'required': 'Mobile number is required'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      // Educational Background Section
      SurveyQuestionModel(
        id: 'section_education',
        title: 'EDUCATIONAL BACKGROUND',
        type: QuestionType.section,
        isRequired: false,
        order: 15,
        sectionId: 'section_education',
        configuration: {'showDivider': true},
        options: [],
        validation: {},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'year_graduated',
        title: 'Year Graduated',
        type: QuestionType.multipleChoice,
        isRequired: true,
        order: 16,
        sectionId: 'section_education',
        configuration: {'dynamicOptions': 'batchYears'}, // Mark as dynamic options
        options: BatchYearUtils.generateBatchYears(), // Use dynamic year generation
        validation: {'required': 'Year graduated is required'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'essu_campus',
        title: 'EASTERN SAMAR STATE UNIVERSITY',
        type: QuestionType.textInput,
        isRequired: true,
        order: 17,
        sectionId: 'section_education',
        configuration: {},
        options: [
          'BORONGAN (Main Campus)'
        ],
        validation: {'required': 'Campus is required'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'college_degree',
        title: 'College Degree',
        type: QuestionType.dropdown,
        isRequired: true,
        order: 18,
        sectionId: 'section_education',
        configuration: {'dynamicOptions': 'courses', 'searchable': true}, // Dynamic courses with search
        options: [], // Will be populated dynamically from database
        validation: {'required': 'College degree is required'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'graduate_studies_degree',
        title: 'IF PURSUING GRADUATE STUDIES:\nDegree Program\n(please answer "N/A" if not pursuing graduate studies)',
        type: QuestionType.textInput,
        isRequired: false,
        order: 22,
        sectionId: 'section_education',
        configuration: {'maxLength': 200},
        options: [],
        validation: {},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'graduate_studies_institution',
        title: 'University/Institution:\n(please answer "N/A" if not pursuing graduate studies)',
        type: QuestionType.textInput,
        isRequired: false,
        order: 23,
        sectionId: 'section_education',
        configuration: {'maxLength': 200},
        options: [],
        validation: {},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      // Employment Section
      SurveyQuestionModel(
        id: 'section_employment',
        title: 'EMPLOYMENT INFORMATION',
        type: QuestionType.section,
        isRequired: false,
        order: 24,
        sectionId: 'section_employment',
        configuration: {'showDivider': true},
        options: [],
        validation: {},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'currently_employed',
        title: 'Are you presently employed?',
        type: QuestionType.multipleChoice,
        isRequired: true,
        order: 25,
        sectionId: 'section_employment',
        configuration: {},
        options: ['Yes', 'No', 'Never Employed'],
        validation: {'required': 'Employment status is required'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'organization_name',
        title: 'Name of Organization/Employer',
        description: 'example: Eastern Samar State University Main Campus',
        type: QuestionType.textInput,
        isRequired: true,
        order: 36,
        sectionId: 'section_self_employment',
        configuration: {'maxLength': 200},
        options: [],
        validation: {'required': 'Organization name is required'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'organization_address',
        title: 'Organization/Employer\'s Address',
        type: QuestionType.textArea,
        isRequired: true,
        order: 37,
        sectionId: 'section_self_employment',
        configuration: {'maxLength': 200, 'minLines': 2},
        options: [],
        validation: {'required': 'Organization address is required'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'organization_type',
        title: 'Type of Organization',
        type: QuestionType.multipleChoice,
        isRequired: true,
        order: 38,
        sectionId: 'section_self_employment',
        configuration: {},
        options: ['Government', 'Private', 'NGO', 'Non-Profit'],
        validation: {'required': 'Organization type is required'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'employment_status',
        title: 'Employment Status',
        type: QuestionType.multipleChoice,
        isRequired: true,
        order: 39,
        sectionId: 'section_self_employment',
        configuration: {},
        options: [
          'Permanent',
          'Temporary',
          'Coterminous',
          'Contractual',
          'Fixed term',
          'Substitute/Provisional'
        ],
        validation: {'required': 'Employment status is required'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'employment_type',
        title: 'Employment Type',
        type: QuestionType.multipleChoice,
        isRequired: true,
        order: 40,
        sectionId: 'section_self_employment',
        configuration: {},
        options: ['Working Fulltime', 'Working Part-time'],
        validation: {'required': 'Employment type is required'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'job_position',
        title: 'Job Position',
        type: QuestionType.textInput,
        isRequired: true,
        order: 41,
        sectionId: 'section_self_employment',
        configuration: {'maxLength': 100},
        options: [],
        validation: {'required': 'Job position is required'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'monthly_income',
        title: 'Monthly Income Range',
        type: QuestionType.multipleChoice,
        isRequired: true,
        order: 42,
        sectionId: 'section_self_employment',
        configuration: {},
        options: [
          'Below 10,000',
          '10,000-15,000',
          '16,000-20,000',
          '21,000-25,000',
          '26,000-30,000',
          '31,000 above'
        ],
        validation: {'required': 'Monthly income range is required'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'job_related_to_degree',
        title: 'Is your current job related to the degree program you took up in college?',
        type: QuestionType.multipleChoice,
        isRequired: true,
        order: 43,
        sectionId: 'section_self_employment',
        configuration: {},
        options: ['Yes', 'No'],
        validation: {'required': 'This field is required'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'first_job_after_college',
        title: 'Is this your first job after College?',
        type: QuestionType.multipleChoice,
        isRequired: true,
        order: 44,
        sectionId: 'section_self_employment',
        configuration: {},
        options: ['Yes', 'No'],
        validation: {'required': 'This field is required'},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      // Employment Details Section
      SurveyQuestionModel(
        id: 'section_self_employment',
        title: 'EMPLOYMENT DETAILS',
        type: QuestionType.section,
        isRequired: false,
        order: 35,
        sectionId: 'section_self_employment',
        configuration: {'showDivider': true},
        options: [],
        validation: {},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'nature_of_employment',
        title: 'Nature of Employment',
        description: 'please answer "N/A" if not self employed',
        type: QuestionType.textInput,
        isRequired: false,
        order: 45,
        sectionId: 'section_self_employment',
        configuration: {'maxLength': 100},
        options: [],
        validation: {},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'self_employment_years',
        title: 'Number of Years',
        type: QuestionType.multipleChoice,
        isRequired: false,
        order: 46,
        sectionId: 'section_self_employment',
        configuration: {},
        options: ['0-5', '6-10', '11 above', 'N/A', 'Other'],
        validation: {},
        createdAt: DateTime.now(),
        isActive: true,
      ),

      SurveyQuestionModel(
        id: 'self_employment_income',
        title: 'Monthly Income Range',
        type: QuestionType.multipleChoice,
        isRequired: false,
        order: 47,
        sectionId: 'section_self_employment',
        configuration: {},
        options: [
          'Below 10,000',
          '10,000-15,000',
          '16,000-20,000',
          '21,000-25,000',
          '26,000 above',
          'N/A'
        ],
        validation: {},
        createdAt: DateTime.now(),
        isActive: true,
      ),
    ];
  }
} 