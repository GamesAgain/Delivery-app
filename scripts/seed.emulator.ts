import * as admin from 'firebase-admin';

admin.initializeApp({ projectId: 'ddelivery-app' });
const db = admin.firestore();
db.settings({ host: 'localhost:8080', ssl: false });

async function seed() {
  console.log('Seeding emulator data...');
  const users = [
    {
      uid: 'sender1',
      role: 'user',
      phone: '+15550000001',
      name: 'Sender Sam',
    },
    {
      uid: 'receiver1',
      role: 'user',
      phone: '+15550000002',
      name: 'Receiver Riley',
    },
    {
      uid: 'rider1',
      role: 'rider',
      phone: '+15550000003',
      name: 'Rider Rowan',
    },
  ];
  for (const user of users) {
    await db.collection('users').doc(user.uid).set({
      role: user.role,
      phone: user.phone,
      name: user.name,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  await db
    .collection('users')
    .doc('sender1')
    .collection('addresses')
    .doc('home')
    .set({
      ownerUid: 'sender1',
      label: 'Sender HQ',
      fullAddress: '123 Sender Street',
      geo: { lat: 14.5995, lng: 120.9842 },
    });
  await db
    .collection('users')
    .doc('receiver1')
    .collection('addresses')
    .doc('home')
    .set({
      ownerUid: 'receiver1',
      label: 'Receiver Home',
      fullAddress: '456 Receiver Ave',
      geo: { lat: 14.6095, lng: 120.9892 },
    });

  const shipments = [
    {
      id: 'ship1',
      senderUid: 'sender1',
      receiverUid: 'receiver1',
      riderUid: 'rider1',
      statusCode: 3,
      statusLabel: 'Picked up',
    },
    {
      id: 'ship2',
      senderUid: 'sender1',
      receiverUid: 'receiver1',
      statusCode: 1,
      statusLabel: 'Awaiting rider',
    },
    {
      id: 'ship3',
      senderUid: 'sender1',
      receiverUid: 'receiver1',
      riderUid: 'rider1',
      statusCode: 5,
      statusLabel: 'Delivered',
    },
  ];
  for (const shipment of shipments) {
    await db.collection('shipments').doc(shipment.id).set({
      senderUid: shipment.senderUid,
      receiverUid: shipment.receiverUid,
      riderUid: shipment.riderUid ?? null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      pickup: { inline: '123 Sender Street', lat: 14.5995, lng: 120.9842 },
      dropoff: { inline: '456 Receiver Ave', lat: 14.6095, lng: 120.9892 },
      item: { name: `Sample Parcel ${shipment.id}` },
      statusCode: shipment.statusCode,
      statusLabel: shipment.statusLabel,
      sharedMap: true,
    });
    await db
      .collection('shipments')
      .doc(shipment.id)
      .collection('history')
      .doc()
      .set({
        code: shipment.statusCode,
        label: shipment.statusLabel,
        ts: admin.firestore.FieldValue.serverTimestamp(),
        byUid: shipment.riderUid ?? shipment.senderUid,
        photoURL: 'https://via.placeholder.com/300',
      });
  }
  console.log('Seed complete');
}

seed().then(() => process.exit(0));
