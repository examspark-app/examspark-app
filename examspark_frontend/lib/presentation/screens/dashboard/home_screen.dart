import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/credit_usage_display.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';

/// Minimalist interface inspired by ChatGPT layout with historical sidebar
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSidebarOpen = true;
  List<Map<String, dynamic>> _lectureHistory = [];
  int _creditsBalance = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = SupabaseClient.instance.currentUser;
    if (user != null) {
      final profile = await SupabaseClient.instance.getUserProfile(user.id);
      if (profile != null) {
        setState(() {
          _creditsBalance = profile['credits_balance'] as int? ?? 0;
        });
      }
      final lectures = await LectureService.instance.getLecturesForUser();
      setState(() {
        _lectureHistory = lectures;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Historical Sidebar
          _isSidebarOpen
              ? Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border(right: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Column(
                    children: [
                      // Sidebar Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    SupabaseClient.instance.currentUser?.email ?? 'User',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '$_creditsBalance Credits Remaining',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  Text(
                                    CreditUsageDisplay.primaryBalanceLine(_creditsBalance),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // New Lecture Button
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/recording_setup'),
                          icon: const Icon(Icons.add),
                          label: const Text('New Lecture'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                      ),
                      // Lecture History
                      Expanded(
                        child: ListView.builder(
                          itemCount: _lectureHistory.length,
                          itemBuilder: (context, index) {
                            final lecture = _lectureHistory[index];
                            return ListTile(
                              leading: const Icon(Icons.history),
                              title: Text(
                                lecture['title'] ?? 'Lecture ${index + 1}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                _formatDate(lecture['created_at']),
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                final id = lecture['id'] as String?;
                                if (id != null) {
                                  Navigator.pushNamed(
                                    context,
                                    '/notes_result',
                                    arguments: {'lectureId': id},
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
                      // Sidebar Footer
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: Colors.grey[300]!)),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.settings),
                          title: const Text('Settings'),
                          onTap: () => Navigator.pushNamed(context, '/subscription'),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(_isSidebarOpen ? Icons.menu_open : Icons.menu),
                        onPressed: () {
                          setState(() => _isSidebarOpen = !_isSidebarOpen);
                        },
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'ExamSpark',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.school_outlined),
                        tooltip: 'Teacher Dashboard',
                        onPressed: () => Navigator.pushNamed(context, '/teacher'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.people_outline),
                        tooltip: 'Student Portal',
                        onPressed: () => Navigator.pushNamed(context, '/student'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.account_circle),
                        onPressed: () => Navigator.pushNamed(context, '/subscription'),
                      ),
                    ],
                  ),
                ),
                // Welcome Content
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mic,
                          size: 100,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Start a new lecture',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Record audio or upload content to generate intelligent notes',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/recording_setup'),
                          icon: const Icon(Icons.mic),
                          label: const Text('Start Recording'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
}
