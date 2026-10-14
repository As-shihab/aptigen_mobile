import 'package:flutter/material.dart';
import '../../core/network/http_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/skeleton.dart';
import '../auth/data/auth_service.dart';
import '../market/data/market_service.dart';
import '../market/models/market_extras.dart';
import '../market/presentation/widgets/common.dart';
import 'address_form.dart';

/// Saved delivery addresses — port of me/profile/_components/AddressesTab.tsx.
class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  final _api = MarketService();
  List<BuyerAddress>? _items;
  bool _error = false;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final list = await _api.getAddresses();
      if (mounted) setState(() => _items = list);
    } on ApiException catch (e) {
      if (e.statusCode == 401) await Session.expire();
      if (mounted) setState(() => _error = true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _edit([BuyerAddress? address]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddressSheet(address: address, makeDefault: address?.isDefault ?? (_items?.isEmpty ?? true)),
    );
    if (saved == true && mounted) {
      showToast(context, address == null ? 'Address saved' : 'Address updated');
      _load();
    }
  }

  Future<void> _setDefault(BuyerAddress a) async {
    setState(() => _busyId = a.id);
    try {
      final list = await _api.setDefaultAddress(a.id);
      if (mounted) setState(() => _items = list.isEmpty ? _items : list);
      if (list.isEmpty) await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, "Couldn't update the address. Try again.");
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(BuyerAddress a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this address?'),
        content: Text(a.oneLine),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyId = a.id);
    try {
      await _api.deleteAddress(a.id);
      await _load();
      if (mounted) showToast(context, 'Address deleted');
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, "Couldn't delete the address. Try again.");
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget body;
    if (_items == null && _error) {
      body = ErrorState(onRetry: _load);
    } else if (_items == null) {
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(2, (_) => const Padding(padding: EdgeInsets.only(bottom: 12), child: Skeleton(height: 110))),
      );
    } else if (_items!.isEmpty) {
      body = EmptyState(
        icon: Icons.location_on_outlined,
        title: 'No saved addresses',
        message: 'Save an address to check out faster next time.',
        actionLabel: 'Add address',
        onAction: () => _edit(),
      );
    } else {
      body = RefreshIndicator(
        color: p.accent,
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          itemCount: _items!.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final a = _items![i];
            return _AddressCard(
              address: a,
              busy: _busyId == a.id,
              onEdit: () => _edit(a),
              onDelete: () => _delete(a),
              onSetDefault: a.isDefault ? null : () => _setDefault(a),
            );
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(backgroundColor: p.bg, title: const Text('Saved addresses')),
      body: body,
      floatingActionButton: (_items?.isNotEmpty ?? false)
          ? FloatingActionButton.extended(
              onPressed: () => _edit(),
              backgroundColor: p.accent,
              foregroundColor: Colors.white,
              elevation: 1,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add address'),
            )
          : null,
    );
  }
}

class _AddressCard extends StatelessWidget {
  final BuyerAddress address;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onSetDefault;
  const _AddressCard({
    required this.address,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final a = address;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: a.isDefault ? p.accent : p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 18, color: p.accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  (a.label?.trim().isNotEmpty ?? false) ? a.label! : a.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: p.text),
                ),
              ),
              if (a.isDefault) ...[
                const SizedBox(width: 8),
                Pill('Default', bg: p.accentSoft, fg: p.accent),
              ],
              const Spacer(),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 26, right: 8, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${a.fullName} · ${a.phone}', style: TextStyle(fontSize: 13, color: p.text)),
                const SizedBox(height: 2),
                Text(a.oneLine, style: TextStyle(fontSize: 13, height: 1.4, color: p.textSecondary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Wrap(
              children: [
                TextButton(onPressed: busy ? null : onEdit, child: const Text('Edit')),
                if (onSetDefault != null)
                  TextButton(onPressed: busy ? null : onSetDefault, child: const Text('Set as default')),
                TextButton(
                  onPressed: busy ? null : onDelete,
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Add / edit form in a bottom sheet. Pops `true` once saved.
class AddressSheet extends StatefulWidget {
  final BuyerAddress? address;
  final bool makeDefault;
  const AddressSheet({super.key, this.address, this.makeDefault = false});

  @override
  State<AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<AddressSheet> {
  late final _draft = AddressDraft(widget.address);
  late bool _default = widget.makeDefault;
  Map<String, String> _errors = const {};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final errs = _draft.validate();
    setState(() {
      _errors = errs;
      _error = errs.isEmpty ? null : 'Please fix the highlighted fields.';
    });
    if (errs.isNotEmpty) return;
    setState(() => _saving = true);
    try {
      final api = MarketService();
      final input = _draft.toInput(isDefault: _default);
      if (widget.address == null) {
        await api.createAddress(input);
      } else {
        await api.updateAddress(widget.address!.id, input);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't save the address. Try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.address == null ? 'Add address' : 'Edit address',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.text)),
            const SizedBox(height: 16),
            AddressFields(
              draft: _draft,
              errors: _errors,
              onEdited: (k) {
                if (_errors.containsKey(k)) setState(() => _errors = Map.of(_errors)..remove(k));
              },
            ),
            if (!(widget.address?.isDefault ?? false))
              SwitchListTile.adaptive(
                value: _default,
                onChanged: (v) => setState(() => _default = v),
                contentPadding: EdgeInsets.zero,
                activeTrackColor: p.accent,
                title: Text('Use as my default address', style: TextStyle(fontSize: 14, color: p.text)),
              ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.danger)),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(widget.address == null ? 'Save address' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
