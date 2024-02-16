#!/usr/bin/env node

import { parseArgs } from 'node:util';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { Downloader } from './index.js';

const { values: flags } = parseArgs({
  options: {
    concurrency: { type: 'string' },
    'range-start': { type: 'string' },
    'range-end': { type: 'string' },
  },
});

const { 'range-start': rangeStart, 'range-end': rangeEnd, concurrency } = flags;

const readHashes = await new Downloader({
  rangeStart,
  rangeEnd,
  concurrency: concurrency ? Number(concurrency) : undefined,
}).download();

await pipeline(
  Readable.from(readHashes()),
  async function* (hashes) {
    for await (const hash of hashes) {
      yield `${hash}\n`;
    }
  },
  process.stdout,
);
