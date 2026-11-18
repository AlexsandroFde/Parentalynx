import 'package:equatable/equatable.dart';

/// Campos dos formularios de conta.
enum CredentialField { name, email, password, confirmation, recoveryKey }

/// Erros de preenchimento de um formulario de conta, por campo, com as mensagens prontas
/// para a tela. [form] e a mensagem geral, sem campo especifico.
final class CredentialErrors extends Equatable {
  const CredentialErrors({
    this.name,
    this.email,
    this.password,
    this.confirmation,
    this.recoveryKey,
    this.form,
  });

  static const CredentialErrors none = CredentialErrors();

  final String? name;
  final String? email;
  final String? password;
  final String? confirmation;
  final String? recoveryKey;
  final String? form;

  bool get isEmpty =>
      name == null &&
      email == null &&
      password == null &&
      confirmation == null &&
      recoveryKey == null &&
      form == null;

  /// Mensagem do campo informado.
  String? of(CredentialField field) {
    return switch (field) {
      CredentialField.name => name,
      CredentialField.email => email,
      CredentialField.password => password,
      CredentialField.confirmation => confirmation,
      CredentialField.recoveryKey => recoveryKey,
    };
  }

  /// Os mesmos erros sem o do campo informado (a pessoa voltou a digitar nele).
  CredentialErrors without(CredentialField field) {
    return CredentialErrors(
      name: field == CredentialField.name ? null : name,
      email: field == CredentialField.email ? null : email,
      password: field == CredentialField.password ? null : password,
      confirmation: field == CredentialField.confirmation ? null : confirmation,
      recoveryKey: field == CredentialField.recoveryKey ? null : recoveryKey,
      form: form,
    );
  }

  @override
  List<Object?> get props => <Object?>[name, email, password, confirmation, recoveryKey, form];
}
