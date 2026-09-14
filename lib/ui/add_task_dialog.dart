import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';

/// Composer for a new to-do. Enter (and the Add button) submit; empty
/// or whitespace-only input is ignored. Single-line — Enter always adds.
class AddTaskDialog extends StatefulWidget {
  const AddTaskDialog({super.key});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _controller = TextEditingController();
  var _urgency = TaskUrgency.normal;
  var _submitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty || _submitted) return;
    _submitted = true;
    Navigator.pop(context, (title, _urgency));
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _submit,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _submit,
      },
      child: AlertDialog(
        title: const Text('Add task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                hintText: 'e.g., 45 min past paper Qs',
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Urgency',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            SegmentedButton<TaskUrgency>(
              segments: const [
                ButtonSegment(
                  value: TaskUrgency.normal,
                  label: Text('Normal'),
                  icon: Icon(Icons.low_priority, size: 18),
                ),
                ButtonSegment(
                  value: TaskUrgency.urgent,
                  label: Text('Urgent'),
                  icon: Icon(Icons.priority_high, size: 18),
                ),
              ],
              selected: {_urgency},
              onSelectionChanged: (v) => setState(() => _urgency = v.first),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _submit,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
