import { IsOptional, IsString, IsUrl, MaxLength } from 'class-validator';

/// Merchant marks the VAT invoice as issued for an order. The actual PDF
/// is hosted externally (e.g. uploaded to the merchant's invoice provider)
/// and the URL is stored here so the customer can download it from the
/// order detail screen.
export class IssueInvoiceDto {
  @IsOptional()
  @IsString()
  @IsUrl({ require_protocol: true })
  @MaxLength(2048)
  invoiceFileUrl?: string;
}
