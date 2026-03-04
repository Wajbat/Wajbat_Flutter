import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Dummy FAQ Data structure
  final List<Map<String, String>> _faqs = [
    // Getting Started
    {'q': 'How do I create an account?', 'a': 'To create an account, tap "Sign Up" on the login screen, fill in your details, and select your role (Donor or Recipient).', 'category': 'Getting Started'},
    {'q': 'What is Wajbat?', 'a': 'Wajbat is a platform connecting food donors with recipients to reduce food waste.', 'category': 'Getting Started'},
    // Donations
    {'q': 'How do I donate food?', 'a': 'Tap the "+" button on the home screen, take a photo, and fill in the details. AI will help detect ingredients!', 'category': 'Donations'},
    {'q': 'Who can see my donation?', 'a': 'Registered recipients in your area can see and request your available food posts.', 'category': 'Donations'},
    // Requests
    {'q': 'How do I request food?', 'a': 'Browse available posts, tap one to view details, and click "Request Food".', 'category': 'Requests'},
    {'q': 'Can I cancel a request?', 'a': 'Yes, go to "My Requests", select the request, and tap "Cancel".', 'category': 'Requests'},
    // Rewards
    {'q': 'What are Impact Points?', 'a': 'Points awarded to donors for successful donations. Earn badges like Silver, Gold, and Platinum!', 'category': 'Rewards'},
  ];

  final List<Map<String, dynamic>> _messages = [
    {'text': 'Hello! I am your Wajbat assistant. How can I help you today?', 'isUser': false},
  ];

  String _selectedCategory = 'All';

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({'text': text, 'isUser': true});
      _controller.clear();
    });

    _processResponse(text);
    _scrollToBottom();
  }

  void _processResponse(String query) {
    // 1. Check for exact match or keyword match
    final lowerQuery = query.toLowerCase();
    
    // Simple relevance scoring
    var bestMatch = _faqs.firstWhere(
      (faq) => faq['q']!.toLowerCase() == lowerQuery, 
      orElse: () => {},
    );

    if (bestMatch.isNotEmpty) {
      _addBotResponse(bestMatch['a']!);
      return;
    }

    // Keyword search
    List<Map<String, String>> matches = _faqs.where((faq) {
      final qWords = faq['q']!.toLowerCase().split(' ');
      final userWords = lowerQuery.split(' ');
      return userWords.any((w) => qWords.contains(w) && w.length > 3);
    }).toList();

    if (matches.isNotEmpty) {
       _addBotResponse('Here is what I found:');
       for (var match in matches.take(2)) { // Show top 2
         _messages.add({'text': 'Q: ${match['q']}\nA: ${match['a']}', 'isUser': false});
       }
    } else {
      _messages.add({
        'text': "I couldn't find an answer to that. Would you like to contact support?",
        'isUser': false,
        'action': 'contact_support'
      });
    }
  }

  void _addBotResponse(String text) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _messages.add({'text': text, 'isUser': false});
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', 'Getting Started', 'Donations', 'Requests', 'Rewards'];

    return Scaffold(
      appBar: AppBar(title: const Text('Help Center')),
      body: Column(
        children: [
          // FAQs Categories
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() {
                      _selectedCategory = cat;
                      // Show FAQs for this category as proactive bot message
                      if (cat != 'All') {
                         final catFaqs = _faqs.where((f) => f['category'] == cat).toList();
                         _messages.add({'text': 'Here are some common questions about $cat:', 'isUser': false});
                         for (var faq in catFaqs) {
                            _messages.add({'text': faq['q'], 'isUser': false, 'isOption': true, 'answer': faq['a']});
                         }
                      }
                    });
                  },
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  labelStyle: TextStyle(color: isSelected ? AppColors.primary : Colors.black),
                );
              },
            ),
          ),

          // Chat Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'] as bool? ?? false;
                final isOption = msg['isOption'] as bool? ?? false;
                final action = msg['action'] as String?;

                if (isOption) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8, right: 40),
                    child: ActionChip(
                      label: Text(msg['text'] as String),
                      onPressed: () {
                        // Treat as user asking this question
                        _sendMessage(msg['text'] as String);
                      },
                      backgroundColor: Colors.white,
                      side: BorderSide(color: AppColors.primary),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isUser ? AppColors.primary : Colors.grey[200],
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                          bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                        ),
                      ),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                      child: Text(
                        msg['text'] as String,
                        style: TextStyle(color: isUser ? Colors.white : Colors.black87),
                      ),
                    ),
                    if (action == 'contact_support')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.supportTicket),
                          icon: const Icon(Icons.support_agent),
                          label: const Text('Contact Support'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask a question...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary),
                  onPressed: () => _sendMessage(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
