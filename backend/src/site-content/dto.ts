import { IsDefined, IsObject } from 'class-validator';

export class UpdateSiteContentDto {
  /// Free-form content object; shape validated server-side per key.
  @IsDefined()
  @IsObject()
  data!: Record<string, unknown>;
}
