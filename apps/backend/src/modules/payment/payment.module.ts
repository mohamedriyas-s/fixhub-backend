import { Module } from '@nestjs/common';

import { QueueModule } from '../../common/queue/queue.module';
import { RedisModule } from '../../common/redis/redis.module';
import { AdminModule } from '../admin/admin.module';
import { BookingModule } from '../booking/booking.module';
import { NotificationModule } from '../notification/notification.module';
import { TrackingModule } from '../tracking/tracking.module';
import { AdminPaymentController } from './controllers/admin-payment.controller';
import { PaymentController } from './controllers/payment.controller';
import { PaymentWebhookProcessor } from './processors/payment-webhook.processor';
import { PaymentRepository } from './repositories/payment.repository';
import { PaymentService } from './services/payment.service';
import { RazorpayGatewayService } from './services/razorpay-gateway.service';

@Module({
  imports: [
    QueueModule,
    RedisModule,
    BookingModule,
    NotificationModule,
    AdminModule,
    TrackingModule,
  ],
  controllers: [PaymentController, AdminPaymentController],
  providers: [PaymentService, RazorpayGatewayService, PaymentRepository, PaymentWebhookProcessor],
  exports: [PaymentService],
})
export class PaymentModule {}
