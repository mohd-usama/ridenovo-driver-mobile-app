import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_flushbar.dart';
import '../auth/auth_provider.dart';
import '../vehicle/vehicle_details_screen.dart';
import 'kyc_model.dart';
import 'kyc_provider.dart';

class KycDetailsScreen extends ConsumerStatefulWidget {
  const KycDetailsScreen({super.key});

  @override
  ConsumerState<KycDetailsScreen> createState() => _KycDetailsScreenState();
}

class _KycDetailsScreenState extends ConsumerState<KycDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _mobileController;
  late TextEditingController _aadharController;
  late TextEditingController _panController;
  late TextEditingController _dlController;
  late TextEditingController _dlExpiryController;
  late TextEditingController _bankNameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _accountNameController;
  late TextEditingController _ifscController;
  late TextEditingController _upiController;

  String? _profilePhotoBase64;
  String? _profilePhotoFileName;

  String? _aadharDocBase64;
  String? _aadharFileName;

  String? _panDocBase64;
  String? _panFileName;

  String? _dlDocBase64;
  String? _dlFileName;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authProvider);
    final phone = authState.phoneNumber;

    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _mobileController = TextEditingController(text: phone);
    _aadharController = TextEditingController();
    _panController = TextEditingController();
    _dlController = TextEditingController();
    _dlExpiryController = TextEditingController();
    _accountNameController = TextEditingController();
    _accountNumberController = TextEditingController();
    _ifscController = TextEditingController();
    _bankNameController = TextEditingController();
    _upiController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _aadharController.dispose();
    _panController.dispose();
    _dlController.dispose();
    _dlExpiryController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _bankNameController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _showDocumentPickerOptions({
    required String title,
    required Function(String base64Data, String fileName) onPicked,
    bool isImageOnly = false,
  }) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select $title Source',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                  title: const Text('Take Photo with Camera'),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      final picker = ImagePicker();
                      final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 60);
                      if (photo != null) {
                        final bytes = await photo.readAsBytes();
                        final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                        onPicked(base64Str, photo.name);
                        if (mounted) {
                          AppFlushbar.success(context, title: 'Photo Captured', message: '$title compressed & uploaded!');
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        AppFlushbar.error(context, title: 'Camera Error', message: 'Failed to capture photo');
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                  title: const Text('Choose Image from Gallery'),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      final picker = ImagePicker();
                      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
                      if (image != null) {
                        final bytes = await image.readAsBytes();
                        final extension = image.name.split('.').last.toLowerCase();
                        final mime = extension == 'png' ? 'image/png' : 'image/jpeg';
                        final base64Str = 'data:$mime;base64,${base64Encode(bytes)}';
                        onPicked(base64Str, image.name);
                        if (mounted) {
                          AppFlushbar.success(context, title: 'Image Uploaded', message: '$title compressed & selected!');
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        AppFlushbar.error(context, title: 'Gallery Error', message: 'Failed to select image');
                      }
                    }
                  },
                ),
                if (!isImageOnly)
                  ListTile(
                    leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primary),
                    title: const Text('Choose PDF / Document File'),
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                          withData: true,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          final file = result.files.first;
                          final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
                          if (bytes != null) {
                            final ext = file.extension?.toLowerCase() ?? 'pdf';
                            final mime = ext == 'pdf' ? 'application/pdf' : (ext == 'png' ? 'image/png' : 'image/jpeg');
                            final base64Str = 'data:$mime;base64,${base64Encode(bytes)}';
                            onPicked(base64Str, file.name);
                            if (mounted) {
                              AppFlushbar.success(context, title: 'Document Uploaded', message: '$title document selected!');
                            }
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          AppFlushbar.error(context, title: 'File Error', message: 'Failed to pick document');
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_profilePhotoBase64 == null || _profilePhotoBase64!.isEmpty) {
        AppFlushbar.warning(context, title: 'Profile Photo Required', message: 'Please upload your Profile Photo.');
        return;
      }
      if (_aadharDocBase64 == null || _aadharDocBase64!.isEmpty) {
        AppFlushbar.warning(context, title: 'Aadhar Required', message: 'Please upload Aadhar Card document.');
        return;
      }
      if (_panDocBase64 == null || _panDocBase64!.isEmpty) {
        AppFlushbar.warning(context, title: 'PAN Required', message: 'Please upload PAN Card document.');
        return;
      }
      if (_dlDocBase64 == null || _dlDocBase64!.isEmpty) {
        AppFlushbar.warning(context, title: 'DL Required', message: 'Please upload Driving License document.');
        return;
      }

      final kycModel = KycModel(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        mobileNumber: _mobileController.text.trim(),
        profilePhoto: _profilePhotoBase64!,
        aadharNumber: _aadharController.text.trim(),
        aadharDocUrl: _aadharDocBase64!,
        panNumber: _panController.text.trim().toUpperCase(),
        panDocUrl: _panDocBase64!,
        drivingLicenseNumber: _dlController.text.trim().toUpperCase(),
        drivingLicenseDocUrl: _dlDocBase64!,
        drivingLicenseExpiry: _dlExpiryController.text.trim(),
        bankAccountName: _accountNameController.text.trim(),
        bankAccountNumber: _accountNumberController.text.trim(),
        bankIfscCode: _ifscController.text.trim().toUpperCase(),
        bankName: _bankNameController.text.trim(),
        upiId: _upiController.text.trim(),
      );

      final token = ref.read(authProvider).authToken;
      ref.read(kycProvider.notifier).updateKycData(kycModel);
      final success = await ref.read(kycProvider.notifier).submitKycDetails(token: token);

      if (success && mounted) {
        AppFlushbar.success(context, title: 'KYC Submitted', message: 'KYC details & documents saved successfully!');
        Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleDetailsScreen()));
      } else if (mounted) {
        AppFlushbar.error(context, title: 'Submission Error', message: 'Failed to submit KYC details. Please check fields.');
      }
    } else {
      AppFlushbar.warning(context, title: 'Incomplete Form', message: 'Please fill all required KYC fields correctly.');
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2045),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        controller.text = picked.toString().split(' ')[0];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final kycState = ref.watch(kycProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Driver KYC Registration'), backgroundColor: AppColors.secondary),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step Indicator Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: const Text(
                          '1',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Step 1 of 2: KYC Details',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                            ),
                            Text('Personal Info, Identity & Bank Info', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (kycState.status == KycStatus.error && kycState.errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            kycState.errorMessage!,
                            style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Card 0: Personal Info (Name, Email, Mobile, Profile Photo)
                _buildSectionCard(
                  title: '1. Personal Information',
                  icon: Icons.person_outline_rounded,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          _showDocumentPickerOptions(
                            title: 'Profile Photo',
                            isImageOnly: true,
                            onPicked: (base64Data, fileName) {
                              setState(() {
                                _profilePhotoBase64 = base64Data;
                                _profilePhotoFileName = fileName;
                              });
                            },
                          );
                        },
                        child: Stack(
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: AppColors.primary, width: 2),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10)],
                              ),
                              child: _profilePhotoBase64 != null
                                  ? ClipOval(child: Image.memory(base64Decode(_profilePhotoBase64!.split(',').last), fit: BoxFit.cover))
                                  : const Icon(Icons.person, size: 45, color: AppColors.textSecondary),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        hintText: 'Enter your full name',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Enter Full Name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address *',
                        hintText: 'e.g. ramesh@example.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (val) => val == null || !val.contains('@') ? 'Enter valid Email address' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number *',
                        hintText: '10-digit mobile number',
                        prefixIcon: Icon(Icons.phone_android),
                      ),
                      validator: (val) => val == null || val.length != 10 ? 'Enter valid 10-digit mobile number' : null,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Card 1: Identity Information (Aadhar & PAN)
                _buildSectionCard(
                  title: '2. Identity Documents',
                  icon: Icons.badge_outlined,
                  children: [
                    TextFormField(
                      controller: _aadharController,
                      keyboardType: TextInputType.number,
                      maxLength: 12,
                      decoration: const InputDecoration(
                        labelText: 'Aadhar Number *',
                        hintText: '12-digit Aadhar Number',
                        prefixIcon: Icon(Icons.credit_card),
                      ),
                      validator: (val) => val == null || val.length != 12 ? 'Enter valid 12-digit Aadhar Number' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildDocumentUploadWidget(
                      label: 'Aadhar Card Document (PDF/Photo) *',
                      fileName: _aadharFileName,
                      base64Data: _aadharDocBase64,
                      onTap: () {
                        _showDocumentPickerOptions(
                          title: 'Aadhar Card Document',
                          onPicked: (base64Data, fileName) {
                            setState(() {
                              _aadharDocBase64 = base64Data;
                              _aadharFileName = fileName;
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _panController,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 10,
                      decoration: const InputDecoration(
                        labelText: 'PAN Number *',
                        hintText: 'e.g. ABCDE1234F',
                        prefixIcon: Icon(Icons.assignment_ind),
                      ),
                      validator: (val) => val == null || val.length != 10 ? 'Enter valid 10-character PAN' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildDocumentUploadWidget(
                      label: 'PAN Card Photo/Doc *',
                      fileName: _panFileName,
                      base64Data: _panDocBase64,
                      onTap: () {
                        _showDocumentPickerOptions(
                          title: 'PAN Card Document',
                          onPicked: (base64Data, fileName) {
                            setState(() {
                              _panDocBase64 = base64Data;
                              _panFileName = fileName;
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Card 2: Driving License Details
                _buildSectionCard(
                  title: '3. Driving License Info',
                  icon: Icons.drive_eta_outlined,
                  children: [
                    TextFormField(
                      controller: _dlController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Driving License Number *',
                        hintText: 'e.g. DL1420110012345',
                        prefixIcon: Icon(Icons.card_membership),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Enter Driving License Number' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dlExpiryController,
                      readOnly: true,
                      onTap: () => _selectDate(_dlExpiryController),
                      decoration: const InputDecoration(
                        labelText: 'Driving License Expiry Date *',
                        hintText: 'YYYY-MM-DD',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Select DL Expiry Date' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildDocumentUploadWidget(
                      label: 'Driving License Document *',
                      fileName: _dlFileName,
                      base64Data: _dlDocBase64,
                      onTap: () {
                        _showDocumentPickerOptions(
                          title: 'Driving License Document',
                          onPicked: (base64Data, fileName) {
                            setState(() {
                              _dlDocBase64 = base64Data;
                              _dlFileName = fileName;
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Card 3: Bank Account & UPI
                _buildSectionCard(
                  title: '4. Bank Account & Payouts',
                  icon: Icons.account_balance_outlined,
                  children: [
                    TextFormField(
                      controller: _accountNameController,
                      decoration: const InputDecoration(
                        labelText: 'Account Holder Name *',
                        hintText: 'As per Bank Records',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Enter Account Holder Name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _accountNumberController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Bank Account Number *',
                        hintText: 'Enter Account Number',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Enter Bank Account Number' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ifscController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'IFSC Code *', hintText: 'e.g. SBIN0001234', prefixIcon: Icon(Icons.code)),
                      validator: (val) => val == null || val.isEmpty ? 'Enter Bank IFSC Code' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bankNameController,
                      decoration: const InputDecoration(
                        labelText: 'Bank Name *',
                        hintText: 'e.g. State Bank of India',
                        prefixIcon: Icon(Icons.apartment),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Enter Bank Name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _upiController,
                      decoration: const InputDecoration(
                        labelText: 'UPI ID (Optional for Instant Pay)',
                        hintText: 'e.g. name@upi',
                        prefixIcon: Icon(Icons.qr_code),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: kycState.status == KycStatus.loading ? null : _submitForm,
                    child: kycState.status == KycStatus.loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('SAVE AND PROCEED', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.secondary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.secondary),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentUploadWidget({
    required String label,
    required String? fileName,
    required String? base64Data,
    required VoidCallback onTap,
  }) {
    final bool isUploaded = base64Data != null && base64Data.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isUploaded ? AppColors.success.withValues(alpha: 0.06) : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isUploaded ? AppColors.success : const Color(0xFFCBD5E1), width: isUploaded ? 1.5 : 1.0),
      ),
      child: Row(
        children: [
          Icon(
            isUploaded ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
            color: isUploaded ? AppColors.success : AppColors.primary,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  isUploaded ? (fileName ?? 'Document Uploaded') : 'PDF or Image (Max 5MB)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isUploaded ? AppColors.success : AppColors.textSecondary,
                    fontWeight: isUploaded ? FontWeight.bold : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: isUploaded ? AppColors.success : AppColors.secondary,
              side: BorderSide(color: isUploaded ? AppColors.success : AppColors.secondary),
              minimumSize: const Size(64, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(isUploaded ? 'Change' : 'Upload'),
          ),
        ],
      ),
    );
  }
}
