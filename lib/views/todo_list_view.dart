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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Todo App'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
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
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              viewModel.addTodo(
                                _titleController.text,
                                _descriptionController.text,
                              );
                              _titleController.clear();
                              _descriptionController.clear();
                              setState(() => _showAddTodo = false);
                            }
                          },
                          child: const Text('Add Todo'),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'My Todos'),
                          Tab(text: 'Shared With Me'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildTodoList(viewModel.todos),
                            _buildTodoList(viewModel.sharedTodos),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
          onDelete: () => context.read<TodoViewModel>().deleteTodo(todo.id),
          onToggleComplete: (value) => context.read<TodoViewModel>().updateTodo(
                todo.copyWith(isCompleted: value),
              ),
          onShare: () => _showShareDialog(todo),
        );
      },
    );
  }
}
