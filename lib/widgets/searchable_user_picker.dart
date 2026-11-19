import 'package:flutter/material.dart';

/// A reusable, searchable picker for selecting users/assignees across Social Media
/// and Development pipelines. Supports searching by name, branch name (e.g. "(Delhi)"),
/// email, role, or username.
class SearchableUserPicker extends StatelessWidget {
  final String title;
  final String? value;
  final List<Map<String, dynamic>> users;
  final String valueField;
  final String? hintText;
  final bool allowAutoAssign;
  final String autoAssignLabel;
  final bool allowOther;
  final String otherLabel;
  final VoidCallback? onOtherSelected;
  final ValueChanged<String?>? onChanged;
  final void Function(String? value, Map<String, dynamic>? user)? onUserChanged;
  final EdgeInsetsGeometry? contentPadding;
  final bool isDense;
  final bool enabled;

  const SearchableUserPicker({
    super.key,
    required this.title,
    required this.value,
    required this.users,
    this.valueField = 'email',
    this.hintText,
    this.allowAutoAssign = false,
    this.autoAssignLabel = 'Auto-assign (least loaded)',
    this.allowOther = false,
    this.otherLabel = '+ Other (Add New User)',
    this.onOtherSelected,
    this.onChanged,
    this.onUserChanged,
    this.contentPadding,
    this.isDense = false,
    this.enabled = true,
  });

  String _getUserId(Map<String, dynamic> u) {
    if (valueField == 'username') {
      return (u['username'] ?? u['Username'] ?? u['email'] ?? u['Email'] ?? u['name'] ?? u['Name'] ?? '').toString();
    }
    return (u['email'] ?? u['Email'] ?? u['username'] ?? u['Username'] ?? u['name'] ?? u['Name'] ?? '').toString();
  }

  String _getUserName(Map<String, dynamic> u) {
    final n = (u['Name'] ?? u['name'] ?? '').toString().trim();
    if (n.isNotEmpty) return n;
    final e = (u['Email'] ?? u['email'] ?? '').toString().trim();
    if (e.isNotEmpty) return e;
    return (u['username'] ?? u['Username'] ?? 'User').toString();
  }

  String _getUserRole(Map<String, dynamic> u) {
    return (u['Role'] ?? u['role'] ?? '').toString().trim();
  }

  String _getUserStatus(Map<String, dynamic> u) {
    return (u['Status'] ?? u['status'] ?? '').toString().trim();
  }

  dynamic _getUserActiveTasks(Map<String, dynamic> u) {
    return u['activeTasks'] ?? u['ActiveTasks'];
  }

  Map<String, dynamic>? _findSelectedUser() {
    if (value == null || value!.isEmpty) return null;
    final v = value!.trim().toLowerCase();
    for (final u in users) {
      final id = _getUserId(u).trim().toLowerCase();
      final email = (u['email'] ?? u['Email'] ?? '').toString().trim().toLowerCase();
      final username = (u['username'] ?? u['Username'] ?? '').toString().trim().toLowerCase();
      final name = (u['name'] ?? u['Name'] ?? '').toString().trim().toLowerCase();
      if (id == v || email == v || username == v || name == v) {
        return u;
      }
    }
    return null;
  }

