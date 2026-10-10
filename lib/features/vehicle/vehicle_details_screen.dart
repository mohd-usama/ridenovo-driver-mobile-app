import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_flushbar.dart';
import '../auth/auth_provider.dart';
import '../home/screens/main_navigation_screen.dart';
import 'package:uuid/uuid.dart';
import 'vehicle_model.dart';
import 'vehicle_provider.dart';

class VehicleDetailsScreen extends ConsumerStatefulWidget {
  const VehicleDetailsScreen({super.key});

  @override
  ConsumerState<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends ConsumerState<VehicleDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _regNumberController;
  late TextEditingController _makeController;
  late TextEditingController _modelController;
  late TextEditingController _yearController;
  late TextEditingController _colorController;
  late TextEditingController _insuranceExpiryController;

  final Uuid _uuid = const Uuid();
  late String _carUuid;
  late String _bikeUuid;
  late String _autoUuid;
  late String _selectedVehicleType;
  String _selectedFuelType = 'cng';

  String? _rcDocBase64;
  String? _rcFileName;

  String? _insuranceDocBase64;
  String? _insuranceFileName;

  String? _vehiclePhotoBase64;
  String? _vehiclePhotoFileName;

  final List<String> _fuelTypes = ['petrol', 'diesel', 'cng', 'electric'];

  @override
  void initState() {
    super.initState();
    _carUuid = _uuid.v4();
    _bikeUuid = _uuid.v4();
    _autoUuid = _uuid.v4();
    _selectedVehicleType = _carUuid;
    _regNumberController = TextEditingController();
    _makeController = TextEditingController();
    _modelController = TextEditingController();
    _yearController = TextEditingController(text: DateTime.now().year.toString());
    _colorController = TextEditingController();
    _insuranceExpiryController = TextEditingController();
  }

