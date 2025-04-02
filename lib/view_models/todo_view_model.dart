import 'package:flutter/foundation.dart';
import '../models/todo_item.dart';
import '../services/firebase_service.dart';

class TodoViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService;
  List<TodoItem> _todos = [];
  List<TodoItem> _sharedTodos = [];
  bool _isLoading = false;
  String _error = '';

  List<TodoItem> get todos => _todos;
  List<TodoItem> get sharedTodos => _sharedTodos;
  bool get isLoading => _isLoading;
  String get error => _error;

  TodoViewModel({required FirebaseService firebaseService})
      : _firebaseService = firebaseService {
    _loadTodos();
  }

  void _loadTodos() {
    _firebaseService.getTodosStream().listen(
      (todos) {
        _todos = todos;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );

    _firebaseService.getSharedTodosStream().listen(
      (todos) {
        _sharedTodos = todos;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  Future<void> addTodo(String title, String description) async {
    try {
      _isLoading = true;
      notifyListeners();

      final todo = TodoItem(
        id: '', // Will be set by Firestore
        title: title,
        description: description,
        isCompleted: false,
        createdAt: DateTime.now(),
        ownerId: _firebaseService.currentUser?.uid ?? '',
        ownerEmail: _firebaseService.currentUser?.email ?? '',
        sharedWith: [],
        lastModifiedBy: {},
      );

      await _firebaseService.addTodo(todo);
      _error = '';
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateTodo(TodoItem todo) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firebaseService.updateTodo(todo);
      _error = '';
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteTodo(String todoId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firebaseService.deleteTodo(todoId);
      _error = '';
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> shareTodo(String todoId, String userEmail) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firebaseService.shareTodo(todoId, userEmail);
      _error = '';
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeShare(String todoId, String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firebaseService.removeShare(todoId, userId);
      _error = '';
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }

  String? getLastModifiedInfo(TodoItem todo) {
    if (todo.lastModifiedBy.isEmpty) return null;

    final email = todo.lastModifiedBy['email'];
    final timestamp = todo.lastModifiedBy['timestamp'];
    final action = todo.lastModifiedBy['action'];

    if (email == null || timestamp == null) return null;

    final date = (timestamp as DateTime).toLocal();
    final timeStr = '${date.hour}:${date.minute}';

    if (action != null) {
      return '$email $action at $timeStr';
    }
    return '$email modified at $timeStr';
  }
}
