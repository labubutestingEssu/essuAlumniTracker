import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../../models/survey_question_model.dart';
import '../../services/survey_question_service.dart';
import '../../services/excel_import_export_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/responsive_screen_wrapper.dart';
import '../../utils/responsive.dart';
import '../../utils/navigation_service.dart';
import '../../config/routes.dart';
import '../../utils/batch_year_utils.dart';

class SurveyQuestionManagementScreen extends StatefulWidget {
  const SurveyQuestionManagementScreen({Key? key}) : super(key: key);

  @override
  State<SurveyQuestionManagementScreen> createState() => _SurveyQuestionManagementScreenState();
}

class _SurveyQuestionManagementScreenState extends State<SurveyQuestionManagementScreen> {
  final SurveyQuestionService _questionService = SurveyQuestionService();
  
  List<SurveyQuestionModel> _questions = [];
  List<SurveyQuestionModel> _editableQuestions = []; // For batch edit mode
  List<String> _availableSets = [];
  Map<String, int> _questionCounts = {};
  Map<String, String> _setNames = {};
  String? _currentSetId;
  String? _activeSetId;
  
  bool _isLoading = false;
  bool _isBatchEditMode = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  String _searchQuery = '';
  QuestionType? _filterType;
  
  // Controllers for batch edit mode
  final Map<String, Map<String, TextEditingController>> _controllers = {};
  
  // Scroll controller for batch edit view
  final ScrollController _batchEditScrollController = ScrollController();
  
  // Multi-select state for batch delete
  Set<String> _selectedQuestionIds = {};

  @override
  void initState() {
    super.initState();
    _loadQuestionSetsAndQuestions();
  }

