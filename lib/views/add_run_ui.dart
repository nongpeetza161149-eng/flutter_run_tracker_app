import 'dart:typed_data';
 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
 
class AddRunUI extends StatefulWidget {
  const AddRunUI({super.key});
 
  @override
  State<AddRunUI> createState() => _AddRunUIState();
}
 
class _AddRunUIState extends State<AddRunUI> {
  final supabase = Supabase.instance.client;
 
  // ตัวควบคุมช่องกรอกข้อมูล
  final placeCtrl = TextEditingController();
  final whoCtrl = TextEditingController();
  final distanceCtrl = TextEditingController();
 
  Uint8List? imageBytes; // รูปที่เลือก (ไม่บังคับ)
  bool saving = false;
 
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
 
  // เลือกรูปจากกล้องหรือแกลเลอรี
  Future<void> pickImage(ImageSource source) async {
    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 70);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => imageBytes = bytes);
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
 
  // บันทึกข้อมูลลง Database (และอัปโหลดรูปขึ้น Storage ถ้ามี)
  Future<void> save() async {
    // Validate
    if (placeCtrl.text.trim().isEmpty) return showMsg('กรุณากรอกวิ่งที่ไหน');
    if (whoCtrl.text.trim().isEmpty) return showMsg('กรุณากรอกวิ่งกับใคร');
    final distance = double.tryParse(distanceCtrl.text.trim());
    if (distance == null) return showMsg('ระยะทางต้องเป็นตัวเลข');
 
    setState(() => saving = true);
    String? uploadedName; // ใช้ลบรูปทิ้งถ้าบันทึกข้อมูลไม่สำเร็จ
    try {
      String? imageUrl;
      if (imageBytes != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        uploadedName = fileName;
        await supabase.storage.from('run_images').uploadBinary(
              fileName,
              imageBytes!,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        imageUrl = supabase.storage.from('run_images').getPublicUrl(fileName);
      }
 
      await supabase.from('run_tracker').insert({
        'place': placeCtrl.text.trim(),
        'with_who': whoCtrl.text.trim(),
        'distance': distance,
        'image_url': imageUrl,
      });
 
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (uploadedName != null) {
        try {
          await supabase.storage.from('run_images').remove([uploadedName]);
        } catch (_) {}
      }
      showMsg('บันทึกไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
 
  // ยกเลิก เคลียร์ข้อมูลที่ป้อนและเลือก
  void clearAll() {
    setState(() {
      placeCtrl.clear();
      whoCtrl.clear();
      distanceCtrl.clear();
      imageBytes = null;
    });
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ส่วนของ appBar
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 5, 1, 80),
        title: const Text(
          'Run Tracker (เพิ่ม)',
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
                  child: imageBytes == null
                      ? Icon(
                          Icons.add_a_photo,
                          size: MediaQuery.of(context).size.width * 0.50,
                          color: Colors.grey,
                        )
                      : Image.memory(
                          imageBytes!,
                          width: MediaQuery.of(context).size.width * 0.50,
                          height: MediaQuery.of(context).size.width * 0.50,
                          fit: BoxFit.cover,
                        ),
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
                    hintText: 'เช่น สวนสาธารณะ, สนามกีฬา หรือ อื่นๆ',
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
                    hintText: 'เช่น เพื่อน 3 คน, แฟน หรือ อื่นๆ',
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
                    hintText: 'เช่น 1, 5, 11 หรือ อื่นๆ',
                  ),
                ),
                const SizedBox(
                  height: 30,
                ),
                // ปุ่มบันทึกข้อมูล
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: saving ? null : save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('บันทึกข้อมูล'),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                // ปุ่มยกเลิก
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: clearAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF44336),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('ยกเลิก'),
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