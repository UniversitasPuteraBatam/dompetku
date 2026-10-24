import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/dummy_transactions.dart';
import '../services/app_clock.dart';
import '../services/auth_service.dart';
import '../widgets/field_label.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key, this.transaction, this.authService});

  final TransactionItem? transaction;
  final AuthService? authService;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateFieldKey = GlobalKey<FormFieldState<DateTime>>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool? _isIncome;
  String? _category;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    if (transaction == null) return;
    _isIncome = transaction.isIncome;
    _category = transaction.category;
    _amountController.text = transaction.amount.toString();
    _noteController.text = transaction.note;
    _initialDate = transaction.date;
  }

  List<String> get _categories {
    final categories = switch (_isIncome) {
      true => const ['Gaji', 'Bonus', 'Investasi', 'Freelance', 'Lainnya'],
      false => const [
        'Makanan',
        'Transportasi',
        'Belanja',
        'Tagihan',
        'Kesehatan',
        'Hiburan',
        'Lainnya',
      ],
      null => const <String>[],
    };
    // A transaction saved with a category outside this list (from the API or
    // an older version) must still be selectable, otherwise the dropdown
    // asserts on an initial value it does not contain.
    final category = _category;
    return category == null || categories.contains(category)
        ? categories
        : [...categories, category];
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    final selectedDate = _dateFieldKey.currentState?.value;
    if (selectedDate == null) return;

    final isIncome = _isIncome!;
    final transaction = TransactionItem(
      id: widget.transaction?.id,
      category: _category!,
      amount: int.parse(_amountController.text.trim()),
      date: selectedDate,
      isIncome: isIncome,
      icon: iconForCategory(_category!, isIncome),
      note: _noteController.text.trim(),
    );

    setState(() => _isSaving = true);
    try {
      final service = widget.authService ?? AuthService();
      if (widget.transaction == null) {
        await service.addTransaction(
          type: isIncome ? 'income' : 'expense',
          category: transaction.category,
          amount: transaction.amount,
          description: transaction.note,
          transactionDate: selectedDate,
        );
      } else {
        final id = widget.transaction!.id;
        if (id == null) {
          throw const AuthApiException(
            'ID transaksi tidak tersedia. Muat ulang riwayat lalu coba lagi.',
          );
        }
        await service.updateTransaction(
          id: id,
          type: isIncome ? 'income' : 'expense',
          category: transaction.category,
          amount: transaction.amount,
          description: transaction.note,
          transactionDate: selectedDate,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, transaction);
    } on AuthApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat terhubung ke server. Periksa koneksi.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  DateTime? _initialDate;

  Future<void> _pickDate(FormFieldState<DateTime> field) async {
    final now = AppClock.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: field.value == null
          ? DateTime(now.year, now.month, now.day)
          : DateTime(field.value!.year, field.value!.month, field.value!.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || pickedDate == null) return;

    final existingValue = field.value;
    final initialTime = existingValue == null
        ? TimeOfDay(hour: now.hour, minute: now.minute)
        : TimeOfDay(hour: existingValue.hour, minute: existingValue.minute);
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (!mounted || pickedTime == null) return;

    final dateWithTime = DateTime.utc(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    field.didChange(dateWithTime);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.transaction == null ? 'Tambah Transaksi' : 'Edit Transaksi',
      ),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
              children: [
                const FieldLabel('Jenis transaksi'),
                const SizedBox(height: 8),
                FormField<bool>(
                  initialValue: _isIncome,
                  validator: (value) =>
                      value == null ? 'Pilih jenis transaksi' : null,
                  builder: (field) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<bool>(
                        emptySelectionAllowed: true,
                        selected: field.value == null
                            ? <bool>{}
                            : {field.value!},
                        onSelectionChanged: (selection) {
                          if (selection.isEmpty) return;
                          final selectedType = selection.first;
                          setState(() {
                            _isIncome = selectedType;
                            _category = null;
                          });
                          field.didChange(selectedType);
                        },
                        segments: const [
                          ButtonSegment(
                            value: true,
                            label: Text('Pemasukan'),
                            icon: Icon(Icons.south_west_rounded),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text('Pengeluaran'),
                            icon: Icon(Icons.north_east_rounded),
                          ),
                        ],
                      ),
                      if (field.errorText != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          field.errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const FieldLabel('Kategori'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey(_isIncome),
                  initialValue: _category,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: _isIncome == null
                        ? 'Pilih jenis transaksi terlebih dahulu'
                        : 'Pilih kategori',
                    prefixIcon: const Icon(Icons.category_outlined),
                  ),
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: _isIncome == null
                      ? null
                      : (value) => setState(() => _category = value),
                  validator: (value) =>
                      value == null ? 'Pilih kategori transaksi' : null,
                ),
                const SizedBox(height: 20),
                const FieldLabel('Nominal'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Contoh: 50000',
                    prefixText: 'Rp ',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (value) {
                    final amount = int.tryParse(value?.trim() ?? '');
                    if (amount == null) return 'Masukkan nominal berupa angka';
                    if (amount <= 0) return 'Nominal harus lebih dari 0';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const FieldLabel('Keterangan (opsional)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Tambahkan keterangan',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 20),
                const FieldLabel('Tanggal & waktu'),
                const SizedBox(height: 8),
                FormField<DateTime>(
                  key: _dateFieldKey,
                  initialValue: _initialDate,
                  validator: (value) => value == null
                      ? 'Pilih tanggal dan waktu transaksi'
                      : null,
                  builder: (field) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(field),
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(
                            field.value == null
                                ? 'Pilih tanggal'
                                : formatTransactionDate(field.value!),
                          ),
                        ),
                      ),
                      if (field.errorText != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          field.errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Simpan'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

