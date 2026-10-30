import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FloosyApp());
}

const Color brandGreen = Color(0xFF1769D2);

class MoneyEntry {
  final String id;
  final String title;
  final String note;
  final String type; // income, expense, debt_in, debt_out, transfer
  final double amount;
  final DateTime date;
  final String category;
  final String account;

  MoneyEntry({
    required this.id,
    required this.title,
    required this.note,
    required this.type,
    required this.amount,
    required this.date,
    required this.category,
    required this.account,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'type': type,
        'amount': amount,
        'date': date.toIso8601String(),
        'category': category,
        'account': account,
      };

  factory MoneyEntry.fromJson(Map<String, dynamic> j) => MoneyEntry(
        id: j['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: j['title'] ?? '',
        note: j['note'] ?? '',
        type: j['type'] ?? 'expense',
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
        category: j['category'] ?? 'عام',
        account: j['account'] ?? 'الرئيسي',
      );
}

class FloosyApp extends StatefulWidget {
  const FloosyApp({super.key});
  @override
  State<FloosyApp> createState() => _FloosyAppState();
}

class _FloosyAppState extends State<FloosyApp> {
  bool dark = false;
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'فلوسي',
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: brandGreen),
          scaffoldBackgroundColor: const Color(0xFFF5F7F6),
          appBarTheme: const AppBarTheme(centerTitle: false),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.withOpacity(.12)),
            ),
          ),
          fontFamily: 'Roboto',
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: brandGreen,
            brightness: Brightness.dark,
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        home: FloosyHome(
          dark: dark,
          onThemeChanged: (v) => setState(() => dark = v),
        ),
      );
}

class FloosyHome extends StatefulWidget {
  final bool dark;
  final ValueChanged<bool> onThemeChanged;
  const FloosyHome({
    super.key,
    required this.dark,
    required this.onThemeChanged,
  });

  @override
  State<FloosyHome> createState() => _FloosyHomeState();
}

class _FloosyHomeState extends State<FloosyHome> {
  List<MoneyEntry> entries = [];
  int tab = 0;
  String currency = 'ريال';
  double budget = 0;
  double savingGoal = 0;
  double openingBalance = 0;
  bool hideAmounts = false;
  bool loaded = false;

