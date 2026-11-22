import { NextResponse } from 'next/server';
import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { getFirestore } from 'firebase-admin/firestore';

const serviceAccount = {
  type: "service_account",
  project_id: "mnpschool-bb50b",
  private_key_id: "54026ff323167810a9b01365c9feb6ca9be84f79",
  private_key: "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDNohcQ/55+hWgN\np4F0VaqkS9fbcpMmh8PjMZmyAE8oonJ0ETHkvxTBbBTTO7JxCGC5T8Y1eX4rNGhc\nVPGeGOE6wUEvi+bcfMjK/XV80QVKleHSGK/Ei6RXAUkOm485y9FjCTihLAwcj907\nHqX5FybkmVkY2a7cpg1NUaJsD1n4/BvGE7kCkCmK4oYHL0EX07AEk2HExbeYFf2A\n9QJZg+giCAZ6yk8+/oNHo82Hz7IuzpZM3+nivRGLtrSgX+0JfoFsB1veYIxJ7KNf\nenade2mCg5mct9Dh++0T/b9rrP+0ba0tVFjcMjuJPkgEPdqZlcwl9Mj4fnD4H4h5\nZ4/b+TAJAgMBAAECggEABFEmW25AKUOnjm/UAoCkduGYLeHQz98vLmkAMVVwfqmW\nn+zlRAFRECZdeo8B3Sh1gdLjAL1WopyC217umb4O6t9i0l5ajjS4/24vm3C90jlz\nsxKmNx4/twQ5JEesC6wMtfxN0sycdXthJ4iN4RJf4pIZew3v/Cfv8yo8b+Oauk95\n31zzYEukbSo0Y/zoBePZAUywxm1KbxN1oZkpVXIVxKsuBeGEQNcLDbqt33c8PFwF\nG4FF4vELa9pdC4u6phlR0sWnGWWL0oXtHegt0/vP5D8zmBE3VQPt0Scn/NZ/Bk8B\nCilQmaS2Fk1+uvhwUM+iCMrFSiAxLjjX421czrC2nQKBgQD0KEeR6a97mRMF/CBK\nzWkSJ7BmkVIuHuu3o56PWzbRGcM+MpNlqVrm9X+zXBJIVs7SMdTdWkhi2mfcLbba\nh47jhQK1K7jpsn8/7uR6vFYvCwIam18q9IkmFk27Giy2c6lbTrP5JvPbVhUM9u5t\nKXZoA6XVsPp6lMlpkbL8b8AnlQKBgQDXm3PvFko8Q3gEu+OnQYkFi9Gd5KqPikBU\nYJVTeLdYWyUEc9ww48R92opYxolS/eSwee19bKWMz8UMA+PmX/mAyWw4b0Wqy+c0\nQw2psOhjODtCnk/qqVNiVxoiwwZN+NJK5xqfLKJrpo2CL+G8O0OINrAU9gBqBd17\nvM6LkTG5pQKBgD62DdPzgsgrRBCYdq7f3an1GcDueH4yIPc1Bmfp1MWWaWiTUvqc\nqiWCTv+BmYyNB2hDtln4c3k4gc6yyzGL+e6EXnKsPT2BRF/mezbvIu/IUw0EdUgy\nMPvgZKy3B18BjDFQoLdRAveGP7fpwMm3CZujvDeL0nojtyvvaVqfVWqVAoGACLR4\nC9EkkiZPNDG50UjuFVE911giIsV8L2vu233mOSUE65cZ7sdjaYlnSIpLhRRHJXDm\ny8eVL4g79m45x1Vcp3x6aBTmBS1SWmPSq2U/HLJqghgONfU8Lp5BqeGh4YgIRYnr\nIz4UGLCSygzQ2l6yLU+38EC2Z5FxDcvjsvLbxRkCgYEA5JYoxlZ7gSlQNhkl0RLQ\nYmW1g2B1bzrfL7hfz0QkEw/IzswxzYJzY3APo7CWJ8dyWCoKcGJKZS3dzxGJc3/m\ndAuDMwWtl8GTHlQPmYxS2hx9Kj7C2LN28o7qndbE6wUQx8O0NEGnRd2QM8S99jS3\nQwOvyA3IE0WdBLD4WEfXvQo=\n-----END PRIVATE KEY-----\n",
  client_email: "firebase-adminsdk-fbsvc@mnpschool-bb50b.iam.gserviceaccount.com",
  client_id: "103949808061409297679"
};

function getAdminApp() {
  if (getApps().length === 0) {
    return initializeApp({
      credential: cert(serviceAccount)
    });
  }
  return getApps()[0];
}

export async function POST(request) {
  try {
    const body = await request.json();
    const {
      title = 'School Alert',
      body: content = '',
      channelId = 'school_notices_channel',
      channelName = 'School Notices & Circulars',
      payload = '',
      topic,
      schoolId = 'SCHOOL_007'
    } = body;

    const adminApp = getAdminApp();
    const messaging = getMessaging(adminApp);
    const db = getFirestore(adminApp);

    // 1. Gather all registered device tokens for the school
    const tokensSet = new Set();
    const targetSchools = [schoolId, 'SCHOOL_007', 'SCHOOL_001'];

    for (const sId of targetSchools) {
      try {
        const snap = await db.collection('schools').doc(sId).collection('fcm_tokens').get();
        snap.forEach(docSnap => {
          const t = docSnap.data()?.token || docSnap.id;
          if (t && typeof t === 'string' && t.length > 20) {
            tokensSet.add(t);
          }
        });
      } catch (err) {
        console.warn(`Error fetching tokens for ${sId}:`, err.message);
      }
    }

    const tokensList = Array.from(tokensSet);
    console.log(`[FCM API] Sending push to ${tokensList.length} devices for: "${title}"`);

    const messageTemplate = {
      notification: {
        title: title,
        body: content,
      },
      data: {
        title: title,
        body: content,
        channelId: channelId,
        channelName: channelName,
        payload: payload || '',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: channelId,
          sound: 'default',
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
        }
      }
    };

    const results = [];

    // 2. Send direct push to all registered devices
    for (const t of tokensList) {
      try {
        const res = await messaging.send({
          ...messageTemplate,
          token: t
        });
        results.push({ token: t.substring(0, 15) + '...', success: true, messageId: res });
      } catch (sendErr) {
        console.warn('Push error for token:', t.substring(0, 15), sendErr.message);
        results.push({ token: t.substring(0, 15) + '...', success: false, error: sendErr.message });
      }
    }

    // 3. Also send to topic if specified (or principal topic for enquiries/alerts)
    const effectiveTopic = topic || (channelId.includes('enquiry') ? `school_${schoolId}_principal` : `school_${schoolId}_notices`);
    try {
      const topicRes = await messaging.send({
        ...messageTemplate,
        topic: effectiveTopic
      });
      console.log(`[FCM API] Topic ${effectiveTopic} sent:`, topicRes);
    } catch (topicErr) {
      console.warn(`[FCM API] Topic send notice:`, topicErr.message);
    }

    return NextResponse.json({
      success: true,
      deliveredDevices: results.filter(r => r.success).length,
      totalDevices: tokensList.length,
      topic: effectiveTopic,
      results
    });
  } catch (error) {
    console.error('[FCM API Error]:', error);
    return NextResponse.json(
      { success: false, error: error.message || 'Internal error' },
      { status: 500 }
    );
  }
}
