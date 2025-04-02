import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/todo_view_model.dart';
import '../widgets/todo_item_widget.dart';
import '../widgets/custom_input_field.dart';
import '../models/todo_item.dart';
import '../services/firebase_service.dart';

class TodoListView extends StatefulWidget {
  const TodoListView({Key? key}) : super(key: key);

  @override
  State<TodoListView> createState() => _TodoListViewState();
}

class _TodoListViewState extends State<TodoListView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _showAddTodo = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showShareDialog(TodoItem todo) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Todo'),
        content: CustomInputField(
          label: 'Email',
          hint: 'Enter email address',
          controller: emailController,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter an email address';
            }
            return null;
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (emailController.text.isNotEmpty) {
                context.read<TodoViewModel>().shareTodo(
                      todo.id,
                      emailController.text,
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    final firebaseService =
        Provider.of<FirebaseService>(context, listen: false);
    await firebaseService.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  Future<void> _handleDelete(TodoItem todo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Todo'),
        content: const Text('Are you sure you want to delete this todo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await context.read<TodoViewModel>().deleteTodo(todo.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Todo deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete todo: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);
    final userEmail = firebaseService.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Todo App'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                userEmail,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          IconButton(
            icon: Icon(_showAddTodo ? Icons.close : Icons.add),
            onPressed: () => setState(() => _showAddTodo = !_showAddTodo),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Consumer<TodoViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Combine owned and shared todos
          final allTodos = [
            ...viewModel.todos.map((todo) => todo.copyWith(isOwned: true)),
            ...viewModel.sharedTodos
                .map((todo) => todo.copyWith(isOwned: false)),
          ];

          return Column(
            children: [
              if (_showAddTodo)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        CustomInputField(
                          label: 'Title',
                          hint: 'Enter todo title',
                          controller: _titleController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a title';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomInputField(
                          label: 'Description',
                          hint: 'Enter todo description',
                          controller: _descriptionController,
                          isMultiline: true,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              try {
                                await viewModel.addTodo(
                                  _titleController.text,
                                  _descriptionController.text,
                                );
                                _titleController.clear();
                                _descriptionController.clear();
                                setState(() => _showAddTodo = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Todo added successfully'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Failed to add todo: ${e.toString()}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          child: const Text('Add Todo'),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: _buildTodoList(allTodos),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTodoList(List<TodoItem> todos) {
    if (todos.isEmpty) {
      return const Center(
        child: Text('No todos yet. Add one to get started!'),
      );
    }

    return ListView.builder(
      itemCount: todos.length,
      itemBuilder: (context, index) {
        final todo = todos[index];
        return TodoItemWidget(
          todo: todo,
          onDelete: todo.isOwned ? () => _handleDelete(todo) : null,
          onToggleComplete: (value) => context.read<TodoViewModel>().updateTodo(
                todo.copyWith(isCompleted: value),
              ),
          onShare: todo.isOwned ? () => _showShareDialog(todo) : null,
        );
      },
    );
  }
}