  final currencies = ['ريال', 'ريال سعودي', 'دولار', 'درهم'];
  final accounts = ['الرئيسي', 'نقدًا', 'بنك', 'محفظة إلكترونية'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    try {
      final raw = p.getString('floosy_entries') ?? '[]';
      entries = (jsonDecode(raw) as List)
          .map((e) => MoneyEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      entries = [];
    }
    currency = p.getString('floosy_currency') ?? 'ريال';
    budget = p.getDouble('floosy_budget') ?? 0;
    savingGoal = p.getDouble('floosy_goal') ?? 0;
    openingBalance = p.getDouble('floosy_opening') ?? 0;
    if (mounted) setState(() => loaded = true);
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      'floosy_entries',
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
    await p.setString('floosy_currency', currency);
    await p.setDouble('floosy_budget', budget);
    await p.setDouble('floosy_goal', savingGoal);
    await p.setDouble('floosy_opening', openingBalance);
  }

  double get income => entries
      .where((e) => e.type == 'income')
      .fold(0, (s, e) => s + e.amount);
  double get expense => entries
      .where((e) => e.type == 'expense')
      .fold(0, (s, e) => s + e.amount);
  double get balance => openingBalance + income - expense;
  double get debtOwedToMe => entries
      .where((e) => e.type == 'debt_in')
      .fold(0, (s, e) => s + e.amount);
  double get debtIOwe => entries
      .where((e) => e.type == 'debt_out')
      .fold(0, (s, e) => s + e.amount);
  double get monthIncome {
    final n = DateTime.now();
    return entries
        .where((e) =>
            e.type == 'income' && e.date.year == n.year && e.date.month == n.month)
        .fold(0, (s, e) => s + e.amount);
  }
  double get monthExpense {
    final n = DateTime.now();
    return entries
        .where((e) =>
            e.type == 'expense' && e.date.year == n.year && e.date.month == n.month)
        .fold(0, (s, e) => s + e.amount);
  }

  String money(double n) => hideAmounts
      ? '••••••'
      : '${n.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '')} $currency';

  Future<void> _addEntry(String type) async {
    final result = await showDialog<MoneyEntry>(
      context: context,
      builder: (_) => EntryDialog(type: type, accounts: accounts),
    );
    if (result != null) {
      setState(() => entries.insert(0, result));
      await _save();
    }
  }

  Future<void> _editEntry(MoneyEntry old) async {
    final result = await showDialog<MoneyEntry>(
      context: context,
      builder: (_) => EntryDialog(type: old.type, accounts: accounts, existing: old),
    );
    if (result != null) {
      setState(() {
        final i = entries.indexWhere((e) => e.id == old.id);
        if (i >= 0) entries[i] = result;
      });
      await _save();
    }
  }

  Future<void> _deleteEntry(MoneyEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العملية؟'),
        content: Text('سيتم حذف «${e.title}» نهائيًا من سجل التطبيق.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => entries.removeWhere((x) => x.id == e.id));
      await _save();
    }
  }

  Future<void> _setNumber(String title, double current, ValueChanged<double> save) async {
    final c = TextEditingController(text: current == 0 ? '' : current.toString());
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(c.text.trim());
              if (v == null || v < 0) return;
              Navigator.pop(ctx, v);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (value != null) {
      setState(() => save(value));
      await _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pages = [
      _dashboard(),
      _transactionsPage(),
      _planningPage(),
      _settingsPage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: brandGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('فلوسي', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('إدارة أموالك ببساطة', style: TextStyle(fontSize: 11)),
          ]),
        ]),
        actions: [
          IconButton(
            tooltip: hideAmounts ? 'إظهار المبالغ' : 'إخفاء المبالغ',
            onPressed: () => setState(() => hideAmounts = !hideAmounts),
            icon: Icon(hideAmounts ? Icons.visibility_off : Icons.visibility),
          ),
        ],
      ),
      body: SafeArea(child: pages[tab]),
      floatingActionButton: tab < 2
          ? FloatingActionButton.extended(
              onPressed: () => _showAddMenu(),
              icon: const Icon(Icons.add),
              label: const Text('إضافة عملية'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'السجل'),
          NavigationDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings), label: 'الميزانية'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }

  Future<void> _showAddMenu() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          _menuItem(ctx, 'income', Icons.south_west, 'إضافة دخل', Colors.green),
          _menuItem(ctx, 'expense', Icons.north_east, 'إضافة مصروف', Colors.red),
          _menuItem(ctx, 'debt_in', Icons.handshake_outlined, 'مبلغ لي عند شخص', Colors.blue),
          _menuItem(ctx, 'debt_out', Icons.request_quote_outlined, 'مبلغ عليّ لشخص', Colors.orange),
        ]),
      ),
    );
    if (type != null) await _addEntry(type);
  }

  Widget _menuItem(BuildContext ctx, String type, IconData icon, String label, Color color) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color.withOpacity(.12), child: Icon(icon, color: color)),
      title: Text(label),
      onTap: () => Navigator.pop(ctx, type),
    );
  }

  Widget _dashboard() {
    final recent = entries.take(5).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF103B78), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('رصيدك الحالي', style: TextStyle(color: Colors.white70, fontSize: 14))),
              const Icon(Icons.trending_up, color: Colors.white70),
            ]),
            const SizedBox(height: 12),
            Text(money(balance), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: _heroSmall('الدخل الكلي', money(income), Icons.arrow_downward)),
              const SizedBox(width: 12),
              Expanded(child: _heroSmall('المصروفات', money(expense), Icons.arrow_upward)),
            ]),
          ]),
        ),
        const SizedBox(height: 18),
        const Text('نظرة عامة', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.65,
          children: [
            _statCard('دخل هذا الشهر', money(monthIncome), Icons.south_west, Colors.green),
            _statCard('صرف هذا الشهر', money(monthExpense), Icons.north_east, Colors.red),
            _statCard('لي عند الآخرين', money(debtOwedToMe), Icons.call_received, Colors.blue),
            _statCard('عليّ للآخرين', money(debtIOwe), Icons.call_made, Colors.orange),
          ],
        ),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('آخر العمليات', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          TextButton(onPressed: () => setState(() => tab = 1), child: const Text('عرض الكل')),
        ]),
        if (recent.isEmpty)
          _emptyState('لا توجد عمليات حتى الآن', 'ابدأ بإضافة دخلك أو مصروفاتك.')
        else
          ...recent.map(_entryTile),
        const SizedBox(height: 12),
        _progressPanel(),
      ],
    );
  }

  Widget _heroSmall(String label, String value, IconData icon) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
      );

  Widget _statCard(String label, String value, IconData icon, Color color) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ]),
        ),
      );

  Widget _progressPanel() {
    final spent = budget > 0 ? (monthExpense / budget).clamp(0.0, 1.0) : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ميزانية الشهر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(budget > 0 ? 'استخدمت ${ (spent * 100).round() }٪ من ميزانيتك' : 'حدد ميزانيتك الشهرية لمتابعة الصرف.'),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: spent, minHeight: 8, borderRadius: BorderRadius.circular(8)),
          const SizedBox(height: 8),
          Text('الميزانية: ${money(budget)}  •  المصروف: ${money(monthExpense)}'),
        ]),
      ),
    );
  }

  Widget _transactionsPage() {
    final sorted = [...entries]..sort((a, b) => b.date.compareTo(a.date));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('سجل العمليات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('${entries.length} عملية مسجلة'),
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          _emptyState('السجل فارغ', 'ستظهر هنا كل عمليات الدخل والمصروفات والديون.')
        else
          ...sorted.map(_entryTile),
      ],
    );
  }

  Widget _entryTile(MoneyEntry e) {
    final isPositive = e.type == 'income' || e.type == 'debt_in';
    final color = isPositive ? Colors.green : (e.type == 'expense' ? Colors.red : Colors.orange);
    final sign = e.type == 'income' ? '+' : (e.type == 'expense' ? '−' : '');
    final typeName = {
      'income': 'دخل',
      'expense': 'مصروف',
      'debt_in': 'دين لي',
      'debt_out': 'دين عليّ',
      'transfer': 'تحويل',
    }[e.type] ?? 'عملية';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(.12),
          child: Icon(
            e.type == 'income' ? Icons.south_west : e.type == 'expense' ? Icons.north_east : Icons.handshake_outlined,
            color: color,
          ),
        ),
        title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$typeName • ${e.category} • ${e.date.day}/${e.date.month}/${e.date.year}'),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _editEntry(e);
            if (v == 'delete') _deleteEntry(e);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('تعديل')),
            PopupMenuItem(value: 'delete', child: Text('حذف')),
          ],
          child: SizedBox(
            width: 100,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              FittedBox(child: Text('$sign${money(e.amount)}', style: TextStyle(fontWeight: FontWeight.bold, color: color))),
              const Text('خيارات', style: TextStyle(fontSize: 10)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _planningPage() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('الميزانية والتوفير', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.account_balance_wallet_outlined)),
              title: const Text('رصيد بداية الاستخدام'),
              subtitle: Text(money(openingBalance)),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _setNumber('رصيد بداية الاستخدام', openingBalance, (v) => openingBalance = v),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.pie_chart_outline)),
              title: const Text('الميزانية الشهرية'),
              subtitle: Text(budget == 0 ? 'لم تحدد بعد' : money(budget)),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _setNumber('الميزانية الشهرية', budget, (v) => budget = v),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.savings_outlined)),
              title: const Text('هدف التوفير'),
              subtitle: Text(savingGoal == 0 ? 'لم تحدد هدفًا بعد' : money(savingGoal)),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _setNumber('هدف التوفير', savingGoal, (v) => savingGoal = v),
            ),
          ),
          if (savingGoal > 0) ...[
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('تقدم هدف التوفير', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: (balance / savingGoal).clamp(0.0, 1.0), minHeight: 9),
                  const SizedBox(height: 8),
                  Text('${((balance / savingGoal).clamp(0.0, 1.0) * 100).round()}٪ من الهدف'),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ملخص الديون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 12),
                _summaryRow('ديون لك عند الآخرين', money(debtOwedToMe), Colors.blue),
                _summaryRow('ديون عليك للآخرين', money(debtIOwe), Colors.orange),
              ]),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('ملاحظة: سجلات الديون هنا للتذكير والمتابعة، ولا تدخل في رصيدك النقدي تلقائيًا.', style: TextStyle(fontSize: 12)),
          ),
        ],
      );

  Widget _summaryRow(String label, String value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );

  Widget _settingsPage() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('الإعدادات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('الوضع الليلي'),
              value: widget.dark,
              onChanged: widget.onThemeChanged,
            ),
          ),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.visibility_off_outlined),
              title: const Text('إخفاء المبالغ'),
              subtitle: const Text('إخفاء الأرقام من الشاشة عند الحاجة'),
              value: hideAmounts,
              onChanged: (v) => setState(() => hideAmounts = v),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.currency_exchange),
              title: const Text('العملة'),
              subtitle: Text(currency),
              trailing: const Icon(Icons.chevron_left),
              onTap: () async {
                final c = await showModalBottomSheet<String>(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: Column(mainAxisSize: MainAxisSize.min, children: currencies.map((x) =>
                      ListTile(title: Text(x), trailing: x == currency ? const Icon(Icons.check, color: brandGreen) : null,
                        onTap: () => Navigator.pop(ctx, x))).toList(),
                    ),
                  ),
                );
                if (c != null) {
                  setState(() => currency = c);
                  await _save();
                }
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('حول التطبيق'),
              subtitle: const Text('الإصدار، الخصوصية، وحقوق التطبيق'),
              trailing: const Icon(Icons.chevron_left),
              onTap: _aboutPage,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.support_agent, color: brandGreen),
              title: const Text('الشكاوى والاستفسارات'),
              subtitle: const Text('+967 717176123'),
              trailing: const Icon(Icons.open_in_new),
              onTap: _contactOptions,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.ios_share_outlined),
              title: const Text('تصدير ملخص مالي'),
              subtitle: const Text('فتح الملخص لمشاركته أو نسخه'),
              trailing: const Icon(Icons.chevron_left),
              onTap: _showReport,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
              title: const Text('مسح جميع البيانات'),
              subtitle: const Text('حذف كل العمليات والإعدادات المالية المحفوظة'),
              onTap: _clearAll,
            ),
          ),
          const SizedBox(height: 18),
          const Center(child: Text('فلوسي • أموالك تحت سيطرتك', style: TextStyle(fontSize: 12))),
        ],
      );

  Future<void> _aboutPage() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: const [
          Icon(Icons.account_balance_wallet_rounded, color: brandGreen),
          SizedBox(width: 8),
          Text('حول تطبيق فلوسي'),
        ]),
        content: const SingleChildScrollView(
          child: Text(
            'فلوسي تطبيق شخصي لتنظيم الأموال ومتابعة الدخل والمصروفات والميزانية والديون وأهداف التوفير.\n\n'
            'الإصدار: 1.0.0\n'
            'المطوّر: خالد الشامي\n'
            'رقم التواصل: +967 717176123\n\n'
            'الخصوصية: تُحفظ البيانات المالية على هذا الجهاز باستخدام التخزين المحلي. لا تضع بيانات حساسة على جهاز مشترك، واستخدم النسخ الاحتياطي من إعدادات الجهاز إن توفر. حذف التطبيق أو بياناته قد يؤدي إلى فقدان السجلات.\n\n'
            'شروط الاستخدام: النتائج تعتمد على البيانات التي تدخلها، ويجب مراجعة العمليات للتأكد من صحتها. التطبيق أداة تنظيم شخصية وليس خدمة مصرفية أو استشارة مالية.\n\n'
            'حقوق الملكية: جميع الحقوق محفوظة لتطبيق فلوسي.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _contactOptions();
            },
            icon: const Icon(Icons.chat),
            label: const Text('تواصل مع المطوّر'),
          ),
        ],
      ),
    );
  }

  Future<void> _contactOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const ListTile(
              leading: CircleAvatar(child: Icon(Icons.support_agent)),
              title: Text('التواصل مع مطوّر فلوسي', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('للشكاوى والأخطاء والاستفسارات والاقتراحات'),
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.green),
              title: const Text('فتح واتساب'),
              subtitle: const Text('+967 717176123'),
              onTap: () {
                Navigator.pop(ctx);
                _openWhatsApp();
              },
            ),
            ListTile(
              leading: const Icon(Icons.call, color: brandGreen),
              title: const Text('اتصال هاتفي'),
              subtitle: const Text('+967 717176123'),
              onTap: () {
                Navigator.pop(ctx);
                _openPhone();
              },
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/967717176123?text=${Uri.encodeComponent('السلام عليكم، لدي استفسار بخصوص تطبيق فلوسي.') }');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب. تأكد من وجود اتصال بالإنترنت.')));
    }
  }

  Future<void> _openPhone() async {
    final uri = Uri.parse('tel:+967717176123');
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح تطبيق الاتصال.')));
    }
  }

  Future<void> _showReport() async {
    final report = 'ملخص مالي — فلوسي\n'
        'تاريخ التقرير: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}\n'
        'العملة: $currency\n'
        'رصيد بداية الاستخدام: ${money(openingBalance)}\n'
        'إجمالي الدخل: ${money(income)}\n'
        'إجمالي المصروفات: ${money(expense)}\n'
        'الرصيد الحالي: ${money(balance)}\n'
        'دخل الشهر: ${money(monthIncome)}\n'
        'مصروف الشهر: ${money(monthExpense)}\n'
        'ديون لك: ${money(debtOwedToMe)}\n'
        'ديون عليك: ${money(debtIOwe)}\n\n'
        'عدد العمليات: ${entries.length}\n'
        'ملاحظة: هذا الملخص للمتابعة الشخصية.';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ملخصك المالي'),
        content: SingleChildScrollView(child: SelectableText(report)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مسح جميع البيانات؟'),
        content: const Text('هذا الإجراء لا يمكن التراجع عنه. تأكد أنك لا تحتاج إلى سجلاتك.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('مسح الكل'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        entries.clear();
        budget = 0;
        savingGoal = 0;
        openingBalance = 0;
        currency = 'ريال';
      });
      await _save();
    }
  }

  Widget _emptyState(String title, String sub) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
        ]),
      );
}

