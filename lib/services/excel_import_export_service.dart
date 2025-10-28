import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../models/survey_question_model.dart';
import '../utils/batch_year_utils.dart';

class ExcelImportExportService {
  /// Generate and download Excel template for question import
  static Future<Uint8List> generateTemplate() async {
    final excel = Excel.createExcel();
    
    // Create the template sheet directly
    final sheet = excel['Question Template'];
    
    // Define headers
    final headers = [
      'Order',
      'Section ID',
      'Title',
      'Description',
      'Question Type',
      'Is Required',
      'Options',
      'Dynamic Options',
      'Is Active',
    ];
    
    // Add header row
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = headers[i];
    }
    
    // Add instructions row
    final instructions = [
      '1',
      'section_privacy',
      'Enter question title here',
      'Optional description',
      'textInput',
      'YES',
      'Option1, Option2, Option3',
      'Leave blank or use: batchYears, courses, colleges',
      'YES',
    ];
    
    for (int i = 0; i < instructions.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      cell.value = instructions[i];
    }
    
    // Add sample questions for each section
    final samples = [
      ['2', 'section_privacy', 'Do you consent to data collection?', 'Privacy notice', 'singleChoice', 'YES', 'Yes, No', '', 'YES'],
      ['3', 'section_personal', 'What is your full name?', '', 'textInput', 'YES', '', '', 'YES'],
      ['4', 'section_personal', 'Mobile Number', 'Enter 11-digit number', 'textInput', 'YES', '', '', 'YES'],
      ['5', 'section_education', 'Year Graduated', '', 'singleChoice', 'YES', '', 'batchYears', 'YES'],
      ['6', 'section_education', 'College Degree', '', 'dropdown', 'YES', '', 'courses', 'YES'],
      ['7', 'section_employment', 'Are you currently employed?', '', 'singleChoice', 'YES', 'Yes, No, Never Employed', '', 'YES'],
      ['8', 'section_self_employment', 'Job Position', '', 'textInput', 'YES', '', '', 'YES'],
    ];
    