  Future<void> _loadQuestionSetsAndQuestions() async {
    setState(() => _isLoading = true);
    try {
      // Initialize survey settings
      await _questionService.initializeSurveySettings();
      
      // Load available sets, active set, and question counts
      final futures = await Future.wait([
        _questionService.getAvailableSets(),
        _questionService.getActiveSetId(),
        _questionService.getQuestionCountPerSet(),
      ]);
      
      final availableSets = futures[0] as List<String>;
      final activeSetId = futures[1] as String;
      final questionCounts = futures[2] as Map<String, int>;
      
      // Load display names for all sets
      final setNames = <String, String>{};
      for (final setId in availableSets) {
        setNames[setId] = await _questionService.getSetDisplayName(setId);
      }
      
      setState(() {
        _availableSets = availableSets;
        _activeSetId = activeSetId;
        _questionCounts = questionCounts;
        _setNames = setNames;
        _currentSetId = activeSetId; // Default to active set
      });
      
      // Load questions for the current set
      await _loadQuestions();
    } catch (e) {
      _showErrorSnackBar('Error loading question sets: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadQuestions() async {
    if (_currentSetId == null) return;
    
    try {
      final questions = await _questionService.getAllQuestions(setId: _currentSetId);
      setState(() {
        _questions = questions;
        if (_isBatchEditMode) {
          _initializeBatchEditMode();
        }
      });
      
      // Update question count cache
      _questionCounts[_currentSetId!] = questions.length;
    } catch (e) {
      _showErrorSnackBar('Error loading questions: $e');
    }
  }

  void _initializeBatchEditMode() {
    // Use sorted questions by section for batch edit mode
    _editableQuestions = _sortQuestionsBySection(List.from(_questions));
    _disposeControllers();
    _controllers.clear();
    
    for (final question in _editableQuestions) {
      _controllers[question.id] = {
        'title': TextEditingController(text: question.title),
        'description': TextEditingController(text: question.description ?? ''),
        'options': TextEditingController(text: question.options.join('\n')),
      };
    }
  }

  void _toggleBatchEditMode() {
    setState(() {
      _isBatchEditMode = !_isBatchEditMode;
      if (_isBatchEditMode) {
        _initializeBatchEditMode();
      } else {
        _disposeControllers();
        _controllers.clear();
        _editableQuestions.clear();
        _selectedQuestionIds.clear();
      }
    });
  }

  List<SurveyQuestionModel> get _filteredQuestions {
    var filtered = _questions;
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((q) => 
        q.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (q.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }
    
    if (_filterType != null) {
      filtered = filtered.where((q) => q.type == _filterType).toList();
    }
    
    // Group by section and sort within each section
    return _sortQuestionsBySection(filtered);
  }

  List<SurveyQuestionModel> _sortQuestionsBySection(List<SurveyQuestionModel> questions) {
    print('🔍 SORT_DEBUG: Starting sort with ${questions.length} questions');
    
    // Define section order
    final sectionOrder = [
      'section_privacy',
      'section_personal',
      'section_education',
      'section_employment',
      'section_self_employment',
    ];
    
    // Helper function to map sectionId to a section name
    String? getSectionNameFromId(String? sectionId) {
      if (sectionId == null || sectionId.isEmpty) {
        print('🔍 SORT_DEBUG: sectionId is null or empty');
        return null;
      }
      
      print('🔍 SORT_DEBUG: Checking sectionId="$sectionId"');
      
      // Check if it's already a section name
      if (sectionOrder.contains(sectionId)) {
        print('🔍 SORT_DEBUG: sectionId is already a valid section name');
        return sectionId;
      }
      
      // Check if it's a section header question by its ID
      final sectionHeaderQuestion = questions.where((q) => q.id == sectionId && q.type == QuestionType.section).firstOrNull;
      if (sectionHeaderQuestion != null) {
        print('🔍 SORT_DEBUG: Found section header question with id="$sectionId"');
        // This is a section header question, check its sectionId field
        if (sectionOrder.contains(sectionHeaderQuestion.sectionId)) {
          print('🔍 SORT_DEBUG: Returning sectionId="${sectionHeaderQuestion.sectionId}" from header question');
          return sectionHeaderQuestion.sectionId;
        }
      }
      
      // Try to find section header questions that match section names
      for (var sectionName in sectionOrder) {
        final sectionHeader = questions.where((q) => q.id == sectionName && q.type == QuestionType.section).firstOrNull;
        if (sectionHeader != null && sectionHeader.sectionId == sectionId) {
          print('🔍 SORT_DEBUG: Found matching section header, returning sectionName="$sectionName"');
          return sectionName;
        }
      }
      
      // If sectionId is a question ID that points to a section header, extract the section name
      final pointedSection = questions.where((q) => q.id == sectionId && q.type == QuestionType.section).firstOrNull;
      if (pointedSection != null && pointedSection.sectionId != null) {
        print('🔍 SORT_DEBUG: Extracted section name="${pointedSection.sectionId}" from pointed section');
        return pointedSection.sectionId;
      }
      
      print('🔍 SORT_DEBUG: Could not determine section name, returning null');
      return null;
    }
    
    // Separate questions by section
    Map<String, List<SurveyQuestionModel>> sectionMap = {};
    List<SurveyQuestionModel> questionsWithoutSection = [];
    
    for (var question in questions) {
      print('🔍 SORT_DEBUG: Processing question id="${question.id}", title="${question.title}", sectionId="${question.sectionId}", order=${question.order}');
      
      if (question.sectionId != null && question.sectionId!.isNotEmpty) {
        // Try to get the section name from the sectionId
        final sectionName = getSectionNameFromId(question.sectionId);
        print('🔍 SORT_DEBUG: Resolved sectionName="$sectionName" for question id="${question.id}"');
        
        if (sectionName != null) {
          sectionMap.putIfAbsent(sectionName, () => []);
          sectionMap[sectionName]!.add(question);
          print('🔍 SORT_DEBUG: Added to sectionMap["$sectionName"]');
        } else {
          // Can't determine section, use the sectionId as-is
          print('🔍 SORT_DEBUG: Using sectionId as-is: "${question.sectionId}"');
          sectionMap.putIfAbsent(question.sectionId!, () => []);
          sectionMap[question.sectionId!]!.add(question);
        }
      } else {
        // Question has no section
        print('🔍 SORT_DEBUG: Question has no sectionId, adding to questionsWithoutSection');
        questionsWithoutSection.add(question);
      }
    }
    
    // Sort within each section by order
    sectionMap.forEach((sectionId, sectionQuestions) {
      print('🔍 SORT_DEBUG: Sorting ${sectionQuestions.length} questions in section="$sectionId"');
      sectionQuestions.sort((a, b) => a.order.compareTo(b.order));
      for (var q in sectionQuestions) {
        print('🔍 SORT_DEBUG:   - order=${q.order}, title="${q.title}"');
      }
    });
    
    // Combine in section order
    List<SurveyQuestionModel> result = [];
    for (var sectionName in sectionOrder) {
      if (sectionMap.containsKey(sectionName)) {
        print('🔍 SORT_DEBUG: Adding ${sectionMap[sectionName]!.length} questions from section="$sectionName"');
        result.addAll(sectionMap[sectionName]!);
      } else {
        print('🔍 SORT_DEBUG: No questions in section="$sectionName"');
      }
    }
    
    // Handle questions without section at the end
    questionsWithoutSection.sort((a, b) => a.order.compareTo(b.order));
    result.addAll(questionsWithoutSection);
    
    // Handle any sections not in the predefined order (shouldn't happen but just in case)
    for (var sectionName in sectionMap.keys) {
      if (!sectionOrder.contains(sectionName)) {
        print('🔍 SORT_DEBUG: Adding ${sectionMap[sectionName]!.length} questions from unlisted section="$sectionName"');
        result.addAll(sectionMap[sectionName]!);
      }
    }
    
    print('🔍 SORT_DEBUG: Final result has ${result.length} questions');
    for (var q in result) {
      print('🔍 SORT_DEBUG:   RESULT - order=${q.order}, sectionId="${q.sectionId}", title="${q.title}"');
    }
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    
    return WillPopScope(
      onWillPop: () async {
        NavigationService.navigateToWithReplacement(AppRoutes.alumniDirectory);
        return false;
      },
      child: Stack(
        children: [
          ResponsiveScreenWrapper(
            title: 'Survey Question Management',
            customAppBar: const CustomAppBar(
              title: 'Survey Questions',
              showBackButton: false,
            ),
            body: Column(
              children: [
                _buildHeader(isDesktop),
                if (!_isBatchEditMode) _buildFilters(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _isBatchEditMode
                          ? _buildBatchEditView()
                          : _buildQuestionsList(),
                ),
              ],
            ),
          ),
          if (_isDeleting)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Deleting questions...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Padding(
      padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Survey Question Management',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isBatchEditMode 
                          ? 'Batch Edit Mode: ${_editableQuestions.length} questions being edited'
                          : 'Manage survey questions dynamically. Total: ${_questions.length} questions',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              _buildActionButtons(),
            ],
          ),
          const SizedBox(height: 16),
          _buildActiveSetBanner(),
          const SizedBox(height: 16),
          _buildSetSelector(),
        ],
      ),
    );
  }

  Widget _buildActiveSetBanner() {
    final activeSetDisplayName = _setNames[_activeSetId] ?? _activeSetId ?? 'No Set';
    final activeSetQuestionCount = _questionCounts[_activeSetId] ?? 0;
    final isViewingActiveSet = _currentSetId == _activeSetId;
    
    // Don't show the banner if there are no questions yet (empty database)
    if (_availableSets.isEmpty || (_availableSets.length == 1 && _availableSets.first == 'set_1' && activeSetQuestionCount == 0)) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.public, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🌍 ACTIVE SET FOR ALL USERS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activeSetDisplayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$activeSetQuestionCount questions • Alumni will see this set in their survey',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (!isViewingActiveSet && _activeSetId != null) ...[
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () => _changeCurrentSet(_activeSetId!),
              icon: const Icon(Icons.visibility),
              label: const Text('View Active Set'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green.shade700,
              ),
            ),
          ],
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _showSetManagementDialog,
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Change Active Set'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetSelector() {
    // Don't show the set selector if there are no questions yet (empty database)
    if (_availableSets.isEmpty || (_availableSets.length == 1 && _availableSets.first == 'set_1' && (_questionCounts['set_1'] ?? 0) == 0)) {
      return Card(
        color: Colors.grey.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey.shade600),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No question sets yet. Initialize default questions or create a new set to get started.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _showCreateSetDialog,
                icon: const Icon(Icons.add),
                label: const Text('New Set'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Safeguard: Ensure _currentSetId is in _availableSets, otherwise use first available set
    final effectiveCurrentSetId = _availableSets.contains(_currentSetId) 
        ? _currentSetId 
        : (_availableSets.isNotEmpty ? _availableSets.first : null);
    
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.edit, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            const Text(
              'Editing Set:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(Select which set to manage)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButton<String>(
                value: effectiveCurrentSetId,
                isExpanded: true,
                items: _availableSets.map((setId) {
                  final isActive = setId == _activeSetId;
                  final isDefault = setId == 'set_1';
                  final displayName = _setNames[setId] ?? setId;
                  final questionCount = _questionCounts[setId] ?? 0;
                  
                  return DropdownMenuItem<String>(
                    value: setId,
                    child: Row(
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'DEFAULT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          '$questionCount questions',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    _changeCurrentSet(value);
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _showCreateSetDialog,
              icon: const Icon(Icons.add),
              label: const Text('New Set'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _showSetManagementDialog,
              icon: const Icon(Icons.settings),
              tooltip: 'Manage Sets',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeCurrentSet(String setId) async {
    setState(() {
      _currentSetId = setId;
      _isBatchEditMode = false; // Exit batch edit mode when changing sets
    });
    await _loadQuestions();
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (!_isBatchEditMode) ...[
          PopupMenuButton<String>(
            icon: const Icon(Icons.import_export),
            tooltip: 'Import/Export',
            onSelected: (value) {
              switch (value) {
                case 'download_template':
                  _downloadExcelTemplate();
                  break;
                case 'import_excel':
                  _importQuestionsFromExcel();
                  break;
                case 'export_excel':
                  _exportCurrentSetToExcel();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'download_template',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20),
                    SizedBox(width: 8),
                    Text('Download Template'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import_excel',
                child: Row(
                  children: [
                    Icon(Icons.upload_file, size: 20),
                    SizedBox(width: 8),
                    Text('Import Questions'),
                  ],
                ),
              ),
              if (_questions.isNotEmpty)
                const PopupMenuItem(
                  value: 'export_excel',
                  child: Row(
                    children: [
                      Icon(Icons.file_download, size: 20),
                      SizedBox(width: 8),
                      Text('Export Current Set'),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: _initializeDefaultQuestions,
            icon: const Icon(Icons.restore),
            tooltip: 'Initialize Default Questions',
          ),
          IconButton(
            onPressed: _loadQuestions,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _toggleBatchEditMode,
            icon: const Icon(Icons.edit_note),
            label: const Text('Batch Edit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showQuestionDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Question'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ] else ...[
          // Multi-select controls
          if (_selectedQuestionIds.isNotEmpty) ...[
            Text(
              '${_selectedQuestionIds.length} selected',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _selectAllQuestions,
              icon: const Icon(Icons.select_all),
              tooltip: 'Select All',
            ),
            IconButton(
              onPressed: _clearSelection,
              icon: const Icon(Icons.clear),
              tooltip: 'Clear Selection',
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _deleteSelectedQuestions,
              icon: const Icon(Icons.delete_sweep),
              label: Text('Delete (${_selectedQuestionIds.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ] else ...[
            IconButton(
              onPressed: _selectAllQuestions,
              icon: const Icon(Icons.checklist),
              tooltip: 'Select Questions',
            ),
          ],
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveBatchChanges,
            icon: _isSaving 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'Saving...' : 'Save All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _addNewQuestionToBatch,
            icon: const Icon(Icons.add),
            label: const Text('Add New'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _toggleBatchEditMode,
            icon: const Icon(Icons.close),
            label: const Text('Cancel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search questions...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<QuestionType>(
                      value: _filterType,
                      decoration: const InputDecoration(
                        labelText: 'Filter by Type',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<QuestionType>(
                          value: null,
                          child: Text('All Types'),
                        ),
                        ...QuestionType.values.map((type) {
                          return DropdownMenuItem<QuestionType>(
                            value: type,
                            child: Text(_getQuestionTypeLabel(type)),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() => _filterType = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Total Questions: ${_questions.length}'),
                  const SizedBox(width: 24),
                  Text('Active: ${_questions.where((q) => q.isActive).length}'),
                  const SizedBox(width: 24),
                  Text('Inactive: ${_questions.where((q) => !q.isActive).length}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionsList() {
    final filteredQuestions = _filteredQuestions;
    
    if (filteredQuestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _questions.isEmpty ? 'No questions available' : 'No questions match your filters',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            if (_questions.isEmpty)
              ElevatedButton(
                onPressed: _initializeDefaultQuestions,
                child: const Text('Initialize Default Questions'),
              ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: filteredQuestions.length,
      onReorder: _reorderQuestions,
      itemBuilder: (context, index) {
        final question = filteredQuestions[index];
        return _buildQuestionCard(question, index, key: ValueKey(question.id));
      },
    );
  }

  Widget _buildQuestionCard(SurveyQuestionModel question, int index, {required Key key}) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 12.0),
      child: ExpansionTile(
        leading: _buildQuestionTypeIcon(question.type),
        title: Row(
          children: [
            Expanded(
              child: Text(
                question.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: question.isActive ? null : Colors.grey,
                ),
              ),
            ),
            if (!question.isActive)
              const Chip(
                label: Text('Inactive'),
                backgroundColor: Colors.orange,
              ),
            if (question.isRequired)
              const Chip(
                label: Text('Required'),
                backgroundColor: Colors.red,
              ),
          ],
        ),
                 subtitle: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Row(
               children: [
                 Text(_getQuestionTypeLabel(question.type)),
                 const SizedBox(width: 16),
                 if (question.sectionId != null && question.sectionId!.isNotEmpty)
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                     decoration: BoxDecoration(
                       color: _getSectionColor(question.sectionId!),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Text(
                       _getSectionDisplayName(question.sectionId!),
                       style: const TextStyle(
                         color: Colors.white,
                         fontSize: 10,
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                   ),
               ],
             ),
             if (question.description != null)
               Text(
                 question.description!,
                 maxLines: 2,
                 overflow: TextOverflow.ellipsis,
               ),
           ],
         ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (question.options.isNotEmpty) ...[
                  const Text('Options:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: question.options.map((option) {
                      return Chip(label: Text(option));
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (question.configuration.isNotEmpty) ...[
                  const Text('Configuration:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...question.configuration.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        children: [
                          Text('${entry.key}: ${entry.value}'),
                          if (entry.key == 'dynamicOptions') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getDynamicTypeColor(entry.value.toString()).shade100,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: _getDynamicTypeColor(entry.value.toString()).shade300),
                              ),
                              child: Text(
                                'DYNAMIC',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _getDynamicTypeColor(entry.value.toString()).shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${_getDynamicTypeLabel(entry.value.toString())})',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Text('Order: ${question.order}'),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _duplicateQuestion(question),
                      icon: const Icon(Icons.copy),
                      tooltip: 'Duplicate',
                    ),
                    IconButton(
                      onPressed: () => _showQuestionDialog(question: question),
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      onPressed: () => _toggleQuestionStatus(question),
                      icon: Icon(question.isActive ? Icons.visibility_off : Icons.visibility),
                      tooltip: question.isActive ? 'Deactivate' : 'Activate',
                    ),
                    IconButton(
                      onPressed: () => _deleteQuestion(question),
                      icon: const Icon(Icons.delete),
                      color: Colors.red,
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionTypeIcon(QuestionType type) {
    IconData icon;
    switch (type) {
      case QuestionType.section:
        icon = Icons.title;
        break;
      case QuestionType.textInput:
        icon = Icons.text_fields;
        break;
      case QuestionType.textArea:
        icon = Icons.text_snippet;
        break;
      case QuestionType.singleChoice:
        icon = Icons.radio_button_checked;
        break;
      case QuestionType.multipleChoice:
        icon = Icons.check_box;
        break;
      case QuestionType.dropdown:
        icon = Icons.arrow_drop_down;
        break;
      case QuestionType.rating:
        icon = Icons.star;
        break;
      case QuestionType.dateInput:
        icon = Icons.calendar_today;
        break;
      case QuestionType.numberInput:
        icon = Icons.numbers;
        break;
      case QuestionType.switchToggle:
        icon = Icons.toggle_on;
        break;
      default:
        icon = Icons.help;
    }
    return Icon(icon);
  }

  Widget _buildBatchEditView() {
    if (_editableQuestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_note, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No questions to edit',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addNewQuestionToBatch,
              child: const Text('Add First Question'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollUpdateNotification>(
            onNotification: (notification) {
              return false;
            },
            child: SingleChildScrollView(
              controller: _batchEditScrollController,
              padding: const EdgeInsets.all(16.0),
              child: ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                onReorder: _reorderBatchQuestions,
                children: _editableQuestions.asMap().entries.map((entry) {
                  int index = entry.key;
                  final question = entry.value;
                  return _buildBatchEditCard(question, index, key: ValueKey(question.id));
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Multi-select methods
  void _toggleQuestionSelection(String questionId) {
    setState(() {
      if (_selectedQuestionIds.contains(questionId)) {
        _selectedQuestionIds.remove(questionId);
      } else {
        _selectedQuestionIds.add(questionId);
      }
    });
  }

  void _selectAllQuestions() {
    setState(() {
      _selectedQuestionIds = _editableQuestions.map((q) => q.id).toSet();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedQuestionIds.clear();
    });
  }

    Future<void> _deleteSelectedQuestions() async {
    if (_selectedQuestionIds.isEmpty) return;

    final count = _selectedQuestionIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
          'Are you sure you want to permanently delete $count question${count > 1 ? 's' : ''}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading state
    setState(() {
      _isDeleting = true;
    });

    try {
      // Delete selected questions
      int deletedCount = 0;
      for (final questionId in _selectedQuestionIds.toList()) {
        final question = _editableQuestions.firstWhere(
          (q) => q.id == questionId,
          orElse: () => SurveyQuestionModel(id: '', title: '', type: QuestionType.textInput, order: 0, isRequired: false, options: [], validation: {}, createdAt: DateTime.now(), isActive: true, configuration: {}),
        );
       
        final isNewQuestion = question.id.isEmpty || question.id.startsWith('new_');
       
        if (!isNewQuestion) {
          try {
            await _questionService.permanentlyDeleteQuestion(question.id);
            deletedCount++;
          } catch (e) {
            _showErrorSnackBar('Error deleting question: $e');
          }
        }
      }

      // Remove from local list and clear selection
      setState(() {
        _editableQuestions.removeWhere((q) => _selectedQuestionIds.contains(q.id));
        _selectedQuestionIds.forEach((id) {
          _controllers[id]?.forEach((key, controller) => controller.dispose());
          _controllers.remove(id);
        });
        _selectedQuestionIds.clear();
      });

      if (deletedCount > 0) {
        _showSuccessSnackBar('$deletedCount question${deletedCount > 1 ? 's' : ''} deleted successfully');
      }
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  Widget _buildBatchEditCard(SurveyQuestionModel question, int index, {required Key key}) {
    final controllers = _controllers[question.id];
    if (controllers == null) return Container(key: key);

    final isSelected = _selectedQuestionIds.contains(question.id);

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 16.0),
      color: isSelected ? Colors.blue.shade50 : null,
      elevation: isSelected ? 4 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with drag handle and actions
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) => _toggleQuestionSelection(question.id),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.drag_handle, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Question ${index + 1}${question.title.isNotEmpty ? ': ${question.title}' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: question.isActive ? Colors.green.shade100 : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildQuestionTypeIcon(question.type),
                        const SizedBox(width: 4),
                        Text(
                          _getQuestionTypeLabel(question.type),
                          style: TextStyle(
                            fontSize: 12,
                            color: question.isActive ? Colors.green.shade700 : Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _deleteBatchQuestion(index),
                    icon: const Icon(Icons.delete),
                    color: Colors.red,
                    tooltip: 'Delete Question',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Form fields in responsive layout
            Responsive.isDesktop(context) 
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: controllers['title'],
                          decoration: const InputDecoration(
                            labelText: 'Question Title *',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: null,
                          onChanged: (value) => setState(() {}), // Trigger rebuild to update header
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: controllers['description'],
                          decoration: const InputDecoration(
                            labelText: 'Description (Optional)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      TextFormField(
                        controller: controllers['title'],
                        decoration: const InputDecoration(
                          labelText: 'Question Title *',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: null,
                        onChanged: (value) => setState(() {}), // Trigger rebuild to update header
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: controllers['description'],
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
            const SizedBox(height: 12),
            
            // Dropdowns in responsive layout
            Responsive.isDesktop(context)
                ? Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<QuestionType>(
                          value: question.type,
                          decoration: const InputDecoration(
                            labelText: 'Question Type',
                            border: OutlineInputBorder(),
                          ),
                          items: QuestionType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(_getQuestionTypeLabel(type)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _editableQuestions[index] = question.copyWith(type: value);
                                // Update configuration based on new type
                                _editableQuestions[index] = _editableQuestions[index].copyWith(
                                  configuration: SurveyQuestionModel.getDefaultConfiguration(value),
                                );
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: question.sectionId,
                          decoration: const InputDecoration(
                            labelText: 'Section',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('No Section')),
                            const DropdownMenuItem(
                              value: 'section_privacy', 
                              child: Text('1. Privacy & Data Act')
                            ),
                            const DropdownMenuItem(
                              value: 'section_personal', 
                              child: Text('2. Personal Information')
                            ),
                            const DropdownMenuItem(
                              value: 'section_education', 
                              child: Text('3. Educational Background')
                            ),
                            const DropdownMenuItem(
                              value: 'section_employment', 
                              child: Text('4. Employment Information')
                            ),
                            const DropdownMenuItem(
                              value: 'section_self_employment', 
                              child: Text('5. Employment Details')
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _editableQuestions[index] = question.copyWith(sectionId: value);
                            });
                          },
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      DropdownButtonFormField<QuestionType>(
                        value: question.type,
                        decoration: const InputDecoration(
                          labelText: 'Question Type',
                          border: OutlineInputBorder(),
                        ),
                        items: QuestionType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(_getQuestionTypeLabel(type)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _editableQuestions[index] = question.copyWith(type: value);
                              // Update configuration based on new type
                              _editableQuestions[index] = _editableQuestions[index].copyWith(
                                configuration: SurveyQuestionModel.getDefaultConfiguration(value),
                              );
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: question.sectionId,
                        decoration: const InputDecoration(
                          labelText: 'Section',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('No Section')),
                          const DropdownMenuItem(
                            value: 'section_privacy', 
                            child: Text('1. Privacy & Data Act')
                          ),
                          const DropdownMenuItem(
                            value: 'section_personal', 
                            child: Text('2. Personal Information')
                          ),
                          const DropdownMenuItem(
                            value: 'section_education', 
                            child: Text('3. Educational Background')
                          ),
                          const DropdownMenuItem(
                            value: 'section_employment', 
                            child: Text('4. Employment Information')
                          ),
                          const DropdownMenuItem(
                            value: 'section_self_employment', 
                            child: Text('5. Employment Details')
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _editableQuestions[index] = question.copyWith(sectionId: value);
                          });
                        },
                      ),
                    ],
                  ),
            const SizedBox(height: 12),
            
            // Options field (if needed)
            if (_needsOptions(question.type)) ...[
              if (question.configuration.containsKey('dynamicOptions')) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dynamic Options: ${_getDynamicTypeLabel(question.configuration['dynamicOptions'])}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            Text(
                              'Options are automatically generated from database',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            final newConfig = Map<String, dynamic>.from(question.configuration);
                            newConfig.remove('dynamicOptions');
                            _editableQuestions[index] = question.copyWith(
                              configuration: newConfig,
                              options: [],
                            );
                          });
                        },
                        icon: const Icon(Icons.clear),
                        tooltip: 'Convert to Static Options',
                      ),
                    ],
                  ),
                ),
              ] else ...[
                TextFormField(
                  controller: controllers['options'],
                  decoration: const InputDecoration(
                    labelText: 'Options (one per line)',
                    border: OutlineInputBorder(),
                    helperText: 'Enter each option on a new line',
                  ),
                  maxLines: 4,
                  onChanged: (value) {
                    final options = value.split('\n').where((s) => s.trim().isNotEmpty).toList();
                    setState(() {
                      _editableQuestions[index] = question.copyWith(options: options);
                    });
                  },
                ),
              ],
              const SizedBox(height: 12),
            ],
            
            // Settings checkboxes
            Row(
              children: [
                Checkbox(
                  value: question.isRequired,
                  onChanged: (value) {
                    setState(() {
                      _editableQuestions[index] = question.copyWith(isRequired: value ?? false);
                    });
                  },
                ),
                const Text('Required'),
                const SizedBox(width: 24),
                Checkbox(
                  value: question.isActive,
                  onChanged: (value) {
                    setState(() {
                      _editableQuestions[index] = question.copyWith(isActive: value ?? true);
                    });
                  },
                ),
                const Text('Active'),
              ],
            ),
          ],
        ),
      ),
    );
  }

     String _getQuestionTypeLabel(QuestionType type) {
     switch (type) {
       case QuestionType.section:
         return 'Section Header';
       case QuestionType.textInput:
         return 'Short Answer';
       case QuestionType.textArea:
         return 'Paragraph';
       case QuestionType.singleChoice:
         return 'Multiple Choice';
       case QuestionType.multipleChoice:
         return 'Multiple Choice';
       case QuestionType.checkboxList:
         return 'Checkboxes';
       case QuestionType.dropdown:
         return 'Dropdown';
       case QuestionType.rating:
         return 'Linear Scale';
       case QuestionType.dateInput:
         return 'Date and Time';
       case QuestionType.numberInput:
         return 'Number Input';
       case QuestionType.switchToggle:
         return 'Switch Toggle';
     }
   }

   Color _getSectionColor(String sectionId) {
     switch (sectionId) {
       case 'section_privacy':
         return Colors.purple;
       case 'section_personal':
         return Colors.blue;
       case 'section_education':
         return Theme.of(context).primaryColor;
       case 'section_employment':
         return Colors.orange;
       case 'section_self_employment':
         return Colors.red;
       default:
         return Colors.grey;
     }
   }

   String _getSectionDisplayName(String sectionId) {
     switch (sectionId) {
       case 'section_privacy':
         return 'Privacy';
       case 'section_personal':
         return 'Personal';
       case 'section_education':
         return 'Education';
       case 'section_employment':
         return 'Employment';
       case 'section_self_employment':
         return 'Employment Details';
       default:
         return sectionId.replaceAll('section_', '').replaceAll('_', ' ');
     }
   }

  MaterialColor _getDynamicTypeColor(String dynamicType) {
    switch (dynamicType) {
      case 'batchYears':
        return Colors.blue;
      case 'courses':
        return MaterialColor(Theme.of(context).primaryColor.value, {
          50: Theme.of(context).primaryColor.withOpacity(0.1),
          100: Theme.of(context).primaryColor.withOpacity(0.2),
          200: Theme.of(context).primaryColor.withOpacity(0.3),
          300: Theme.of(context).primaryColor.withOpacity(0.4),
          400: Theme.of(context).primaryColor.withOpacity(0.5),
          500: Theme.of(context).primaryColor,
          600: Theme.of(context).primaryColor.withOpacity(0.7),
          700: Theme.of(context).primaryColor.withOpacity(0.8),
          800: Theme.of(context).primaryColor.withOpacity(0.9),
          900: Theme.of(context).primaryColor,
        });
      case 'colleges':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

   String _getDynamicTypeLabel(String dynamicType) {
     switch (dynamicType) {
       case 'batchYears':
         return 'Years';
       case 'courses':
         return 'Courses';
       case 'colleges':
         return 'Colleges';
       default:
         return 'Unknown';
     }
   }

  Future<void> _showCreateSetDialog() async {
    final nameController = TextEditingController();
    bool copyFromExisting = false;
    String? selectedSourceSetId;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Create New Question Set'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Set Display Name',
                      hintText: 'e.g., Alumni Survey 2024',
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Copy questions from existing set'),
                    value: copyFromExisting,
                    onChanged: (value) {
                      setState(() {
                        copyFromExisting = value ?? false;
                        if (!copyFromExisting) {
                          selectedSourceSetId = null;
                        }
                      });
                    },
                  ),
                  if (copyFromExisting) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedSourceSetId,
                      decoration: const InputDecoration(
                        labelText: 'Source Set',
                        border: OutlineInputBorder(),
                      ),
                      items: _availableSets.map((setId) {
                        final displayName = _setNames[setId] ?? setId;
                        final questionCount = _questionCounts[setId] ?? 0;
                        return DropdownMenuItem<String>(
                          value: setId,
                          child: Text('$displayName ($questionCount questions)'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedSourceSetId = value;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  copyFromExisting && selectedSourceSetId != null
                      ? 'Creating new set and copying questions...\nThis may take a moment.'
                      : 'Creating new set...',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );

      try {
        // Generate new set ID
        final maxSetNumber = _availableSets
            .where((id) => id.startsWith('set_'))
            .map((id) => int.tryParse(id.replaceAll('set_', '')) ?? 0)
            .fold(0, (max, num) => num > max ? num : max);
        
        final newSetId = 'set_${maxSetNumber + 1}';
        final newSetDisplayName = nameController.text;

        // Save the display name to database
        await _questionService.updateSetDisplayName(newSetId, newSetDisplayName);

        // Immediately update local state to show the new set in dropdown (even with 0 questions)
        setState(() {
          if (!_availableSets.contains(newSetId)) {
            _availableSets.add(newSetId);
          }
          _setNames[newSetId] = newSetDisplayName;
          _questionCounts[newSetId] = 0; // Start with 0 questions
        });

        // Copy questions if requested
        if (copyFromExisting && selectedSourceSetId != null) {
          await _questionService.duplicateQuestionsToSet(selectedSourceSetId!, newSetId);
          
          // After copying, update the question count
          final copiedQuestions = await _questionService.getAllQuestions(setId: newSetId);
          setState(() {
            _questionCounts[newSetId] = copiedQuestions.length;
          });
        }
        
        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
        }

        // Now switch to the new set (local state is already updated)
        await _changeCurrentSet(newSetId);
        
        // Show success message
        _showSuccessSnackBar(
          copyFromExisting && selectedSourceSetId != null
              ? 'Question set created and ${_questionCounts[newSetId] ?? 0} questions copied successfully'
              : 'Question set created successfully. You can now add questions to this set.'
        );
      } catch (e) {
        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
        }
        _showErrorSnackBar('Error creating question set: $e');
      }
    }
  }

  Future<void> _showSetManagementDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Question Sets'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.6,
          height: MediaQuery.of(context).size.height * 0.6,
          child: ListView.builder(
            itemCount: _availableSets.length,
            itemBuilder: (context, index) {
              final setId = _availableSets[index];
              final isActive = setId == _activeSetId;
              final isDefault = setId == 'set_1';
              final displayName = _setNames[setId] ?? setId;
              final questionCount = _questionCounts[setId] ?? 0;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Row(
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'DEFAULT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '$questionCount questions',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isActive)
                        IconButton(
                          onPressed: () async {
                            await _questionService.setActiveSetId(setId);
                            await _loadQuestionSetsAndQuestions();
                            Navigator.of(context).pop();
                            _showSuccessSnackBar('$displayName is now the active set for users');
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          tooltip: 'Set as Active',
                          color: Colors.green,
                        ),
                      // Cannot delete set_1
                      if (setId != 'set_1')
                        IconButton(
                          onPressed: () async {
                            final canDelete = await _questionService.canDeleteSet(setId);
                            if (!canDelete) {
                              _showErrorSnackBar('Cannot delete the active set. Please set another set as active first.');
                              return;
                            }
                            
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Question Set'),
                                content: Text(
                                  'Are you sure you want to delete "$displayName"?\n\nThis will permanently delete all $questionCount questions in this set.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              try {
                                // Delete all questions in the set
                                await _questionService.deleteAllQuestionsInSet(setId);
                                await _loadQuestionSetsAndQuestions();
                                Navigator.of(context).pop();
                                _showSuccessSnackBar('Question set deleted');
                              } catch (e) {
                                _showErrorSnackBar('Error deleting set: $e');
                              }
                            }
                          },
                          icon: const Icon(Icons.delete),
                          tooltip: 'Delete Set',
                          color: Colors.red,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showQuestionDialog({SurveyQuestionModel? question}) {
    if (_currentSetId == null) {
      _showErrorSnackBar('No question set selected');
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => QuestionEditDialog(
        question: question,
        currentSetId: _currentSetId!,
        onSave: (savedQuestion) async {
          try {
            if (question == null) {
              await _questionService.createQuestion(savedQuestion);
            } else {
              await _questionService.updateQuestion(savedQuestion);
            }
            _loadQuestions();
            Navigator.of(context).pop();
            _showSuccessSnackBar(question == null ? 'Question created' : 'Question updated');
          } catch (e) {
            _showErrorSnackBar('Error saving question: $e');
          }
        },
      ),
    );
  }

  Future<void> _reorderQuestions(int oldIndex, int newIndex) async {
    final filteredQuestions = _filteredQuestions;
    if (newIndex > oldIndex) newIndex--;
    
    final question = filteredQuestions.removeAt(oldIndex);
    filteredQuestions.insert(newIndex, question);
    
    try {
      await _questionService.reorderQuestions(filteredQuestions);
      _loadQuestions();
      _showSuccessSnackBar('Questions reordered');
    } catch (e) {
      _showErrorSnackBar('Error reordering questions: $e');
    }
  }

  Future<void> _duplicateQuestion(SurveyQuestionModel question) async {
    try {
      await _questionService.duplicateQuestion(question.id);
      _loadQuestions();
      _showSuccessSnackBar('Question duplicated');
    } catch (e) {
      _showErrorSnackBar('Error duplicating question: $e');
    }
  }

  Future<void> _toggleQuestionStatus(SurveyQuestionModel question) async {
    try {
      await _questionService.toggleQuestionStatus(question.id, !question.isActive);
      _loadQuestions();
      _showSuccessSnackBar('Question ${question.isActive ? 'deactivated' : 'activated'}');
    } catch (e) {
      _showErrorSnackBar('Error toggling question status: $e');
    }
  }

  Future<void> _deleteQuestion(SurveyQuestionModel question) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to permanently delete "${question.title}"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        print('Starting delete process for question: ${question.id} - ${question.title}');
        await _questionService.permanentlyDeleteQuestion(question.id);
        print('Delete completed, reloading questions...');
        await _loadQuestions();
        print('Questions reloaded, showing success message');
        _showSuccessSnackBar('Question permanently deleted');
      } catch (e) {
        print('Error in delete process: $e');
        _showErrorSnackBar('Error deleting question: $e');
      }
    }
  }

  Future<void> _initializeDefaultQuestions() async {
    try {
      await _questionService.initializeDefaultQuestions();
      _loadQuestions();
      _showSuccessSnackBar('Default questions initialized');
    } catch (e) {
      _showErrorSnackBar('Error initializing questions: $e');
    }
  }

  Future<void> _saveBatchChanges() async {
    setState(() => _isSaving = true);
    
    try {
      // Validate all questions
      List<String> errors = [];
      for (int i = 0; i < _editableQuestions.length; i++) {
        final question = _editableQuestions[i];
        final controllers = _controllers[question.id];
        
        if (controllers != null) {
          final title = controllers['title']!.text.trim();
          if (title.isEmpty) {
            errors.add('Question ${i + 1}: Title is required');
          }
          
          // Update question with controller values, preserving all other fields
          _editableQuestions[i] = question.copyWith(
            title: title,
            description: controllers['description']!.text.trim().isEmpty 
                ? null 
                : controllers['description']!.text.trim(),
            options: controllers['options']!.text
                .split('\n')
                .where((s) => s.trim().isNotEmpty)
                .toList(),
            updatedAt: DateTime.now(),
          );
        }
      }
      
      if (errors.isNotEmpty) {
        _showErrorSnackBar('Validation errors:\n${errors.join('\n')}');
        return;
      }
      
      // Save all questions
      for (final question in _editableQuestions) {
        if (question.id.isEmpty || question.id.startsWith('new_')) {
          // New question - create a clean question without the temporary ID
          final cleanQuestion = question.copyWith(id: '');
          await _questionService.createQuestion(cleanQuestion);
        } else {
          // Update existing question with all fields preserved
          await _questionService.updateQuestion(question);
        }
      }
      
      await _loadQuestions();
      _showSuccessSnackBar('All questions saved successfully');
      
    } catch (e) {
      _showErrorSnackBar('Error saving questions: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _addNewQuestionToBatch() {
    if (_currentSetId == null) return;
    
    final newQuestionId = 'new_${DateTime.now().millisecondsSinceEpoch}';
    final newQuestion = SurveyQuestionModel(
      id: '', // Will be assigned by Firestore
      title: '',
      type: QuestionType.textInput,
      isRequired: false,
      order: _editableQuestions.length + 1,
      sectionId: 'section_personal', // Default to Personal Information section
      setId: _currentSetId!, // Use current set
      configuration: SurveyQuestionModel.getDefaultConfiguration(QuestionType.textInput),
      options: [],
      validation: {},
      createdAt: DateTime.now(),
      isActive: true,
    );
    
    setState(() {
      _editableQuestions.add(newQuestion);
      _controllers[newQuestionId] = {
        'title': TextEditingController(),
        'description': TextEditingController(),
        'options': TextEditingController(),
      };
      
      // Update the question ID in the list to match controller key
      _editableQuestions[_editableQuestions.length - 1] = newQuestion.copyWith(id: newQuestionId);
    });
    
    // Scroll to bottom after the new question is added
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_batchEditScrollController.hasClients) {
          _batchEditScrollController.jumpTo(_batchEditScrollController.position.maxScrollExtent);
        }
      });
    });
  }

  Future<void> _deleteBatchQuestion(int index) async {
    final question = _editableQuestions[index];
    
    // Check if this is an existing question or a new one
    final isNewQuestion = question.id.isEmpty || question.id.startsWith('new_');
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: Text(
          isNewQuestion
              ? 'Are you sure you want to remove "${question.title.isEmpty ? 'this new question' : question.title}"?'
              : 'Are you sure you want to permanently delete "${question.title}" from the database?\n\nThis action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(isNewQuestion ? 'Remove' : 'Delete Permanently'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      // If this is an existing question, delete it from the database
      if (!isNewQuestion) {
        try {
          print('[BATCH DELETE] Starting delete process for question: ${question.id} - ${question.title}');
          await _questionService.permanentlyDeleteQuestion(question.id);
          print('[BATCH DELETE] Delete completed from database');
          _showSuccessSnackBar('Question permanently deleted from database');
        } catch (e) {
          print('[BATCH DELETE] Error in delete process: $e');
          _showErrorSnackBar('Error deleting question: $e');
          return; // Don't remove from local list if database delete failed
        }
      }
      
      // Remove from local batch edit list and dispose controllers
      setState(() {
        _editableQuestions.removeAt(index);
        _controllers[question.id]?.forEach((key, controller) => controller.dispose());
        _controllers.remove(question.id);
      });
      
      if (isNewQuestion) {
        _showSuccessSnackBar('New question removed from batch');
      }
    }
  }

  void _reorderBatchQuestions(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final question = _editableQuestions.removeAt(oldIndex);
      _editableQuestions.insert(newIndex, question);
      
      // Update orders
      for (int i = 0; i < _editableQuestions.length; i++) {
        _editableQuestions[i] = _editableQuestions[i].copyWith(order: i + 1);
      }
    });
  }

  void _disposeControllers() {
    for (final controllerMap in _controllers.values) {
      for (final controller in controllerMap.values) {
        controller.dispose();
      }
    }
  }

  bool _needsOptions(QuestionType type) {
    return [
      QuestionType.singleChoice,
      QuestionType.multipleChoice,
      QuestionType.checkboxList,
      QuestionType.dropdown,
    ].contains(type);
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Theme.of(context).primaryColor),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ==================== EXCEL IMPORT/EXPORT ====================

  Future<void> _downloadExcelTemplate() async {
    try {
      final bytes = await ExcelImportExportService.generateTemplate();
      
      // Download file
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'ESSU_Question_Template.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
      
      _showSuccessSnackBar('Template downloaded successfully');
    } catch (e) {
      _showErrorSnackBar('Error downloading template: $e');
    }
  }

  Future<void> _importQuestionsFromExcel() async {
    try {
      // Parse Excel file
      final result = await ExcelImportExportService.pickAndParseExcelFile();
      
      if (result == null) {
        // User cancelled
        return;
      }
      
      final questions = result['questions'] as List<Map<String, dynamic>>;
      final errors = result['errors'] as List<String>;
      final totalRows = result['totalRows'] as int;
      
      // Show validation dialog
      if (errors.isNotEmpty || questions.isEmpty) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                const Text('Import Validation Errors'),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.6,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Found ${questions.length} valid questions out of $totalRows rows'),
                  const SizedBox(height: 16),
                  if (errors.isNotEmpty) ...[
                    const Text('Errors:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: errors.map((error) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• $error', style: TextStyle(color: Colors.red.shade700)),
                          )).toList(),
                        ),
                      ),
                    ),
                  ],
                  if (questions.isEmpty)
                    const Text(
                      '\nNo valid questions found. Please fix the errors and try again.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      }
      
      // Show import dialog with set name
      final setNameController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Questions'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Successfully parsed ${questions.length} questions from Excel file.'),
              const SizedBox(height: 16),
              const Text(
                'A new question set will be created.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: setNameController,
                decoration: const InputDecoration(
                  labelText: 'New Set Name',
                  hintText: 'e.g., Imported Survey 2024',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      
      if (confirmed != true || setNameController.text.isEmpty) {
        return;
      }
      
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Importing ${questions.length} questions...\nThis may take a moment.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
      
      try {
        // Generate new set ID
        final maxSetNumber = _availableSets
            .where((id) => id.startsWith('set_'))
            .map((id) => int.tryParse(id.replaceAll('set_', '')) ?? 0)
            .fold(0, (max, num) => num > max ? num : max);
        
        final newSetId = 'set_${maxSetNumber + 1}';
        final newSetDisplayName = setNameController.text;
        
        // Create questions
        final questionModels = ExcelImportExportService.createQuestionsFromParsedData(
          questions,
          newSetId,
        );
        
        // Save all questions to Firestore
        for (final question in questionModels) {
          await _questionService.createQuestion(question);
        }
        
        // Save set display name
        await _questionService.updateSetDisplayName(newSetId, newSetDisplayName);
        
        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
        }
        
        // Reload and switch to new set
        await _loadQuestionSetsAndQuestions();
        await _changeCurrentSet(newSetId);
        
        _showSuccessSnackBar(
          'Successfully imported ${questionModels.length} questions to "$newSetDisplayName"'
        );
      } catch (e) {
        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
        }
        _showErrorSnackBar('Error importing questions: $e');
      }
    } catch (e) {
      _showErrorSnackBar('Error processing Excel file: $e');
    }
  }

  Future<void> _exportCurrentSetToExcel() async {
    if (_currentSetId == null || _questions.isEmpty) {
      _showErrorSnackBar('No questions to export');
      return;
    }
    
    try {
      final setName = _setNames[_currentSetId] ?? _currentSetId!;
      final bytes = await ExcelImportExportService.exportQuestionsToExcel(_questions, setName);
      
      // Download file
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final fileName = '${setName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      
      _showSuccessSnackBar('${_questions.length} questions exported successfully');
    } catch (e) {
      _showErrorSnackBar('Error exporting questions: $e');
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    _batchEditScrollController.dispose();
    super.dispose();
  }

}

// Question Edit Dialog (simplified version)
class QuestionEditDialog extends StatefulWidget {
  final SurveyQuestionModel? question;
  final String currentSetId;
  final Function(SurveyQuestionModel) onSave;

  const QuestionEditDialog({
    Key? key,
    this.question,
    required this.currentSetId,
    required this.onSave,
  }) : super(key: key);

  @override
  State<QuestionEditDialog> createState() => _QuestionEditDialogState();
}

class _QuestionEditDialogState extends State<QuestionEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _optionsController = TextEditingController();
  QuestionType _selectedType = QuestionType.textInput;
  bool _isRequired = false;
  bool _isActive = true;
  String? _selectedSectionId;
  bool _hasDynamicOptions = false;
  String? _selectedDynamicType;

  @override
  void initState() {
    super.initState();
    if (widget.question != null) {
      final question = widget.question!;
      _titleController.text = question.title;
      _descriptionController.text = question.description ?? '';
      _optionsController.text = question.options.join('\n');
      _selectedType = question.type;
      _isRequired = question.isRequired;
      _isActive = question.isActive;
      _selectedSectionId = question.sectionId;
      
      
      // Load dynamic options if present
      if (question.configuration.containsKey('dynamicOptions')) {
        _hasDynamicOptions = true;
        _selectedDynamicType = question.configuration['dynamicOptions'] as String?;
      }
    } else {
      // Default to Personal Information section for new questions
      _selectedSectionId = 'section_personal';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.question == null ? 'Add Question' : 'Edit Question'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Question Title'),
                  validator: (value) => value?.isEmpty == true ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description (Optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<QuestionType>(
                  value: _selectedType,
                  decoration: const InputDecoration(labelText: 'Question Type'),
                  items: QuestionType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_getQuestionTypeLabel(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedType = value!);
                  },
                ),
                const SizedBox(height: 16),
                                 DropdownButtonFormField<String>(
                   value: _selectedSectionId,
                   decoration: const InputDecoration(
                     labelText: 'Section',
                     helperText: 'Select which section this question belongs to',
                   ),
                   items: [
                     const DropdownMenuItem(value: null, child: Text('No Section (Will appear at the end)')),
                     const DropdownMenuItem(
                       value: 'section_privacy', 
                       child: Text('1. Privacy & Data Act (Purpose & Consent)')
                     ),
                     const DropdownMenuItem(
                       value: 'section_personal', 
                       child: Text('2. Personal Information (Name, Address, Contact)')
                     ),
                     const DropdownMenuItem(
                       value: 'section_education', 
                       child: Text('3. Educational Background (Graduation, Campus, Program)')
                     ),
                     const DropdownMenuItem(
                       value: 'section_employment', 
                       child: Text('4. Employment Information (Current Job Details)')
                     ),
                     const DropdownMenuItem(
                       value: 'section_self_employment', 
                       child: Text('5. Employment Details (Job & Business Details)')
                     ),
                   ],
                   onChanged: (value) {
                     setState(() => _selectedSectionId = value);
                   },
                 ),
                const SizedBox(height: 16),
                if (_needsOptions(_selectedType)) ...[
                  Row(
                    children: [
                      Checkbox(
                        value: _hasDynamicOptions,
                        onChanged: (value) => setState(() => _hasDynamicOptions = value!),
                      ),
                      const Text('Use Dynamic Options'),
                    ],
                  ),
                  if (_hasDynamicOptions) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedDynamicType,
                      decoration: const InputDecoration(
                        labelText: 'Dynamic Option Type',
                        helperText: 'Select the type of dynamic options',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'batchYears',
                          child: Text('Academic Years (2020-2021 to current)'),
                        ),
                        DropdownMenuItem(
                          value: 'courses',
                          child: Text('Programs (from database)'),
                        ),
                        DropdownMenuItem(
                          value: 'colleges',
                          child: Text('Colleges (from database)'),
                        ),
                        // Add more dynamic types here in the future
                      ],
                      onChanged: (value) => setState(() => _selectedDynamicType = value),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    TextFormField(
                      controller: _optionsController,
                      decoration: const InputDecoration(
                        labelText: 'Options (one per line)',
                        helperText: 'Enter each option on a new line',
                      ),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
                Row(
                  children: [
                    Checkbox(
                      value: _isRequired,
                      onChanged: (value) => setState(() => _isRequired = value!),
                    ),
                    const Text('Required'),
                    const SizedBox(width: 24),
                    Checkbox(
                      value: _isActive,
                      onChanged: (value) => setState(() => _isActive = value!),
                    ),
                    const Text('Active'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  bool _needsOptions(QuestionType type) {
    return [
      QuestionType.singleChoice,
      QuestionType.multipleChoice,
      QuestionType.checkboxList,
      QuestionType.dropdown,
    ].contains(type);
  }

  String _getQuestionTypeLabel(QuestionType type) {
    // Same implementation as in the main screen
    switch (type) {
      case QuestionType.section:
        return 'Section Header';
      case QuestionType.textInput:
        return 'Short Answer';
      case QuestionType.textArea:
        return 'Paragraph';
      case QuestionType.singleChoice:
        return 'Single Choice';
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.checkboxList:
        return 'Checkboxes';
      case QuestionType.dropdown:
        return 'Dropdown';
      case QuestionType.rating:
        return 'Linear Scale';
      case QuestionType.dateInput:
        return 'Date and Time';
      case QuestionType.numberInput:
        return 'Number Input';
      case QuestionType.switchToggle:
        return 'Switch Toggle';
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    // Build configuration
    Map<String, dynamic> configuration = SurveyQuestionModel.getDefaultConfiguration(_selectedType);
    
    // Handle options based on whether they're dynamic or static
    List<String> options = <String>[];
    if (_needsOptions(_selectedType)) {
      if (_hasDynamicOptions && _selectedDynamicType != null) {
        // For dynamic options, we'll set the configuration and let the service handle the actual options
        configuration['dynamicOptions'] = _selectedDynamicType;
        
        // Set initial options based on dynamic type
        switch (_selectedDynamicType) {
          case 'batchYears':
            options = BatchYearUtils.generateBatchYears();
            break;
          case 'courses':
          case 'colleges':
            // For courses and colleges, we'll start with empty options
            // The service will populate them dynamically
            options = <String>[];
            break;
          default:
            options = <String>[];
        }
      } else {
        // Static options from text input
        options = _optionsController.text.split('\n').where((s) => s.trim().isNotEmpty).toList();
      }
    }

    // No conditional logic needed - section-level visibility is handled in the UI
    Map<String, dynamic> conditionalLogic = {};

    final question = SurveyQuestionModel(
      id: widget.question?.id ?? '',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      type: _selectedType,
      isRequired: _isRequired,
      order: widget.question?.order ?? 0,
      sectionId: _selectedSectionId,
      setId: widget.question?.setId ?? widget.currentSetId, // Use current set or existing set
      configuration: configuration,
      options: options,
      validation: _isRequired ? {'required': 'This field is required'} : {},
      conditionalLogic: conditionalLogic,
      createdAt: widget.question?.createdAt ?? DateTime.now(),
      updatedAt: widget.question != null ? DateTime.now() : null,
      isActive: _isActive,
    );

    widget.onSave(question);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _optionsController.dispose();
    super.dispose();
  }
} 