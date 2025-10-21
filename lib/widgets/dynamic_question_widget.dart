import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../models/survey_question_model.dart';
import '../utils/input_validators.dart';

class DynamicQuestionWidget extends StatelessWidget {
  final SurveyQuestionModel question;
  final dynamic currentValue;
  final Function(dynamic value) onChanged;
  final String? errorText;

  const DynamicQuestionWidget({
    Key? key,
    required this.question,
    this.currentValue,
    required this.onChanged,
    this.errorText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (question.type) {
      case QuestionType.section:
        return _buildSectionHeader(context);
      case QuestionType.textInput:
        return _buildTextInput(context);
      case QuestionType.textArea:
        return _buildTextArea(context);
      case QuestionType.singleChoice:
        return _buildSingleChoice(context);
      case QuestionType.multipleChoice:
        return _buildMultipleChoice(context);
      case QuestionType.checkboxList:
        return _buildCheckboxList(context);
      case QuestionType.dropdown:
        return _buildDropdown(context);
      case QuestionType.rating:
        return _buildRating(context);
      case QuestionType.dateInput:
        return _buildDateInput(context);
      case QuestionType.numberInput:
        return _buildNumberInput(context);
      case QuestionType.switchToggle:
        return _buildSwitchToggle(context);
    }
  }

  Widget _buildSectionHeader(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      elevation: 2,
      color: Colors.blue.shade50,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      question.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              if (question.description != null) ...[
                const SizedBox(height: 12),
                Text(
                  question.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                    height: 1.5,
                  ),
                ),
              ],
              if (question.configuration['showDivider'] == true) ...[
                const SizedBox(height: 16),
                Divider(color: Colors.blue.shade200),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextInput(BuildContext context) {
    // Check if this is a field that should be auto-filled and disabled
    // Use title matching since the actual question IDs might be different
    final title = question.title.toUpperCase();
    final isAutoFillField = title.contains('FIRST NAME') || title.contains('MIDDLE NAME') || 
                           title.contains('LAST NAME') || title.contains('SUFFIX') ||
                           title.contains('EMAIL') || title.contains('PHONE') || 
                           title.contains('MOBILE') || title.contains('CONTACT NUMBER') ||
                           title.contains('STUDENT ID') || title.contains('ID NUMBER') ||
                           title.contains('COMPANY') || title.contains('EMPLOYER') ||
                           title.contains('POSITION') || title.contains('JOB TITLE') || 
                           title.contains('OCCUPATION') || title.contains('LOCATION') || 
                           title.contains('ADDRESS') || title.contains('BIO') || 
                           title.contains('ABOUT') ||
                           title.contains('EASTERN SAMAR STATE UNIVERSITY');
    
    // Check if bypass is enabled for this field
    final isBypassed = currentValue is Map && currentValue['bypassed'] == true;
    
    // Get the actual value (handle both string and Map formats)
    final actualValue = currentValue is Map ? currentValue['value']?.toString() ?? '' : currentValue?.toString() ?? '';
    
    // If it's an auto-fill field and not bypassed, show disabled field with bypass option
    if (isAutoFillField && !isBypassed && actualValue.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionTitle(),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey.shade50,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      actualValue,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      // Enable bypass mode
                      onChanged({
                        'value': '',
                        'bypassed': true,
                        'originalValue': actualValue,
                      });
                    },
                    child: const Text('Bypass'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Auto-filled from your profile. Click "Bypass" to edit manually.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }
    
    // If bypassed, show normal text input
    if (isAutoFillField && isBypassed) {
      // Check if this is a phone number field
      final isPhoneField = title.contains('PHONE') || title.contains('MOBILE') || title.contains('CONTACT NUMBER');
      
      // Get the current text value from the map structure
      final textValue = currentValue is Map ? currentValue['value']?.toString() ?? '' : '';
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionTitle(),
          const SizedBox(height: 8),
          TextFormField(
            // Use a stable key for the bypassed state to prevent recreation on every keystroke
            key: ValueKey('text_${question.id}_bypassed'),
            initialValue: textValue,
            decoration: InputDecoration(
              hintText: isPhoneField ? '09XX XXX XXXX' : (question.configuration['placeholder'] ?? ''),
              border: const OutlineInputBorder(),
              errorText: errorText,
              prefixIcon: isPhoneField ? const Icon(Icons.phone_android) : null,
              suffixIcon: IconButton(
                icon: const Icon(Icons.undo),
                onPressed: () {
                  // Restore auto-filled value
                  final originalValue = currentValue is Map ? currentValue['originalValue'] ?? '' : '';
                  onChanged(originalValue);
                },
                tooltip: 'Restore auto-filled value',
              ),
            ),
            maxLength: question.configuration['maxLength'] ?? 255,
            onChanged: (value) {
              onChanged({
                'value': value,
                'bypassed': true,
                'originalValue': currentValue is Map ? currentValue['originalValue'] : currentValue,
              });
            },
            validator: _getTextValidator(),
            keyboardType: _getKeyboardType(),
            inputFormatters: _getInputFormatters(),
          ),
          const SizedBox(height: 8),
          if (isPhoneField) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Format: 09XX XXX XXXX (11 digits, Philippine mobile number)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'Manual entry mode. Click undo icon to restore auto-filled value.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      );
    }
    
    // Default text input for non-auto-fill fields or when no auto-fill value
    // Check if this is a phone number field
    final isPhoneField = title.contains('PHONE') || title.contains('MOBILE') || title.contains('CONTACT NUMBER');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionTitle(),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('text_${question.id}'),
          initialValue: currentValue?.toString() ?? '',
          decoration: InputDecoration(
            hintText: isPhoneField ? '09XX XXX XXXX' : (question.configuration['placeholder'] ?? ''),
            border: const OutlineInputBorder(),
            errorText: errorText,
            prefixIcon: isPhoneField ? const Icon(Icons.phone_android) : null,
          ),
          maxLength: question.configuration['maxLength'] ?? 255,
          onChanged: (value) {
            // For auto-fill fields that start empty, mark as bypassed when user types
            // This prevents them from switching to disabled state after first character
            if (isAutoFillField) {
              onChanged({
                'value': value,
                'bypassed': true,
                'originalValue': '',
              });
            } else {
              onChanged(value);
            }
          },
          validator: _getTextValidator(),
          keyboardType: _getKeyboardType(),
          inputFormatters: _getInputFormatters(),
        ),
        if (isPhoneField) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Format: 09XX XXX XXXX (11 digits, Philippine mobile number)',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextArea(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionTitle(),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('textarea_${question.id}'),
          initialValue: currentValue?.toString() ?? '',
          decoration: InputDecoration(
            hintText: question.configuration['placeholder'] ?? '',
            border: const OutlineInputBorder(),
            errorText: errorText,
          ),
          maxLength: question.configuration['maxLength'] ?? 1000,
          minLines: question.configuration['minLines'] ?? 3,
          maxLines: question.configuration['maxLines'] ?? 5,
          onChanged: onChanged,
          validator: _getTextValidator(),
          keyboardType: _getKeyboardType(),
        ),
      ],
    );
  }

  Widget _buildSingleChoice(BuildContext context) {
    // Helper function to check if option contains "other"
    bool isOtherOption(String option) => option.toLowerCase().contains('other');
    
    // Check if this is a "Year Graduated" auto-fill field
    final title = question.title.toUpperCase();
    final isYearGraduatedField = title.contains('YEAR') && title.contains('GRADUATED');
    final isBypassed = currentValue is Map && currentValue['bypassed'] == true;
    
    // Get current selected value (handle both string and Map formats)
    String? selectedValue = currentValue is Map 
        ? (currentValue as Map)['value']?.toString()
        : currentValue?.toString();
    
    // If it's a Year Graduated auto-fill field and not bypassed, show disabled field with bypass option
    if (isYearGraduatedField && !isBypassed && selectedValue != null && selectedValue.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionTitle(),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey.shade50,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedValue,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      // Enable bypass mode
                      onChanged({
                        'value': '',
                        'bypassed': true,
                        'originalValue': selectedValue,
                      });
                    },
                    child: const Text('Bypass'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Auto-filled from your profile. Click "Bypass" to select a different year.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }
    
    // Normal single choice display (for non-auto-fill fields or when bypassed)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionTitle(),
        const SizedBox(height: 8),
        ...question.options.map((option) {
          return Column(
            children: [
              RadioListTile<String>(
                title: Text(option),
                value: option,
                groupValue: selectedValue,
                onChanged: (value) {
                  // If it's a Year Graduated field in bypass mode, preserve the bypass structure
                  if (isYearGraduatedField && isBypassed) {
                    onChanged({
                      'value': value,
                      'bypassed': true,
                      'originalValue': currentValue is Map ? currentValue['originalValue'] : currentValue,
                    });
                  } else {
                    onChanged(value);
                  }
                },
              ),
              // Show text input if this is an "Other" option and it's selected
              if (isOtherOption(option) && selectedValue == option) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
                  child: TextFormField(
                    decoration: const InputDecoration(
                      hintText: 'Please specify...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (text) {
                      // Save both the selection and the specification
                      final result = {
                        'value': option,
                        'other_specify': text,
                      };
                      onChanged(result);
                    },
                  ),
                ),
              ],
            ],
          );
        }).toList(),
        // Show undo button if in bypass mode for Year Graduated
        if (isYearGraduatedField && isBypassed) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.orange.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Manual selection mode.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('Restore'),
                  onPressed: () {
                    // Restore auto-filled value
                    final originalValue = currentValue is Map ? currentValue['originalValue'] ?? '' : '';
                    onChanged(originalValue);
                  },
                ),
              ],
            ),
          ),
        ],
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Text(
              errorText!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMultipleChoice(BuildContext context) {
    final List<String> selectedValues = currentValue is List 
        ? List<String>.from(currentValue) 
        : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionTitle(),
        const SizedBox(height: 8),
        ...question.options.map((option) {
          return CheckboxListTile(
            title: Text(option),
            value: selectedValues.contains(option),
            onChanged: (bool? selected) {
              final newValues = List<String>.from(selectedValues);
              if (selected == true) {
                newValues.add(option);
              } else {
                newValues.remove(option);
              }
              onChanged(newValues);
            },
          );
        }),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Text(
              errorText!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCheckboxList(BuildContext context) {
    return _buildMultipleChoice(context); // Same as multiple choice
  }

  Widget _buildDropdown(BuildContext context) {
    // Ensure unique options to prevent dropdown assertion errors
    final uniqueOptions = question.options.toSet().toList();
    
    // Check if this dropdown should be searchable
    final isSearchable = question.configuration['searchable'] == true;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionTitle(),
        const SizedBox(height: 8),
        isSearchable ? _buildSearchableDropdown(uniqueOptions) : _buildBasicDropdown(uniqueOptions),
      ],
    );
  }
  
  Widget _buildSearchableDropdown(List<String> uniqueOptions) {
    return DropdownSearch<String>(
      key: ValueKey('searchable_dropdown_${question.id}'),
      popupProps: PopupProps.menu(
        showSearchBox: true,
        searchFieldProps: TextFieldProps(
          decoration: InputDecoration(
            hintText: 'Search ${question.title.toLowerCase()}...',
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        menuProps: MenuProps(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      items: uniqueOptions,
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          border: const OutlineInputBorder(),
          errorText: errorText,
          hintText: 'Select an option',
        ),
      ),
      onChanged: onChanged,
      selectedItem: currentValue?.toString(),
      dropdownBuilder: (context, selectedItem) {
        return Text(
          selectedItem ?? 'Select an option',
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        );
      },
      filterFn: (item, filter) {
        return item.toLowerCase().contains(filter.toLowerCase());
      },
    );
  }
  
  Widget _buildBasicDropdown(List<String> uniqueOptions) {
    return DropdownButtonFormField<String>(
      key: ValueKey('dropdown_${question.id}'),
      value: currentValue?.toString(),
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        errorText: errorText,
      ),
      hint: const Text('Select an option'),
      items: uniqueOptions.map((option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Text(option),
        );
      }).toList(),
      onChanged: onChanged,
      validator: _getDropdownValidator(),
    );
  }

  Widget _buildRating(BuildContext context) {
    final int minValue = question.configuration['minValue'] ?? 1;
    final int maxValue = question.configuration['maxValue'] ?? 5;
    final int step = question.configuration['step'] ?? 1;
    final List<String> labels = List<String>.from(question.configuration['labels'] ?? []);
    
    int currentRating = currentValue is int ? currentValue : minValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionTitle(),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Rating: $currentRating'),
                    Text('$minValue - $maxValue'),
                  ],
                ),
                const SizedBox(height: 16),
                Slider(
                  value: currentRating.toDouble(),
                  min: minValue.toDouble(),
                  max: maxValue.toDouble(),
                  divisions: ((maxValue - minValue) / step).round(),
                  label: currentRating.toString(),
                  onChanged: (value) => onChanged(value.round()),
                ),
                if (labels.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: labels.asMap().entries.map((entry) {
                      int index = entry.key;
                      String label = entry.value;
                      int value = minValue + (index * step);
                      
                      return FilterChip(
                        label: Text(label),
                        selected: currentRating == value,
                        onSelected: (_) => onChanged(value),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Text(
              errorText!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDateInput(BuildContext context) {
    // Custom birthday selector if this is a birthday/date of birth question
    final isBirthday = question.id.toLowerCase().contains('birth') ||
        question.title.toLowerCase().contains('birth');
    if (isBirthday) {
      // Parse current value
      DateTime? selectedDate;
      if (currentValue is DateTime) {
        selectedDate = currentValue;
      } else if (currentValue is String && currentValue.isNotEmpty) {
        try {
          selectedDate = DateTime.parse(currentValue);
        } catch (_) {}
      }
      int? selectedYear = selectedDate?.year;
      int? selectedMonth = selectedDate?.month;
      int? selectedDay = selectedDate?.day;
      final now = DateTime.now();
      final years = List.generate(now.year - 1900 + 1, (i) => now.year - i);
      final months = List.generate(12, (i) => i + 1);
      final days = List.generate(31, (i) => i + 1);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionTitle(),
          const SizedBox(height: 8),
          Row(
            children: [
              // Month
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: selectedMonth,
                  decoration: const InputDecoration(
                    labelText: 'Month',
                    border: OutlineInputBorder(),
                  ),
                  items: months
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                                '${m.toString().padLeft(2, '0')} - ${_monthName(m)}'),
                          ))
                      .toList(),
                  onChanged: (val) {
                    final newDate = _combineDate(val, selectedDay, selectedYear);
                    if (newDate != null) onChanged(newDate);
                  },
                  validator: (val) {
                    if (question.isRequired && val == null) {
                      return 'Select month';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Day
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: selectedDay,
                  decoration: const InputDecoration(
                    labelText: 'Day',
                    border: OutlineInputBorder(),
                  ),
                  items: days
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d.toString().padLeft(2, '0')),
                          ))
                      .toList(),
                  onChanged: (val) {
                    final newDate = _combineDate(selectedMonth, val, selectedYear);
                    if (newDate != null) onChanged(newDate);
                  },
                  validator: (val) {
                    if (question.isRequired && val == null) {
                      return 'Select day';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Year
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: selectedYear,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(),
                  ),
                  items: years
                      .map((y) => DropdownMenuItem(
                            value: y,
                            child: Text(y.toString()),
                          ))
                      .toList(),
                  onChanged: (val) {
                    final newDate = _combineDate(selectedMonth, selectedDay, val);
                    if (newDate != null) onChanged(newDate);
                  },
                  validator: (val) {
                    if (question.isRequired && val == null) {
                      return 'Select year';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 8),
              child: Text(
                errorText!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      );
    }
    // Fallback to default date picker
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionTitle(),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: currentValue is DateTime ? currentValue : DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              onChanged(picked);
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.calendar_today),
              errorText: errorText,
            ),
            child: Text(
              currentValue is DateTime
                  ? '${currentValue.day}/${currentValue.month}/${currentValue.year}'
                  : 'Select date',
            ),
          ),
        ),
      ],
    );
  }

  // Helper for month name
  String _monthName(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[month - 1];
  }

  // Helper to combine date
  DateTime? _combineDate(int? month, int? day, int? year) {
    if (month != null && day != null && year != null) {
      try {
        return DateTime(year, month, day);
      } catch (_) {}
    }
    return null;
  }

  Widget _buildNumberInput(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionTitle(),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('number_${question.id}'),
          initialValue: currentValue?.toString() ?? '',
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            errorText: errorText,
          ),
          keyboardType: question.configuration['allowDecimals'] == true 
              ? TextInputType.number
              : const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: question.configuration['allowDecimals'] == false
              ? [FilteringTextInputFormatter.digitsOnly]
              : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
          onChanged: (value) {
            if (value.isEmpty) {
              onChanged(null);
              return;
            }
            
            if (question.configuration['allowDecimals'] == false) {
              onChanged(int.tryParse(value));
            } else {
              onChanged(double.tryParse(value));
            }
          },
          validator: _getNumberValidator(),
        ),
      ],
    );
  }

  Widget _buildSwitchToggle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(question.title),
          subtitle: question.description != null ? Text(question.description!) : null,
          value: currentValue == true,
          onChanged: onChanged,
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Text(
              errorText!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuestionTitle() {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
        children: [
          TextSpan(text: question.title),
          if (question.isRequired)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }

  String? Function(String?)? _getTextValidator() {
    return (value) {
      // Handle bypass structure for auto-fill fields
      String actualValue = '';
      if (value is Map) {
        final mapValue = value as Map<String, dynamic>;
        actualValue = mapValue['value']?.toString() ?? '';
      } else {
        actualValue = value?.toString() ?? '';
      }
      
      // Required field validation
      if (question.isRequired && actualValue.trim().isEmpty) {
        return question.validation['required'] ?? 'This field is required';
      }
      
      // Skip validation if field is empty and not required
      if (actualValue.trim().isEmpty) {
        return null;
      }
      
      final title = question.title.toUpperCase();
      
      // Email validation
      if (title.contains('EMAIL') || question.validation.containsKey('email')) {
        return InputValidators.validateEmail(actualValue);
      }
      
      // Phone number validation
      if (title.contains('PHONE') || title.contains('MOBILE') || title.contains('CONTACT NUMBER')) {
        return InputValidators.validatePhilippinePhone(actualValue);
      }
      
      // Name validation
      if (title.contains('FIRST NAME') || title.contains('MIDDLE NAME') || title.contains('LAST NAME')) {
        return InputValidators.validateName(actualValue, 'name');
      }
      
      // Student/Faculty ID validation
      if (title.contains('STUDENT ID') || title.contains('ID NUMBER') || title.contains('FACULTY ID')) {
        return InputValidators.validateId(actualValue, 'ID');
      }
      
      // Company/Position validation
      if (title.contains('COMPANY') || title.contains('EMPLOYER') || title.contains('POSITION') || 
          title.contains('JOB TITLE') || title.contains('OCCUPATION')) {
        return InputValidators.validateCompany(actualValue, 'field');
      }
      
      // Location validation
      if (title.contains('LOCATION') || title.contains('ADDRESS')) {
        return InputValidators.validateLocation(actualValue);
      }
      
      // Bio validation
      if (title.contains('BIO') || title.contains('ABOUT')) {
        return InputValidators.validateBio(actualValue);
      }
      
      // Suffix validation
      if (title.contains('SUFFIX')) {
        return InputValidators.validateSuffix(actualValue);
      }
      
      return null;
    };
  }
  
  TextInputType? _getKeyboardType() {
    final title = question.title.toUpperCase();
    
    if (title.contains('EMAIL')) {
      return TextInputType.emailAddress;
    }
    
    if (title.contains('PHONE') || title.contains('MOBILE') || title.contains('CONTACT NUMBER')) {
      return TextInputType.phone;
    }
    
    if (title.contains('NUMBER') && !title.contains('CONTACT NUMBER')) {
      return TextInputType.number;
    }
    
    return TextInputType.text;
  }
  
  List<TextInputFormatter>? _getInputFormatters() {
    final title = question.title.toUpperCase();
    
    if (title.contains('PHONE') || title.contains('MOBILE') || title.contains('CONTACT NUMBER')) {
      return InputValidators.getPhoneInputFormatters();
    }
    
    if (title.contains('NAME')) {
      // Allow only letters, spaces, hyphens, apostrophes, and periods for names
      return [
        FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-'\.]+"))
      ];
    }
    
    return null;
  }

  String? Function(String?)? _getDropdownValidator() {
    if (!question.isRequired) return null;
    
    return (value) {
      if (value == null || value.isEmpty) {
        return question.validation['required'] ?? 'Please select an option';
      }
      return null;
    };
  }

  String? Function(String?)? _getNumberValidator() {
    return (value) {
      if (question.isRequired && (value == null || value.isEmpty)) {
        return question.validation['required'] ?? 'This field is required';
      }
      
      if (value != null && value.isNotEmpty) {
        final number = question.configuration['allowDecimals'] == false
            ? int.tryParse(value)
            : double.tryParse(value);
            
        if (number == null) {
          return 'Please enter a valid number';
        }
        
        final minValue = question.configuration['minValue'];
        final maxValue = question.configuration['maxValue'];
        
        if (minValue != null && number < minValue) {
          return 'Value must be at least $minValue';
        }
        
        if (maxValue != null && number > maxValue) {
          return 'Value must be at most $maxValue';
        }
      }
      
      return null;
    };
  }
} 