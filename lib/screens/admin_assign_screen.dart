import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/event_provider.dart';
import 'package:intl/intl.dart';

class AdminAssignScreen extends StatefulWidget {
  final Map<String, dynamic> postData;

  const AdminAssignScreen({super.key, required this.postData});

  @override
  State<AdminAssignScreen> createState() => _AdminAssignScreenState();
}

class _AdminAssignScreenState extends State<AdminAssignScreen> {
  String? _selectedWriter;
  String? _selectedEditor;
  String? _selectedProofreader;
  String? _selectedCrosscheck;
  String? _selectedUploader;
  
  String? _selectedThumbnailSelect;
  String? _selectedThumbnailProcess;
  String? _selectedThumbnailCrosscheck;
  String? _selectedPhotoSelect;
  String? _selectedPhotosClean;
  String? _selectedPhotoEdit;
  String? _selectedVideoEdit;
  String? _selectedMediaCheck;

  DateTime? _writingDue;
  DateTime? _editingDue;
  DateTime? _proofreadingDue;
  DateTime? _crosscheckDue;
  DateTime? _uploaderDue;
  
  DateTime? _thumbnailSelectDue;
  DateTime? _thumbnailProcessDue;
  DateTime? _thumbnailCrosscheckDue;
  DateTime? _photoSelectDue;
  DateTime? _photosCleanDue;
  DateTime? _photoEditDue;
  DateTime? _videoEditDue;
  DateTime? _mediaCheckDue;

  String _publishPlatform = 'WhatsApp';
  String _postType = 'Individual';
  String _mediaMode = 'Photos';

  final _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().fetchUsers();
      