  @override
  void dispose() {
    _regNumberController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _insuranceExpiryController.dispose();
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

  void _submitVehicle() async {
    if (_formKey.currentState!.validate()) {
      if (_rcDocBase64 == null || _rcDocBase64!.isEmpty) {
        AppFlushbar.warning(context, title: 'RC Required', message: 'Please upload Vehicle RC Document.');
        return;
      }

      if (_insuranceDocBase64 == null || _insuranceDocBase64!.isEmpty) {
        AppFlushbar.warning(context, title: 'Insurance Required', message: 'Please upload Vehicle Insurance Certificate.');
        return;
      }

      if (_vehiclePhotoBase64 == null || _vehiclePhotoBase64!.isEmpty) {
        AppFlushbar.warning(context, title: 'Photo Required', message: 'Please upload Vehicle Photo.');
        return;
      }

      final vehicleModel = VehicleModel(
        vehicleTypeId: _selectedVehicleType,
        registrationNumber: _regNumberController.text.trim().toUpperCase(),
        make: _makeController.text.trim(),
        model: _modelController.text.trim(),
        year: int.tryParse(_yearController.text.trim()) ?? 2022,
        color: _colorController.text.trim(),
        fuelType: _selectedFuelType,
        rcDocUrl: _rcDocBase64!,
        insuranceDocUrl: _insuranceDocBase64!,
        insuranceExpiry: _insuranceExpiryController.text.trim(),
        vehiclePhotoUrl: _vehiclePhotoBase64!,
      );

      final token = ref.read(authProvider).authToken;
      ref.read(vehicleProvider.notifier).updateVehicleData(vehicleModel);
      final success = await ref.read(vehicleProvider.notifier).registerVehicle(token: token);

      if (success && mounted) {
        await ref.read(authProvider.notifier).markOnboardingComplete();
        if (mounted) {
          AppFlushbar.success(context, title: 'Vehicle Registered!', message: 'Vehicle registered & onboarding complete!');
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainNavigationScreen()), (route) => false);
        }
      } else if (mounted) {
        AppFlushbar.error(context, title: 'Registration Error', message: 'Failed to register vehicle. Please check fields.');
      }
    } else {
      AppFlushbar.warning(context, title: 'Incomplete Details', message: 'Please fill all required vehicle fields correctly.');
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
    final vehicleState = ref.watch(vehicleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Register Vehicle'), backgroundColor: AppColors.secondary),
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
                          '2',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Step 2 of 2: Vehicle Registration',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                            ),
                            Text('Registration, RC & Insurance Info', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (vehicleState.status == VehicleStatus.error && vehicleState.errorMessage != null)
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
                            vehicleState.errorMessage!,
                            style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Card 1: Basic Vehicle Spec
                _buildSectionCard(
                  title: '1. Vehicle Details',
                  icon: Icons.directions_car_outlined,
                  children: [
                    const Text(
                      'Vehicle Category *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildVehicleTypeOption(id: _carUuid, title: 'Cab / Car', icon: Icons.local_taxi),
                        const SizedBox(width: 8),
                        _buildVehicleTypeOption(id: _bikeUuid, title: 'Bike / Scooter', icon: Icons.two_wheeler),
                        const SizedBox(width: 8),
                        _buildVehicleTypeOption(id: _autoUuid, title: 'Auto', icon: Icons.electric_rickshaw),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _regNumberController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Registration Number *',
                        hintText: 'e.g. DL01AB1234',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Enter Registration Number' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _makeController,
                            decoration: const InputDecoration(labelText: 'Make (Brand) *', hintText: 'e.g. Maruti'),
                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _modelController,
                            decoration: const InputDecoration(labelText: 'Model *', hintText: 'e.g. Swift Dzire'),
                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _yearController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Year *', hintText: 'e.g. 2022'),
                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _colorController,
                            decoration: const InputDecoration(labelText: 'Color *', hintText: 'e.g. White'),
                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Fuel Type *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _fuelTypes.map((fuel) {
                        final isSelected = _selectedFuelType == fuel;
                        return ChoiceChip(
                          label: Text(
                            fuel.toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedFuelType = fuel;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Card 2: RC & Insurance Documents
                _buildSectionCard(
                  title: '2. Documents & Photos',
                  icon: Icons.folder_copy_outlined,
                  children: [
                    _buildDocumentUploadWidget(
                      label: 'Vehicle RC Document (PDF/Photo) *',
                      fileName: _rcFileName,
                      base64Data: _rcDocBase64,
                      onTap: () {
                        _showDocumentPickerOptions(
                          title: 'Vehicle RC Document',
                          onPicked: (base64Data, fileName) {
                            setState(() {
                              _rcDocBase64 = base64Data;
                              _rcFileName = fileName;
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDocumentUploadWidget(
                      label: 'Vehicle Insurance Certificate *',
                      fileName: _insuranceFileName,
                      base64Data: _insuranceDocBase64,
                      onTap: () {
                        _showDocumentPickerOptions(
                          title: 'Insurance Certificate',
                          onPicked: (base64Data, fileName) {
                            setState(() {
                              _insuranceDocBase64 = base64Data;
                              _insuranceFileName = fileName;
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _insuranceExpiryController,
                      readOnly: true,
                      onTap: () => _selectDate(_insuranceExpiryController),
                      decoration: const InputDecoration(
                        labelText: 'Insurance Expiry Date *',
                        hintText: 'YYYY-MM-DD',
                        prefixIcon: Icon(Icons.event_available),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Select Insurance Expiry Date' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildDocumentUploadWidget(
                      label: 'Vehicle Front Photo *',
                      fileName: _vehiclePhotoFileName,
                      base64Data: _vehiclePhotoBase64,
                      onTap: () {
                        _showDocumentPickerOptions(
                          title: 'Vehicle Photo',
                          isImageOnly: true,
                          onPicked: (base64Data, fileName) {
                            setState(() {
                              _vehiclePhotoBase64 = base64Data;
                              _vehiclePhotoFileName = fileName;
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Register Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: vehicleState.status == VehicleStatus.loading ? null : _submitVehicle,
                    child: vehicleState.status == VehicleStatus.loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('SAVE AND REGISTER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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

  Widget _buildVehicleTypeOption({required String id, required String title, required IconData icon}) {
    final isSelected = _selectedVehicleType == id;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedVehicleType = id;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1), width: isSelected ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 22),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
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
