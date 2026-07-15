import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/event.dart';
import '../providers/event_provider.dart';

class EventDetailScreen extends StatefulWidget {
  final Event event;
  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isLoadingMedia = true;
  bool _isSaving = false;
  String _rawFolderLink = '';
  String _selectedFolderLink = '';
  String _editedFolderLink = '';
  String _writingDocLink = '';
  List<Map<String, dynamic>> _photos = [];

  @override
  void initState() {
    super.initState();
    _fetchMediaLinks();
  }

  Future<void> _fetchMediaLinks() async {
    final provider = context.read<EventProvider>();
    final links = await provider.fetchMediaFolders(widget.event.folderLink, widget.event.date, widget.event.stage);
    
    List<Map<String, dynamic>> fetchedPhotos = [];
    if (links['raw'] != null && links['raw']!.isNotEmpty) {
      fetchedPhotos = await provider.fetchPhotos(links['raw']!);
    }
    
    if (mounted) {
      setState(() {
        _rawFolderLink = links['raw'] ?? '';
        _selectedFolderLink = links['selected'] ?? '';
        _editedFolderLink = links['edited'] ?? '';
        _writingDocLink = links['writingDoc'] ?? '';
        _photos = fetchedPhotos;
        _isLoadingMedia = false;
      });
    }
  }

  /// Get the best available doc link (prefer backend-found over stored)
  String get _bestDocLink {
    if (_writingDocLink.isNotEmpty && _writingDocLink.startsWith('http')) return _writingDocLink;
    if (widget.event.docLink.isNotEmpty && widget.event.docLink.startsWith('http')) return widget.event.docLink;
    return '';
  }

