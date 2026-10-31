// ignore_for_file: sort_child_properties_last
 
import 'package:flutter/material.dart';
import 'package:flutter_run_tracker_app/views/add_run_ui.dart';
import 'package:flutter_run_tracker_app/views/update_delete_run_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
 
class ShowAllRunUI extends StatefulWidget {
  const ShowAllRunUI({super.key});
 
  @override
  State<ShowAllRunUI> createState() => _ShowAllRunUIState();
}
 
class _ShowAllRunUIState extends State<ShowAllRunUI> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> runs = [];
  bool loading = true;
 
  @override
  void initState() {
    super.initState();
    loadData();
  }
 
  // ดึงข้อมูลทั้งหมดจาก Supabase
  Future<void> loadData() async {
    try {
      final data = await supabase
          .from('run_tracker')
          .select()
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        runs = List<Map<String, dynamic>>.from(data);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดข้อมูลไม่สำเร็จ: $e')),
      );
    }
  }
 
  Widget smallLogo() => Image.asset(
        'assets/images/speed.png',
        width: 44,
        height: 44,
        fit: BoxFit.contain,
      );
 
  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
 
    return Scaffold(
      // ส่วนของ appBar
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 5, 1, 80),
        title: const Text(
          'Run Tracker',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      // ส่วนของ floatingActionButton
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // เปิดไป AddRunUI() แบบย้อนกลับได้ แล้วโหลดข้อมูลใหม่เมื่อกลับมา
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddRunUI(),
            ),
          ).then((_) => loadData());
        },
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
        backgroundColor: const Color.fromARGB(255, 5, 1, 80),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      // ส่วนของ body
      body: Column(
        children: [
          const SizedBox(
            height: 50,
          ),
          Image.asset(
            'assets/images/speed.png',
            width: MediaQuery.of(context).size.width * 0.45,
            height: MediaQuery.of(context).size.width * 0.45,
            fit: BoxFit.cover,
          ),
          Text(
            'วิ่งกันเถอะ',
            style: TextStyle(
              fontSize: h * 0.0325,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 15,
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    itemCount: runs.length,
                    itemBuilder: (context, i) {
                      final r = runs[i];
                      final img = r['image_url'] as String?;
                      final hasImg = img != null && img.isNotEmpty;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: i.isEven
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          // เปิดไป UpdateDeleteRunUI() แบบย้อนกลับได้
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    UpdateDeleteRunUI(run: r),
                              ),
                            ).then((_) => loadData());
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: hasImg
                                      ? ClipOval(
                                          child: Image.network(
                                            img,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                smallLogo(),
                                          ),
                                        )
                                      : smallLogo(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'วิ่งที่ไหน: ${r['place'] ?? ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: h * 0.02),
                                      ),
                                      Text(
                                        'วิ่งไปเท่าไหร่: ${r['distance']} กม.',
                                        style: TextStyle(
                                          fontSize: h * 0.0175,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.info,
                                  size: 22,
                                  color: Color(0xFFF44336),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}