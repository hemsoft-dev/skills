import contextlib
from dataclasses import replace
from datetime import datetime, timedelta, timezone
from email.message import EmailMessage
import importlib.util
import io
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import Mock, patch

SCRIPTS = Path(__file__).resolve().parents[1] / 'scripts'
sys.path.insert(0, str(SCRIPTS))
import booking_guard as guard
import cleanup_hemmer_us as cleanup


class BookingGuardTests(unittest.TestCase):
    def message(self, uid='1', subject='Reservation for Amelia Island, Oct 12-18',
                body='Check-in October 12, 2026. Checkout October 18, 2026.',
                received='2026-09-28T12:00:00+00:00', **extra):
        return cleanup.Message(folder='INBOX', uid=uid, received=datetime.fromisoformat(received),
            sender_address=extra.pop('sender_address', 'express@airbnb.com'), sender_name='Airbnb',
            subject=subject, message_id=extra.pop('message_id', '<booking-'+uid+'>'), body=body, **extra)

    def decision(self, message, now='2026-10-06T07:00:00+00:00', others=()):
        when=datetime.fromisoformat(now)
        holds=guard.booking_holds([message,*others], when)
        return cleanup.classify(message, when-timedelta(days=3), when-timedelta(days=7), holds)

    def test_known_airbnb_booking_is_excluded_when_old_enough_for_trash(self):
        m=self.message()
        self.assertEqual(('trash','Airbnb'), cleanup.classify_rule(m, datetime(2026,10,3,tzinfo=timezone.utc), datetime(2026,9,29,tzinfo=timezone.utc)))
        self.assertIsNone(self.decision(m))

    def test_booking_remains_protected_on_checkout_day(self):
        self.assertIsNone(self.decision(self.message(), '2026-10-19T03:59:00+00:00'))

    def test_known_eastern_booking_reverts_to_existing_rule_after_end_date(self):
        self.assertEqual(('trash','Airbnb'),self.decision(self.message(), '2026-10-19T07:00:00+00:00'))

    def test_ambiguous_dates_are_retained_even_when_header_is_old(self):
        self.assertIsNone(self.decision(self.message(body='Your reservation. Check-in Oct 12, checkout Oct 18.'), '2027-01-01T00:00:00+00:00'))

    def test_incomplete_booking_text_is_retained(self):
        self.assertIsNone(self.decision(self.message(body_complete=False)))

    def test_unavailable_travel_provider_body_is_held_even_with_generic_subject(self):
        self.assertIsNone(self.decision(self.message(subject='New message from your host',body='',body_complete=False)))

    def test_conflicting_same_timestamp_updates_are_not_used_to_release_booking(self):
        old=self.message(body='Booking reference ABC123. Check-in October 12, 2026. Checkout October 18, 2026.')
        update=self.message(uid='2',subject='Reservation canceled',body='Booking reference ABC123.')
        self.assertIsNone(self.decision(old,others=[update]))

    def test_cancelled_reference_retires_earlier_confirmation(self):
        old=self.message(body='Booking reference ABC123. Check-in October 12, 2026. Checkout October 18, 2026.')
        cancellation=self.message(uid='2',subject='Your reservation has been canceled',body='Booking reference ABC123.', received='2026-10-02T12:00:00+00:00')
        self.assertEqual(('trash','Airbnb'),self.decision(old,others=[cancellation]))

    def test_cancellation_request_does_not_remove_protection(self):
        old=self.message(body='Booking reference ABC123. Check-in October 12, 2026. Checkout October 18, 2026.')
        pending=self.message(uid='2',subject='Your reservation cancellation request',body='Booking reference ABC123. Request received.',received='2026-10-02T12:00:00+00:00')
        self.assertIsNone(self.decision(old,others=[pending]))

    def test_conflicting_status_is_held_for_review(self):
        m=self.message(body='Your reservation has been canceled. Your reservation is confirmed. Booking reference ABC123.')
        self.assertIsNone(self.decision(m))

    def test_clear_body_cancellation_for_same_reference_retires_confirmation(self):
        old=self.message(body='Booking reference ABC123. Check-in October 12, 2026. Checkout October 18, 2026.')
        new=self.message(uid='2',subject='Update about your reservation',body='Booking reference ABC123. Your reservation has been canceled.',received='2026-10-02T12:00:00+00:00')
        self.assertEqual(('trash','Airbnb'),self.decision(old,others=[new]))

    def test_unrelated_cancellation_never_releases_active_booking(self):
        old=self.message(body='Booking reference ABC123. Check-in October 12, 2026. Checkout October 18, 2026.')
        other=self.message(uid='2',subject='Reservation canceled',body='Booking reference DIFFERENT456.',received='2026-10-02T12:00:00+00:00')
        self.assertIsNone(self.decision(old,others=[other]))

    def test_new_rescheduled_dates_extend_protection_for_earlier_correspondence(self):
        old=self.message(body='Booking reference ABC123. Check-in October 12, 2026. Checkout October 18, 2026.')
        update=self.message(uid='2',subject='Reservation updated',body='Booking reference ABC123. Check-in November 12, 2026. Checkout November 18, 2026.',received='2026-10-02T12:00:00+00:00')
        self.assertIsNone(self.decision(old,'2026-10-20T07:00:00+00:00',others=[update]))

    def test_reschedule_without_new_dates_is_held_past_original_end(self):
        old=self.message(body='Booking reference ABC123. Check-in October 12, 2026. Checkout October 18, 2026.')
        update=self.message(uid='2',subject='Reservation updated',body='Booking reference ABC123. Your reservation was rescheduled.',received='2026-10-02T12:00:00+00:00')
        self.assertIsNone(self.decision(old,'2026-10-20T07:00:00+00:00',others=[update]))

    def test_thread_reference_links_clear_cancellation_without_booking_code(self):
        old=self.message()
        update=self.message(uid='2',subject='Reservation canceled',body='',received='2026-10-02T12:00:00+00:00',references=(old.message_id,))
        self.assertEqual(('trash','Airbnb'),self.decision(old,others=[update]))

    def test_unknown_destination_is_not_released_before_end_date_passes_everywhere(self):
        m=self.message(subject='Your reservation',body='Check-in October 12, 2026. Checkout October 18, 2026.')
        self.assertIsNone(self.decision(m,'2026-10-19T07:00:00+00:00'))
        self.assertEqual(('trash','Airbnb'),self.decision(m,'2026-10-20T00:00:00+00:00'))

    def test_rescheduled_destination_does_not_inherit_original_timezone(self):
        old=self.message(body='Booking reference ABC123. Check-in October 12, 2026. Checkout October 18, 2026.')
        update=self.message(uid='2',subject='Reservation updated',body='Booking reference ABC123. Your reservation for Hawaii. Check-in October 12, 2026. Checkout October 18, 2026.',received='2026-10-02T12:00:00+00:00')
        self.assertIsNone(self.decision(old,'2026-10-19T07:00:00+00:00',others=[update]))

    def test_email_timestamp_timezone_does_not_establish_destination_timezone(self):
        m=self.message(subject='Your reservation for Hawaii',body='Check-in October 12, 2026. Checkout October 18, 2026. Notification sent at 8 AM EDT.')
        self.assertIsNone(self.decision(m,'2026-10-19T07:00:00+00:00'))

    def test_airbnb_promotion_keeps_existing_cleanup_behavior(self):
        m=self.message(subject='Plan your next vacation',body='Make a reservation now and save ten percent.')
        self.assertEqual(('trash','Airbnb'),self.decision(m))

    def test_unrelated_approved_rules_are_unchanged(self):
        m=self.message(subject='Daily newsletter',body='News and updates',sender_address='no-reply@email.claude.com')
        self.assertEqual(('trash','Claude Team'),self.decision(m))

    def test_invalid_or_conflicting_dates_stay_protected(self):
        for body in ['Check-in October 32, 2026. Checkout November 2, 2026.',
                     'Check-in October 12, 2026. Checkout October 18, 2026. New dates November 12, 2026 to November 18, 2026.']:
            self.assertIsNone(self.decision(self.message(body=body)))

    def test_explicit_iso_and_month_ranges_are_supported(self):
        self.assertEqual((datetime(2026,10,12).date(),datetime(2026,10,18).date()),guard.booking_dates('October 12-18, 2026'))
        self.assertEqual((datetime(2026,10,12).date(),datetime(2026,10,18).date()),guard.booking_dates('2026-10-12 to 2026-10-18'))

    def test_protected_deleted_source_is_not_expunged(self):
        client=Mock()
        when=datetime(2026,10,6,tzinfo=timezone.utc)
        with patch.object(cleanup,'fetch_messages',return_value=[self.message()]):
            expunged,held=cleanup.expunge_verified_sources(client,['INBOX'],when-timedelta(days=3),when-timedelta(days=7),[self.message()])
        self.assertEqual({},expunged)
        self.assertEqual('not-an-approved-match',held[0]['reason'])
        client.expunge.assert_not_called()
        client.uid.assert_not_called()

    def test_booking_body_fetch_is_readonly_peek_and_ignores_attachments(self):
        full=EmailMessage();full['Subject']='Your reservation';full.set_content('Check-in October 12, 2026. Checkout October 18, 2026.')
        full.add_attachment(b'private attachment',maintype='application',subtype='octet-stream',filename='attachment.bin')
        client=Mock();client.uid.return_value=('OK',[(b'1 (UID 1)',full.as_bytes())])
        text,complete=cleanup.booking_body(client,'1')
        self.assertTrue(complete);self.assertIn('October 18',text);self.assertNotIn('private attachment',text)
        client.uid.assert_called_once_with('FETCH','1','(UID BODY.PEEK[])')

    def test_body_fetch_failure_is_ambiguous_not_cleanup_permission(self):
        client=Mock();client.uid.return_value=('NO',[])
        text,complete=cleanup.booking_body(client,'1')
        self.assertFalse(complete)
        self.assertIsNone(self.decision(self.message(body=text,body_complete=complete)))


if __name__ == '__main__': unittest.main()
