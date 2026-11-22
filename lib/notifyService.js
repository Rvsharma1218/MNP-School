/**
 * Helper to trigger real-time FCM Push Notifications across all registered
 * mobile devices (even when app is killed or screen is locked).
 */
export async function triggerPushNotification({ title, body, channelId, channelName, payload, schoolId }) {
  try {
    const res = await fetch('/api/send-push', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        title,
        body,
        channelId: channelId || 'school_notices_channel',
        channelName: channelName || 'School Notices & Circulars',
        payload: payload || '',
        schoolId: schoolId || 'SCHOOL_007'
      })
    });
    return await res.json();
  } catch (err) {
    console.warn('[Push Notification trigger note]:', err.message);
    return null;
  }
}
