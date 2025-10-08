import 'package:flutter/material.dart';
import '../../models/survey_question_model.dart';
import '../../services/survey_question_service.dart';
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
  bool _isLoading = false;
  bool _isBatchEditMode = false;
  bool _isSaving = false;
  String _searchQuery = '';
  QuestionType? _filterType;
  
  // Controllers for batch edit mode
  final Map<String, Map<String, TextEditingController>> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final questions = await _questionService.getAllQuestions();
      setState(() {
        _questions = questions;
        if (_isBatchEditMode) {
          _initializeBatchEditMode();
        }
      });
    } catch (e) {
      _showErrorSnackBar('Error loading questions: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _initializeBatchEditMode() {
    _editableQuestions = List.from(_questions);
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
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    
    return WillPopScope(
      onWillPop: () async {
        NavigationService.navigateToWithReplacement(AppRoutes.alumniDirectory);
        return false;
      },
      child: ResponsiveScreenWrapper(
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
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Padding(
      padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
      child: Row(
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
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (!_isBatchEditMode) ...[
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

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _editableQuestions.length,
      onReorder: _reorderBatchQuestions,
      itemBuilder: (context, index) {
        final question = _editableQuestions[index];
        return _buildBatchEditCard(question, index, key: ValueKey(question.id));
      },
    );
  }

  Widget _buildBatchEditCard(SurveyQuestionModel question, int index, {required Key key}) {
    final controllers = _controllers[question.id];
    if (controllers == null) return Container(key: key);

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 16.0),
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
         return 'Text Input';
       case QuestionType.textArea:
         return 'Text Area';
       case QuestionType.singleChoice:
         return 'Single Choice';
       case QuestionType.multipleChoice:
         return 'Multiple Choice';
       case QuestionType.checkboxList:
         return 'Checkbox List';
       case QuestionType.dropdown:
         return 'Dropdown';
       case QuestionType.rating:
         return 'Rating';
       case QuestionType.dateInput:
         return 'Date Input';
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

  void _showQuestionDialog({SurveyQuestionModel? question}) {
    showDialog(
      context: context,
      builder: (context) => QuestionEditDialog(
        question: question,
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
          
          // Update question with controller values
          _editableQuestions[i] = question.copyWith(
            title: title,
            description: controllers['description']!.text.trim().isEmpty 
                ? null 
                : controllers['description']!.text.trim(),
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
          // Update existing question
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
    final newQuestionId = 'new_${DateTime.now().millisecondsSinceEpoch}';
    final newQuestion = SurveyQuestionModel(
      id: '', // Will be assigned by Firestore
      title: '',
      type: QuestionType.textInput,
      isRequired: false,
      order: _editableQuestions.length + 1,
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
  }

  void _deleteBatchQuestion(int index) {
    final question = _editableQuestions[index];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: Text('Are you sure you want to delete "${question.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _editableQuestions.removeAt(index);
                _controllers[question.id]?.forEach((key, controller) => controller.dispose());
                _controllers.remove(question.id);
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

}

// Question Edit Dialog (simplified version)
class QuestionEditDialog extends StatefulWidget {
  final SurveyQuestionModel? question;
  final Function(SurveyQuestionModel) onSave;

  const QuestionEditDialog({
    Key? key,
    this.question,
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
                          child: Text('School Years (2020-2021 to current)'),
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
        return 'Text Input';
      case QuestionType.textArea:
        return 'Text Area';
      case QuestionType.singleChoice:
        return 'Single Choice';
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.checkboxList:
        return 'Checkbox List';
      case QuestionType.dropdown:
        return 'Dropdown';
      case QuestionType.rating:
        return 'Rating';
      case QuestionType.dateInput:
        return 'Date Input';
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