// Entrada do servidor: le a configuracao, sobe o Fastify e liga as tarefas periodicas.

import { buildApp } from './app.ts';
import { loadConfig } from './config.ts';
import { HOUR_MS, MINUTE_MS } from './core/time.ts';
import { runFrequentTasks, runRetention } from './modules/retention/service.ts';

const FREQUENT_INTERVAL_MS = MINUTE_MS;
const IDLE_SWEEP_INTERVAL_MS = 30_000;
const RETENTION_INTERVAL_MS = 24 * HOUR_MS;
/** A primeira limpeza roda pouco depois da subida, para um servidor reiniciado todo dia. */
const RETENTION_FIRST_DELAY_MS = 2 * MINUTE_MS;

async function main(): Promise<void> {
  const config = loadConfig();
  const { app, ctx } = await buildApp(config);

  const guarded = (name: string, task: () => void) => () => {
    try {
      task();
    } catch (error) {
      app.log.error({ err: error, task: name }, 'tarefa periódica falhou');
    }
  };
  const retention = guarded('retention', () => {
    const result = runRetention(ctx);
    app.log.info({ result }, 'retenção aplicada');
  });

  const timers: NodeJS.Timeout[] = [
    setInterval(guarded('frequent', () => runFrequentTasks(ctx)), FREQUENT_INTERVAL_MS),
    setInterval(guarded('idle-sweep', () => ctx.hub.sweepIdle(ctx.now())), IDLE_SWEEP_INTERVAL_MS),
    setInterval(retention, RETENTION_INTERVAL_MS),
    setTimeout(retention, RETENTION_FIRST_DELAY_MS),
  ];
  for (const timer of timers) timer.unref();

  let closing = false;
  const shutdown = (signal: string): void => {
    if (closing) return;
    closing = true;
    app.log.info({ signal }, 'encerrando');
    for (const timer of timers) clearTimeout(timer);
    app.close().then(
      () => process.exit(0),
      (error: unknown) => {
        app.log.error({ err: error }, 'falha ao encerrar');
        process.exit(1);
      },
    );
  };
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));

  await app.listen({ port: config.port, host: config.host });
  if (config.env !== 'production') {
    app.log.warn('Ambiente de desenvolvimento: use HTTPS por um proxy reverso antes de expor o servidor.');
  }
}

main().catch((error: unknown) => {
  console.error('Falha ao iniciar o servidor:', error instanceof Error ? error.message : error);
  process.exit(1);
});