      // Init from existing data if any
      setState(() {
        _publishPlatform = widget.postData['PublishPlatform']?.toString().isNotEmpty == true 
            ? widget.postData['PublishPlatform'] 
            : 'WhatsApp';
        _postType = widget.postData['PostType']?.toString().isNotEmpty == true 
            ? widget.postData['PostType'] 
            : 'Individual';
        _mediaMode = widget.postData['MediaMode']?.toString().isNotEmpty == true 
            ? widget.postData['MediaMode'] 
            : 'Photos';
        _descController.text = widget.postData['Description']?.toString() ?? '';
      });
    });
  }

  Future<void> _pickDate(BuildContext context, Function(DateTime) onSelect) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) onSelect(date);
  }

  Widget _buildUserDropdown(String title, String role, String? value, Function(String?) onChanged) {
    final users = context.watch<EventProvider>().users.where((u) => u['role'] == role).toList();
    final uniqueUsers = <String, Map<String, dynamic>>{};
    for (var u in users) {
      final email = u['email']?.toString() ?? '';
      if (email.isNotEmpty) {
        uniqueUsers[email] = u;
      }
    }
    
    // Ensure the current value is in the unique list, otherwise reset it
    final safeValue = (value == null || uniqueUsers.containsKey(value)) ? value : null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('Auto-assign (least loaded)'),
              value: safeValue,
              items: [
                const DropdownMenuItem(value: null, child: Text('Auto-assign (least loaded)')),
                ...uniqueUsers.values.map((u) {
                  final email = u['email'];
                  final status = u['status'];
                  final active = u['activeTasks'];
                  return DropdownMenuItem<String>(
                    value: email,
                    child: Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: status == 'Available' ? Colors.green : Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(email)),
                        Text('($active active)', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String title, DateTime? date, Function(DateTime) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pickDate(context, onSelect),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(date == null ? 'No due date' : DateFormat('dd MMM yyyy').format(date)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRadioGroup(String title, List<String> options, String selected, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: options.map((opt) => InkWell(
            onTap: () => onChanged(opt),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Radio<String>(
                  value: opt,
                  groupValue: selected,
                  onChanged: (v) => onChanged(v!),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Text(opt),
              ],
            ),
          )).toList(),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final provider = context.read<EventProvider>();
    final isCombined = widget.postData['isCombined'] == true;
    final postNo = isCombined ? widget.postData['postNo']?.toString() : widget.postData['PostNo']?.toString();
    if (postNo == null) return;

    final assignees = <String, String>{};
    if (_selectedWriter != null) assignees['Writing'] = _selectedWriter!;
    if (_selectedEditor != null) assignees['Editing'] = _selectedEditor!;
    if (_selectedProofreader != null) assignees['Proofreading'] = _selectedProofreader!;
    if (_selectedCrosscheck != null) assignees['Cross check'] = _selectedCrosscheck!;
    if (_selectedUploader != null) assignees['Ready to Post'] = _selectedUploader!;
    
    if (_publishPlatform.toLowerCase().contains('insta')) {
      if (_selectedThumbnailSelect != null) assignees['Thumbnail Selection'] = _selectedThumbnailSelect!;
      if (_selectedThumbnailProcess != null) assignees['Thumbnail Processing'] = _selectedThumbnailProcess!;
      if (_selectedThumbnailCrosscheck != null) assignees['Thumbnail Cross checking'] = _selectedThumbnailCrosscheck!;
    }

    if (_selectedPhotoSelect != null) assignees['Photos Selection'] = _selectedPhotoSelect!;
    if (_selectedPhotosClean != null) assignees['Photos Clean'] = _selectedPhotosClean!;
    
    if (_mediaMode.toLowerCase().contains('photo')) {
      if (_selectedPhotoEdit != null) assignees['Photo Editing'] = _selectedPhotoEdit!;
    }
    if (_mediaMode.toLowerCase().contains('video')) {
      if (_selectedVideoEdit != null) assignees['Video Editing'] = _selectedVideoEdit!;
    }
    if (_selectedMediaCheck != null) assignees['Media Cross Check'] = _selectedMediaCheck!;

    final dueDates = <String, String>{};
    if (_writingDue != null) dueDates['Writing'] = _writingDue!.toIso8601String();
    if (_editingDue != null) dueDates['Editing'] = _editingDue!.toIso8601String();
    if (_proofreadingDue != null) dueDates['Proofreading'] = _proofreadingDue!.toIso8601String();
    if (_crosscheckDue != null) dueDates['Cross check'] = _crosscheckDue!.toIso8601String();
    if (_uploaderDue != null) dueDates['Ready to Post'] = _uploaderDue!.toIso8601String();
    
    if (_publishPlatform.toLowerCase().contains('insta')) {
      if (_thumbnailSelectDue != null) dueDates['Thumbnail Selection'] = _thumbnailSelectDue!.toIso8601String();
      if (_thumbnailProcessDue != null) dueDates['Thumbnail Processing'] = _thumbnailProcessDue!.toIso8601String();
      if (_thumbnailCrosscheckDue != null) dueDates['Thumbnail Cross checking'] = _thumbnailCrosscheckDue!.toIso8601String();
    }
    
    if (_photoSelectDue != null) dueDates['Photos Selection'] = _photoSelectDue!.toIso8601String();
    if (_photosCleanDue != null) dueDates['Photos Clean'] = _photosCleanDue!.toIso8601String();
    
    if (_mediaMode.toLowerCase().contains('photo')) {
      if (_photoEditDue != null) dueDates['Photo Editing'] = _photoEditDue!.toIso8601String();
    }
    if (_mediaMode.toLowerCase().contains('video')) {
      if (_videoEditDue != null) dueDates['Video Editing'] = _videoEditDue!.toIso8601String();
    }
    if (_mediaCheckDue != null) dueDates['Media Cross Check'] = _mediaCheckDue!.toIso8601String();

    final success = await provider.createTasksForPostV2(
      postNo: postNo,
      assignees: assignees,
      dueDates: dueDates,
      description: _descController.text,
      publishPlatform: _publishPlatform,
      postType: _postType,
      mediaMode: _mediaMode,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workflow setup successfully!'), backgroundColor: Colors.green));
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to setup workflow or tasks already exist.'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCombined = widget.postData['isCombined'] == true;
    final postNo = isCombined ? widget.postData['postNo'] : widget.postData['PostNo'];
    final themeName = isCombined ? 'Combined Group' : (widget.postData['Theme'] ?? 'No Theme');
    final provider = context.watch<EventProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Workflow'),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Post Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Post #$postNo', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(themeName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Post Meta
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Post Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          _buildRadioGroup('Publishing Platform', ['WhatsApp', 'Instagram'], _publishPlatform, (v) => setState(() => _publishPlatform = v)),
                          const Divider(height: 24),
                          _buildRadioGroup('Post Type', ['Individual', 'Combined'], _postType, (v) => setState(() => _postType = v)),
                          const Divider(height: 24),
                          _buildRadioGroup('Media Mode', ['Photos', 'Video'], _mediaMode, (v) => setState(() => _mediaMode = v)),
                          const Divider(height: 24),
                          const Text('Content Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _descController,
                            maxLines: 3,
                            decoration: const InputDecoration(hintText: 'Enter guidelines for writers...'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Assignments
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Content Assignments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildUserDropdown('1. Writer', 'Writer', _selectedWriter, (v) => setState(() => _selectedWriter = v))),
                              const SizedBox(width: 12),
                              Expanded(flex: 1, child: _buildDateField('Due Date', _writingDue, (d) => setState(() => _writingDue = d))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildUserDropdown('2. Editor', 'Editor', _selectedEditor, (v) => setState(() => _selectedEditor = v))),
                              const SizedBox(width: 12),
                              Expanded(flex: 1, child: _buildDateField('Due Date', _editingDue, (d) => setState(() => _editingDue = d))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildUserDropdown('3. Proofreader', 'Proofreader', _selectedProofreader, (v) => setState(() => _selectedProofreader = v))),
                              const SizedBox(width: 12),
                              Expanded(flex: 1, child: _buildDateField('Due Date', _proofreadingDue, (d) => setState(() => _proofreadingDue = d))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildUserDropdown('4. Cross check', 'CrossChecker', _selectedCrosscheck, (v) => setState(() => _selectedCrosscheck = v))),
                              const SizedBox(width: 12),
                              Expanded(flex: 1, child: _buildDateField('Due Date', _crosscheckDue, (d) => setState(() => _crosscheckDue = d))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildUserDropdown('5. Ready to Post', 'Uploader', _selectedUploader, (v) => setState(() => _selectedUploader = v))),
                              const SizedBox(width: 12),
                              Expanded(flex: 1, child: _buildDateField('Due Date', _uploaderDue, (d) => setState(() => _uploaderDue = d))),
                            ],
                          ),
                          const SizedBox(height: 32),
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text('Media Assignments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          
                          if (_publishPlatform.toLowerCase().contains('insta')) ...[
                            const SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: _buildUserDropdown('1. Thumbnail Selection', 'Thumbnail Designer', _selectedThumbnailSelect, (v) => setState(() => _selectedThumbnailSelect = v))),
                                const SizedBox(width: 12),
                                Expanded(flex: 1, child: _buildDateField('Due Date', _thumbnailSelectDue, (d) => setState(() => _thumbnailSelectDue = d))),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: _buildUserDropdown('2. Thumbnail Processing', 'Thumbnail Designer', _selectedThumbnailProcess, (v) => setState(() => _selectedThumbnailProcess = v))),
                                const SizedBox(width: 12),
                                Expanded(flex: 1, child: _buildDateField('Due Date', _thumbnailProcessDue, (d) => setState(() => _thumbnailProcessDue = d))),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: _buildUserDropdown('3. Thumbnail Cross checking', 'Thumbnail Designer', _selectedThumbnailCrosscheck, (v) => setState(() => _selectedThumbnailCrosscheck = v))),
                                const SizedBox(width: 12),
                                Expanded(flex: 1, child: _buildDateField('Due Date', _thumbnailCrosscheckDue, (d) => setState(() => _thumbnailCrosscheckDue = d))),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Divider(),
                            ),
                          ],
                          
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildUserDropdown('Photos Selection', 'Photo Selector', _selectedPhotoSelect, (v) => setState(() => _selectedPhotoSelect = v))),
                              const SizedBox(width: 12),
                              Expanded(flex: 1, child: _buildDateField('Due Date', _photoSelectDue, (d) => setState(() => _photoSelectDue = d))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildUserDropdown('Photos Clean', 'Photo Selector', _selectedPhotosClean, (v) => setState(() => _selectedPhotosClean = v))),
                              const SizedBox(width: 12),
                              Expanded(flex: 1, child: _buildDateField('Due Date', _photosCleanDue, (d) => setState(() => _photosCleanDue = d))),
                            ],
                          ),
                          
                          if (_mediaMode.toLowerCase().contains('photo')) ...[
                            const SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: _buildUserDropdown('Photo Editing', 'Photo Editor', _selectedPhotoEdit, (v) => setState(() => _selectedPhotoEdit = v))),
                                const SizedBox(width: 12),
                                Expanded(flex: 1, child: _buildDateField('Due Date', _photoEditDue, (d) => setState(() => _photoEditDue = d))),
                              ],
                            ),
                          ],
                          
                          if (_mediaMode.toLowerCase().contains('video')) ...[
                            const SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: _buildUserDropdown('Video Editing', 'Video Editor', _selectedVideoEdit, (v) => setState(() => _selectedVideoEdit = v))),
                                const SizedBox(width: 12),
                                Expanded(flex: 1, child: _buildDateField('Due Date', _videoEditDue, (d) => setState(() => _videoEditDue = d))),
                              ],
                            ),
                          ],
                          
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildUserDropdown('Media Cross Check', 'Media CrossChecker', _selectedMediaCheck, (v) => setState(() => _selectedMediaCheck = v))),
                              const SizedBox(width: 12),
                              Expanded(flex: 1, child: _buildDateField('Due Date', _mediaCheckDue, (d) => setState(() => _mediaCheckDue = d))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.rocket_launch),
                    label: const Text('Create Tasks & Folders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: theme.colorScheme.secondary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
