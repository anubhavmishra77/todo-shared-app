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

      // Add to local state immediately for better UX
      final newTodo = todo.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // Temporary ID
      );
      _todos.insert(0, newTodo); // Add to the beginning of the list
      notifyListeners();

      await _firebaseService.addTodo(todo);
      _error = '';
    } catch (e) {
      // If adding fails, remove from local state
      _todos.removeWhere(
          (t) => t.id == DateTime.now().millisecondsSinceEpoch.toString());
      _error = e.toString();
      rethrow; // Rethrow to let the UI handle the error
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

      // Remove the todo from local state immediately for better UX
      _todos.removeWhere((todo) => todo.id == todoId);
      _sharedTodos.removeWhere((todo) => todo.id == todoId);
      notifyListeners();

      await _firebaseService.deleteTodo(todoId);
      _error = '';
    } catch (e) {
      // If deletion fails, reload todos to ensure consistency
      _loadTodos();
      _error = e.toString();
      rethrow; // Rethrow to let the UI handle the error
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
