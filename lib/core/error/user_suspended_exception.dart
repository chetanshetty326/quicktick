class UserSuspendedException implements Exception {
  final String message;
  const UserSuspendedException([this.message = 'Account suspended. Contact support.']);

  @override
  String toString() => message;
}
