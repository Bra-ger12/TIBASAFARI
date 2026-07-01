import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DataColumn2 {
  final String label;
  final String key;
  final double? width;
  final bool numeric;
  final bool hideOnSmall;
  const DataColumn2({
    required this.label,
    required this.key,
    this.width,
    this.numeric = false,
    this.hideOnSmall = false,
  });
}

class DataTable2<T> extends StatefulWidget {
  final List<DataColumn2> columns;
  final List<T> rows;
  final String Function(T row) rowKey;
  final List<dynamic> Function(T row) cellValues;
  final int? sortColumnIndex;
  final bool sortAscending;
  final void Function(int columnIndex, bool ascending)? onSort;
  final void Function(T row)? onRowTap;
  final List<Widget> Function(T row)? trailing;
  final String emptyMessage;
  final int pageSize;

  const DataTable2({
    super.key,
    required this.columns,
    required this.rows,
    required this.rowKey,
    required this.cellValues,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.onSort,
    this.onRowTap,
    this.trailing,
    this.emptyMessage = 'No records found.',
    this.pageSize = 8,
  });

  @override
  State<DataTable2<T>> createState() => _DataTable2State<T>();
}

class _DataTable2State<T> extends State<DataTable2<T>> {
  int _page = 0;
  final ScrollController _hScroll = ScrollController();

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 768;
    final visibleCols = widget.columns
        .where((c) => !c.hideOnSmall || !isSmall)
        .toList();

    final pageSize = widget.pageSize;
    final pageCount = (widget.rows.length / pageSize).ceil().clamp(1, 999999);
    final currentPage = _page.clamp(0, pageCount - 1);
    final start = currentPage * pageSize;
    final end = (start + pageSize).clamp(0, widget.rows.length);
    final pageRows = widget.rows.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: Scrollbar(
            controller: _hScroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _hScroll,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: visibleCols.fold(0.0, (sum, c) => sum + (c.width ?? 160.0)) +
                      (visibleCols.length - 1) * 16.0 +
                      24.0,
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      color: const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          for (int i = 0; i < visibleCols.length; i++) ...[
                            _buildHeaderCell(visibleCols[i], i),
                            if (i < visibleCols.length - 1)
                              const SizedBox(width: 16),
                          ],
                        ],
                      ),
                    ),
                    Divider(height: 1, color: AppTheme.border),
                    // Rows
                    if (pageRows.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 40, horizontal: 16),
                        alignment: Alignment.center,
                        child: Text(widget.emptyMessage,
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.textMuted)),
                      )
                    else
                      for (int r = 0; r < pageRows.length; r++)
                        _buildRow(pageRows[r], visibleCols, r),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Pagination
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.rows.isEmpty
                  ? 'Showing 0 of 0'
                  : 'Showing ${start + 1}-$end of ${widget.rows.length}',
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            Row(
              children: [
                Text('Page ${currentPage + 1} of $pageCount',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(width: 8),
                _pageBtn(Icons.first_page, currentPage == 0, () => _go(0)),
                _pageBtn(Icons.chevron_left, currentPage == 0,
                    () => _go(currentPage - 1)),
                _pageBtn(Icons.chevron_right, currentPage >= pageCount - 1,
                    () => _go(currentPage + 1)),
                _pageBtn(Icons.last_page, currentPage >= pageCount - 1,
                    () => _go(pageCount - 1)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderCell(DataColumn2 col, int index) {
    final isSortCol = widget.sortColumnIndex == index;
    final cellWidth = col.width ?? 160.0;
    return SizedBox(
      width: cellWidth,
      child: GestureDetector(
        onTap: widget.onSort == null
            ? null
            : () => widget.onSort!(index, !(isSortCol && widget.sortAscending)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                col.label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSortCol ? AppTheme.primary : AppTheme.textMuted,
                  letterSpacing: 0.4,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.onSort != null && isSortCol) ...[
              const SizedBox(width: 4),
              Icon(
                widget.sortAscending
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                size: 12,
                color: AppTheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(T row, List<DataColumn2> cols, int rowIndex) {
    final values = widget.cellValues(row);
    return InkWell(
      onTap: widget.onRowTap == null ? null : () => widget.onRowTap!(row),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: rowIndex.isOdd ? const Color(0xFFFCFCFD) : Colors.white,
          border: Border(
            bottom: BorderSide(
              color: rowIndex == widget.pageSize - 1
                  ? Colors.transparent
                  : AppTheme.border.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          children: [
            for (int i = 0; i < cols.length; i++) ...[
              SizedBox(
                width: cols[i].width ?? 160.0,
                child: ClipRect(child: _cellWidget(values[i], cols[i])),
              ),
              if (i < cols.length - 1) const SizedBox(width: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cellWidget(dynamic value, DataColumn2 col) {
    if (value is Widget) return value;
    return Text(
      value?.toString() ?? '—',
      style: TextStyle(
        fontSize: 13,
        fontWeight: col.numeric ? FontWeight.w600 : FontWeight.w400,
        color: AppTheme.textPrimary,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _pageBtn(IconData icon, bool disabled, VoidCallback onTap) {
    return IconButton(
      onPressed: disabled ? null : onTap,
      icon: Icon(icon, size: 18),
      iconSize: 18,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
      color: disabled ? AppTheme.border : AppTheme.textMuted,
    );
  }

  void _go(int p) {
    setState(() => _page = p < 0 ? 0 : p);
  }
}

class SearchField extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  const SearchField(
      {super.key, required this.hintText, required this.onChanged, this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textMuted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
        ),
      ),
    );
  }
}
