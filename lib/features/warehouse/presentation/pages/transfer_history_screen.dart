import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../presentation/bloc/warehouse_bloc.dart';
import '../../presentation/bloc/warehouse_event.dart';
import '../../presentation/bloc/warehouse_state.dart';

class TransferHistoryScreen extends StatelessWidget {
  const TransferHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => WarehouseBloc()..add(LoadTransfers()),
      child: Scaffold(
        appBar: AppBar(title: const Text('Transfer History')),
        body: BlocBuilder<WarehouseBloc, WarehouseState>(builder: (context, state) {
          if (state is WarehouseLoading) return const Center(child: CircularProgressIndicator());
          if (state is TransfersLoaded) {
            return ListView.builder(itemCount: state.transfers.length, itemBuilder: (ctx, i) {
              final t = state.transfers[i];
              return ListTile(
                title: Text('Item ${t['item_id']} — ${t['qty']}'),
                subtitle: Text('From: ${t['from'] ?? 'GLOBAL'} → To: ${t['to'] ?? 'GLOBAL'}'),
                trailing: Text(t['createdAt'] ?? ''),
              );
            });
          }
          if (state is WarehouseOperationFailure) return Center(child: Text('Error: ${state.message}'));
          return const Center(child: Text('No transfers'));
        }),
      ),
    );
  }
}
