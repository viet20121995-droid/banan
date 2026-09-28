import { createHmac } from 'node:crypto';

import { EmailService } from '../notifications/email.service';

import { GrokClient } from './grok.client';
import { MetaGraphClient, splitForMessenger } from './meta-graph.client';
import {
  buildSystemPrompt,
  formatHours,
  HANDOFF_MARKER,
  MetaInboxKnowledge,
} from './meta-inbox.knowledge';
import { MetaInboxService } from './meta-inbox.service';
import { IncomingMessage, parseMetaWebhook } from './meta-events';
import { isValidMetaSignature } from './meta-signature';

const PAGE = '111';
const USER = '999';

function messaging(message: Record<string, unknown>, from = USER, to = PAGE) {
  return {
    object: 'page',
    entry: [
      {
        id: PAGE,
        messaging: [
          { sender: { id: from }, recipient: { id: to }, timestamp: Date.now(), message },
        ],
      },
    ],
  };
}

describe('isValidMetaSignature', () => {
  const body = Buffer.from('{"object":"page"}');
  const sig = `sha256=${createHmac('sha256', 'secret').update(body).digest('hex')}`;

  it('accepts the HMAC of the raw body', () => {
    expect(isValidMetaSignature(body, sig, 'secret')).toBe(true);
  });

  it('rejects a wrong secret, a tampered body, or a missing header', () => {
    expect(isValidMetaSignature(body, sig, 'other')).toBe(false);
    expect(isValidMetaSignature(Buffer.from('{"object":"x"}'), sig, 'secret')).toBe(false);
    expect(isValidMetaSignature(body, undefined, 'secret')).toBe(false);
    expect(isValidMetaSignature(body, 'sha1=abc', 'secret')).toBe(false);
    expect(isValidMetaSignature(body, sig, '')).toBe(false);
  });
});

describe('parseMetaWebhook', () => {
  it('extracts customer text messages', () => {
    const [e] = parseMetaWebhook(messaging({ mid: 'm1', text: ' Bánh giá bao nhiêu? ' }));
    expect(e).toMatchObject({
      kind: 'incoming',
      channel: 'messenger',
      pageId: PAGE,
      userId: USER,
      text: 'Bánh giá bao nhiêu?',
    });
  });

  it('marks attachments and maps instagram', () => {
    const payload = {
      ...messaging({ mid: 'm2', attachments: [{ type: 'image' }] }),
      object: 'instagram',
    };
    expect(parseMetaWebhook(payload)[0]).toMatchObject({
      channel: 'instagram',
      text: '',
      hasAttachment: true,
    });
  });

  it('turns page echoes into echo events addressed to the customer', () => {
    const [e] = parseMetaWebhook(
      messaging({ mid: 'm3', text: 'hi', is_echo: true, app_id: 42 }, PAGE, USER),
    );
    expect(e).toMatchObject({ kind: 'echo', userId: USER, appId: '42' });
  });

  it('ignores unknown objects, reads and page-sent non-echoes', () => {
    expect(parseMetaWebhook({ object: 'user', entry: [] })).toEqual([]);
    expect(
      parseMetaWebhook({
        object: 'page',
        entry: [
          { id: PAGE, messaging: [{ sender: { id: USER }, recipient: { id: PAGE }, read: {} }] },
        ],
      }),
    ).toEqual([]);
    expect(parseMetaWebhook(messaging({ mid: 'm4', text: 'x' }, PAGE, USER))).toEqual([]);
    expect(parseMetaWebhook(null)).toEqual([]);
  });
});

describe('knowledge helpers', () => {
  it('groups equal opening hours', () => {
    const h = Object.fromEntries(
      ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'].map((d) => [d, [['10:00', '21:30']]]),
    );
    expect(formatHours({ ...h, sun: [] })).toBe('T2–T7 10:00–21:30; CN nghỉ');
  });

  it('puts the handoff marker and data into the prompt', () => {
    const p = buildSystemPrompt(['- Store A'], ['- [Bánh] Cake: 100.000đ']);
    expect(p).toContain(HANDOFF_MARKER);
    expect(p).toContain('- Store A');
    expect(p).toContain('Cake: 100.000đ');
  });

  it('splits long replies under the Messenger cap', () => {
    const chunks = splitForMessenger(('a'.repeat(900) + '\n').repeat(5), 2000);
    expect(chunks.length).toBeGreaterThan(1);
    expect(chunks.every((c) => c.length <= 2000)).toBe(true);
  });
});

