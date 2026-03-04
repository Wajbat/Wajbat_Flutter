import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../services/database_service.dart';
import '../../providers/auth_provider.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';

class SupportTicketScreen extends StatefulWidget {
  const SupportTicketScreen({super.key});

  @override
  State<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends State<SupportTicketScreen> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedCategory = 'Technical Issue';
  bool _isGlobalLoading = false; // For submission
  bool _isLoadingTickets = true; // For fetching list
  
  List<Map<String, dynamic>> _myTickets = [];

  final List<String> _categories = [
    'Technical Issue',
    'Account Problem',
    'Food Post Issue',
    'Request Problem',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    setState(() => _isLoadingTickets = true);
    try {
      final tickets = await _dbService.getUserTickets(user.id);
      setState(() {
        _myTickets = tickets;
        _isLoadingTickets = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTickets = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading tickets: $e')));
      }
    }
  }

  Future<void> _submitTicket() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    if (_descriptionController.text.length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide at least 20 characters description.')),
      );
      return;
    }

    setState(() => _isGlobalLoading = true);
    try {
      // Assuming dbService update to accept category
      await _dbService.createSupportTicket(
        user.id, 
        _descriptionController.text,
      );
      
      _descriptionController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket submitted successfully!')),
        );
        _loadTickets(); // Refresh list
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isGlobalLoading = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Support')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Create Ticket Section
            const Text('Create New Ticket', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Issue Description',
                hintText: 'Please describe the issue in detail...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'Submit Ticket',
                onPressed: _submitTicket,
                isLoading: _isGlobalLoading,
              ),
            ),

            const Divider(height: 48, thickness: 2),

            // My Tickets Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('My Tickets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTickets),
              ],
            ),
            const SizedBox(height: 8),

            if (_isLoadingTickets)
              const Center(child: CircularProgressIndicator())
            else if (_myTickets.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('No support tickets found.', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _myTickets.length,
                itemBuilder: (context, index) {
                  final ticket = _myTickets[index];
                  return _buildTicketCard(ticket);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    // Handling generic Map structure from Supabase
    final status = ticket['ticket_status'] ?? 'open';
    final createdAt = DateTime.tryParse(ticket['created_at'] ?? '') ?? DateTime.now();
    final description = ticket['issue_description'] ?? 'No description';
    final category = ticket['category'] ?? 'General';
    final adminResponse = ticket['admin_response'];

    Color statusColor;
    switch (status) {
      case 'resolved': statusColor = Colors.green; break;
      case 'in_progress': statusColor = Colors.blue; break;
      default: statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                category, 
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Text(
          DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Text(description),
                const SizedBox(height: 16),
                if (adminResponse != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.support_agent, size: 16, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Support Response', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(adminResponse),
                      ],
                    ),
                  ),
                ] else 
                   const Text('Waiting for support response...', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