class EntryDialog extends StatefulWidget {
  final String type;
  final List<String> accounts;
  final MoneyEntry? existing;
  const EntryDialog({super.key, required this.type, required this.accounts, this.existing});

  @override
  State<EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<EntryDialog> {
  late final TextEditingController title;
  late final TextEditingController amount;
  late final TextEditingController note;
  late String category;
  late String account;
  String? error;

  final categories = ['عام', 'راتب', 'عمل', 'طعام', 'مواصلات', 'فواتير', 'تسوق', 'صحة', 'تعليم', 'ترفيه', 'سكن', 'أخرى'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    title = TextEditingController(text: e?.title ?? '');
    amount = TextEditingController(text: e == null ? '' : e.amount.toString());
    note = TextEditingController(text: e?.note ?? '');
    category = e?.category ?? (widget.type == 'income' ? 'عمل' : 'عام');
    account = e?.account ?? widget.accounts.first;
  }

  String get heading => {
        'income': 'إضافة دخل',
        'expense': 'إضافة مصروف',
        'debt_in': 'تسجيل مبلغ لي عند شخص',
        'debt_out': 'تسجيل مبلغ عليّ لشخص',
      }[widget.type] ?? 'إضافة عملية';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.existing == null ? heading : 'تعديل العملية'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: title,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'العنوان أو اسم الشخص', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: categories.contains(category) ? category : 'عام',
              decoration: const InputDecoration(labelText: 'التصنيف', border: OutlineInputBorder()),
              items: categories.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
              onChanged: (v) => setState(() => category = v ?? 'عام'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: account,
              decoration: const InputDecoration(labelText: 'الحساب', border: OutlineInputBorder()),
              items: widget.accounts.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
              onChanged: (v) => setState(() => account = v ?? widget.accounts.first),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', border: OutlineInputBorder()),
            ),
            if (error != null) Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: _submit, child: const Text('حفظ العملية')),
        ],
      );

  void _submit() {
    final t = title.text.trim();
    final a = double.tryParse(amount.text.trim().replaceAll(',', '.'));
    if (t.isEmpty) {
      setState(() => error = 'اكتب عنوان العملية أو اسم الشخص.');
      return;
    }
    if (a == null || !a.isFinite || a <= 0) {
      setState(() => error = 'أدخل مبلغًا صحيحًا أكبر من صفر.');
      return;
    }
    final old = widget.existing;
    Navigator.pop(
      context,
      MoneyEntry(
        id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: t,
        note: note.text.trim(),
        type: widget.type,
        amount: a,
        date: old?.date ?? DateTime.now(),
        category: category,
        account: account,
      ),
    );
  }

  @override
  void dispose() {
    title.dispose();
    amount.dispose();
    note.dispose();
    super.dispose();
  }
}