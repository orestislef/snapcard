import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../models/business_card.dart';
import '../../widgets/field_row.dart';

/// A phone/email row keeps its own text controller plus the selected label.
class _LabeledRow {
  _LabeledRow(this.controller, this.label);
  final TextEditingController controller;
  String label;
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.card, this.isNew = true});

  final BusinessCard card;

  /// New scan (vs. editing an existing history entry). Only affects copy.
  final bool isNew;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final TextEditingController _fullName;
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _jobTitle;
  late final TextEditingController _company;
  late final TextEditingController _address;
  late final TextEditingController _notes;

  late final List<_LabeledRow> _phones;
  late final List<_LabeledRow> _emails;
  late final List<TextEditingController> _websites;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.card;
    _fullName = TextEditingController(text: c.fullName ?? '');
    _firstName = TextEditingController(text: c.firstName ?? '');
    _lastName = TextEditingController(text: c.lastName ?? '');
    _jobTitle = TextEditingController(text: c.jobTitle ?? '');
    _company = TextEditingController(text: c.company ?? '');
    _address = TextEditingController(text: c.address ?? '');
    _notes = TextEditingController(text: c.notes ?? '');
    _phones = c.phones
        .map((p) => _LabeledRow(TextEditingController(text: p.number), p.label))
        .toList();
    _emails = c.emails
        .map((e) => _LabeledRow(TextEditingController(text: e.address), e.label))
        .toList();
    _websites =
        c.websites.map((w) => TextEditingController(text: w)).toList();
  }

  @override
  void dispose() {
    for (final c in [
      _fullName,
      _firstName,
      _lastName,
      _jobTitle,
      _company,
      _address,
      _notes,
    ]) {
      c.dispose();
    }
    for (final r in _phones) {
      r.controller.dispose();
    }
    for (final r in _emails) {
      r.controller.dispose();
    }
    for (final c in _websites) {
      c.dispose();
    }
    super.dispose();
  }

  String? _t(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  BusinessCard _buildCard() {
    return BusinessCard(
      id: widget.card.id,
      scannedAt: widget.card.scannedAt,
      addedToContacts: widget.card.addedToContacts,
      fullName: _t(_fullName),
      firstName: _t(_firstName),
      lastName: _t(_lastName),
      jobTitle: _t(_jobTitle),
      company: _t(_company),
      address: _t(_address),
      notes: _t(_notes),
      phones: _phones
          .where((r) => r.controller.text.trim().isNotEmpty)
          .map((r) => PhoneEntry(label: r.label, number: r.controller.text.trim()))
          .toList(),
      emails: _emails
          .where((r) => r.controller.text.trim().isNotEmpty)
          .map((r) =>
              EmailEntry(label: r.label, address: r.controller.text.trim()))
          .toList(),
      websites: _websites
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }

  Future<void> _saveToHistory() async {
    final card = _buildCard();
    await context.read<AppState>().history.upsert(card);
    if (!mounted) return;
    _toast('Saved to history');
    Navigator.of(context).pop(card);
  }

  Future<void> _saveAndAddContact() async {
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final card = _buildCard();
    try {
      final granted = await state.contacts.ensurePermission();
      if (!granted) {
        if (!mounted) return;
        final permanent = await state.contacts.isPermanentlyDenied();
        if (permanent) {
          await _openSettingsDialog(state);
        } else {
          _toast('Contacts permission denied');
        }
        return;
      }
      await state.contacts.save(card);
      card.addedToContacts = true;
      await state.history.upsert(card);
      if (!mounted) return;
      _toast('Added to contacts');
      Navigator.of(context).pop(card);
    } catch (e) {
      if (mounted) _toast('Could not save contact: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openSettingsDialog(AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contacts permission needed'),
        content: const Text(
          'Contacts access is turned off. Open Settings to allow SnapCard to '
          'save contacts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    if (ok == true) await state.contacts.openSettings();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Body shrinks for the keyboard so the bottom bar rides above it.
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.isNew ? 'Review card' : 'Edit card'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                LabeledField(
                    label: 'Full name', controller: _fullName, icon: Icons.person),
                Row(
                  children: [
                    Expanded(
                        child: LabeledField(
                            label: 'First name', controller: _firstName)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: LabeledField(
                            label: 'Last name', controller: _lastName)),
                  ],
                ),
                LabeledField(
                    label: 'Job title', controller: _jobTitle, icon: Icons.badge_outlined),
                LabeledField(
                    label: 'Company', controller: _company, icon: Icons.business),
                const SizedBox(height: 8),
                _SectionHeader(
                  title: 'Phones',
                  onAdd: () => setState(() => _phones.add(
                      _LabeledRow(TextEditingController(), 'mobile'))),
                ),
                ..._phones.asMap().entries.map((e) => _LabeledRowEditor(
                      key: ObjectKey(e.value),
                      row: e.value,
                      labels: BusinessCard.phoneLabels,
                      keyboardType: TextInputType.phone,
                      hint: 'Number',
                      onLabelChanged: (l) => setState(() => e.value.label = l),
                      onRemoveTapped: () =>
                          setState(() => _phones.removeAt(e.key)),
                    )),
                const SizedBox(height: 8),
                _SectionHeader(
                  title: 'Emails',
                  onAdd: () => setState(() => _emails
                      .add(_LabeledRow(TextEditingController(), 'work'))),
                ),
                ..._emails.asMap().entries.map((e) => _LabeledRowEditor(
                      key: ObjectKey(e.value),
                      row: e.value,
                      labels: BusinessCard.emailLabels,
                      keyboardType: TextInputType.emailAddress,
                      hint: 'Email',
                      onLabelChanged: (l) => setState(() => e.value.label = l),
                      onRemoveTapped: () =>
                          setState(() => _emails.removeAt(e.key)),
                    )),
                const SizedBox(height: 8),
                _SectionHeader(
                  title: 'Websites',
                  onAdd: () =>
                      setState(() => _websites.add(TextEditingController())),
                ),
                ..._websites.asMap().entries.map((e) => Padding(
                      key: ObjectKey(e.value),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: e.value,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                labelText: 'Website',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              e.value.dispose();
                              setState(() => _websites.removeAt(e.key));
                            },
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 8),
                LabeledField(
                    label: 'Address',
                    controller: _address,
                    icon: Icons.location_on_outlined,
                    maxLines: 2),
                LabeledField(
                    label: 'Notes',
                    controller: _notes,
                    icon: Icons.notes,
                    maxLines: 3),
              ],
            ),
          ),
          _BottomBar(
            saving: _saving,
            onSaveHistory: _saving ? null : _saveToHistory,
            onAddContact: _saving ? null : _saveAndAddContact,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onAdd});
  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const Spacer(),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add'),
        ),
      ],
    );
  }
}

class _LabeledRowEditor extends StatelessWidget {
  const _LabeledRowEditor({
    super.key,
    required this.row,
    required this.labels,
    required this.onLabelChanged,
    required this.onRemoveTapped,
    this.keyboardType,
    this.hint,
  });

  final _LabeledRow row;
  final List<String> labels;
  final ValueChanged<String> onLabelChanged;
  final VoidCallback onRemoveTapped;
  final TextInputType? keyboardType;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: row.controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                labelText: hint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: labels.contains(row.label) ? row.label : labels.last,
            underline: const SizedBox.shrink(),
            items: labels
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (v) => onLabelChanged(v ?? labels.last),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: onRemoveTapped,
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.saving,
    required this.onSaveHistory,
    required this.onAddContact,
  });

  final bool saving;
  final VoidCallback? onSaveHistory;
  final VoidCallback? onAddContact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // top:false — the AppBar already handled the top inset; this only guards the
    // bottom (gesture nav bar). The Scaffold shrinks the body for the keyboard,
    // so this bar stays visible above it.
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.dividerColor),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onSaveHistory,
                icon: const Icon(Icons.history),
                label: const Text('Save'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: onAddContact,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt),
                label: const Text('Add contact'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
