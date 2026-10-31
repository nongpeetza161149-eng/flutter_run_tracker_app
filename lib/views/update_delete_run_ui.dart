import 'dart:typed_data';
 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
 
class UpdateDeleteRunUI extends StatefulWidget {
  // รับข้อมูลรายการที่เลือกมาจากหน้า ShowAllRunUI
  final Map<String, dynamic> run;
 
  const UpdateDeleteRunUI({super.key, required this.run});
 
  @override
  State<UpdateDeleteRunUI> createState() => _UpdateDeleteRunUIState();
}
 
class _UpdateDeleteRunUIState extends State<UpdateDeleteRunUI> {
  final supabase = Supabase.instance.client;
 
  late TextEditingController placeCtrl;
  late TextEditingController whoCtrl;
  late TextEditingController distanceCtrl;
 
  Uint8List? newImageBytes; // รูปใหม่ที่เลือก
  String? oldImageUrl; // รูปเดิมใน Storage
  bool saving = false;
 
  @override
  void initState() {
    super.initState();
    placeCtrl = TextEditingController(text: widget.run['place'] ?? '');
    whoCtrl = TextEditingController(text: widget.run['with_who'] ?? '');
    distanceCtrl = TextEditingController(text: '${widget.run['distance']}');
    oldImageUrl = widget.run['image_url'];
  }
 
  @override
  void dispose() {
    placeCtrl.dispose();
    whoCtrl.dispose();
    distanceCtrl.dispose();
    super.dispose();
  }
 
  void showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
 
  // ดึงชื่อไฟล์จาก public URL เพื่อใช้ลบรูปใน Storage
  String? fileNameFromUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    return Uri.parse(url).pathSegments.last;
  }
 
  Future<void> pickImage(ImageSource source) async {
    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 70);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => newImageBytes = bytes);
  }
 
  void chooseSource() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('ถ่ายภาพ'),
              onTap: () {
                Navigator.pop(context);
                pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('เลือกจากแกลเลอรี'),
              onTap: () {
                Navigator.pop(context);
                pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
 
  // บันทึกการแก้ไข
  Future<void> update() async {
    if (placeCtrl.text.trim().isEmpty) return showMsg('กรุณากรอกวิ่งที่ไหน');
    if (whoCtrl.text.trim().isEmpty) return showMsg('กรุณากรอกวิ่งกับใคร');
    final distance = double.tryParse(distanceCtrl.text.trim());
    if (distance == null) return showMsg('ระยะทางต้องเป็นตัวเลข');
 
    setState(() => saving = true);
    String? uploadedName; // รูปใหม่ที่อัปโหลด ใช้ลบทิ้งถ้า DB พัง
    try {
      String? imageUrl = oldImageUrl;
      String? oldName; // รูปเก่าที่จะลบหลังอัปเดต DB สำเร็จ
 
      // ถ้าเลือกรูปใหม่ ให้อัปโหลดรูปใหม่ก่อน (รูปเก่าลบทีหลัง)
      if (newImageBytes != null) {
        oldName = fileNameFromUrl(oldImageUrl);
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        uploadedName = fileName;
        await supabase.storage.from('run_images').uploadBinary(
              fileName,
              newImageBytes!,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        imageUrl = supabase.storage.from('run_images').getPublicUrl(fileName);
      }
 
      await supabase.from('run_tracker').update({
        'place': placeCtrl.text.trim(),
        'with_who': whoCtrl.text.trim(),
        'distance': distance,
        'image_url': imageUrl,
      }).eq('id', widget.run['id']);
 
      // อัปเดต DB สำเร็จแล้ว ค่อยลบรูปเก่า
      if (oldName != null) {
        try {
          await supabase.storage.from('run_images').remove([oldName]);
        } catch (_) {}
      }
 
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (uploadedName != null) {
        try {
          await supabase.storage.from('run_images').remove([uploadedName]);
        } catch (_) {}
      }
      showMsg('แก้ไขไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
 
  // ลบข้อมูล (และรูปใน Storage ถ้ามี)
  Future<void> delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('ต้องการลบรายการนี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (ok != true) return;
 
    try {
      final oldName = fileNameFromUrl(oldImageUrl);
      if (oldName != null) {
        await supabase.storage.from('run_images').remove([oldName]);
      }
      await supabase.from('run_tracker').delete().eq('id', widget.run['id']);
 
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      showMsg('ลบไม่สำเร็จ: $e');
    }
  }
 
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
 
    final logo = Image.asset(
      'assets/images/speed.png',
      width: w * 0.355,
      height: w * 0.355,
      fit: BoxFit.contain,
    );
 
    Widget imageWidget;
    if (newImageBytes != null) {
      imageWidget = Image.memory(
        newImageBytes!,
        width: w * 0.355,
        height: w * 0.355,
        fit: BoxFit.cover,
      );
    } else if (oldImageUrl != null && oldImageUrl!.isNotEmpty) {
      imageWidget = Image.network(
        oldImageUrl!,
        width: w * 0.355,
        height: w * 0.355,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => logo,
      );
    } else {
      imageWidget = logo;
    }
 
    return Scaffold(
      // ส่วนของ appBar
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 5, 1, 80),
        title: const Text(
          'Run Tracker (แก้ไข/ลบ)',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
          ),
        ),
      ),
      // ส่วนของ body
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(
            top: 50,
            bottom: 50,
            left: 36,
            right: 36,
          ),
          child: Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: chooseSource,
                  child: imageWidget,
                ),
                const SizedBox(
                  height: 30,
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'วิ่งที่ไหน',
                  ),
                ),
                TextField(
                  controller: placeCtrl,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'วิ่งกับใคร',
                  ),
                ),
                TextField(
                  controller: whoCtrl,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ระยะทาง',
                  ),
                ),
                TextField(
                  controller: distanceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 30,
                ),
                // ปุ่มบันทึกแก้ไขข้อมูล
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: saving ? null : update,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('บันทึกแก้ไขข้อมูล'),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                // ปุ่มลบข้อมูล
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: delete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF44336),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('ลบข้อมูล'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}