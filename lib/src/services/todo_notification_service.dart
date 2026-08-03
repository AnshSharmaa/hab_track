import '../db/app_db.dart';
import 'app_notification_service.dart';

class TodoNotificationService {
  TodoNotificationService._();
  static final instance = TodoNotificationService._();

  Future<void> initialize() => AppNotificationService.instance.initialize();

  Future<void> scheduleTodo(Todo todo) =>
      AppNotificationService.instance.scheduleTodoNagChain(todo);

  Future<void> cancelTodo(Todo todo) =>
      AppNotificationService.instance.cancelTodoSchedules(todo.id);

  Future<void> cancelTodoById(String todoId) =>
      AppNotificationService.instance.cancelTodoSchedules(todoId);

  Future<void> cancelAllPendingTodos() =>
      AppNotificationService.instance.cancelAllPendingTodoNotifications();

  Future<void> resyncOpenTodos(List<Todo> todos) =>
      AppNotificationService.instance.resyncTodoSchedules(todos);
}