describe('MetaInboxService', () => {
  let grok: { reply: jest.Mock };
  let graph: { sendText: jest.Mock; typing: jest.Mock };
  let email: { sendRaw: jest.Mock };
  let svc: MetaInboxService;
  const key = `messenger:${PAGE}:${USER}`;
  const incoming = (text: string, mid = `m-${Math.random()}`): IncomingMessage => ({
    kind: 'incoming',
    channel: 'messenger',
    pageId: PAGE,
    userId: USER,
    mid,
    text,
    hasAttachment: false,
    timestamp: Date.now(),
  });

  beforeEach(() => {
    process.env.META_BOT_ENABLED = 'true';
    process.env.META_APP_ID = '42';
    process.env.META_BOT_HANDOFF_TO = 'ops@banancakes.vn';
    grok = { reply: jest.fn().mockResolvedValue('Dạ bánh 100.000đ ạ') };
    graph = {
      sendText: jest.fn().mockResolvedValue(true),
      typing: jest.fn().mockResolvedValue(undefined),
    };
    email = { sendRaw: jest.fn().mockResolvedValue(true) };
    const knowledge = { systemPrompt: jest.fn().mockResolvedValue('SYS') };
    svc = new MetaInboxService(
      grok as unknown as GrokClient,
      graph as unknown as MetaGraphClient,
      knowledge as unknown as MetaInboxKnowledge,
      email as unknown as EmailService,
    );
  });

  afterEach(() => {
    delete process.env.META_BOT_ENABLED;
    delete process.env.META_APP_ID;
    delete process.env.META_BOT_HANDOFF_TO;
    jest.useRealTimers();
  });

  it('replies once to a debounced burst, with both messages as context', async () => {
    jest.useFakeTimers();
    svc.handle([incoming('chào shop'), incoming('bánh giá sao')]);
    await jest.runAllTimersAsync();
    expect(grok.reply).toHaveBeenCalledTimes(1);
    expect(grok.reply.mock.calls[0][1]).toEqual([
      { role: 'user', content: 'chào shop\nbánh giá sao' },
    ]);
    expect(graph.sendText).toHaveBeenCalledWith(USER, 'Dạ bánh 100.000đ ạ');
  });

  it('does nothing when the bot is disabled', async () => {
    jest.useFakeTimers();
    process.env.META_BOT_ENABLED = 'false';
    svc.handle([incoming('hi')]);
    await jest.runAllTimersAsync();
    expect(grok.reply).not.toHaveBeenCalled();
  });

  it('ignores duplicate deliveries of the same message', async () => {
    jest.useFakeTimers();
    const e = incoming('hi', 'dup');
    svc.handle([e]);
    svc.handle([e]);
    await jest.runAllTimersAsync();
    expect(grok.reply).toHaveBeenCalledTimes(1);
  });

  it('goes quiet after a human (other app) replies, but not after its own echoes', () => {
    svc.handle([
      {
        kind: 'echo',
        channel: 'messenger',
        pageId: PAGE,
        userId: USER,
        mid: 'e1',
        appId: '42',
        timestamp: Date.now(),
      },
    ]);
    expect(svc.isPaused(key)).toBe(false);
    svc.handle([
      {
        kind: 'echo',
        channel: 'messenger',
        pageId: PAGE,
        userId: USER,
        mid: 'e2',
        appId: '263902037430900',
        timestamp: Date.now(),
      },
    ]);
    expect(svc.isPaused(key)).toBe(true);
  });

  it('strips the handoff marker, pauses and alerts staff', async () => {
    grok.reply.mockResolvedValue(`Dạ em chuyển nhân viên ạ ${HANDOFF_MARKER}`);
    await svc.respond(key, [incoming('làm bánh vẽ hình được không')]);
    expect(graph.sendText).toHaveBeenCalledWith(USER, 'Dạ em chuyển nhân viên ạ');
    expect(svc.isPaused(key)).toBe(true);
    expect(email.sendRaw).toHaveBeenCalledWith(
      expect.objectContaining({ toEmail: 'ops@banancakes.vn' }),
    );
  });

  it('falls back to a holding message when Grok is down', async () => {
    grok.reply.mockResolvedValue(null);
    await svc.respond(key, [incoming('hi')]);
    expect(graph.sendText).toHaveBeenCalledWith(USER, expect.stringContaining('nhân viên tiệm'));
    expect(svc.isPaused(key)).toBe(true);
  });
});
