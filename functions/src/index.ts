import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

const statusLabels: Record<number, string> = {
  1: 'Awaiting rider',
  2: 'Accepted',
  3: 'Picked up',
  4: 'En-route',
  5: 'Delivered',
  90: 'Cancelled by sender',
  91: 'Cancelled by rider',
};

export const assignRider = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required.');
  }
  const shipmentId = data.shipmentId as string | undefined;
  const riderUid = data.riderUid as string | undefined;
  if (!shipmentId || !riderUid) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing shipmentId or riderUid');
  }
  const shipmentRef = db.collection('shipments').doc(shipmentId);
  let accepted = false;
  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(shipmentRef);
    if (!snapshot.exists) {
      throw new functions.https.HttpsError('not-found', 'Shipment not found');
    }
    const data = snapshot.data()!;
    if (data.riderUid) {
      return;
    }
    tx.update(shipmentRef, {
      riderUid,
      statusCode: 2,
      statusLabel: statusLabels[2],
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(
      shipmentRef.collection('history').doc(),
      {
        code: 2,
        label: statusLabels[2],
        ts: admin.firestore.FieldValue.serverTimestamp(),
        byUid: riderUid,
      },
    );
    accepted = true;
  });
  return accepted;
});

export const onShipmentStatusWrite = functions.firestore
  .document('shipments/{sid}')
  .onWrite(async (change, context) => {
    if (!change.after.exists) {
      return;
    }
    const before = change.before.data();
    const after = change.after.data()!;
    if (
      before &&
      before.statusCode === after.statusCode &&
      before.statusLabel === after.statusLabel
    ) {
      return;
    }
    const recipients = new Set<string>();
    recipients.add(after.senderUid);
    recipients.add(after.receiverUid);
    if (after.riderUid) {
      recipients.add(after.riderUid);
    }
    const tokenDocs = await Promise.all(
      Array.from(recipients).map((uid) => db.collection('tokens').doc(uid).get()),
    );
    const tokens = tokenDocs
      .map((doc) => doc.data()?.fcmToken as string | undefined)
      .filter((token): token is string => !!token);
    if (tokens.length === 0) {
      return;
    }
    const payload: admin.messaging.MulticastMessage = {
      tokens,
      notification: {
        title: `Shipment update`,
        body: `${after.item?.name ?? 'Package'} → ${after.statusLabel}`,
      },
      data: {
        shipmentId: context.params.sid,
        statusCode: String(after.statusCode),
      },
    };
    await messaging.sendEachForMulticast(payload);
  });

export const validateNear = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required.');
  }
  const shipmentId = data.shipmentId as string | undefined;
  const lat = Number(data.lat);
  const lng = Number(data.lng);
  const code = Number(data.code);
  if (!shipmentId || Number.isNaN(lat) || Number.isNaN(lng)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid payload');
  }
  const snapshot = await db.collection('shipments').doc(shipmentId).get();
  if (!snapshot.exists) {
    throw new functions.https.HttpsError('not-found', 'Shipment missing');
  }
  const shipment = snapshot.data()!;
  let target: { lat: number; lng: number } | null = null;
  if (code === 3 && shipment.pickup?.lat && shipment.pickup?.lng) {
    target = { lat: shipment.pickup.lat, lng: shipment.pickup.lng };
  }
  if (code === 5 && shipment.dropoff?.lat && shipment.dropoff?.lng) {
    target = { lat: shipment.dropoff.lat, lng: shipment.dropoff.lng };
  }
  if (!target) {
    return false;
  }
  const distance = haversineMeters(lat, lng, target.lat, target.lng);
  return distance <= 20;
});

function haversineMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const toRad = (value: number) => (value * Math.PI) / 180;
  const R = 6371000;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}
