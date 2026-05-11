import { ValidationPipe, VersioningType } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import compression from 'compression';
import cookieParser from 'cookie-parser';
import express from 'express';
import helmet from 'helmet';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { Logger } from 'nestjs-pino';

import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { EnvelopeInterceptor } from './common/interceptors/envelope.interceptor';

async function bootstrap() {
  // `rawBody: true` lets the Stripe webhook controller verify the
  // `Stripe-Signature` header against the original byte stream.
  const app = await NestFactory.create(AppModule, {
    bufferLogs: true,
    rawBody: true,
  });
  app.useLogger(app.get(Logger));

  const config = app.get(ConfigService);

  app.use(
    helmet({
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    }),
  );
  app.use(compression());
  app.use(cookieParser());

  // Serve user-uploaded media — dev-only flow; M-later moves to S3 / R2.
  const uploadDir = join(process.cwd(), 'uploads');
  mkdirSync(uploadDir, { recursive: true });
  app.use('/uploads', express.static(uploadDir));

  app.enableCors({
    origin: (config.get<string>('CORS_ORIGINS') ?? '').split(',').filter(Boolean),
    credentials: true,
  });

  app.setGlobalPrefix('api');
  app.enableVersioning({ type: VersioningType.URI, defaultVersion: '1' });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  app.useGlobalInterceptors(new EnvelopeInterceptor());
  app.useGlobalFilters(new AllExceptionsFilter());

  if (config.get<string>('NODE_ENV') !== 'production') {
    const swagger = new DocumentBuilder()
      .setTitle('Banan API')
      .setDescription('Patisserie ordering platform — REST + WebSocket')
      .setVersion('1.0')
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, swagger);
    SwaggerModule.setup('api/docs', app, document);
  }

  const port = config.get<number>('PORT') ?? 3000;
  await app.listen(port);
  // eslint-disable-next-line no-console
  console.log(`Banan API listening on http://localhost:${port}`);
}

void bootstrap();
