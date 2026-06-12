import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/room_model.dart';
import '../models/savings_transaction_model.dart';
import '../repositories/joint_pot_repository.dart';

class JointPotProvider with ChangeNotifier {
  final JointPotRepository _repository;
  final String roomId;

  RoomModel? _room;
  List<SavingsTransactionModel> _transactions = [];
  bool _isLoading = true;
  String? _error;

  StreamSubscription? _roomSubscription;
  StreamSubscription? _transactionsSubscription;

  JointPotProvider({
    required JointPotRepository repository,
    required this.roomId,
  }) : _repository = repository {
    _init();
  }

  RoomModel? get room => _room;
  List<SavingsTransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get currentBalance => _room?.jointPotBalance ?? 0.0;

  void _init() {
    _roomSubscription = _repository.watchRoom(roomId).listen(
      (room) {
        _room = room;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );

    _transactionsSubscription = _repository.watchSavingsTransactions(roomId).listen(
      (transactions) {
        _transactions = transactions;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  Future<void> addTransaction(SavingsTransactionModel transaction) async {
    await _repository.performTransaction(
      roomId: roomId,
      transaction: transaction,
    );
  }

  Future<void> updateTransaction(String transactionId, Map<String, dynamic> newData) async {
    await _repository.updateTransaction(
      roomId: roomId,
      transactionId: transactionId,
      newData: newData,
    );
  }

  Future<void> deleteTransaction(String transactionId) async {
    await _repository.deleteTransaction(
      roomId: roomId,
      transactionId: transactionId,
    );
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _transactionsSubscription?.cancel();
    super.dispose();
  }
}
