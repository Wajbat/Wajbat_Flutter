import 'package:flutter/material.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/utils/snackbar_helper.dart';

class SupportTicketScreen extends StatefulWidget {
  const SupportTicketScreen({super.key});

  @override
  State<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends State<SupportTicketScreen> {
  final _messageController = TextEditingController();
  final _subjectController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitTicket() async {
    if (_messageController.text.trim().isEmpty) {
      SnackbarHelper.showError(context, 'Please enter a message');
      return;
    }

    setState(() => _isLoading = true);
    
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      setState(() => _isLoading = false);
      SnackbarHelper.showSuccess(context, 'Ticket submitted successfully!');
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Support')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              'How can we help you?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            CustomTextField(
              controller: _subjectController,
              label: 'Subject',
              hint: 'Brief summary of the issue',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _messageController,
              label: 'Message',
              hint: 'Describe your issue in detail...',
              maxLines: 5,
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : CustomButton(
                    text: 'Submit Ticket',
                    onPressed: _submitTicket,
                  ),
          ],
        ),
      ),
    );
  }
}