  void _openSearchDialog(BuildContext context) {
    if (!enabled) return;

    showDialog(
      context: context,
      builder: (ctx) => _SearchableUserPickerDialog(
        title: title,
        initialValue: value,
        users: users,
        valueField: valueField,
        allowAutoAssign: allowAutoAssign,
        autoAssignLabel: autoAssignLabel,
        allowOther: allowOther,
        otherLabel: otherLabel,
        onOtherSelected: () {
          Navigator.pop(ctx);
          if (onOtherSelected != null) {
            onOtherSelected!();
          } else {
            onChanged?.call('other');
            onUserChanged?.call('other', null);
          }
        },
        onSelected: (selectedId, selectedUser) {
          Navigator.pop(ctx);
          onChanged?.call(selectedId);
          onUserChanged?.call(selectedId, selectedUser);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedUser = _findSelectedUser();
    final isAutoAssign = allowAutoAssign && (value == null || value!.isEmpty);
    final isOtherSelected = (value == 'other' || value == '__other__');

    String displayText;
    if (isAutoAssign) {
      displayText = autoAssignLabel;
    } else if (isOtherSelected) {
      displayText = otherLabel;
    } else if (selectedUser != null) {
      displayText = _getUserName(selectedUser);
    } else if (value != null && value!.isNotEmpty) {
      displayText = value!;
    } else {
      displayText = hintText ?? (allowAutoAssign ? autoAssignLabel : 'Select $title...');
    }

    final status = selectedUser != null ? _getUserStatus(selectedUser) : '';
    final role = selectedUser != null ? _getUserRole(selectedUser) : '';
    final active = selectedUser != null ? _getUserActiveTasks(selectedUser) : null;

    final pad = contentPadding ?? EdgeInsets.symmetric(horizontal: 12, vertical: isDense ? 8 : 11);

    return InkWell(
      onTap: () => _openSearchDialog(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: pad,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (isAutoAssign) ...[
              Icon(Icons.auto_awesome, size: 16, color: Colors.amber.shade800),
              const SizedBox(width: 8),
            ] else if (selectedUser != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: status.toLowerCase() == 'available' ? Colors.green : Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ] else if (isOtherSelected) ...[
              const Icon(Icons.person_add_alt_1, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                displayText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selectedUser != null ? FontWeight.w600 : FontWeight.normal,
                  color: (selectedUser != null || isOtherSelected || isAutoAssign)
                      ? Colors.black87
                      : Colors.grey.shade600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (active != null) ...[
              const SizedBox(width: 6),
              Text(
                '($active active)',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ] else if (role.isNotEmpty && selectedUser != null && !displayText.contains(role)) ...[
              const SizedBox(width: 6),
              Text(
                '($role)',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ],
            const SizedBox(width: 6),
            Icon(Icons.search, size: 17, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }
}

class _SearchableUserPickerDialog extends StatefulWidget {
  final String title;
  final String? initialValue;
  final List<Map<String, dynamic>> users;
  final String valueField;
  final bool allowAutoAssign;
  final String autoAssignLabel;
  final bool allowOther;
  final String otherLabel;
  final VoidCallback onOtherSelected;
  final void Function(String? value, Map<String, dynamic>? user) onSelected;

  const _SearchableUserPickerDialog({
    required this.title,
    required this.initialValue,
    required this.users,
    required this.valueField,
    required this.allowAutoAssign,
    required this.autoAssignLabel,
    required this.allowOther,
    required this.otherLabel,
    required this.onOtherSelected,
    required this.onSelected,
  });

  @override
  State<_SearchableUserPickerDialog> createState() => _SearchableUserPickerDialogState();
}

class _SearchableUserPickerDialogState extends State<_SearchableUserPickerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _getUserId(Map<String, dynamic> u) {
    if (widget.valueField == 'username') {
      return (u['username'] ?? u['Username'] ?? u['email'] ?? u['Email'] ?? u['name'] ?? u['Name'] ?? '').toString();
    }
    return (u['email'] ?? u['Email'] ?? u['username'] ?? u['Username'] ?? u['name'] ?? u['Name'] ?? '').toString();
  }

  String _getUserName(Map<String, dynamic> u) {
    final n = (u['Name'] ?? u['name'] ?? '').toString().trim();
    if (n.isNotEmpty) return n;
    final e = (u['Email'] ?? u['email'] ?? '').toString().trim();
    if (e.isNotEmpty) return e;
    return (u['username'] ?? u['Username'] ?? 'User').toString();
  }

  String _getUserRole(Map<String, dynamic> u) {
    return (u['Role'] ?? u['role'] ?? '').toString().trim();
  }

  String _getUserStatus(Map<String, dynamic> u) {
    return (u['Status'] ?? u['status'] ?? '').toString().trim();
  }

  dynamic _getUserActiveTasks(Map<String, dynamic> u) {
    return u['activeTasks'] ?? u['ActiveTasks'];
  }

  bool _matchesUser(Map<String, dynamic> u, String query) {
    if (query.isEmpty) return true;
    final name = _getUserName(u).toLowerCase();
    final email = (u['email'] ?? u['Email'] ?? '').toString().toLowerCase();
    final username = (u['username'] ?? u['Username'] ?? '').toString().toLowerCase();
    final role = _getUserRole(u).toLowerCase();
    final branch = (u['branch'] ?? u['Branch'] ?? '').toString().toLowerCase();
    final category = (u['category'] ?? u['Category'] ?? '').toString().toLowerCase();

    // Multi-term matching (e.g. "rahul delhi")
    final terms = query.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    for (final term in terms) {
      final matches = name.contains(term) ||
          email.contains(term) ||
          username.contains(term) ||
          role.contains(term) ||
          branch.contains(term) ||
          category.contains(term);
      if (!matches) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = widget.users.where((u) => _matchesUser(u, _searchQuery)).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_search_rounded, size: 20, color: Color(0xFF1A237E)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select ${widget.title}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search name, branch (e.g. Delhi), email...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1A237E), width: 1.5),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),
            const Divider(height: 1),

            // User List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  // Auto-assign option
                  if (widget.allowAutoAssign && _searchQuery.isEmpty) ...[
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.amber.shade100,
                        child: Icon(Icons.auto_awesome, size: 16, color: Colors.amber.shade900),
                      ),
                      title: Text(
                        widget.autoAssignLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: const Text('Automatically pick available / least loaded user', style: TextStyle(fontSize: 11)),
                      trailing: (widget.initialValue == null || widget.initialValue!.isEmpty)
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                          : null,
                      onTap: () => widget.onSelected(null, null),
                    ),
                    const Divider(height: 1),
                  ],

                  // Other / Add new option
                  if (widget.allowOther) ...[
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.blue.shade50,
                        child: const Icon(Icons.person_add_alt_1, size: 16, color: Colors.blue),
                      ),
                      title: Text(
                        widget.otherLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue),
                      ),
                      subtitle: const Text('Add someone not in the list', style: TextStyle(fontSize: 11)),
                      onTap: widget.onOtherSelected,
                    ),
                    const Divider(height: 1),
                  ],

                  if (filteredUsers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'No users found matching "$_searchQuery"',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try searching by person name or branch name.',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ...filteredUsers.map((u) {
                      final id = _getUserId(u);
                      final name = _getUserName(u);
                      final role = _getUserRole(u);
                      final status = _getUserStatus(u);
                      final active = _getUserActiveTasks(u);
                      final email = (u['email'] ?? u['Email'] ?? '').toString();
                      final isSelected = widget.initialValue != null &&
                          widget.initialValue!.isNotEmpty &&
                          id.toLowerCase() == widget.initialValue!.toLowerCase();

                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: status.toLowerCase() == 'available' ? Colors.green : Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? const Color(0xFF1A237E) : Colors.black87,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            if (role.isNotEmpty && !name.contains(role)) ...[
                              Text(role, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(width: 6),
                            ],
                            if (email.isNotEmpty && email != name) ...[
                              Flexible(
                                child: Text(
                                  email,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (active != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$active active',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                            : null,
                        onTap: () => widget.onSelected(id, u),
                      );
                    }),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Text(
                    '${filteredUsers.length} user${filteredUsers.length == 1 ? '' : 's'} available',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
