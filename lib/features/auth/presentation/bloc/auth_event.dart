abstract class AuthEvent {}

class SignupRequested extends AuthEvent {
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String mobile;
  final String password;
  final String confirmPassword;

  SignupRequested({
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.mobile,
    required this.password,
    required this.confirmPassword,
  });
}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  LoginRequested({
    required this.email,
    required this.password,
  });
}