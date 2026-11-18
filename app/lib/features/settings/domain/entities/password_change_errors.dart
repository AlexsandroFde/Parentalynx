import 'package:equatable/equatable.dart';

/// Campos do formulario de troca de senha.
enum PasswordChangeField { current, next, confirmation }

/// Erros do formulario de troca de senha, por campo, com as mensagens prontas para a tela.
/// [form] e a mensagem geral, sem campo especifico.
final class PasswordChangeErrors extends Equatable {
  const PasswordChangeErrors({this.current, this.next, this.confirmation, this.form});

  static const PasswordChangeErrors none = PasswordChangeErrors();

  final String? current;
  final String? next;
  final String? confirmation;
  final String? form;

  bool get isEmpty => current == null && next == null && confirmation == null && form == null;

  /// Mensagem do campo informado.
  String? of(PasswordChangeField field) {
    return switch (field) {
      PasswordChangeField.current => current,
      PasswordChangeField.next => next,
      PasswordChangeField.confirmation => confirmation,
    };
  }

  /// Os mesmos erros sem o do campo informado (a pessoa voltou a digitar nele).
  PasswordChangeErrors without(PasswordChangeField field) {
    return PasswordChangeErrors(
      current: field == PasswordChangeField.current ? null : current,
      next: field == PasswordChangeField.next ? null : next,
      confirmation: field == PasswordChangeField.confirmation ? null : confirmation,
      form: form,
    );
  }

  @override
  List<Object?> get props => <Object?>[current, next, confirmation, form];
}
