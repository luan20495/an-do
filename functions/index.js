const {initializeApp} = require("firebase-admin/app");
const {getDatabase} = require("firebase-admin/database");
const {getMessaging} = require("firebase-admin/messaging");
const {onValueCreated} = require("firebase-functions/v2/database");
const {setGlobalOptions} = require("firebase-functions/v2");

initializeApp();
setGlobalOptions({region: "asia-southeast1"});

/**
 * When a SOS chat message is created, push FCM to the other participant.
 * Path: sos_chats/{sosId}/{helperId}/messages/{msgId}
 */
exports.onSosChatMessageCreated = onValueCreated(
  {
    ref: "sos_chats/{sosId}/{helperId}/messages/{msgId}",
    instance: "fir-integration-4405d-default-rtdb",
  },
  async (event) => {
    const sosId = event.params.sosId;
    const helperId = event.params.helperId;
    const msg = event.data.val() || {};
    const senderId = msg.senderId;
    if (!senderId) return;

    const db = getDatabase();
    const sosSnap = await db.ref(`active_sos/${sosId}`).get();
    if (!sosSnap.exists()) return;
    const ownerId = sosSnap.val().ownerId;
    if (!ownerId) return;

    const recipientId = senderId === ownerId ? helperId : ownerId;
    if (!recipientId || recipientId === senderId) return;

    const tokenSnap = await db.ref(`user_tokens/${recipientId}/token`).get();
    const token = tokenSnap.val();
    if (!token) {
      console.log("No FCM token for", recipientId);
      return;
    }

    const isAudio = msg.type === "audio";
    const body = isAudio
      ? "Tin audio mới trong phiên SOS"
      : (msg.text || "Tin nhắn mới trong phiên SOS");

    await getMessaging().send({
      token,
      notification: {
        title: "An Đồ · SOS chat",
        body: String(body).slice(0, 120),
      },
      data: {
        sosId: String(sosId),
        helperId: String(helperId),
        ownerId: String(ownerId),
        type: "sos_chat",
      },
      android: {
        priority: "high",
      },
    });
  },
);
