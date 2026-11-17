// Hub de WebSocket em memoria (protocolo, secao 7).
//
// O WebSocket e so um aviso para o cliente buscar o estado por HTTP. Por isso nao ha fila nem
// reenvio: perder uma mensagem nao causa inconsistencia.

import type { WebSocket } from 'ws';

/** Codigo de fechamento usado quando o token e invalido ou deixou de valer. */
export const CLOSE_UNAUTHORIZED = 4401;
/** Codigo de fechamento por inatividade. */
export const CLOSE_IDLE = 4408;

const IDLE_MS = 90_000;
const OPEN = 1;
const CLOSED = 3;
/** Tempo dado ao cliente para confirmar o fechamento antes de a conexao ser derrubada. */
const CLOSE_GRACE_MS = 1500;

export type ServerMessage = { type: string } & Record<string, unknown>;

/**
 * Fecha com o codigo informado e, se o cliente nao confirmar o fechamento a tempo, derruba a
 * conexao. Sem isso, um cliente que some no meio do fechamento seguraria o socket por 30 s.
 */
export function closeSocket(socket: WebSocket, code: number, reason: string): void {
  try {
    socket.close(code, reason);
  } catch {
    socket.terminate();
    return;
  }
  const timer = setTimeout(() => {
    if (socket.readyState !== CLOSED) socket.terminate();
  }, CLOSE_GRACE_MS);
  timer.unref();
  socket.once('close', () => clearTimeout(timer));
}

export interface GuardianConnection {
  kind: 'guardian';
  socket: WebSocket;
  guardianId: string;
  sessionId: string;
  lastSeen: number;
}

export interface DeviceConnection {
  kind: 'device';
  socket: WebSocket;
  deviceId: string;
  lastSeen: number;
}

export type Connection = GuardianConnection | DeviceConnection;

function send(socket: WebSocket, payload: string): void {
  if (socket.readyState !== OPEN) return;
  try {
    socket.send(payload);
  } catch {
    // Conexao caindo: o evento de fechamento remove o registro.
  }
}

export class RealtimeHub {
  private readonly guardians = new Map<string, Set<GuardianConnection>>();
  private readonly devices = new Map<string, Set<DeviceConnection>>();

  addGuardian(guardianId: string, sessionId: string, socket: WebSocket, now: number): GuardianConnection {
    const connection: GuardianConnection = { kind: 'guardian', socket, guardianId, sessionId, lastSeen: now };
    let set = this.guardians.get(guardianId);
    if (!set) {
      set = new Set();
      this.guardians.set(guardianId, set);
    }
    set.add(connection);
    return connection;
  }

  addDevice(deviceId: string, socket: WebSocket, now: number): DeviceConnection {
    const connection: DeviceConnection = { kind: 'device', socket, deviceId, lastSeen: now };
    let set = this.devices.get(deviceId);
    if (!set) {
      set = new Set();
      this.devices.set(deviceId, set);
    }
    set.add(connection);
    return connection;
  }

  remove(connection: Connection): void {
    if (connection.kind === 'guardian') {
      const set = this.guardians.get(connection.guardianId);
      set?.delete(connection);
      if (set && set.size === 0) this.guardians.delete(connection.guardianId);
    } else {
      const set = this.devices.get(connection.deviceId);
      set?.delete(connection);
      if (set && set.size === 0) this.devices.delete(connection.deviceId);
    }
  }

  /** Envia a todas as sessoes da conta, exceto a que originou a mudanca, se informada. */
  toGuardian(guardianId: string, message: ServerMessage, exceptSessionId?: string | null): void {
    const set = this.guardians.get(guardianId);
    if (!set) return;
    const payload = JSON.stringify(message);
    for (const connection of set) {
      if (exceptSessionId && connection.sessionId === exceptSessionId) continue;
      send(connection.socket, payload);
    }
  }

  toDevice(deviceId: string, message: ServerMessage): void {
    const set = this.devices.get(deviceId);
    if (!set) return;
    const payload = JSON.stringify(message);
    for (const connection of set) send(connection.socket, payload);
  }

  isDeviceOnline(deviceId: string): boolean {
    return (this.devices.get(deviceId)?.size ?? 0) > 0;
  }

  /** Avisa o aparelho de que o vinculo acabou e fecha as conexoes dele. */
  revokeDevice(deviceId: string): void {
    const set = this.devices.get(deviceId);
    if (!set) return;
    const payload = JSON.stringify({ type: 'revoked' });
    for (const connection of [...set]) {
      send(connection.socket, payload);
      closeSocket(connection.socket, CLOSE_UNAUTHORIZED, 'revoked');
      this.remove(connection);
    }
  }

  /** Fecha as conexoes de uma sessao revogada. */
  closeSession(guardianId: string, sessionId: string): void {
    const set = this.guardians.get(guardianId);
    if (!set) return;
    for (const connection of [...set]) {
      if (connection.sessionId !== sessionId) continue;
      closeSocket(connection.socket, CLOSE_UNAUTHORIZED, 'session');
      this.remove(connection);
    }
  }

  /** Fecha todas as conexoes de uma conta (exclusao da conta ou troca de senha). */
  closeGuardian(guardianId: string, exceptSessionId?: string | null): void {
    const set = this.guardians.get(guardianId);
    if (!set) return;
    for (const connection of [...set]) {
      if (exceptSessionId && connection.sessionId === exceptSessionId) continue;
      closeSocket(connection.socket, CLOSE_UNAUTHORIZED, 'session');
      this.remove(connection);
    }
  }

  /** Encerra conexoes sem trafego ha mais de 90 segundos. */
  sweepIdle(now: number): number {
    let closed = 0;
    const all: Connection[] = [];
    for (const set of this.guardians.values()) all.push(...set);
    for (const set of this.devices.values()) all.push(...set);
    for (const connection of all) {
      if (now - connection.lastSeen <= IDLE_MS) continue;
      closeSocket(connection.socket, CLOSE_IDLE, 'idle');
      this.remove(connection);
      closed += 1;
    }
    return closed;
  }

  closeAll(): void {
    const all: Connection[] = [];
    for (const set of this.guardians.values()) all.push(...set);
    for (const set of this.devices.values()) all.push(...set);
    for (const connection of all) {
      closeSocket(connection.socket, 1001, 'shutdown');
      this.remove(connection);
    }
  }

  get connectionCount(): number {
    let total = 0;
    for (const set of this.guardians.values()) total += set.size;
    for (const set of this.devices.values()) total += set.size;
    return total;
  }
}
