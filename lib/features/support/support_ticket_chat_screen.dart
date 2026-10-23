import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_flushbar.dart';
import 'support_provider.dart';
import 'support_model.dart';

class SupportTicketChatScreen extends ConsumerStatefulWidget {
  final String ticketId;

  const SupportTicketChatScreen({super.key, required this.ticketId});

  @override
  ConsumerState<SupportTicketChatScreen> createState() => _SupportTicketChatScreenState();
}

class _SupportTicketChatScreenState extends ConsumerState<SupportTicketChatScreen> {
  final _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(supportProvider.notifier).fetchTicketDetails(widget.ticketId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final supportState = ref.watch(supportProvider);
    final detail = supportState.currentTicketDetail;
    final ticket = detail?.ticket ?? SupportTicket(id: widget.ticketId);
    final messages = detail?.messages ?? [];

    Color badgeColor = Colors.orange;
    final statusKey = ticket.statusBadge.status.toLowerCase();
    if (statusKey == 'resolved' || statusKey == 'success') {
      badgeColor = Colors.green;
    } else if (statusKey == 'in_progress' || statusKey == 'investigation') {
      badgeColor = Colors.blue;
    } else if (statusKey == 'closed') {
      badgeColor = Colors.grey;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(ticket.ticketNumber.isNotEmpty ? ticket.ticketNumber : 'Ticket #${widget.ticketId}'),
        backgroundColor: AppColors.secondary,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Ticket Header Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          ticket.subject,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          ticket.statusBadge.label.isNotEmpty ? ticket.statusBadge.label : ticket.status.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Category: ${ticket.categoryName.isNotEmpty ? ticket.categoryName : ticket.category}',
                    style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                  ),
                  if (detail?.assignedAgentName != null && detail!.assignedAgentName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.support_agent_rounded, size: 14, color: AppColors.secondary),
                        const SizedBox(width: 4),
                        Text(
                          'Assigned Agent: ${detail.assignedAgentName}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),

            // Messages List Thread
            Expanded(
              child: supportState.isActionLoading && messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () async {
                        await ref.read(supportProvider.notifier).fetchTicketDetails(widget.ticketId);
                      },
                      child: messages.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 100),
                                Center(child: Text('No messages in this thread yet.')),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final msg = messages[index];
                                final isDriver = msg.sender.toLowerCase() == 'driver';
                                final isSystem = msg.sender.toLowerCase() == 'system' || msg.sender.toLowerCase() == 'bot';

                                if (isSystem) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(vertical: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                                    child: Center(
                                      child: Text(
                                        msg.text,
                                        style: const TextStyle(fontSize: 11, color: Colors.black87),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  );
                                }

                                return Align(
                                  alignment: isDriver ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 6),
                                    padding: const EdgeInsets.all(12),
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                    decoration: BoxDecoration(
                                      color: isDriver ? AppColors.primary : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: isDriver ? null : Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          msg.senderName.isNotEmpty ? msg.senderName : (isDriver ? 'You' : 'Support Agent'),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isDriver ? Colors.white70 : AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(msg.text, style: TextStyle(fontSize: 13, color: isDriver ? Colors.white : AppColors.textPrimary)),
                                        const SizedBox(height: 4),
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: Text(
                                            msg.createdAt.isNotEmpty ? msg.createdAt.substring(11, 16) : '',
                                            style: TextStyle(fontSize: 9, color: isDriver ? Colors.white60 : Colors.grey),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),

            // Reply Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      decoration: InputDecoration(
                        hintText: 'Type your reply...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    icon: supportState.isActionLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 18),
                    onPressed: supportState.isActionLoading
                        ? null
                        : () async {
                            final text = _replyController.text.trim();
                            if (text.isEmpty) return;

                            _replyController.clear();
                            final success = await ref.read(supportProvider.notifier).replyTicket(ticketId: widget.ticketId, message: text);

                            if (!context.mounted) return;
                            if (success) {
                              AppFlushbar.success(context, title: 'Reply Sent', message: 'Your message was sent to support.');
                            } else {
                              AppFlushbar.error(context, title: 'Error', message: 'Failed to send reply.');
                            }
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