  void _openLink(String url, {bool inApp = true}) async {
    if (url.isEmpty || !url.startsWith('http')) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No valid link available')));
      return;
    }
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: inApp ? LaunchMode.inAppBrowserView : LaunchMode.externalApplication);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open link')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid link: ${url.substring(0, url.length > 50 ? 50 : url.length)}...')));
    }
  }

  void _markDone() async {
    setState(() => _isSaving = true);
    final success = await context.read<EventProvider>().updateEvent(widget.event, {'Status': 'Done'});
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task marked Done! Next stage assigned and notified.'), backgroundColor: Colors.green));
      Navigator.pop(context); // Go back without refreshing the whole app first
    } else if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update task'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = _isSaving;
    final isDone = widget.event.status == 'Done';
    final theme = Theme.of(context);
    final e = widget.event;

    Color stageColor = e.stage == 'Writing'
        ? const Color(0xFF42A5F5)
        : e.stage == 'Editing'
            ? const Color(0xFFFF8A65)
            : const Color(0xFFAB47BC);

    return Scaffold(
      appBar: AppBar(
        title: Text('Post ${e.postNo} • ${e.stage}'),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDone ? Colors.green : stageColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(child: Text(isDone ? 'Done' : (e.status.isEmpty ? 'Pending' : e.status), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stage header strip
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [stageColor.withOpacity(0.15), stageColor.withOpacity(0.03)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (e.theme.isNotEmpty)
                    Text(e.theme, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      if (e.date.isNotEmpty) _headerChip(Icons.calendar_today, e.date),
                      if (e.activityType.isNotEmpty) _headerChip(Icons.category, e.activityType),
                      if (e.publishPlatform.isNotEmpty) _headerChip(Icons.campaign, e.publishPlatform),
                      if (e.mediaMode.isNotEmpty) _headerChip(e.mediaMode == 'Video' ? Icons.videocam : Icons.photo, e.mediaMode),
                    ],
                  ),
                  if (e.assigneeName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.person, size: 16, color: stageColor),
                      const SizedBox(width: 4),
                      Text('Assigned to: ${e.assigneeName}', style: TextStyle(fontWeight: FontWeight.w600, color: stageColor)),
                    ]),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Event Details Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Event Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 12),
                          _infoRow(Icons.location_city, 'Branch', '${e.branch}, ${e.state}'),
                          _infoRow(Icons.place, 'Venue', e.venue),
                          _infoRow(Icons.people, 'Organizers', e.organizers),
                          _infoRow(Icons.handshake, 'Partners', e.partners),
                          if (e.importantInfo.isNotEmpty)
                            _infoRow(Icons.info_outline, 'Important', e.importantInfo),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Guest Card
                  if (e.guestName.isNotEmpty || e.guestOrg.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Guest / Speaker Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 12),
                            if (e.guestType.isNotEmpty) _infoRow(Icons.person_pin, 'Type', e.guestType),
                            if (e.guestName.isNotEmpty) _infoRow(Icons.person, 'Name', e.guestName),
                            if (e.guestDesignation.isNotEmpty) _infoRow(Icons.work, 'Designation', e.guestDesignation),
                            if (e.guestOrg.isNotEmpty) _infoRow(Icons.business, 'Organization', e.guestOrg),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Additional Info Card
                  if (e.activitiesConducted.isNotEmpty || e.anyInformation.isNotEmpty || e.description.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Additional Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 12),
                            if (e.activitiesConducted.isNotEmpty)
                              _infoRow(Icons.local_activity, 'Activities Conducted', e.activitiesConducted),
                            if (e.anyInformation.isNotEmpty)
                              _infoRow(Icons.info, 'Other Information', e.anyInformation),
                            if (e.description.isNotEmpty)
                              _infoRow(Icons.description, 'Note from Admin', e.description, color: Colors.blue.shade700),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Beneficiary Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Beneficiaries', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _benCircle('👨', 'Male', e.male, const Color(0xFF42A5F5)),
                              _benCircle('👩', 'Female', e.female, const Color(0xFFE91E63)),
                              _benCircle('🧒', 'Children', e.children, const Color(0xFFFF9800)),
                              _benCircle('👥', 'Total', e.totalBeneficiary, theme.colorScheme.primary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Media Folders Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Media Folders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 12),
                          if (_isLoadingMedia)
                            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                          else if (e.isCombined) ...[
                            const Text('Raw Media Folders for Group:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 8),
                            ...e.combinedPosts.map((p) {
                              final folderLink = p['FolderLink']?.toString() ?? '';
                              if (folderLink.isEmpty) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: _mediaButton(Icons.folder, 'Post #${p['PostNo']}', p['Theme'] ?? '', Colors.blueGrey, () => _openLink(folderLink)),
                              );
                            }),
                          ] else ...[
                            if (_rawFolderLink.isNotEmpty)
                              _mediaButton(Icons.photo_library, 'View Photos / Videos (Raw)', 'Original unedited files', Colors.blueGrey, () => _openLink(_rawFolderLink)),
                            if (_selectedFolderLink.isNotEmpty)
                              _mediaButton(Icons.checklist, 'Selected Photos', 'Best picks from Raw', Colors.teal, () => _openLink(_selectedFolderLink)),
                            if (_editedFolderLink.isNotEmpty)
                              _mediaButton(Icons.auto_fix_high, 'Selected (Edited)', 'Edited and approved files', Colors.purple, () => _openLink(_editedFolderLink)),
                            _mediaButton(Icons.folder_shared, 'Month Folder', 'Master media archive', const Color(0xFFF39C12), () => _openLink(e.folderLink)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Content Document Card
                  Card(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: stageColor.withOpacity(0.4), width: 2),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.description, color: stageColor),
                              const SizedBox(width: 8),
                              Text('${e.stage} Document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: stageColor)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text('Open this document to work on the content. Google Docs saves automatically.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.open_in_new),
                              label: Text('Open ${e.stage} Doc'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: stageColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () {
                                final docUrl = _bestDocLink;
                                if (docUrl.isNotEmpty) {
                                  _openLink(docUrl);
                                } else {
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Writing doc not found in the Drive folder')));
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Button
                  if (!isDone)
                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        icon: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle),
                        label: Text(isSaving ? 'Saving...' : 'Mark Done & Handoff', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: isSaving ? null : _markDone,
                      ),
                    ),
                  if (isDone)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text('This task is completed', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? color}) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey.shade500),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: color ?? Colors.black87, fontSize: 13),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _benCircle(String emoji, String label, int value, Color color) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Center(child: Text('$value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color))),
        ),
        const SizedBox(height: 4),
        Text(emoji, style: const TextStyle(fontSize: 14)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _mediaButton(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: color.withOpacity(0.08),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Icon(Icons.open_in_new, size: 18, color: color.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
