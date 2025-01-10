import nodemailer from "nodemailer";
import { ENV } from "@/config/env";
import { logger } from "@/config/logger";
import { getVerificationEmailTemplate } from '@/templates/emails';

export class EmailService {
  private transporter!: nodemailer.Transporter;
  private readonly fromAddress: string;

  constructor() {
    // Production SMTP setup
    this.transporter = nodemailer.createTransport({
      host: ENV.SMTP_HOST,
      port: ENV.SMTP_PORT,
      secure: ENV.SMTP_PORT === 465,
      auth: {
        user: ENV.SMTP_USER,
        pass: ENV.SMTP_PASSWORD,
      },
      tls: {
        rejectUnauthorized: true
      }
    });
    this.fromAddress = ENV.SMTP_FROM || 'noreply@example.com';
    
    logger.info("Using SMTP configuration", {
      context: "EmailService.constructor",
      host: ENV.SMTP_HOST,
    });

    // Add email template precompilation
    this.precompileTemplates();
    
    // Add connection testing
    this.testConnection();
  }

  private async testConnection() {
    try {
      await this.transporter.verify();
      logger.info("SMTP connection verified");
    } catch (error) {
      logger.error("SMTP connection failed", { error });
    }
  }

  private precompileTemplates() {
    // Currently we only have one template, but this method can be expanded
    // as more templates are added
    try {
      getVerificationEmailTemplate('test', 'test'); // Pre-compile by running once
      logger.info("Email templates precompiled successfully");
    } catch (error) {
      logger.error("Failed to precompile email templates", { error });
    }
  }

  async sendVerificationEmail(
    to: string,
    name: string,
    verificationToken: string
  ): Promise<void> {
    const verificationUrl = `${ENV.SERVER_URL}/api/auth/verify-email/${verificationToken}`;

    try {
      const info = await this.transporter.sendMail({
        from: this.fromAddress,
        to,
        subject: "Verify your email address",
        html: getVerificationEmailTemplate(name, verificationUrl),
      });

      logger.info("Verification email sent", {
        context: "EmailService.sendVerificationEmail",
        to,
        messageId: info.messageId,
      });
    } catch (error) {
      logger.error("Failed to send verification email", {
        context: "EmailService.sendVerificationEmail",
        error: error instanceof Error ? error.message : "Unknown error",
        to,
      });
      throw error;
    }
  }
} 