    for (int rowIndex = 0; rowIndex < samples.length; rowIndex++) {
      for (int colIndex = 0; colIndex < samples[rowIndex].length; colIndex++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex + 2));
        cell.value = samples[rowIndex][colIndex];
      }
    }
    
    // Add a separate instruction sheet
    final instructionSheet = excel['Instructions'];
    final instructionText = [
      ['ESSU Alumni Tracker - Question Import Template'],
      [''],
      ['Instructions:'],
      ['1. Fill in the question details in the "Question Template" sheet'],
      ['2. Do not modify the header row (first row)'],
      ['3. You can delete the sample rows and add your own questions'],
      ['4. Save the file and import it in the application'],
      [''],
      ['Column Descriptions:'],
      [''],
      ['Order', 'Number determining question sequence (1, 2, 3...)'],
      ['Section ID', 'Options: section_privacy, section_personal, section_education, section_employment, section_self_employment'],
      ['Title', 'The question text displayed to users (Required)'],
      ['Description', 'Optional helper text shown below the question'],
      ['Question Type', 'Options: textInput, textArea, singleChoice, multipleChoice, dropdown, checkboxList, dateInput, numberInput, switchToggle, rating, section'],
      ['Is Required', 'Use YES or NO'],
      ['Options', 'For choice/dropdown questions: comma-separated values (e.g., "Option1, Option2, Option3")'],
      ['Dynamic Options', 'For dynamic data: batchYears (academic years), courses (from database), colleges (from database). Leave blank for static options.'],
      ['Is Active', 'Use YES or NO (NO will hide the question from users)'],
      [''],
      ['Question Type Details:'],
      [''],
      ['textInput', 'Short text answer (single line)'],
      ['textArea', 'Long text answer (multiple lines)'],
      ['singleChoice', 'Radio buttons - user picks one option'],
      ['multipleChoice', 'Checkboxes - user can pick multiple options'],
      ['dropdown', 'Dropdown menu - user selects one option'],
      ['checkboxList', 'Checkbox list - user can select multiple'],
      ['dateInput', 'Date picker'],
      ['numberInput', 'Number input field'],
      ['switchToggle', 'On/off toggle switch'],
      ['rating', 'Star or scale rating'],
      ['section', 'Section header (not a question)'],
      [''],
      ['Section IDs:'],
      [''],
      ['section_privacy', 'Data Privacy & Consent'],
      ['section_personal', 'Personal Information (Name, Address, Contact)'],
      ['section_education', 'Educational Background (Graduation, Campus, Degree)'],
      ['section_employment', 'Employment Status & Information'],
      ['section_self_employment', 'Employment Details (Job, Business, Income)'],
    ];
    
    for (int i = 0; i < instructionText.length; i++) {
      for (int j = 0; j < instructionText[i].length; j++) {
        final cell = instructionSheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i));
        cell.value = instructionText[i][j];
      }
    }
    
    final excelBytes = excel.encode();
    if (excelBytes == null) {
      throw Exception('Failed to encode Excel file');
    }
    return Uint8List.fromList(excelBytes);
  }
  
  /// Pick and parse Excel file
  static Future<Map<String, dynamic>?> pickAndParseExcelFile() async {
    try {
      // Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );
      
      if (result == null || result.files.isEmpty) {
        return null;
      }
      
      final bytes = result.files.first.bytes;
      if (bytes == null) {
        throw Exception('Could not read file data');
      }
      
      // Parse Excel
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables['Question Template'];
      
      if (sheet == null) {
        throw Exception('Could not find "Question Template" sheet in the Excel file');
      }
      
      // Validate and parse questions
      final questions = <Map<String, dynamic>>[];
      final errors = <String>[];
      
      // Skip header row (row 0) and start from row 1
      for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
        final row = sheet.row(rowIndex);
        
        // Skip empty rows
        if (row.isEmpty || row.every((cell) => cell == null || cell.value == null || cell.value.toString().trim().isEmpty)) {
          continue;
        }
        
        try {
          final questionData = _parseRow(row, rowIndex + 1);
          questions.add(questionData);
        } catch (e) {
          errors.add('Row ${rowIndex + 1}: $e');
        }
      }
      
      return {
        'questions': questions,
        'errors': errors,
        'totalRows': sheet.maxRows - 1, // Excluding header
      };
    } catch (e) {
      print('Error picking/parsing Excel file: $e');
      return {
        'questions': [],
        'errors': ['Failed to parse Excel file: $e'],
        'totalRows': 0,
      };
    }
  }
  
  /// Parse a single row into question data
  static Map<String, dynamic> _parseRow(List<Data?> row, int rowNumber) {
    // Helper to get cell value
    String getCellValue(int index) {
      if (index >= row.length || row[index] == null) return '';
      return row[index]!.value.toString().trim();
    }
    
    // Parse cells
    final orderStr = getCellValue(0);
    final sectionId = getCellValue(1);
    final title = getCellValue(2);
    final description = getCellValue(3);
    final typeStr = getCellValue(4);
    final isRequiredStr = getCellValue(5).toUpperCase();
    final optionsStr = getCellValue(6);
    final dynamicOptionsStr = getCellValue(7);
    final isActiveStr = getCellValue(8).toUpperCase();
    
    // Validate required fields
    if (title.isEmpty) {
      throw Exception('Title is required');
    }
    
    if (typeStr.isEmpty) {
      throw Exception('Question Type is required');
    }
    
    // Parse order
    int order;
    try {
      order = int.parse(orderStr);
    } catch (e) {
      throw Exception('Order must be a number');
    }
    
    // Parse question type
    QuestionType? questionType;
    try {
      questionType = QuestionType.values.firstWhere(
        (e) => e.toString().split('.').last.toLowerCase() == typeStr.toLowerCase(),
      );
    } catch (e) {
      throw Exception('Invalid Question Type: $typeStr. Valid types: ${QuestionType.values.map((e) => e.toString().split('.').last).join(', ')}');
    }
    
    // Parse booleans
    final isRequired = isRequiredStr == 'YES' || isRequiredStr == 'TRUE' || isRequiredStr == '1';
    final isActive = isActiveStr.isEmpty || isActiveStr == 'YES' || isActiveStr == 'TRUE' || isActiveStr == '1';
    
    // Parse options
    List<String> options = [];
    if (optionsStr.isNotEmpty) {
      options = optionsStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    
    // Build configuration
    Map<String, dynamic> configuration = SurveyQuestionModel.getDefaultConfiguration(questionType);
    
    // Handle dynamic options
    if (dynamicOptionsStr.isNotEmpty) {
      final dynamicType = dynamicOptionsStr.trim();
      if (['batchYears', 'courses', 'colleges'].contains(dynamicType)) {
        configuration['dynamicOptions'] = dynamicType;
        
        // Set initial options based on type
        if (dynamicType == 'batchYears') {
          options = BatchYearUtils.generateBatchYears();
        } else {
          // For courses and colleges, leave empty - will be populated dynamically
          options = [];
        }
        
        // Add searchable flag for dropdowns with dynamic data
        if (questionType == QuestionType.dropdown) {
          configuration['searchable'] = true;
        }
      }
    }
    
    // Validate options for choice-type questions
    final needsOptions = [
      QuestionType.singleChoice,
      QuestionType.multipleChoice,
      QuestionType.dropdown,
      QuestionType.checkboxList,
    ].contains(questionType);
    
    if (needsOptions && options.isEmpty && !configuration.containsKey('dynamicOptions')) {
      throw Exception('Question type $typeStr requires options (either static options or dynamic options)');
    }
    
    return {
      'order': order,
      'sectionId': sectionId.isEmpty ? null : sectionId,
      'title': title,
      'description': description.isEmpty ? null : description,
      'type': questionType,
      'isRequired': isRequired,
      'options': options,
      'configuration': configuration,
      'isActive': isActive,
    };
  }
  
  /// Convert parsed data to SurveyQuestionModel list
  static List<SurveyQuestionModel> createQuestionsFromParsedData(
    List<Map<String, dynamic>> parsedData,
    String setId,
  ) {
    return parsedData.map((data) {
      return SurveyQuestionModel(
        id: '', // Will be assigned by Firestore
        title: data['title'],
        description: data['description'],
        type: data['type'],
        isRequired: data['isRequired'],
        order: data['order'],
        sectionId: data['sectionId'],
        setId: setId,
        configuration: data['configuration'],
        options: data['options'],
        validation: data['isRequired'] ? {'required': 'This field is required'} : {},
        createdAt: DateTime.now(),
        isActive: data['isActive'],
      );
    }).toList();
  }
  
  /// Export existing questions to Excel
  static Future<Uint8List> exportQuestionsToExcel(List<SurveyQuestionModel> questions, String setName) async {
    final excel = Excel.createExcel();
    
    // Create the sheet directly
    final sheet = excel[setName];
    
    // Define headers
    final headers = [
      'Order',
      'Section ID',
      'Title',
      'Description',
      'Question Type',
      'Is Required',
      'Options',
      'Dynamic Options',
      'Is Active',
    ];
    
    // Add header row
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = headers[i];
    }
    
    // Add question rows
    for (int rowIndex = 0; rowIndex < questions.length; rowIndex++) {
      final question = questions[rowIndex];
      
      final rowData = [
        question.order.toString(),
        question.sectionId ?? '',
        question.title,
        question.description ?? '',
        question.type.toString().split('.').last,
        question.isRequired ? 'YES' : 'NO',
        question.options.join(', '),
        question.configuration['dynamicOptions']?.toString() ?? '',
        question.isActive ? 'YES' : 'NO',
      ];
      
      for (int colIndex = 0; colIndex < rowData.length; colIndex++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex + 1));
        cell.value = rowData[colIndex];
      }
    }
    
    final excelBytes = excel.encode();
    if (excelBytes == null) {
      throw Exception('Failed to encode Excel file');
    }
    return Uint8List.fromList(excelBytes);
  }
}
