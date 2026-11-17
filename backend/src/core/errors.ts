// Erros da API no formato do protocolo (docs/03-protocolo.md, secao 1.1).

export type ErrorCode =
  | 'validation_error'
  | 'weak_password'
  | 'invalid_credentials'
  | 'unauthorized'
  | 'session_expired'
  | 'device_revoked'
  | 'elevation_required'
  | 'forbidden'
  | 'not_found'
  | 'email_in_use'
  | 'version_conflict'
  | 'conflict'
  | 'code_expired'
  | 'payload_too_large'
  | 'account_locked'
  | 'rate_limited'
  | 'internal';

const STATUS: Record<ErrorCode, number> = {
  validation_error: 400,
  weak_password: 400,
  invalid_credentials: 401,
  unauthorized: 401,
  session_expired: 401,
  device_revoked: 401,
  elevation_required: 403,
  forbidden: 403,
  not_found: 404,
  email_in_use: 409,
  version_conflict: 409,
  conflict: 409,
  code_expired: 410,
  payload_too_large: 413,
  account_locked: 423,
  rate_limited: 429,
  internal: 500,
};

export interface FieldIssue {
  field: string;
  message: string;
}

export type ErrorDetails = Record<string, unknown>;

export class ApiError extends Error {
  readonly code: ErrorCode;
  readonly status: number;
  readonly details: ErrorDetails;

  constructor(code: ErrorCode, message: string, details: ErrorDetails = {}) {
    super(message);
    this.name = 'ApiError';
    this.code = code;
    this.status = STATUS[code];
    this.details = details;
  }

  toBody(): { error: { code: ErrorCode; message: string; details: ErrorDetails } } {
    return { error: { code: this.code, message: this.message, details: this.details } };
  }
}

export function validationError(issues: FieldIssue[], message = 'Dados inválidos.'): ApiError {
  return new ApiError('validation_error', message, {
    fields: issues.map((issue) => issue.field),
    issues,
  });
}

export function fieldError(field: string, message: string): ApiError {
  return validationError([{ field, message }], message);
}

export const errors = {
  unauthorized: (message = 'Autenticação necessária.') => new ApiError('unauthorized', message),
  sessionExpired: () => new ApiError('session_expired', 'Sua sessão expirou. Entre novamente.'),
  deviceRevoked: () => new ApiError('device_revoked', 'O vínculo deste aparelho foi removido.'),
  elevationRequired: () =>
    new ApiError('elevation_required', 'Confirme a senha administrativa para continuar.'),
  forbidden: (message = 'Você não tem acesso a este recurso.') => new ApiError('forbidden', message),
  notFound: (message = 'Recurso não encontrado.') => new ApiError('not_found', message),
  conflict: (message: string, details: ErrorDetails = {}) => new ApiError('conflict', message, details),
  invalidCredentials: (message = 'Credenciais inválidas.', details: ErrorDetails = {}) =>
    new ApiError('invalid_credentials', message, details),
  accountLocked: (retryAfterSec: number) =>
    new ApiError('account_locked', 'Muitas tentativas. Aguarde antes de tentar de novo.', {
      retryAfterSec,
    }),
  rateLimited: (retryAfterSec: number) =>
    new ApiError('rate_limited', 'Muitas requisições. Tente novamente em instantes.', {
      retryAfterSec,
    }),
  payloadTooLarge: (message = 'O lote enviado excede o limite permitido.') =>
    new ApiError('payload_too_large', message),
  codeExpired: () =>
    new ApiError('code_expired', 'Este código de vinculação venceu ou já foi usado.'),
  internal: () => new ApiError('internal', 'Erro interno. Tente novamente.'),
};
