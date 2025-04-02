import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/todo_item.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  // Authentication methods
  Future<UserCredential> signUp(String email, String password) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create a user document in Firestore
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return credential;
    } catch (e) {
      throw Exception('Failed to sign up: ${e.toString()}');
    }
  }

  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Stream of todos for the current user (both owned and shared)
  Stream<List<TodoItem>> getTodosStream() {
    final userId = currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('todos')
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TodoItem.fromFirestore(doc)).toList();
    });
  }

  // Stream of shared todos
  Stream<List<TodoItem>> getSharedTodosStream() {
    final userId = currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('todos')
        .where('sharedWith', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TodoItem.fromFirestore(doc)).toList();
    });
  }

  // Add new todo
  Future<void> addTodo(TodoItem todo) async {
    if (currentUser == null) throw Exception('User not authenticated');

    final todoData = todo.toMap();
    todoData['ownerId'] = currentUser!.uid;
    todoData['ownerEmail'] = currentUser!.email;
    todoData['createdAt'] = FieldValue.serverTimestamp();
    todoData['sharedWith'] = [];
    todoData['lastModifiedBy'] = {
      'userId': currentUser!.uid,
      'email': currentUser!.email,
      'timestamp': FieldValue.serverTimestamp(),
      'action': 'created',
    };

    await _firestore.collection('todos').add(todoData);
  }

  // Update todo
  Future<void> updateTodo(TodoItem todo) async {
    if (currentUser == null) throw Exception('User not authenticated');

    final todoRef = _firestore.collection('todos').doc(todo.id);
    final todoDoc = await todoRef.get();

    if (!todoDoc.exists) throw Exception('Todo not found');

    // Check if user has permission to update
    final data = todoDoc.data() as Map<String, dynamic>;
    final isOwner = data['ownerId'] == currentUser!.uid;
    final isShared = (data['sharedWith'] as List).contains(currentUser!.uid);

    if (!isOwner && !isShared) {
      throw Exception('You do not have permission to update this todo');
    }

    // Update with last modified information
    final updateData = todo.toMap();
    updateData['lastModifiedBy'] = {
      'userId': currentUser!.uid,
      'email': currentUser!.email,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await todoRef.update(updateData);
  }

  // Delete todo
  Future<void> deleteTodo(String todoId) async {
    if (currentUser == null) throw Exception('User not authenticated');

    final todoRef = _firestore.collection('todos').doc(todoId);
    final todoDoc = await todoRef.get();

    if (!todoDoc.exists) throw Exception('Todo not found');

    // Only owner can delete
    final data = todoDoc.data() as Map<String, dynamic>;
    if (data['ownerId'] != currentUser!.uid) {
      throw Exception('Only the owner can delete this todo');
    }

    await todoRef.delete();
  }

  // Share todo with user
  Future<void> shareTodo(String todoId, String userEmail) async {
    if (currentUser == null) throw Exception('User not authenticated');

    // Find user by email
    final userQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: userEmail)
        .get();

    if (userQuery.docs.isEmpty) {
      throw Exception('User not found');
    }

    final targetUserId = userQuery.docs.first.id;
    final todoRef = _firestore.collection('todos').doc(todoId);
    final todoDoc = await todoRef.get();

    if (!todoDoc.exists) {
      throw Exception('Todo not found');
    }

    final data = todoDoc.data() as Map<String, dynamic>;

    // Check if user is already shared
    final sharedWith = List<String>.from(data['sharedWith'] ?? []);
    if (sharedWith.contains(targetUserId)) {
      throw Exception('Todo is already shared with this user');
    }

    // Only owner can share
    if (data['ownerId'] != currentUser!.uid) {
      throw Exception('Only the owner can share this todo');
    }

    sharedWith.add(targetUserId);
    await todoRef.update({
      'sharedWith': sharedWith,
      'lastModifiedBy': {
        'userId': currentUser!.uid,
        'email': currentUser!.email,
        'timestamp': FieldValue.serverTimestamp(),
        'action': 'shared',
      },
    });
  }

  // Remove share from todo
  Future<void> removeShare(String todoId, String userId) async {
    if (currentUser == null) throw Exception('User not authenticated');

    final todoRef = _firestore.collection('todos').doc(todoId);
    final todoDoc = await todoRef.get();

    if (!todoDoc.exists) {
      throw Exception('Todo not found');
    }

    final data = todoDoc.data() as Map<String, dynamic>;

    // Only owner can remove share
    if (data['ownerId'] != currentUser!.uid) {
      throw Exception('Only the owner can remove shares');
    }

    final sharedWith = List<String>.from(data['sharedWith'] ?? []);
    sharedWith.remove(userId);

    await todoRef.update({
      'sharedWith': sharedWith,
      'lastModifiedBy': {
        'userId': currentUser!.uid,
        'email': currentUser!.email,
        'timestamp': FieldValue.serverTimestamp(),
        'action': 'unshared',
      },
    });
  }
}
